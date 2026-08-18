import { createHmac, randomInt, timingSafeEqual } from 'node:crypto';

import { createRemoteJWKSet, jwtVerify, SignJWT } from 'jose';

import {
  ACCESS_TOKEN_TTL_SECONDS,
  EMAIL_CODE_MAX_ATTEMPTS,
  EMAIL_CODE_TTL_MINUTES,
  ZERO_DATE,
} from '../constants.js';
import { AppError, ERROR_CODES } from '../errors.js';
import { accounts, clipboards, identifiers, loginCodes } from '../data/repos/index.js';

const GOOGLE_ISSUERS = ['https://accounts.google.com', 'accounts.google.com'];
const googleKeys = createRemoteJWKSet(new URL('https://www.googleapis.com/oauth2/v3/certs'));

function normalizeEmail(email) {
  return email.trim().toLowerCase();
}

function hashCode({ email, code, pepper }) {
  return createHmac('sha256', pepper).update(`${email}:${code}`).digest('hex');
}

function constantTimeEqual(left, right) {
  const leftBuffer = Buffer.from(left);
  const rightBuffer = Buffer.from(right);
  return leftBuffer.length === rightBuffer.length && timingSafeEqual(leftBuffer, rightBuffer);
}

/**
 * Creates authentication operations for email code and Google OpenID Connect sign-in.
 *
 * @param {object} dependencies - Validated config and email delivery service.
 * @returns {object} Authentication service.
 */
export function createAuthService({ config, emailService }) {
  const jwtKey = new TextEncoder().encode(config.jwtSecret);

  async function loadAccountAggregate(account) {
    const clipboard = await clipboards.findClipboardByAccountId({ accountId: account.id });
    if (!clipboard) {
      throw new Error('Account clipboard is missing.');
    }
    return { account, clipboard };
  }

  async function resolveByProvider({ email, providerId, providerIdentifier }) {
    const existingIdentifier = await identifiers.findAccountIdentifier({
      providerId,
      providerIdentifier,
    });
    if (existingIdentifier) {
      const account = await accounts.findAccountById({ accountId: existingIdentifier.accountId });
      if (!account) {
        throw new Error('Authentication identity has no active account.');
      }
      return loadAccountAggregate(account);
    }

    const existingAccount = await accounts.findAccountByEmail({ email });
    if (existingAccount) {
      await identifiers.addAccountIdentifier({
        accountId: existingAccount.id,
        providerId,
        providerIdentifier,
      });
      return loadAccountAggregate(existingAccount);
    }

    return accounts.createAccount({ email, providerId, providerIdentifier });
  }

  async function createAccessToken({ account, clipboard }) {
    const issuedAt = Math.floor(Date.now() / 1000);
    const expiresAt = issuedAt + ACCESS_TOKEN_TTL_SECONDS;
    const accessToken = await new SignJWT({
      accountUid: account.uid,
      clipboardUid: clipboard.uid,
      email: account.primaryEmail,
    })
      .setProtectedHeader({ alg: 'HS256', typ: 'JWT' })
      .setIssuedAt(issuedAt)
      .setExpirationTime(expiresAt)
      .setIssuer('clip-sync-api')
      .setAudience('clip-sync-clients')
      .sign(jwtKey);

    return {
      accessToken,
      expiresAt: new Date(expiresAt * 1000).toISOString(),
      account: {
        uid: account.uid,
        email: account.primaryEmail,
        clipboardUid: clipboard.uid,
      },
    };
  }

  return {
    /** Creates and emails one single-use six-digit challenge. */
    async requestEmailCode({ email }) {
      const normalizedEmail = normalizeEmail(email);
      const code = randomInt(0, 1_000_000).toString().padStart(6, '0');
      const expiresAt = new Date(Date.now() + EMAIL_CODE_TTL_MINUTES * 60 * 1000);
      const challenge = await loginCodes.createLoginCode({
        email: normalizedEmail,
        codeHash: hashCode({ email: normalizedEmail, code, pepper: config.authCodePepper }),
        expiresAt,
      });
      await emailService.sendSignInCode({
        email: normalizedEmail,
        code,
        expiresInMinutes: EMAIL_CODE_TTL_MINUTES,
      });
      return { challengeUid: challenge.uid, expiresAt: challenge.expiresAt.toISOString() };
    },

    /** Consumes a valid email challenge and returns a signed account token. */
    async verifyEmailCode({ challengeUid, code }) {
      const challenge = await loginCodes.findLoginCodeByUid({ challengeUid });
      if (!challenge || challenge.usedAt.getTime() !== ZERO_DATE.getTime()) {
        throw new AppError(401, ERROR_CODES.codeInvalid, 'The sign-in code is invalid.');
      }
      if (challenge.attempts >= EMAIL_CODE_MAX_ATTEMPTS) {
        throw new AppError(
          401,
          ERROR_CODES.codeAttemptsExceeded,
          'Too many incorrect attempts. Request a new code.',
        );
      }
      if (challenge.expiresAt.getTime() <= Date.now()) {
        throw new AppError(401, ERROR_CODES.codeExpired, 'The sign-in code has expired.');
      }

      const suppliedHash = hashCode({
        email: challenge.email,
        code,
        pepper: config.authCodePepper,
      });
      if (!constantTimeEqual(challenge.codeHash, suppliedHash)) {
        await loginCodes.incrementLoginCodeAttempts({
          challengeUid,
          attempts: challenge.attempts + 1,
        });
        throw new AppError(401, ERROR_CODES.codeInvalid, 'The sign-in code is invalid.');
      }

      const consumed = await loginCodes.consumeLoginCode({ challengeUid, usedAt: new Date() });
      if (!consumed) {
        throw new AppError(401, ERROR_CODES.codeInvalid, 'The sign-in code is invalid.');
      }
      const aggregate = await resolveByProvider({
        email: challenge.email,
        providerId: 'E',
        providerIdentifier: challenge.email,
      });
      return createAccessToken(aggregate);
    },

    /** Verifies a Google OIDC ID token and returns a Clip Sync access token. */
    async signInWithGoogle({ idToken }) {
      let payload;
      try {
        ({ payload } = await jwtVerify(idToken, googleKeys, {
          issuer: GOOGLE_ISSUERS,
          audience: config.googleClientIds,
        }));
      } catch {
        throw new AppError(
          401,
          ERROR_CODES.googleIdentityInvalid,
          'Google sign-in could not be verified.',
        );
      }
      if (
        payload.email_verified !== true ||
        typeof payload.email !== 'string' ||
        typeof payload.sub !== 'string'
      ) {
        throw new AppError(
          401,
          ERROR_CODES.googleIdentityInvalid,
          'Google did not return a verified email identity.',
        );
      }
      const aggregate = await resolveByProvider({
        email: normalizeEmail(payload.email),
        providerId: 'G',
        providerIdentifier: payload.sub,
      });
      return createAccessToken(aggregate);
    },

    /** Verifies a Clip Sync bearer token and returns its owner context. */
    async verifyAccessToken(accessToken) {
      try {
        const { payload } = await jwtVerify(accessToken, jwtKey, {
          issuer: 'clip-sync-api',
          audience: 'clip-sync-clients',
        });
        if (
          typeof payload.accountUid !== 'string' ||
          typeof payload.clipboardUid !== 'string' ||
          typeof payload.email !== 'string'
        ) {
          throw new Error('Token context is incomplete.');
        }
        return {
          accountUid: payload.accountUid,
          clipboardUid: payload.clipboardUid,
          email: payload.email,
        };
      } catch {
        throw new AppError(
          401,
          ERROR_CODES.authenticationInvalid,
          'The access token is invalid or expired.',
        );
      }
    },
  };
}

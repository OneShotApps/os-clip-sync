import { readFileSync } from 'node:fs';

import { z } from 'zod';

const booleanText = z.enum(['true', 'false']).transform((value) => value === 'true');

const configurationSchema = z
  .object({
    CLIP_SYNC_ENV: z.enum(['local', 'development', 'production']),
    CLIP_SYNC_API_PORT: z.coerce.number().int().min(1).max(65535),
    CLIP_SYNC_POSTGRES_URL: z.string().url(),
    CLIP_SYNC_MONGO_URL: z.string().url(),
    CLIP_SYNC_JWT_SECRET: z.string().min(32),
    CLIP_SYNC_AUTH_CODE_PEPPER: z.string().min(32),
    CLIP_SYNC_GOOGLE_CLIENT_IDS: z.string().optional().default(''),
    CLIP_SYNC_GOOGLE_OAUTH_CONFIG_PATH: z.string().optional().default(''),
    CLIP_SYNC_SMTP_HOST: z.string().min(1),
    CLIP_SYNC_SMTP_PORT: z.coerce.number().int().min(1).max(65535),
    CLIP_SYNC_SMTP_SECURE: booleanText,
    CLIP_SYNC_SMTP_USER: z.string().optional().default(''),
    CLIP_SYNC_SMTP_PASSWORD: z.string().optional().default(''),
    CLIP_SYNC_EMAIL_FROM: z.string().email(),
    CLIP_SYNC_CORS_ORIGINS: z.string().min(1),
  })
  .superRefine((value, context) => {
    const hasUser = value.CLIP_SYNC_SMTP_USER.length > 0;
    const hasPassword = value.CLIP_SYNC_SMTP_PASSWORD.length > 0;
    if (hasUser !== hasPassword) {
      context.addIssue({
        code: 'custom',
        message: 'CLIP_SYNC_SMTP_USER and CLIP_SYNC_SMTP_PASSWORD must be set together.',
      });
    }
    if (value.CLIP_SYNC_JWT_SECRET === value.CLIP_SYNC_AUTH_CODE_PEPPER) {
      context.addIssue({
        code: 'custom',
        message: 'CLIP_SYNC_JWT_SECRET and CLIP_SYNC_AUTH_CODE_PEPPER must be different.',
      });
    }
    if (
      !value.CLIP_SYNC_GOOGLE_CLIENT_IDS.split(',').some((clientId) => clientId.trim()) &&
      !value.CLIP_SYNC_GOOGLE_OAUTH_CONFIG_PATH.trim()
    ) {
      context.addIssue({
        code: 'custom',
        message: 'Google client IDs or a Google OAuth configuration file is required.',
      });
    }
    const corsOrigins = value.CLIP_SYNC_CORS_ORIGINS.split(',')
      .map((origin) => origin.trim())
      .filter(Boolean);
    if (corsOrigins.length === 0) {
      context.addIssue({ code: 'custom', message: 'At least one CORS origin is required.' });
    } else if (value.CLIP_SYNC_ENV === 'production' && corsOrigins.includes('*')) {
      context.addIssue({
        code: 'custom',
        message: 'Production CORS origins must be explicit.',
      });
    }
  });

function loadGoogleClientIds(value) {
  const configuredClientIds = value.CLIP_SYNC_GOOGLE_CLIENT_IDS.split(',')
    .map((clientId) => clientId.trim())
    .filter(Boolean);
  if (configuredClientIds.length > 0) return configuredClientIds;

  let document;
  try {
    document = JSON.parse(readFileSync(value.CLIP_SYNC_GOOGLE_OAUTH_CONFIG_PATH.trim(), 'utf8'));
  } catch {
    throw new Error(
      'Clip Sync configuration is invalid. The Google OAuth configuration file cannot be read or is not valid JSON.',
    );
  }

  const clientId = document?.web?.client_id;
  if (typeof clientId !== 'string' || !clientId.trim()) {
    throw new Error(
      'Clip Sync configuration is invalid. The Google OAuth configuration file does not contain web.client_id.',
    );
  }
  return [clientId.trim()];
}

/**
 * Validates environment variables and returns application configuration.
 * Startup stops with a concise error if any required value is missing or unsafe.
 *
 * @param {NodeJS.ProcessEnv} environment - Environment variables to validate.
 * @returns {object} Validated application configuration.
 */
export function loadConfig(environment = process.env) {
  const result = configurationSchema.safeParse(environment);
  if (!result.success) {
    const problems = result.error.issues.map((issue) => issue.message).join(' ');
    throw new Error(`Clip Sync configuration is invalid. ${problems}`);
  }

  const value = result.data;
  return Object.freeze({
    environment: value.CLIP_SYNC_ENV,
    port: value.CLIP_SYNC_API_PORT,
    postgresUrl: value.CLIP_SYNC_POSTGRES_URL,
    mongoUrl: value.CLIP_SYNC_MONGO_URL,
    jwtSecret: value.CLIP_SYNC_JWT_SECRET,
    authCodePepper: value.CLIP_SYNC_AUTH_CODE_PEPPER,
    googleClientIds: loadGoogleClientIds(value),
    smtp: {
      host: value.CLIP_SYNC_SMTP_HOST,
      port: value.CLIP_SYNC_SMTP_PORT,
      secure: value.CLIP_SYNC_SMTP_SECURE,
      user: value.CLIP_SYNC_SMTP_USER,
      password: value.CLIP_SYNC_SMTP_PASSWORD,
      from: value.CLIP_SYNC_EMAIL_FROM,
    },
    corsOrigins: value.CLIP_SYNC_CORS_ORIGINS.split(',')
      .map((origin) => origin.trim())
      .filter(Boolean),
  });
}

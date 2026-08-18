import { ZERO_DATE } from '../../../constants.js';
import { createUid } from '../../../utils/uid.js';
import { createOne } from '../../db.js';

function validate({ email, codeHash, expiresAt }) {
  if (typeof email !== 'string' || email.length > 255 || !email.includes('@')) {
    throw new Error('A valid email is required.');
  }
  if (typeof codeHash !== 'string' || !/^[a-f0-9]{64}$/.test(codeHash)) {
    throw new Error('A valid code hash is required.');
  }
  if (!(expiresAt instanceof Date) || Number.isNaN(expiresAt.valueOf())) {
    throw new Error('A valid expiration date is required.');
  }
}

/** Persists a short-lived email sign-in challenge. */
export async function createLoginCode({ email, codeHash, expiresAt }) {
  validate({ email, codeHash, expiresAt });
  return createOne({
    table: 'loginCode',
    data: {
      uid: createUid(),
      email,
      codeHash,
      expiresAt,
      usedAt: ZERO_DATE,
      attempts: 0,
      createdAt: new Date(),
    },
  });
}

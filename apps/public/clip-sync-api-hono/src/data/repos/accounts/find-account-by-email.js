import { findOneByData } from '../../db.js';

function validate({ email }) {
  if (typeof email !== 'string' || email.length > 255 || !email.includes('@')) {
    throw new Error('A valid email is required.');
  }
}

/** Finds an active account by normalized primary email. */
export async function findAccountByEmail({ email }) {
  validate({ email });
  return findOneByData({ table: 'account', data: { primaryEmail: email } });
}

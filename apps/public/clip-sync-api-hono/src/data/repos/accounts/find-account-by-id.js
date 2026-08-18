import { findOneByData } from '../../db.js';

function validate({ accountId }) {
  if (!Number.isInteger(accountId) || accountId < 1) {
    throw new Error('A valid internal account ID is required.');
  }
}

/** Finds an active account by its internal same-schema ID. */
export async function findAccountById({ accountId }) {
  validate({ accountId });
  return findOneByData({ table: 'account', data: { id: accountId } });
}

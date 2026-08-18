import { findOneByData } from '../../db.js';

function validate({ accountId }) {
  if (!Number.isInteger(accountId) || accountId < 1) {
    throw new Error('A valid internal account ID is required.');
  }
}

/** Finds the one active clipboard assigned to an account. */
export async function findClipboardByAccountId({ accountId }) {
  validate({ accountId });
  return findOneByData({ table: 'clipboard', data: { accountId } });
}

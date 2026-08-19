import { findManyByData } from '../../db.js';

function validate({ accountId }) {
  if (!Number.isInteger(accountId) || accountId < 1) {
    throw new Error('A valid account ID is required.');
  }
}

/** Lists active devices owned by one account. */
export async function listDevices({ accountId }) {
  validate({ accountId });
  return findManyByData({ table: 'device', data: { accountId } });
}

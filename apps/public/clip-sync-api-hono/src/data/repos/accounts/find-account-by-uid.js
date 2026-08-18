import { isUid } from '../../../utils/uid.js';
import { findOneByData } from '../../db.js';

function validate({ accountUid }) {
  if (!isUid(accountUid)) {
    throw new Error('A valid account UID is required.');
  }
}

/** Finds an active account by its public UID. */
export async function findAccountByUid({ accountUid }) {
  validate({ accountUid });
  return findOneByData({ table: 'account', data: { uid: accountUid } });
}

import { isUid } from '../../../utils/uid.js';
import { findOneByData } from '../../db.js';

function validate({ accountId, deviceUid }) {
  if (!Number.isInteger(accountId) || accountId < 1 || !isUid(deviceUid)) {
    throw new Error('A valid account ID and device UID are required.');
  }
}

/** Finds one active device within its owning account. */
export async function findDevice({ accountId, deviceUid }) {
  validate({ accountId, deviceUid });
  return findOneByData({
    table: 'device',
    data: { accountId, uid: deviceUid },
  });
}

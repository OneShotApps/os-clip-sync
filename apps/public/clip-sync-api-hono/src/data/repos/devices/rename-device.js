import { ZERO_DATE } from '../../../constants.js';
import { isUid } from '../../../utils/uid.js';
import { updateOneByData } from '../../db.js';

function validate({ accountId, deviceUid, customName }) {
  if (!Number.isInteger(accountId) || accountId < 1 || !isUid(deviceUid)) {
    throw new Error('A valid account ID and device UID are required.');
  }
  if (typeof customName !== 'string' || customName.length < 1 || customName.length > 100) {
    throw new Error('The device name must contain 1 to 100 characters.');
  }
}

/** Applies an account-owned display name to one active device. */
export async function renameDevice({ accountId, deviceUid, customName }) {
  validate({ accountId, deviceUid, customName });
  return updateOneByData({
    table: 'device',
    criteria: { accountId, uid: deviceUid, deletedAt: ZERO_DATE },
    updates: { customName, updatedAt: new Date() },
  });
}

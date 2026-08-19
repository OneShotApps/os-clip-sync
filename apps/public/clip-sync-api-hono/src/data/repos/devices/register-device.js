import { PLATFORMS, ZERO_DATE } from '../../../constants.js';
import { isUid } from '../../../utils/uid.js';
import { createOne, updateOneByData } from '../../db.js';
import { findDevice } from './find-device.js';

function validate({ accountId, deviceUid, platform, reportedName }) {
  if (!Number.isInteger(accountId) || accountId < 1 || !isUid(deviceUid)) {
    throw new Error('A valid account ID and device UID are required.');
  }
  if (!PLATFORMS.includes(platform)) throw new Error('A supported platform is required.');
  if (typeof reportedName !== 'string' || reportedName.length < 1 || reportedName.length > 100) {
    throw new Error('The reported device name must contain 1 to 100 characters.');
  }
}

/** Creates a device or refreshes its operating-system-reported name. */
export async function registerDevice({ accountId, deviceUid, platform, reportedName }) {
  validate({ accountId, deviceUid, platform, reportedName });
  const existing = await findDevice({ accountId, deviceUid });
  const now = new Date();
  if (existing) {
    return updateOneByData({
      table: 'device',
      criteria: { id: existing.id, accountId },
      updates: { platform, reportedName, updatedAt: now },
    });
  }
  return createOne({
    table: 'device',
    data: {
      uid: deviceUid,
      accountId,
      platform,
      reportedName,
      customName: null,
      createdAt: now,
      updatedAt: ZERO_DATE,
      deletedAt: ZERO_DATE,
    },
  });
}

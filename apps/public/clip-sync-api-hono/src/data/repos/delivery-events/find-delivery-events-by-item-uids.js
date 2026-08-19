import { isUid } from '../../../utils/uid.js';
import { findDeliveryEventsByItemUids as findRows } from '../../db.js';

function validate({ accountUid, itemUids }) {
  if (!isUid(accountUid) || !Array.isArray(itemUids) || itemUids.some((uid) => !isUid(uid))) {
    throw new Error('A valid account UID and item UIDs are required.');
  }
}

/** Finds owner-scoped source-client metadata for clipboard items. */
export async function findDeliveryEventsByItemUids({ accountUid, itemUids }) {
  validate({ accountUid, itemUids });
  return findRows({ accountUid, itemUids });
}

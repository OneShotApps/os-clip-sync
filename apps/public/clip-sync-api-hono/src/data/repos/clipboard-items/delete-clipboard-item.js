import { isUid } from '../../../utils/uid.js';
import { softDeleteClipboardItemDocument } from '../../db.js';

function validate({ accountUid, itemUid }) {
  if (!isUid(accountUid) || !isUid(itemUid)) {
    throw new Error('Valid account and item UIDs are required.');
  }
}

/** Soft deletes one active item only when it belongs to the authenticated owner. */
export async function deleteClipboardItem({ accountUid, itemUid }) {
  validate({ accountUid, itemUid });
  return softDeleteClipboardItemDocument({ accountUid, itemUid, deletedAt: Date.now() });
}

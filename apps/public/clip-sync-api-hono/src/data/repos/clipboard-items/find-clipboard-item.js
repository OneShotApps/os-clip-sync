import { isUid } from '../../../utils/uid.js';
import { findClipboardItemDocument } from '../../db.js';

function validate({ accountUid, itemUid }) {
  if (!isUid(accountUid) || !isUid(itemUid)) {
    throw new Error('Valid account and item UIDs are required.');
  }
}

/** Finds one active, owner-scoped clipboard item including its payload. */
export async function findClipboardItem({ accountUid, itemUid }) {
  validate({ accountUid, itemUid });
  return findClipboardItemDocument({ accountUid, itemUid });
}

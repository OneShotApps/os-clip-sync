import { isUid } from '../../../utils/uid.js';
import { findClipboardItemDocuments } from '../../db.js';

function validate({ accountUid, page, pageSize }) {
  if (!isUid(accountUid)) {
    throw new Error('A valid account UID is required.');
  }
  if (!Number.isInteger(page) || page < 1 || !Number.isInteger(pageSize) || pageSize < 1) {
    throw new Error('Valid pagination values are required.');
  }
}

/** Lists an owner-scoped page of active clipboard items. */
export async function listClipboardItems({ accountUid, page, pageSize }) {
  validate({ accountUid, page, pageSize });
  return findClipboardItemDocuments({ accountUid, page, pageSize });
}

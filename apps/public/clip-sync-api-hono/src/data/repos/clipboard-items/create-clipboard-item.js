import { createUid, isUid } from '../../../utils/uid.js';
import { createClipboardItemDocument } from '../../db.js';

function validate(values) {
  if (!isUid(values.accountUid) || !isUid(values.clipboardUid)) {
    throw new Error('Valid ownership UIDs are required.');
  }
  if (!['text', 'image'].includes(values.kind)) {
    throw new Error('A supported content kind is required.');
  }
}

/** Creates a MongoDB clipboard payload document for the authenticated owner. */
export async function createClipboardItem(values) {
  validate(values);
  return createClipboardItemDocument({
    uid: createUid(),
    ...values,
    createdAt: Date.now(),
    deletedAt: 0,
  });
}

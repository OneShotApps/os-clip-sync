import { createUid, isUid } from '../../../utils/uid.js';
import { createOne } from '../../db.js';

function validate(values) {
  for (const key of ['accountUid', 'clipboardUid', 'itemUid', 'sourceClientUid']) {
    if (!isUid(values[key])) {
      throw new Error(`${key} must be a valid UID.`);
    }
  }
  if (!['text', 'image'].includes(values.contentKind)) {
    throw new Error('A supported content kind is required.');
  }
}

/** Persists immutable delivery metadata before live clients are notified. */
export async function createDeliveryEvent(values) {
  validate(values);
  return createOne({
    table: 'deliveryEvent',
    data: {
      uid: createUid(),
      ...values,
      createdAt: new Date(),
    },
  });
}

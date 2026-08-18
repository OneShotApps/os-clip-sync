import { ZERO_DATE } from '../../../constants.js';
import { isUid } from '../../../utils/uid.js';
import { updateOneByData } from '../../db.js';

function validate({ challengeUid, usedAt }) {
  if (!isUid(challengeUid)) {
    throw new Error('A valid challenge UID is required.');
  }
  if (!(usedAt instanceof Date) || Number.isNaN(usedAt.valueOf())) {
    throw new Error('A valid use date is required.');
  }
}

/** Atomically marks an unused login challenge as consumed. */
export async function consumeLoginCode({ challengeUid, usedAt }) {
  validate({ challengeUid, usedAt });
  return updateOneByData({
    table: 'loginCode',
    criteria: { uid: challengeUid, usedAt: ZERO_DATE },
    updates: { usedAt },
  });
}

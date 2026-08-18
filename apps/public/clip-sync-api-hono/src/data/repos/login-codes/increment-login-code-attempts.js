import { ZERO_DATE } from '../../../constants.js';
import { isUid } from '../../../utils/uid.js';
import { updateOneByData } from '../../db.js';

function validate({ challengeUid, attempts }) {
  if (!isUid(challengeUid)) {
    throw new Error('A valid challenge UID is required.');
  }
  if (!Number.isInteger(attempts) || attempts < 1 || attempts > 5) {
    throw new Error('A valid attempt count is required.');
  }
}

/** Records a failed verification attempt while the challenge is still unused. */
export async function incrementLoginCodeAttempts({ challengeUid, attempts }) {
  validate({ challengeUid, attempts });
  return updateOneByData({
    table: 'loginCode',
    criteria: { uid: challengeUid, usedAt: ZERO_DATE },
    updates: { attempts },
  });
}

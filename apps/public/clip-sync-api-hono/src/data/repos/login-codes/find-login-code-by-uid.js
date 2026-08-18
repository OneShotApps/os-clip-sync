import { isUid } from '../../../utils/uid.js';
import { findOneByData } from '../../db.js';

function validate({ challengeUid }) {
  if (!isUid(challengeUid)) {
    throw new Error('A valid challenge UID is required.');
  }
}

/** Finds a login challenge, including whether it was already used. */
export async function findLoginCodeByUid({ challengeUid }) {
  validate({ challengeUid });
  return findOneByData({ table: 'loginCode', data: { uid: challengeUid }, includeDeleted: true });
}

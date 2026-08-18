import { ZERO_DATE } from '../../../constants.js';
import { createUid } from '../../../utils/uid.js';
import { createOne, runPostgresTransaction } from '../../db.js';

function validate({ email, providerId, providerIdentifier }) {
  if (typeof email !== 'string' || email.length > 255 || !email.includes('@')) {
    throw new Error('A valid email is required.');
  }
  if (!['E', 'G'].includes(providerId)) {
    throw new Error('A supported provider ID is required.');
  }
  if (typeof providerIdentifier !== 'string' || providerIdentifier.length > 255) {
    throw new Error('A provider identifier is required.');
  }
}

/**
 * Creates an account, its first provider identity, and its one clipboard atomically.
 *
 * @param {object} values - Normalized registration values.
 * @returns {Promise<{account: object, clipboard: object}>} Created aggregate.
 */
export async function createAccount({ email, providerId, providerIdentifier }) {
  validate({ email, providerId, providerIdentifier });
  const createdAt = new Date();

  return runPostgresTransaction(async (executor) => {
    const newAccount = await createOne({
      table: 'account',
      executor,
      data: {
        uid: createUid(),
        primaryEmail: email,
        createdAt,
        updatedAt: ZERO_DATE,
        deletedAt: ZERO_DATE,
      },
    });
    await createOne({
      table: 'accountIdentifier',
      executor,
      data: {
        accountId: newAccount.id,
        authenticationProviderId: providerId,
        providerIdentifier,
        createdAt,
        deletedAt: ZERO_DATE,
      },
    });
    const newClipboard = await createOne({
      table: 'clipboard',
      executor,
      data: {
        uid: createUid(),
        accountId: newAccount.id,
        createdAt,
        updatedAt: ZERO_DATE,
        deletedAt: ZERO_DATE,
      },
    });
    return { account: newAccount, clipboard: newClipboard };
  });
}

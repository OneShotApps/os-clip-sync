import { ZERO_DATE } from '../../../constants.js';
import { createOne } from '../../db.js';

function validate({ accountId, providerId, providerIdentifier }) {
  if (!Number.isInteger(accountId) || accountId < 1) {
    throw new Error('A valid internal account ID is required.');
  }
  if (!['E', 'G'].includes(providerId)) {
    throw new Error('A supported provider ID is required.');
  }
  if (typeof providerIdentifier !== 'string' || providerIdentifier.length > 255) {
    throw new Error('A provider identifier is required.');
  }
}

/** Adds a verified authentication identity to an existing account. */
export async function addAccountIdentifier({ accountId, providerId, providerIdentifier }) {
  validate({ accountId, providerId, providerIdentifier });
  return createOne({
    table: 'accountIdentifier',
    data: {
      accountId,
      authenticationProviderId: providerId,
      providerIdentifier,
      createdAt: new Date(),
      deletedAt: ZERO_DATE,
    },
  });
}

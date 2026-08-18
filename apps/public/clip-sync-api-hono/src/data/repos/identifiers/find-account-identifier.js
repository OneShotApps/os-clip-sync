import { findOneByData } from '../../db.js';

function validate({ providerId, providerIdentifier }) {
  if (!['E', 'G'].includes(providerId)) {
    throw new Error('A supported provider ID is required.');
  }
  if (typeof providerIdentifier !== 'string' || providerIdentifier.length > 255) {
    throw new Error('A provider identifier is required.');
  }
}

/** Finds an active account identifier by provider and provider-owned value. */
export async function findAccountIdentifier({ providerId, providerIdentifier }) {
  validate({ providerId, providerIdentifier });
  return findOneByData({
    table: 'accountIdentifier',
    data: {
      authenticationProviderId: providerId,
      providerIdentifier,
    },
  });
}

import { randomUUID } from 'node:crypto';

/**
 * Creates a Briskhaven public UID: uppercase UUID v4 without hyphens.
 *
 * @returns {string} A 32-character public UID.
 */
export function createUid() {
  return randomUUID().replaceAll('-', '').toUpperCase();
}

/**
 * Reports whether a value is a valid Clip Sync public UID.
 *
 * @param {unknown} value - Candidate value.
 * @returns {boolean} Whether the value has the expected format.
 */
export function isUid(value) {
  return typeof value === 'string' && /^[A-F0-9]{32}$/.test(value);
}

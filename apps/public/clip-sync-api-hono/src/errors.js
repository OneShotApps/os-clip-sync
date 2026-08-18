export const ERROR_CODES = Object.freeze({
  invalidRequest: 'CLIP_SYNC_INVALID_REQUEST',
  authenticationRequired: 'CLIP_SYNC_AUTHENTICATION_REQUIRED',
  authenticationInvalid: 'CLIP_SYNC_AUTHENTICATION_INVALID',
  codeInvalid: 'CLIP_SYNC_EMAIL_CODE_INVALID',
  codeExpired: 'CLIP_SYNC_EMAIL_CODE_EXPIRED',
  codeAttemptsExceeded: 'CLIP_SYNC_EMAIL_CODE_ATTEMPTS_EXCEEDED',
  googleIdentityInvalid: 'CLIP_SYNC_GOOGLE_IDENTITY_INVALID',
  itemNotFound: 'CLIP_SYNC_ITEM_NOT_FOUND',
  contentTooLarge: 'CLIP_SYNC_CONTENT_TOO_LARGE',
  unsupportedContent: 'CLIP_SYNC_UNSUPPORTED_CONTENT',
  rateLimited: 'CLIP_SYNC_RATE_LIMITED',
  internal: 'CLIP_SYNC_INTERNAL_ERROR',
});

/** Error with an HTTP status and a safe public response. */
export class AppError extends Error {
  /**
   * @param {number} status - HTTP status code.
   * @param {string} code - Stable product error code.
   * @param {string} message - Safe public message.
   */
  constructor(status, code, message) {
    super(message);
    this.name = 'AppError';
    this.status = status;
    this.code = code;
  }
}

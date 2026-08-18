import { AppError, ERROR_CODES } from '../errors.js';

/**
 * Creates bearer-token middleware backed by the authentication service.
 *
 * @param {object} authService - Authentication service.
 * @returns {function} Hono middleware.
 */
export function requireAuthentication(authService) {
  return async (context, next) => {
    const authorization = context.req.header('authorization') ?? '';
    const [scheme, token] = authorization.split(' ');
    if (scheme !== 'Bearer' || !token) {
      throw new AppError(
        401,
        ERROR_CODES.authenticationRequired,
        'A bearer access token is required.',
      );
    }
    context.set('auth', await authService.verifyAccessToken(token));
    await next();
  };
}

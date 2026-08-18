import { z } from 'zod';

import { AppError, ERROR_CODES } from '../../../../errors.js';

const requestSchema = z.object({
  idToken: z.string().min(20).max(20000),
});

function validate(request) {
  const result = requestSchema.safeParse(request);
  return result.success ? null : 'A Google OpenID Connect ID token is required.';
}

/** Creates the Google OIDC sign-in route handler. */
export function googleSignIn(authService) {
  return async (context) => {
    const body = await context.req.json();
    const validationError = validate(body);
    if (validationError) {
      throw new AppError(400, ERROR_CODES.invalidRequest, validationError);
    }
    return context.json(await authService.signInWithGoogle(body));
  };
}

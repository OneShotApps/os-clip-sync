import { z } from 'zod';

import { AppError, ERROR_CODES } from '../../../../errors.js';

const requestSchema = z.object({
  challengeUid: z.string().regex(/^[A-F0-9]{32}$/),
  code: z.string().regex(/^\d{6}$/),
});

function validate(request) {
  const result = requestSchema.safeParse(request);
  return result.success ? null : 'Challenge UID and six-digit code are required.';
}

/** Creates the email-code verification route handler. */
export function verifyEmailCode(authService) {
  return async (context) => {
    const body = await context.req.json();
    const validationError = validate(body);
    if (validationError) {
      throw new AppError(400, ERROR_CODES.invalidRequest, validationError);
    }
    return context.json(await authService.verifyEmailCode(body));
  };
}

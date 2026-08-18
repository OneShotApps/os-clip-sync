import { z } from 'zod';

import { AppError, ERROR_CODES } from '../../../../errors.js';

const requestSchema = z.object({
  email: z.string().trim().email().max(255),
});

function validate(request) {
  const result = requestSchema.safeParse(request);
  return result.success ? null : 'Enter a valid email address.';
}

/** Creates the email-code request route handler. */
export function requestEmailCode(authService) {
  return async (context) => {
    const body = await context.req.json();
    const validationError = validate(body);
    if (validationError) {
      throw new AppError(400, ERROR_CODES.invalidRequest, validationError);
    }
    const challenge = await authService.requestEmailCode({ email: body.email });
    return context.json(challenge, 202);
  };
}

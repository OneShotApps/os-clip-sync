import { z } from 'zod';

import { AppError, ERROR_CODES } from '../../../../errors.js';

const requestSchema = z.object({
  clientUid: z.string().regex(/^[A-F0-9]{32}$/),
  platform: z.enum(['windows', 'macos', 'ios', 'android']),
  name: z.string().trim().min(1).max(100),
});

function validate(request) {
  const result = requestSchema.safeParse(request);
  return result.success ? null : result.error.issues[0].message;
}

/** Creates the idempotent current-device registration handler. */
export function registerDevice(deviceService) {
  return async (context) => {
    const body = await context.req.json();
    const validationError = validate(body);
    if (validationError) {
      throw new AppError(400, ERROR_CODES.invalidRequest, validationError);
    }
    const device = await deviceService.register({ auth: context.get('auth'), ...body });
    return context.json({ device });
  };
}

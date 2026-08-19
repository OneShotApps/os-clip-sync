import { z } from 'zod';

import { AppError, ERROR_CODES } from '../../../../errors.js';
import { isUid } from '../../../../utils/uid.js';

const requestSchema = z.object({ name: z.string().trim().min(1).max(100) });

function validate(request) {
  if (!isUid(request.deviceUid)) return 'A valid device UID is required.';
  const result = requestSchema.safeParse({ name: request.name });
  return result.success ? null : result.error.issues[0].message;
}

/** Creates the account-scoped device rename handler. */
export function renameDevice(deviceService) {
  return async (context) => {
    const body = await context.req.json();
    const request = { deviceUid: context.req.param('deviceUid'), name: body.name };
    const validationError = validate(request);
    if (validationError) {
      throw new AppError(400, ERROR_CODES.invalidRequest, validationError);
    }
    const device = await deviceService.rename({ auth: context.get('auth'), ...request });
    return context.json({ device });
  };
}

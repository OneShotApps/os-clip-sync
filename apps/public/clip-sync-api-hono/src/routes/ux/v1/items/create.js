import { z } from 'zod';

import { AppError, ERROR_CODES } from '../../../../errors.js';

const requestSchema = z
  .object({
    clientUid: z.string().regex(/^[A-F0-9]{32}$/),
    sourcePlatform: z.enum(['windows', 'macos', 'ios', 'android']),
    kind: z.enum(['text', 'image']),
    text: z.string().optional(),
    imageBase64: z.string().optional(),
    mimeType: z.string().optional(),
  })
  .superRefine((value, context) => {
    if (value.kind === 'text' && typeof value.text !== 'string') {
      context.addIssue({ code: 'custom', message: 'text is required for a text item.' });
    }
    if (value.kind === 'image' && (!value.imageBase64 || !value.mimeType)) {
      context.addIssue({ code: 'custom', message: 'imageBase64 and mimeType are required.' });
    }
  });

function validate(request) {
  const result = requestSchema.safeParse(request);
  return result.success ? null : result.error.issues[0].message;
}

/** Creates the new clipboard item route handler. */
export function createItem(clipboardService) {
  return async (context) => {
    const body = await context.req.json();
    const validationError = validate(body);
    if (validationError) {
      throw new AppError(400, ERROR_CODES.invalidRequest, validationError);
    }
    const item = await clipboardService.createItem({ auth: context.get('auth'), ...body });
    return context.json({ item }, 201);
  };
}

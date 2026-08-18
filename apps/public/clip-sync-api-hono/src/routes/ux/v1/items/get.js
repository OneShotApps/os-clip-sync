import { AppError, ERROR_CODES } from '../../../../errors.js';
import { isUid } from '../../../../utils/uid.js';

function validate(request) {
  return isUid(request.itemUid) ? null : 'A valid item UID is required.';
}

/** Creates the owner-scoped clipboard item detail handler. */
export function getItem(clipboardService) {
  return async (context) => {
    const request = { itemUid: context.req.param('itemUid') };
    const validationError = validate(request);
    if (validationError) {
      throw new AppError(400, ERROR_CODES.invalidRequest, validationError);
    }
    return context.json({
      item: await clipboardService.getItem({ auth: context.get('auth'), ...request }),
    });
  };
}

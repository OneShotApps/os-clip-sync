import { AppError, ERROR_CODES } from '../../../../errors.js';
import { isUid } from '../../../../utils/uid.js';

function validate(request) {
  return isUid(request.itemUid) ? null : 'A valid item UID is required.';
}

/** Creates the owner-scoped history deletion handler. */
export function deleteItem(clipboardService) {
  return async (context) => {
    const request = { itemUid: context.req.param('itemUid') };
    const validationError = validate(request);
    if (validationError) {
      throw new AppError(400, ERROR_CODES.invalidRequest, validationError);
    }
    await clipboardService.deleteItem({ auth: context.get('auth'), ...request });
    return context.body(null, 204);
  };
}

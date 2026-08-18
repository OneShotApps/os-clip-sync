import { AppError, ERROR_CODES } from '../../../../errors.js';

function validate(request) {
  if (!Number.isInteger(request.page) || request.page < 1) return 'page must be at least 1.';
  if (!Number.isInteger(request.pageSize) || request.pageSize < 1 || request.pageSize > 100) {
    return 'pageSize must be between 1 and 100.';
  }
  return null;
}

/** Creates the paginated clipboard-history handler. */
export function listHistory(clipboardService) {
  return async (context) => {
    const request = {
      page: Number(context.req.query('page') ?? 1),
      pageSize: Number(context.req.query('pageSize') ?? 50),
    };
    const validationError = validate(request);
    if (validationError) {
      throw new AppError(400, ERROR_CODES.invalidRequest, validationError);
    }
    return context.json(
      await clipboardService.listItems({ auth: context.get('auth'), ...request }),
    );
  };
}

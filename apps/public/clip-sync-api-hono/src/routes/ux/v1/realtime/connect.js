import { AppError, ERROR_CODES } from '../../../../errors.js';
import { isUid } from '../../../../utils/uid.js';

function validate(request) {
  if (!isUid(request.clientUid)) return 'A valid client UID is required.';
  if (!['windows', 'macos'].includes(request.platform)) {
    return 'Real-time delivery is available only to Windows and macOS clients.';
  }
  return null;
}

/** Creates the online-only desktop WebSocket route. */
export function connectRealtime({ upgradeWebSocket, realtimeHub }) {
  return upgradeWebSocket((context) => {
    const request = {
      clientUid: context.req.query('clientUid') ?? '',
      platform: context.req.query('platform') ?? '',
    };
    const validationError = validate(request);
    if (validationError) {
      throw new AppError(400, ERROR_CODES.invalidRequest, validationError);
    }
    const auth = context.get('auth');
    return {
      onOpen(_event, socket) {
        realtimeHub.register({ accountUid: auth.accountUid, clientUid: request.clientUid, socket });
      },
      onMessage(event, socket) {
        if (event.data === 'ping') socket.send(JSON.stringify({ type: 'pong' }));
      },
      onClose(_event, socket) {
        realtimeHub.remove({ accountUid: auth.accountUid, clientUid: request.clientUid, socket });
      },
      onError(_event, socket) {
        realtimeHub.remove({ accountUid: auth.accountUid, clientUid: request.clientUid, socket });
      },
    };
  });
}

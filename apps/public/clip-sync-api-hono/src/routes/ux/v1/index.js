import { Hono } from 'hono';

import { requireAuthentication } from '../../../middleware/authenticate.js';
import { googleSignIn, requestEmailCode, verifyEmailCode } from './auth/index.js';
import { listDevices, registerDevice, renameDevice } from './devices/index.js';
import { listHistory } from './history/index.js';
import { createItem, deleteItem, getItem } from './items/index.js';
import { connectRealtime } from './realtime/index.js';

/** Creates the production UX v1 route boundary. */
export function createV1Router({
  authService,
  clipboardService,
  deviceService,
  realtimeHub,
  upgradeWebSocket,
}) {
  const router = new Hono();
  const requireAuth = requireAuthentication(authService);

  router.post('/auth/email/request', requestEmailCode(authService));
  router.post('/auth/email/verify', verifyEmailCode(authService));
  router.post('/auth/google', googleSignIn(authService));

  router.use('/devices', requireAuth);
  router.use('/devices/*', requireAuth);
  router.get('/devices', listDevices(deviceService));
  router.post('/devices/register', registerDevice(deviceService));
  router.patch('/devices/:deviceUid', renameDevice(deviceService));

  router.use('/history', requireAuth);
  router.get('/history', listHistory(clipboardService));

  router.use('/items', requireAuth);
  router.use('/items/*', requireAuth);
  router.post('/items', createItem(clipboardService));
  router.get('/items/:itemUid', getItem(clipboardService));
  router.delete('/items/:itemUid', deleteItem(clipboardService));

  router.use('/realtime', requireAuth);
  router.get('/realtime', connectRealtime({ upgradeWebSocket, realtimeHub }));

  return router;
}

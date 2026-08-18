import { createBunWebSocket } from 'hono/bun';

import { createApp } from './app.js';
import { loadConfig } from './config.js';
import { closeDatabases, connectDatabases } from './data/db.js';
import { createAuthService } from './services/auth-service.js';
import { createClipboardService } from './services/clipboard-service.js';
import { createEmailService } from './services/email-service.js';
import { createRealtimeHub } from './services/realtime-hub.js';

const config = loadConfig();
await connectDatabases(config);

const { upgradeWebSocket, websocket } = createBunWebSocket();
const realtimeHub = createRealtimeHub();
const authService = createAuthService({
  config,
  emailService: createEmailService(config.smtp),
});
const clipboardService = createClipboardService({ realtimeHub });
const app = createApp({
  config,
  authService,
  clipboardService,
  realtimeHub,
  upgradeWebSocket,
});

const server = Bun.serve({
  port: config.port,
  fetch: app.fetch,
  websocket,
  maxRequestBodySize: 14 * 1024 * 1024,
});

console.log(`Clip Sync API listening on port ${server.port}.`);

let stopping = false;
async function shutdown(signal) {
  if (stopping) return;
  stopping = true;
  console.log(`Clip Sync API received ${signal}; shutting down.`);
  server.stop(false);
  await closeDatabases();
  process.exit(0);
}

process.on('SIGINT', () => shutdown('SIGINT'));
process.on('SIGTERM', () => shutdown('SIGTERM'));

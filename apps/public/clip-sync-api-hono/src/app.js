import { Hono } from 'hono';
import { bodyLimit } from 'hono/body-limit';
import { cors } from 'hono/cors';
import { secureHeaders } from 'hono/secure-headers';
import { rateLimiter } from 'hono-rate-limiter';

import packageMetadata from '../package.json' with { type: 'json' };

import { AppError, ERROR_CODES } from './errors.js';
import { correlationId } from './middleware/correlation-id.js';
import { createUxRouter } from './routes/ux/index.js';

/**
 * Creates the Hono application with middleware and route boundaries.
 *
 * @param {object} dependencies - Validated config, services, and WebSocket upgrade function.
 * @returns {Hono} Configured Hono application.
 */
export function createApp(dependencies) {
  const { config } = dependencies;
  const app = new Hono();

  app.use('*', secureHeaders());
  app.use('*', correlationId);
  app.use(
    '/ux/*',
    cors({
      origin: (origin) => {
        if (config.corsOrigins.includes('*')) return origin || '*';
        return config.corsOrigins.includes(origin) ? origin : '';
      },
      allowHeaders: ['Authorization', 'Content-Type'],
      allowMethods: ['GET', 'POST', 'PATCH', 'DELETE', 'OPTIONS'],
      exposeHeaders: ['x-correlation-id'],
    }),
  );
  app.use(
    '/ux/v1/auth/*',
    rateLimiter({
      windowMs: 60_000,
      limit: 12,
      standardHeaders: 'draft-6',
      keyGenerator: (context) =>
        context.req.header('x-forwarded-for') ?? context.req.header('x-real-ip') ?? 'local',
      handler: (context) =>
        context.json(
          { code: ERROR_CODES.rateLimited, message: 'Too many sign-in requests. Try again soon.' },
          429,
        ),
    }),
  );
  app.use(
    '/ux/v1/items',
    bodyLimit({
      maxSize: 14 * 1024 * 1024,
      onError: (context) =>
        context.json(
          { code: ERROR_CODES.contentTooLarge, message: 'Clipboard payload is too large.' },
          413,
        ),
    }),
  );

  app.get('/', (context) =>
    context.json({
      name: packageMetadata.name,
      description: packageMetadata.description,
      version: packageMetadata.version,
      serverTime: new Date().toISOString(),
    }),
  );
  app.route('/ux', createUxRouter(dependencies));

  app.notFound((context) =>
    context.json({ code: ERROR_CODES.invalidRequest, message: 'Route not found.' }, 404),
  );
  app.onError((error, context) => {
    if (error instanceof AppError) {
      return context.json({ code: error.code, message: error.message }, error.status);
    }
    if (error instanceof SyntaxError) {
      return context.json(
        { code: ERROR_CODES.invalidRequest, message: 'Request body must be valid JSON.' },
        400,
      );
    }
    console.error('Unexpected Clip Sync API error.', {
      correlationId: context.get('correlationId'),
      errorName: error.name,
    });
    return context.json(
      { code: ERROR_CODES.internal, message: 'The request could not be completed.' },
      500,
    );
  });

  return app;
}

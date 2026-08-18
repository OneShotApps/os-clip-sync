import { Hono } from 'hono';

import { createV1Router } from './v1/index.js';

/** Creates the UI-facing route boundary. */
export function createUxRouter(dependencies) {
  const router = new Hono();
  router.route('/v1', createV1Router(dependencies));
  return router;
}

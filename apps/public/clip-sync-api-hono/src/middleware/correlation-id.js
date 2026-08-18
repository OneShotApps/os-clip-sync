import { createUid } from '../utils/uid.js';

/** Adds an authoritative server-generated correlation ID to every API request. */
export async function correlationId(context, next) {
  const id = createUid();
  context.set('correlationId', id);
  context.header('x-correlation-id', id);
  await next();
}

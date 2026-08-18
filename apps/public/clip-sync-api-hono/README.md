# Clip Sync API

This self-contained Bun/Hono application provides passwordless and Google OIDC authentication, owner-scoped history, item persistence, and online-only WebSocket delivery.

Run it through the root local Compose stack for PostgreSQL, MongoDB, and SMTP dependencies. For API-only validation:

```sh
bun install --frozen-lockfile
bun run format
bun run lint
bun run openapi:lint
bun run test
```

`openapi.yaml` documents the client contract. YAML JSON Schemas under `src/data/schemas/` document persisted objects, and `src/data/migrations/` contains idempotent PostgreSQL setup.

After the local Compose stack is healthy, run `bun run test:integration`. The test creates unique accounts through Mailpit, confirms owner isolation and the item lifecycle, and verifies live WebSocket delivery excludes the source and does not replay after reconnect.

Configuration is read only from `CLIP_SYNC_*` environment values and is validated before a datastore connection is opened. See the root `.env.example` and deployment runbook for the complete list. Never store a real token or secret in this folder.

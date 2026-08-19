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

Configuration is validated before a datastore connection is opened. Shared environments use the `CLIP_SYNC_*` values listed in the root `.env.example`. Local Compose mounts the approved `keys/google-oauth.json` file read-only and provides its path through `CLIP_SYNC_GOOGLE_OAUTH_CONFIG_PATH`; an explicit `CLIP_SYNC_GOOGLE_CLIENT_IDS` value takes priority in shared environments. Never store a real token or secret in this folder.

# Deployment runbook

Clip Sync runs its complete server stack with Docker Compose on one host. The API owns its database migration step and waits for healthy datastores before starting.

## Local development

Prerequisites: Docker Desktop/Engine with Compose v2 and the local ports listed in the root README.

```sh
docker compose -f compose.local.yaml config --quiet
docker compose -f compose.local.yaml up --build -d
docker compose -f compose.local.yaml ps
curl --fail http://localhost:4100/
```

The API source is bind-mounted and Bun watch mode reloads changes. PostgreSQL listens on host port 5400, MongoDB on 27017, and Mailpit on 8025. Local credentials are deliberately non-production values and must never be reused in a shared environment.

If one of those host ports is already occupied, set `CLIP_SYNC_LOCAL_API_PORT`, `CLIP_SYNC_LOCAL_POSTGRES_PORT`, `CLIP_SYNC_LOCAL_MONGO_PORT`, or `CLIP_SYNC_LOCAL_MAILPIT_PORT` for the command. Container ports and service-to-service addresses do not change.

Inspect and stop:

```sh
docker compose -f compose.local.yaml logs --tail=200 api postgres mongo mailpit
docker compose -f compose.local.yaml down
```

`down` preserves named database volumes. Use `docker compose -f compose.local.yaml down --volumes` only when intentionally discarding all local Clip Sync data.

## Shared development

Copy `.env.example` to an uncommitted `.env`, replace every placeholder, and use a development-only SMTP account and Google OIDC client ID.

```sh
docker compose --env-file .env -f compose.dev.yaml config --quiet
docker compose --env-file .env -f compose.dev.yaml build api
docker compose --env-file .env -f compose.dev.yaml up -d
docker compose --env-file .env -f compose.dev.yaml ps
curl --fail "http://127.0.0.1:${CLIP_SYNC_API_PORT}/"
```

Stop with `docker compose --env-file .env -f compose.dev.yaml down`.

## Production on EC2

Provision a supported Linux EC2 host with sufficient encrypted storage, Docker Engine/Compose v2, a firewall/security group, DNS, and a TLS reverse proxy. Only the public HTTPS endpoint should be internet-accessible; do not expose PostgreSQL or MongoDB. Configure automated encrypted snapshots or volume backups and practice recovery before accepting important data.

Use an immutable release identifier for `CLIP_SYNC_IMAGE_TAG`. Supply secrets from the deployment environment or an approved secret delivery mechanism; do not copy a production `.env` into source control.

```sh
docker compose --env-file /secure/path/clip-sync.env -f compose.prod.yaml config --quiet
docker compose --env-file /secure/path/clip-sync.env -f compose.prod.yaml build api
docker compose --env-file /secure/path/clip-sync.env -f compose.prod.yaml up -d
docker compose --env-file /secure/path/clip-sync.env -f compose.prod.yaml ps
curl --fail "http://127.0.0.1:${CLIP_SYNC_API_PORT}/"
```

Point the TLS reverse proxy to the configured host API port and allow WebSocket upgrades for `/ux/v1/realtime`. Set `CLIP_SYNC_CORS_ORIGINS` to explicit trusted HTTPS origins if browser clients are introduced; native apps do not require a wildcard.

For a rolling corrective release, update the immutable image tag, validate the rendered Compose configuration, rebuild or pull the image, and run `docker compose ... up -d`. Do not remove the data volumes.

Stop the application with `docker compose --env-file /secure/path/clip-sync.env -f compose.prod.yaml down`. This preserves data but causes downtime and should be intentional.

## Required configuration

- PostgreSQL and MongoDB URLs must use the Compose service names `postgres` and `mongo` inside containers.
- JWT secret and authentication-code pepper must be distinct random values of at least 32 characters.
- `CLIP_SYNC_GOOGLE_CLIENT_IDS` is a comma-separated allowlist of native Google OIDC client IDs.
- SMTP host, port, security flag, optional credentials, and sender must describe a working provider.
- The API port must be available to the reverse proxy.

Startup fails with a readable validation error when required values are absent or malformed.

## Troubleshooting

1. Run `docker compose ... config --quiet` to catch missing variables before changing the stack.
2. Run `docker compose ... ps` and inspect the first unhealthy dependency.
3. Read `docker compose ... logs --tail=200 SERVICE`; API responses also include an `x-correlation-id` useful for matching logs.
4. Verify datastore URLs use container service names, not `localhost`.
5. Verify SMTP reachability and Google audience configuration if one authentication method alone fails.
6. If a database migration fails, stop the rollout and inspect the exact SQL error. Do not delete or recreate production volumes as a repair.

The container registry must be reachable during the first build or pull. A registry timeout is an infrastructure failure; retry after connectivity is restored rather than changing application code.

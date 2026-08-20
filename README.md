# Clip Sync

Clip Sync is a proof-of-concept hosted clipboard service for Windows 11, macOS, iOS, and Android. The desktop applications automatically exchange text and photos while online. Every client can browse the account's private server-backed history, copy an older item, select and confirm deletion of one or more items, receive operating-system share actions, and rename account devices. History identifies new items by the source device's operating-system name or its account-assigned rename.

Visible Android, iOS, and macOS history screens automatically refresh every 5 seconds for 30 seconds, then every 30 seconds until pausing at 2 minutes. The paused indicator remains visible until the user presses Refresh (or pulls down to refresh on mobile), which immediately reloads history and restarts the schedule.

During a refresh, only the circular Refresh icon spins. The existing history remains visible and is repainted only when the server returns changed history.

The approved behavior is defined in [docs/concepts/REQUIREMENTS.md](docs/concepts/REQUIREMENTS.md). Implementation decisions are recorded in [docs/architecture/DECISIONS.md](docs/architecture/DECISIONS.md), and [docs/REQUIREMENT_TRACE.md](docs/REQUIREMENT_TRACE.md) maps every POC outcome to its implementation.

## Repository map

- `apps/public/clip-sync-api-hono`: Bun/Hono API, PostgreSQL migrations, MongoDB model, tests, and Dockerfile.
- `apps/public/clip-sync-{windows,macos,ios,android}-flutter`: four target-specific Flutter applications. Each contains only its own native platform resources.
- `packages/private/clip-sync-client-core-flutter`: small shared client package for authentication, API access, clipboard access, secure session storage, and state.
- `compose.{local,dev,prod}.yaml`: complete server stacks for each environment.
- `docs/architecture`: architecture and data ownership decisions.
- `docs/operations`: deployment and validation runbooks.
- `docs/mockup`: static desktop and mobile interaction references.

## Start the local server

Prerequisites are Docker Desktop with Compose v2 and ports 4200, 5401, 27017, and 8025 available.

```sh
docker compose -f compose.local.yaml up
```

In another terminal, verify the stack:

```sh
docker compose -f compose.local.yaml ps
curl --fail http://localhost:4200/
```

Mailpit captures local sign-in codes at `http://localhost:8025`. Stop the stack without deleting its databases with:

```sh
docker compose -f compose.local.yaml down
```

See [docs/operations/DEPLOYMENT.md](docs/operations/DEPLOYMENT.md) for shared development and production commands, configuration, health checks, and troubleshooting.

## Run a client

Flutter 3.47 or newer and Node.js 22 or newer are required. Android builds also require Android NDK r28 or newer and Rust's stable channel through `rustup` (currently tested with Rust 1.97.1); the Android app README explains the one-time setup and required 16 KB native-library validation. The repository contains the explicitly approved Google OAuth client configuration at `keys/google-oauth.json`. Local Compose mounts that file read-only for the API. The launcher validates it without printing its values and creates a temporary Dart-define file for Flutter that is removed when the command finishes.

```sh
cd apps/public/clip-sync-android-flutter
flutter pub get
node ../../../tools/with-google-oauth.js -- flutter run
```

The local defaults use `http://localhost:4200` on desktop/iOS Simulator and `http://10.0.2.2:4200` on the Android emulator. A physical phone needs an explicit reachable address. The committed Google web client must retain the exact `http://localhost:8000` JavaScript origin and redirect URI because the desktop sign-in callback listens on that loopback address. Android and iOS also require the native registrations described in each app's README. Email-code sign-in works without Google configuration.

Run `node tools/with-google-oauth.js --check` from the repository root to validate the file without starting another process. The OAuth values are intentionally distributed to native builds; this exception does not authorize committing service credentials, signing keys, user tokens, or any other file under `keys/`.

## Validate

```sh
cd apps/public/clip-sync-api-hono
bun install --frozen-lockfile
bun run format
bun run lint
bun run openapi:lint
bun run test

cd ../../../../packages/private/clip-sync-client-core-flutter
flutter pub get
flutter analyze
flutter test
```

Run the same `flutter analyze` and `flutter test` commands in each client folder. The full checklist is in [docs/operations/VALIDATION.md](docs/operations/VALIDATION.md).

## Privacy and operating model

An account owns exactly one private clipboard and its registered devices. Authorization always derives ownership from the signed token; clients never choose an account or clipboard identifier. PostgreSQL stores account, device-name, authentication, and delivery-event data. MongoDB stores clipboard text and image bytes plus the stable source-device UID used for display-name resolution. Clients retain only the session, client identifier, and optional Google credential in platform secure storage; history remains server-backed.

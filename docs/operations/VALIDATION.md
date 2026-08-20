# Validation checklist

Run validation from a clean checkout before release.

## API

```sh
cd apps/public/clip-sync-api-hono
bun install --frozen-lockfile
bun run format
bun run lint
bun run openapi:lint
bun run test
```

Unit tests cover configuration, structured routes/errors, authorization middleware behavior, device registration validation, and online-only real-time routing. With the local Compose stack healthy, run `bun run test:integration` to exercise email authentication, account isolation, device registration and rename propagation, create/list/get/delete, and WebSocket source exclusion against real PostgreSQL and MongoDB containers.

## Flutter package and apps

Run `flutter pub get`, `flutter analyze`, and `flutter test` in the shared package and all four app folders. Android builds require Rust's stable channel through `rustup` (currently tested with Rust 1.97.1) so the stable clipboard plugin's native library is compiled with Android NDK r28 or newer. Then build on the target operating systems:

```sh
# Linux or macOS with Android SDK and android/key.properties signing values
flutter build apk --release --dart-define=CLIP_SYNC_API_URL=https://api.example.com
./tool/check-16kb-alignment.sh build/app/outputs/flutter-apk/app-release.apk

# macOS with a complete Xcode installation
flutter build ios --release --no-codesign --dart-define=CLIP_SYNC_API_URL=https://api.example.com
flutter build macos --release --dart-define=CLIP_SYNC_API_URL=https://api.example.com

# Windows 11 with Visual Studio Desktop C++ and UWP workloads
flutter build windows --release --dart-define=CLIP_SYNC_API_URL=https://api.example.com
msbuild windows/packaging/Package.wapproj /p:Configuration=Release /p:Platform=x64
```

The Android alignment command must report every ARM64 and x86-64 library as `ALIGNED` and end with successful APK ZIP verification. Install the Android build on a 16 KB emulator, confirm `adb shell getconf PAGE_SIZE` returns `16384`, and verify that Android does not enable page-size compatibility mode.

Install signed target builds and manually confirm email and Google sign-in, text/photo copy, share target invocation, history pagination, deletion, tray/menu pause, resume baseline, cross-account denial, and online-only delivery. Also confirm that a new macOS copy shows the Mac's System Settings name, rename that Mac from another app's Devices control, and verify the renamed source label appears after the next history refresh on every open client. Test Windows 11, current macOS, current iOS, and a supported Android version because native device-name, share, and clipboard integrations cannot be proven by Dart widget tests.

## Compose

```sh
docker compose -f compose.local.yaml config --quiet
docker compose --env-file .env.example -f compose.dev.yaml config --quiet
docker compose --env-file .env.example -f compose.prod.yaml config --quiet
docker compose -f compose.local.yaml up -d --wait
curl --fail http://localhost:4200/
docker compose -f compose.local.yaml down
```

## Release evidence

- All checks above pass or any target-environment limitation is explicitly recorded.
- `git diff --check` reports no whitespace errors.
- No credentials, tokens, private keys, build output, local `.env`, or local database files are staged.
- Runtime dependency or environment changes are reflected in all Compose files and this runbook.
- The Conventional Commit contains only the release's intended files and is pushed to its configured upstream.

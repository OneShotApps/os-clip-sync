#!/usr/bin/env bash

# Build and launch the macOS app after closing any currently running copy.
#
# Prerequisites:
# - macOS with Xcode, Flutter, and Node.js installed.
# - The local server stack started with compose.local.yaml.
# - keys/google-oauth.json configured as documented in the repository README.

set -euo pipefail

SCRIPT_DIRECTORY="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd -- "${SCRIPT_DIRECTORY}/.." && pwd)"
APP_DIRECTORY="apps/public/clip-sync-macos-flutter"
APP_PATH="${REPOSITORY_ROOT}/${APP_DIRECTORY}/build/macos/Build/Products/Debug/clip_sync_macos.app"

fail() {
  echo "macOS launcher failed: $*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Required command '$1' was not found."
}

require_command curl
require_command flutter
require_command node
require_command open
require_command osascript

[[ "$(uname -s)" == "Darwin" ]] || fail "This launcher requires macOS."

curl --fail --silent --show-error http://localhost:4200/ >/dev/null ||
  fail "The local API is unavailable. Start it with: docker compose -f compose.local.yaml up"

echo "Building the macOS app..."
node "${REPOSITORY_ROOT}/tools/with-google-oauth.js" \
  --cwd "${APP_DIRECTORY}" \
  -- flutter build macos --debug

[[ -d "${APP_PATH}" ]] || fail "Flutter did not create ${APP_PATH}."
BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "${APP_PATH}/Contents/Info.plist")"
EXECUTABLE_NAME="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "${APP_PATH}/Contents/Info.plist")"
[[ -n "${BUNDLE_ID}" && -n "${EXECUTABLE_NAME}" ]] ||
  fail "The built macOS app is missing bundle metadata."

# Ask the existing app to exit cleanly before using an exact process-name stop.
osascript -e "tell application id \"${BUNDLE_ID}\" to quit" >/dev/null 2>&1 || true
for ((attempt = 0; attempt < 5; attempt += 1)); do
  pgrep -x "${EXECUTABLE_NAME}" >/dev/null 2>&1 || break
  sleep 1
done
if pgrep -x "${EXECUTABLE_NAME}" >/dev/null 2>&1; then
  pkill -x "${EXECUTABLE_NAME}"
fi

open -n "${APP_PATH}"
for ((attempt = 0; attempt < 10; attempt += 1)); do
  pgrep -x "${EXECUTABLE_NAME}" >/dev/null 2>&1 && break
  sleep 1
done
pgrep -x "${EXECUTABLE_NAME}" >/dev/null 2>&1 || fail "The macOS app did not start."

echo "Clip Sync for macOS is running from ${APP_PATH}."

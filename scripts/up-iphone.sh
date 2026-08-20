#!/usr/bin/env bash

# Build, install, and launch the iPhone app in an available iOS Simulator.
#
# Prerequisites:
# - macOS with Xcode, Flutter, and Node.js installed.
# - The local server stack started with compose.local.yaml.
# - keys/google-oauth.json configured as documented in the repository README.

set -euo pipefail

SCRIPT_DIRECTORY="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd -- "${SCRIPT_DIRECTORY}/.." && pwd)"
APP_DIRECTORY="apps/public/clip-sync-ios-flutter"
APP_PATH="${REPOSITORY_ROOT}/${APP_DIRECTORY}/build/ios/iphonesimulator/Runner.app"

fail() {
  echo "iPhone launcher failed: $*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Required command '$1' was not found."
}

require_command curl
require_command flutter
require_command node
require_command open
require_command xcrun

[[ "$(uname -s)" == "Darwin" ]] || fail "This launcher requires macOS."

curl --fail --silent --show-error http://localhost:4200/ >/dev/null ||
  fail "The local API is unavailable. Start it with: docker compose -f compose.local.yaml up"

SIMULATOR_UDID="$({ xcrun simctl list devices available -j; } | node -e '
let input = "";
process.stdin.on("data", (chunk) => input += chunk);
process.stdin.on("end", () => {
  const devices = Object.values(JSON.parse(input).devices)
    .flat()
    .filter((device) => device.isAvailable && device.name.startsWith("iPhone"));
  const selected = devices.find((device) => device.state === "Booted") ?? devices[0];
  if (selected) process.stdout.write(selected.udid);
});
')"

[[ -n "${SIMULATOR_UDID}" ]] || fail "No available iPhone simulator is installed."

if ! xcrun simctl list devices booted -j | grep -q "${SIMULATOR_UDID}"; then
  echo "Booting iPhone simulator ${SIMULATOR_UDID}..."
  xcrun simctl boot "${SIMULATOR_UDID}"
fi
xcrun simctl bootstatus "${SIMULATOR_UDID}" -b
open -a Simulator

echo "Building the iPhone app..."
node "${REPOSITORY_ROOT}/tools/with-google-oauth.js" \
  --cwd "${APP_DIRECTORY}" \
  -- flutter build ios --simulator --debug

[[ -d "${APP_PATH}" ]] || fail "Flutter did not create ${APP_PATH}."
BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "${APP_PATH}/Info.plist")"
[[ -n "${BUNDLE_ID}" ]] || fail "The built iPhone app has no bundle identifier."

# Terminating an app that is not currently installed or running is expected.
xcrun simctl terminate "${SIMULATOR_UDID}" "${BUNDLE_ID}" >/dev/null 2>&1 || true
xcrun simctl install "${SIMULATOR_UDID}" "${APP_PATH}"
xcrun simctl launch "${SIMULATOR_UDID}" "${BUNDLE_ID}"

echo "Clip Sync for iPhone is running on simulator ${SIMULATOR_UDID}."

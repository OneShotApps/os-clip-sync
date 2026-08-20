#!/usr/bin/env bash

# Build, install, and launch the Android app in a local Android emulator.
#
# Prerequisites:
# - Flutter, Node.js, Android SDK/NDK, an Android Virtual Device, and Rust.
# - The local server stack started with compose.local.yaml.
# - keys/google-oauth.json configured as documented in the repository README.

set -euo pipefail

SCRIPT_DIRECTORY="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd -- "${SCRIPT_DIRECTORY}/.." && pwd)"
APP_DIRECTORY="apps/public/clip-sync-android-flutter"
APK_PATH="${REPOSITORY_ROOT}/${APP_DIRECTORY}/build/app/outputs/flutter-apk/app-debug.apk"
PACKAGE_NAME="app.oneshot.clipsync.clip_sync_android"

fail() {
  echo "Android launcher failed: $*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Required command '$1' was not found."
}

resolve_android_binary() {
  local relative_path="$1"
  local command_name="$2"
  local resolved_command=""
  local sdk_root=""

  resolved_command="$(command -v "${command_name}" 2>/dev/null || true)"
  if [[ -n "${resolved_command}" && -x "${resolved_command}" ]]; then
    echo "${resolved_command}"
    return
  fi

  for sdk_root in \
    "${ANDROID_SDK_ROOT:-}" \
    "${ANDROID_HOME:-}" \
    "${HOME:?}/Library/Android/sdk" \
    "/opt/homebrew/share/android-commandlinetools"; do
    [[ -n "${sdk_root}" ]] || continue
    if [[ -x "${sdk_root}/${relative_path}" ]]; then
      echo "${sdk_root}/${relative_path}"
      return
    fi
  done

  fail "Could not find ${command_name}. Install the Android SDK command-line tools."
}

require_command curl
require_command flutter
require_command node

curl --fail --silent --show-error http://localhost:4200/ >/dev/null ||
  fail "The local API is unavailable. Start it with: docker compose -f compose.local.yaml up"

ADB_BINARY="$(resolve_android_binary "platform-tools/adb" "adb")"
EMULATOR_BINARY="$(resolve_android_binary "emulator/emulator" "emulator")"
ANDROID_SERIAL="$("${ADB_BINARY}" devices | awk '$1 ~ /^emulator-/ && $2 == "device" { print $1; exit }')"

if [[ -z "${ANDROID_SERIAL}" ]]; then
  AVD_NAME="$("${EMULATOR_BINARY}" -list-avds | sed -n '1p')"
  [[ -n "${AVD_NAME}" ]] || fail "No Android Virtual Device is installed. Create one in Android Studio."

  ANDROID_EMULATOR_LOG="${TMPDIR:-/tmp}/clip-sync-android-emulator.log"
  echo "Starting Android Virtual Device ${AVD_NAME}..."
  if [[ "$(uname -s)" == "Darwin" ]] && command -v launchctl >/dev/null 2>&1; then
    EMULATOR_JOB_LABEL="app.oneshot.clipsync.android-emulator"
    if ! launchctl print "gui/$(id -u)/${EMULATOR_JOB_LABEL}" >/dev/null 2>&1; then
      launchctl submit \
        -l "${EMULATOR_JOB_LABEL}" \
        -o "${ANDROID_EMULATOR_LOG}" \
        -e "${ANDROID_EMULATOR_LOG}" \
        -- "${EMULATOR_BINARY}" -avd "${AVD_NAME}"
    fi
  else
    nohup "${EMULATOR_BINARY}" -avd "${AVD_NAME}" >"${ANDROID_EMULATOR_LOG}" 2>&1 &
  fi

  for ((attempt = 0; attempt < 120; attempt += 1)); do
    ANDROID_SERIAL="$("${ADB_BINARY}" devices | awk '$1 ~ /^emulator-/ && $2 == "device" { print $1; exit }')"
    [[ -n "${ANDROID_SERIAL}" ]] && break
    sleep 1
  done
  [[ -n "${ANDROID_SERIAL}" ]] ||
    fail "The emulator did not connect. Review ${ANDROID_EMULATOR_LOG}."
fi

"${ADB_BINARY}" -s "${ANDROID_SERIAL}" wait-for-device
for ((attempt = 0; attempt < 120; attempt += 1)); do
  BOOT_COMPLETE="$("${ADB_BINARY}" -s "${ANDROID_SERIAL}" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')"
  [[ "${BOOT_COMPLETE}" == "1" ]] && break
  sleep 1
done
[[ "${BOOT_COMPLETE:-}" == "1" ]] || fail "Android emulator ${ANDROID_SERIAL} did not finish booting."

echo "Building the Android app..."
node "${REPOSITORY_ROOT}/tools/with-google-oauth.js" \
  --cwd "${APP_DIRECTORY}" \
  -- flutter build apk --debug

[[ -f "${APK_PATH}" ]] || fail "Flutter did not create ${APK_PATH}."

if "${ADB_BINARY}" -s "${ANDROID_SERIAL}" shell pm path "${PACKAGE_NAME}" >/dev/null 2>&1; then
  "${ADB_BINARY}" -s "${ANDROID_SERIAL}" shell am force-stop "${PACKAGE_NAME}"
fi
"${ADB_BINARY}" -s "${ANDROID_SERIAL}" install -r "${APK_PATH}"
"${ADB_BINARY}" -s "${ANDROID_SERIAL}" shell am force-stop "${PACKAGE_NAME}"
"${ADB_BINARY}" -s "${ANDROID_SERIAL}" shell am start -W \
  -n "${PACKAGE_NAME}/.MainActivity"

echo "Clip Sync for Android is running on ${ANDROID_SERIAL}."

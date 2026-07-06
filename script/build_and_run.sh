#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# DerivedData defaults to a non-iCloud-synced location: the Desktop/Documents
# file provider adds Finder metadata to build products, which breaks codesign.
# Override with ONECLOCK_DERIVED_DATA to choose another path.
DERIVED_DATA_PATH="${ONECLOCK_DERIVED_DATA:-${TMPDIR:-/tmp}/OneClockDerivedData}"
PROJECT_PATH="${PROJECT_ROOT}/OneClock.xcodeproj"
SCHEME="OneClock"
CONFIGURATION="Debug"
APP_PATH="${DERIVED_DATA_PATH}/Build/Products/${CONFIGURATION}/OneClock.app"
BUNDLE_ID="dev.andrehung.OneClock.dev"

echo "==> Building ${SCHEME} (${CONFIGURATION})"

xattr -cr "${PROJECT_ROOT}/OneClock" "${PROJECT_PATH}" "${DERIVED_DATA_PATH}" 2>/dev/null || true

xcodebuild \
  -project "${PROJECT_PATH}" \
  -scheme "${SCHEME}" \
  -configuration "${CONFIGURATION}" \
  -derivedDataPath "${DERIVED_DATA_PATH}" \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGN_STYLE=Manual \
  build

if [[ ! -d "${APP_PATH}" ]]; then
  echo "error: expected app was not built at ${APP_PATH}" >&2
  exit 1
fi

xattr -cr "${APP_PATH}" 2>/dev/null || true

echo "==> Terminating any running development instance"
if pgrep -x "OneClock" >/dev/null; then
  pkill -x "OneClock"
  sleep 0.5
fi

if pgrep -x "OneClock" >/dev/null; then
  echo "error: previous OneClock instance is still running" >&2
  exit 1
fi

echo "==> Launching ${APP_PATH}"
open "${APP_PATH}"

echo "==> One Clock launched"

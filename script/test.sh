#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="${PROJECT_ROOT}/OneClock.xcodeproj"
SCHEME="OneClock"
CONFIGURATION="Debug"

# DerivedData must live outside iCloud-synced folders (Desktop/Documents):
# the file provider adds com.apple.FinderInfo attributes to build products,
# which makes codesign fail with "resource fork, Finder information, or
# similar detritus not allowed". Override with ONECLOCK_DERIVED_DATA if needed.
DERIVED_DATA_PATH="${ONECLOCK_DERIVED_DATA:-${TMPDIR:-/tmp}/OneClockDerivedData}"

echo "==> Testing ${SCHEME} (${CONFIGURATION})"
echo "==> DerivedData: ${DERIVED_DATA_PATH}"

xattr -cr "${PROJECT_ROOT}/OneClock" "${PROJECT_ROOT}/OneClockTests" "${PROJECT_PATH}" 2>/dev/null || true

xcodebuild \
  -project "${PROJECT_PATH}" \
  -scheme "${SCHEME}" \
  -configuration "${CONFIGURATION}" \
  -derivedDataPath "${DERIVED_DATA_PATH}" \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGN_STYLE=Manual \
  test

echo "==> All tests passed"

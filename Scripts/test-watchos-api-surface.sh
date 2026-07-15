#!/usr/bin/env bash

set -euo pipefail

: "${DEVELOPER_DIR:?run through the reviewed toolchain preflight}"
test -d "$DEVELOPER_DIR"
ACTIVE_SWIFT="$(/usr/bin/xcrun --find swift)"
case "$ACTIVE_SWIFT" in
  "$DEVELOPER_DIR"/*) ;;
  *)
    echo "active Swift is outside DEVELOPER_DIR: $ACTIVE_SWIFT" >&2
    exit 1
    ;;
esac

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

SCRATCH="$(mktemp -d "${RUNNER_TEMP:-/tmp}/adaptiveglyphkit-watch-api.XXXXXX")"
trap 'rm -rf "$SCRATCH"' EXIT

SDK="$(xcrun --sdk watchsimulator --show-sdk-path)"
DIAGNOSTIC="Forge on an encoding-capable platform, then pass imageContent."

build_target() {
  local target="$1"
  local log="$2"
  xcrun swift build \
    --package-path Tests/CompileFixtures \
    --target "$target" \
    --triple arm64-apple-watchos11.0-simulator \
    --sdk "$SDK" \
    --scratch-path "$SCRATCH/$target" \
    -Xswiftc -strict-concurrency=complete \
    -Xswiftc -warnings-as-errors \
    >"$log" 2>&1
}

supported_target="WatchSupportedAPIs"
supported_log="$SCRATCH/$supported_target.log"
if ! build_target "$supported_target" "$supported_log"; then
  cat "$supported_log"
  echo "FAIL: $supported_target must build for watchOS" >&2
  exit 1
fi
cat "$supported_log"
echo "PASS: $supported_target built for watchOS"

negative_targets=(
  "WatchUnavailableMakeImageContentData"
  "WatchUnavailableMakeImageContentCGImage"
  "WatchUnavailableMakeGlyphData"
  "WatchUnavailableMakeGlyphCGImage"
  "WatchUnavailableAttributedStringFromImageData"
)

for target in "${negative_targets[@]}"; do
  log="$SCRATCH/$target.log"
  if build_target "$target" "$log"; then
    cat "$log"
    echo "FAIL: $target unexpectedly built for watchOS" >&2
    exit 1
  else
    status=$?
  fi
  cat "$log"
  test "$status" -ne 0
  grep -F "$target" "$log" >/dev/null || {
    echo "FAIL: $target log did not identify its target" >&2
    exit 1
  }
  grep -F "$DIAGNOSTIC" "$log" >/dev/null || {
    echo "FAIL: $target log did not contain the required diagnostic" >&2
    exit 1
  }
  echo "PASS: $target failed independently with the required diagnostic"
done

#!/bin/bash
set -euo pipefail
: "${DEVELOPER_DIR:?run through the reviewed toolchain preflight}"
test -d "$DEVELOPER_DIR"
runtime_id="$1"

existing="$(
  xcrun simctl list devices available -j |
    jq -r --arg runtime "$runtime_id" \
      '.devices[$runtime] // [] | .[] | select(.isAvailable) | .udid' |
    head -n 1
)"
if test -n "$existing"; then
  printf '%s\n' "$existing"
  exit 0
fi

while IFS= read -r device_type; do
  if udid="$(
    xcrun simctl create \
      "AdaptiveGlyphKit $runtime_id" "$device_type" "$runtime_id" 2>/dev/null
  )"; then
    printf '%s\n' "$udid"
    exit 0
  fi
done < <(
  xcrun simctl list devicetypes -j |
    jq -r '.devicetypes[] |
      select(.name | startswith("Apple Watch")) | .identifier'
)

echo "No compatible Apple Watch simulator device for $runtime_id" >&2
exit 1

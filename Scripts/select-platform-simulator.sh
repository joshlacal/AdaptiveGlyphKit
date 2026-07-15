#!/bin/bash
set -euo pipefail

if [[ $# -ne 2 || -z $1 || -z $2 ]]; then
  echo "usage: $0 RUNTIME_IDENTIFIER DEVICE_NAME_PREFIX" >&2
  exit 64
fi

: "${DEVELOPER_DIR:?run through the reviewed toolchain preflight}"
[[ -d "$DEVELOPER_DIR" ]] || {
  echo "DEVELOPER_DIR does not exist: $DEVELOPER_DIR" >&2
  exit 1
}
command -v jq >/dev/null 2>&1 || {
  echo "jq is required" >&2
  exit 1
}

runtime_id=$1
device_prefix=$2

runtime_json="$(/usr/bin/xcrun simctl list runtimes available -j)"
if ! jq -e --arg runtime "$runtime_id" \
  '.runtimes | any(.identifier == $runtime and .isAvailable == true)' \
  >/dev/null <<<"$runtime_json"; then
  echo "Requested simulator runtime is not available: $runtime_id" >&2
  exit 1
fi

device_types="$({
  /usr/bin/xcrun simctl list devicetypes -j |
    jq -c --arg prefix "$device_prefix" \
      '[.devicetypes[] | select(.name | startswith($prefix)) | .identifier]'
})"
if [[ $(jq 'length' <<<"$device_types") -eq 0 ]]; then
  echo "No simulator device type starts with: $device_prefix" >&2
  exit 1
fi

existing="$({
  /usr/bin/xcrun simctl list devices available -j |
    jq -r --arg runtime "$runtime_id" --argjson deviceTypes "$device_types" '
      [
        (.devices[$runtime] // [])[]
        | select(.isAvailable == true)
        | select(.deviceTypeIdentifier as $identifier | $deviceTypes | index($identifier))
        | .udid
      ][0] // empty
    '
})"
if [[ -n "$existing" ]]; then
  printf '%s\n' "$existing"
  exit 0
fi

while IFS= read -r device_type; do
  if udid="$(
    /usr/bin/xcrun simctl create \
      "AdaptiveGlyphKit $runtime_id" "$device_type" "$runtime_id" 2>/dev/null
  )" && [[ -n "$udid" ]]; then
    printf '%s\n' "$udid"
    exit 0
  fi
done < <(jq -r '.[]' <<<"$device_types")

echo "No compatible $device_prefix simulator for $runtime_id" >&2
exit 1

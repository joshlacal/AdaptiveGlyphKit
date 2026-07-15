#!/bin/bash
set -euo pipefail

if [[ $# -ne 1 || -z $1 ]]; then
  echo "usage: $0 RESULT_DIRECTORY" >&2
  exit 64
fi

RESULT_DIRECTORY=$1
case "$RESULT_DIRECTORY" in
  /tmp/* | /private/tmp/*) ;;
  *)
    echo "RESULT_DIRECTORY must be an absolute path under /tmp" >&2
    exit 64
    ;;
esac

: "${DEVELOPER_DIR:?run through the reviewed toolchain preflight}"
[[ -d "$DEVELOPER_DIR" ]] || {
  echo "DEVELOPER_DIR does not exist: $DEVELOPER_DIR" >&2
  exit 1
}
command -v jq >/dev/null 2>&1 || {
  echo "jq is required" >&2
  exit 1
}

swift_bin="$(/usr/bin/xcrun --find swift)"
case "$swift_bin" in
  "$DEVELOPER_DIR"/*) ;;
  *)
    echo "Active Swift is outside DEVELOPER_DIR: $swift_bin" >&2
    exit 1
    ;;
esac
if [[ -n ${RELEASE_SWIFT:-} && "$swift_bin" != "$RELEASE_SWIFT" ]]; then
  echo "Active Swift does not match RELEASE_SWIFT: $swift_bin" >&2
  exit 1
fi

swift_version="$({
  "$swift_bin" --version |
    sed -n 's/.*Apple Swift version \([0-9][0-9.]*\).*/\1/p' |
    head -n 1
})"
[[ -n "$swift_version" ]] || {
  echo "Unable to determine active Swift version" >&2
  exit 1
}
if [[ -n ${RELEASE_SWIFT_VERSION:-} && "$swift_version" != "$RELEASE_SWIFT_VERSION" ]]; then
  echo "Active Swift $swift_version does not match required $RELEASE_SWIFT_VERSION" >&2
  exit 1
fi

mkdir -p "$RESULT_DIRECTORY/derived-data" "$RESULT_DIRECTORY/results"
runtime_json="$(/usr/bin/xcrun simctl list runtimes available -j)"

latest_runtime() {
  local marker=$1
  jq -r --arg marker "$marker" '
    [
      .runtimes[]
      | select(.isAvailable == true)
      | select(.identifier | contains($marker))
    ]
    | sort_by(.version | split(".") | map(tonumber))
    | (last // {})
    | .identifier // empty
  ' <<<"$runtime_json"
}

runtime_version() {
  local runtime_id=$1
  jq -r --arg runtime "$runtime_id" '
    [.runtimes[] | select(.identifier == $runtime)][0].version // empty
  ' <<<"$runtime_json"
}

IOS_RUNTIME="$(latest_runtime 'iOS')"
TVOS_RUNTIME="$(latest_runtime 'tvOS')"
VISIONOS_RUNTIME="$(latest_runtime 'xrOS')"
[[ -n "$IOS_RUNTIME" ]] || { echo "No available iOS simulator runtime" >&2; exit 1; }
[[ -n "$TVOS_RUNTIME" ]] || { echo "No available tvOS simulator runtime" >&2; exit 1; }
[[ -n "$VISIONOS_RUNTIME" ]] || { echo "No available visionOS simulator runtime" >&2; exit 1; }

IOS_VERSION="$(runtime_version "$IOS_RUNTIME")"
TVOS_VERSION="$(runtime_version "$TVOS_RUNTIME")"
VISIONOS_VERSION="$(runtime_version "$VISIONOS_RUNTIME")"
[[ -n "$IOS_VERSION" && -n "$TVOS_VERSION" && -n "$VISIONOS_VERSION" ]]

if [[ ${RELEASE_TOOLCHAIN_LANE:-} == local-validation ]]; then
  [[ "$IOS_VERSION" == "${RELEASE_IOS_RUNTIME:?}" ]]
  [[ "$TVOS_VERSION" == "${RELEASE_TVOS_RUNTIME:?}" ]]
  [[ "$VISIONOS_VERSION" == "${RELEASE_VISIONOS_RUNTIME:?}" ]]
fi

IOS_UDID="$(bash Scripts/select-platform-simulator.sh "$IOS_RUNTIME" 'iPhone')"
TVOS_UDID="$(bash Scripts/select-platform-simulator.sh "$TVOS_RUNTIME" 'Apple TV')"
VISIONOS_UDID="$(
  bash Scripts/select-platform-simulator.sh "$VISIONOS_RUNTIME" 'Apple Vision'
)"
[[ -n "$IOS_UDID" && -n "$TVOS_UDID" && -n "$VISIONOS_UDID" ]]

{
  printf 'evidence_label=%s\n' "${RELEASE_EVIDENCE_LABEL:-xcode27-beta-local-validation}"
  printf 'evidence_class=%s\n' "${RELEASE_EVIDENCE_CLASS:-unknown}"
  printf 'swift_bin=%s\n' "$swift_bin"
  printf 'swift_version=%s\n' "$swift_version"
  printf 'ios_runtime_id=%s\n' "$IOS_RUNTIME"
  printf 'ios_runtime_version=%s\n' "$IOS_VERSION"
  printf 'ios_udid=%s\n' "$IOS_UDID"
  printf 'tvos_runtime_id=%s\n' "$TVOS_RUNTIME"
  printf 'tvos_runtime_version=%s\n' "$TVOS_VERSION"
  printf 'tvos_udid=%s\n' "$TVOS_UDID"
  printf 'visionos_runtime_id=%s\n' "$VISIONOS_RUNTIME"
  printf 'visionos_runtime_version=%s\n' "$VISIONOS_VERSION"
  printf 'visionos_udid=%s\n' "$VISIONOS_UDID"
} | tee "$RESULT_DIRECTORY/selected-platforms.txt"

strict_settings=(
  SWIFT_STRICT_CONCURRENCY=complete
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES
)

run_full_test() {
  local lane=$1
  local destination=$2
  /usr/bin/xcodebuild test \
    -scheme AdaptiveGlyphKit \
    -configuration Debug \
    -destination "$destination" \
    -derivedDataPath "$RESULT_DIRECTORY/derived-data/$lane" \
    -resultBundlePath "$RESULT_DIRECTORY/results/$lane-full-test.xcresult" \
    "${strict_settings[@]}"
}

run_smoke_test() {
  local lane=$1
  local destination=$2
  local derived_data="$RESULT_DIRECTORY/derived-data/$lane"

  /usr/bin/xcodebuild build-for-testing \
    -scheme AdaptiveGlyphKit \
    -configuration Debug \
    -destination "$destination" \
    -derivedDataPath "$derived_data" \
    -resultBundlePath "$RESULT_DIRECTORY/results/$lane-build-for-testing.xcresult" \
    "${strict_settings[@]}"

  /usr/bin/xcodebuild test-without-building \
    -scheme AdaptiveGlyphKit \
    -configuration Debug \
    -destination "$destination" \
    -derivedDataPath "$derived_data" \
    -resultBundlePath "$RESULT_DIRECTORY/results/$lane-runtime-smoke.xcresult" \
    -only-testing:AdaptiveGlyphKitTests/PlatformRuntimeSmokeTests \
    "${strict_settings[@]}"
}

run_full_test macos 'platform=macOS'
run_full_test ios "platform=iOS Simulator,id=$IOS_UDID"
run_smoke_test catalyst 'platform=macOS,variant=Mac Catalyst'
run_smoke_test tvos "platform=tvOS Simulator,id=$TVOS_UDID"
run_smoke_test visionos "platform=visionOS Simulator,id=$VISIONOS_UDID"

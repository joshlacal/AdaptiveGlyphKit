#!/bin/bash
set -euo pipefail

: "$ADAPTIVE_GLYPHKIT_URL"
: "$ADAPTIVE_GLYPHKIT_VERSION"

if [[ ! "$ADAPTIVE_GLYPHKIT_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Version must be bare SemVer" >&2
  exit 1
fi
case "$ADAPTIVE_GLYPHKIT_URL" in
  https://*) ;;
  *) echo "URL must be public HTTPS" >&2; exit 1 ;;
esac

: "${DEVELOPER_DIR:?workflow must select and verify an exact Xcode first}"
: "${SWIFT_BIN:?workflow must export the verified Xcode Swift binary first}"
test -d "$DEVELOPER_DIR"
# Compare canonical paths: runner images expose the same Xcode under alias
# symlinks, and xcrun reports the canonical one.
canonicalize() {
  printf '%s/%s\n' "$(cd "$(dirname "$1")" && pwd -P)" "$(basename "$1")"
}
EXPECTED_SWIFT="$DEVELOPER_DIR/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift"
test "$(canonicalize "$SWIFT_BIN")" = "$(canonicalize "$EXPECTED_SWIFT")"
test -x "$SWIFT_BIN"
test "$(canonicalize "$(/usr/bin/xcrun --find swift)")" = "$(canonicalize "$SWIFT_BIN")"

ROOT="$(mktemp -d)"
trap 'status=$?; trap - EXIT; rm -rf "$ROOT"; exit "$status"' EXIT
mkdir -p "$ROOT/Sources/Consumer"

sed \
  -e "s|PACKAGE_URL|$ADAPTIVE_GLYPHKIT_URL|" \
  -e "s|PACKAGE_VERSION|$ADAPTIVE_GLYPHKIT_VERSION|" \
  > "$ROOT/Package.swift" <<'MANIFEST'
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "Consumer",
  platforms: [.macOS(.v15)],
  dependencies: [
    .package(url: "PACKAGE_URL", exact: "PACKAGE_VERSION"),
  ],
  targets: [
    .executableTarget(
      name: "Consumer",
      dependencies: [
        .product(name: "AdaptiveGlyphKit", package: "AdaptiveGlyphKit")
      ]),
  ])
MANIFEST

cat > "$ROOT/Sources/Consumer/main.swift" <<'SOURCE'
import AdaptiveGlyphKit
import Foundation

let fallback = AttributedString.adaptiveImageGlyph(
  imageContent: Data(),
  fallback: ":glyph:")
precondition(String(fallback.characters) == ":glyph:")
_ = AdaptiveImageGlyphForge.makeGlyph(imageContent: Data())
SOURCE

"$SWIFT_BIN" package --package-path "$ROOT" resolve
"$SWIFT_BIN" build --package-path "$ROOT" -c release \
  -Xswiftc -strict-concurrency=complete \
  -Xswiftc -warnings-as-errors

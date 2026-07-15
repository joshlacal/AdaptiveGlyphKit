#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FIXTURES="$ROOT/Tests/AdaptiveGlyphKitTests/Fixtures"
PROVENANCE="$FIXTURES/provenance.json"

jq -e '
  def expected_paths: [
    "project-owned-blue-glyph.heic",
    "wrong-type.png",
    "nine-representations.heic",
    "edge-1025.heic",
    "two-1024-representations.heic"
  ];
  .adaptiveGlyphKitSourceRevision ==
    "a1afe9552df4384999a736dcf24cc44d0fdc0750"
  and .sourceArtwork ==
    "Original solid-blue circle drawn by the AdaptiveGlyphKit fixture generator."
  and ((.generatorPlatform | type) == "string")
  and (.generatorPlatform | test("\\S"))
  and .generatorCommand ==
    "xcrun swift Scripts/generate-test-fixtures.swift Tests/AdaptiveGlyphKitTests/Fixtures"
  and .semanticIdentifier == "adaptiveglyphkit.project-owned.blue-circle.v1"
  and .semanticDescription == "Project-owned blue circle"
  and ((.fixtures | type) == "array")
  and (.fixtures | length == 5)
  and (([.fixtures[].path] | unique | length) == 5)
  and (([.fixtures[].path] | sort) == (expected_paths | sort))
  and all(.fixtures[];
    ((.path | type) == "string")
    and ((.byteCount | type) == "number")
    and (.byteCount > 0)
    and (.byteCount == (.byteCount | floor))
    and ((.sha256 | type) == "string")
    and (.sha256 | test("^[0-9a-f]{64}$")))
' "$PROVENANCE" >/dev/null

while IFS=$'\t' read -r path expected_bytes expected_sha; do
  file="$FIXTURES/$path"
  test -f "$file"
  actual_bytes="$(stat -f %z "$file")"
  actual_sha="$(shasum -a 256 "$file" | awk '{print $1}')"
  test "$actual_bytes" = "$expected_bytes"
  test "$actual_sha" = "$expected_sha"
done < <(jq -r '.fixtures[] | [.path, .byteCount, .sha256] | @tsv' "$PROVENANCE")

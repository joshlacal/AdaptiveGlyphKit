# AdaptiveGlyphKit

AdaptiveGlyphKit renders existing artwork as an inline adaptive image glyph in
Apple text. Glyphs flow inside a sentence like Genmoji, scale with Dynamic
Type, and can carry an accessibility description.

`NSAdaptiveImageGlyph` is the system type behind Genmoji and custom stickers,
but its public initializer accepts only prebuilt image content. AdaptiveGlyphKit
is an experimental compatibility bridge: it forges the minimal accepted content
shape on encoding-capable platforms and safely consumes bounded pre-forged
content on every supported platform.

## Installation

After publication, add the package with a library-compatible version range:

```swift
dependencies: [
  .package(
    url: "https://github.com/joshlacal/AdaptiveGlyphKit.git",
    .upToNextMinor(from: "0.1.0")),
]
```

The repository and immutable `0.1.0` tag are not published yet; the coordinate
above is the intended release target. AdaptiveGlyphKit has no third-party
dependencies.

## Prepare glyphs before rendering

```swift
import AdaptiveGlyphKit
import SwiftUI

let renderedGlyph: AttributedString = .adaptiveImageGlyph(
  from: pngData,
  contentIdentifier: stableID,
  accessibilityDescription: "A round blue cat",
  fallback: ":blobcat:")

struct GlyphRow: View {
  let renderedGlyph: AttributedString

  var body: some View {
    Text(renderedGlyph)
  }
}
```

Image decode, EXIF normalization, resize, HEIC encode, structural parse, and
glyph parse are synchronous and must be performed or cached outside SwiftUI body.

## Platform capabilities

| Platform | Forge source images | Consume pre-forged content | Render |
|---|---:|---:|---:|
| iOS 18 / iPadOS 18 | Yes | Yes | Yes |
| macOS 15 | Yes | Yes | Yes |
| Mac Catalyst 18 | Yes | Yes | Yes |
| tvOS 18 | Yes | Yes | Yes |
| visionOS 2 | Yes | Yes | Yes |
| watchOS 11 | No, compile-time unavailable | Yes | Yes |

watchOS can consume and render pre-forged content only. Load persisted content
outside `body`, then build the attributed value:

```swift
let watchText = AttributedString.adaptiveImageGlyph(
  imageContent: persistedGlyphData,
  fallback: ":blobcat:")
```

Forge on an encoding-capable platform, persist or transfer the resulting bytes,
then validate and cache them on watchOS before rendering. Structural parsing,
glyph parsing, and attributed-string bridging are synchronous too.

## Bounded 0.1.0 content policy

`makeGlyph(imageContent:)` accepts externally forged adaptive-glyph data and
reconstructs glyphs from cached bytes; neither origin bypasses preflight. The
same policy applies to content produced by AdaptiveGlyphKit:

- Input must be nonempty and at most 1,048,576 bytes.
- The type must equal `NSAdaptiveImageGlyph.contentType`.
- Content must contain one to eight representations.
- Every representation must have integral width and height from 1 through
  1,024 pixels.
- Cumulative pixels must be at most 1,048,576, using checked arithmetic.
- There is no caller-selectable unlimited sentinel.

The 1 MiB limit is AdaptiveGlyphKit's intentional 0.1.0 policy, not a
documented Apple limit.

Source-image forging defaults to a 512-pixel longer edge and hard-clamps at
1,024 pixels. The `Data` path decodes with ImageIO and normalizes EXIF
orientation. The `CGImage` path performs no EXIF work, never upscales, and uses
CoreGraphics resizing only when the source exceeds the selected bound.

## Accessibility

Provide a description when the inline object needs an accessible label:

```swift
let labeledGlyph = AttributedString.adaptiveImageGlyph(
  from: pngData,
  contentIdentifier: stableID,
  accessibilityDescription: "A round blue cat",
  fallback: ":blobcat:")
```

Omitting `accessibilityDescription` produces an unlabeled inline object. The
`contentIdentifier` is a stable cache key; it is not accessibility text.

## Lower-level API

- `AdaptiveImageGlyphForge.makeImageContent(imageData:...) throws -> Data`
- `AdaptiveImageGlyphForge.makeImageContent(cgImage:...) throws -> Data`
- `AdaptiveImageGlyphForge.makeGlyph(imageData:...) -> NSAdaptiveImageGlyph?`
- `AdaptiveImageGlyphForge.makeGlyph(cgImage:...) -> NSAdaptiveImageGlyph?`
- `AdaptiveImageGlyphForge.makeGlyph(imageContent:) -> NSAdaptiveImageGlyph?`
- `AttributedString(adaptiveImageGlyph:) -> AttributedString?`
- `AttributedString.adaptiveImageGlyph(imageContent:fallback:) -> AttributedString`

To splice a glyph into existing text, replace a range with a glyph run:

```swift
var text = AttributedString("hello :blobcat: world")
if let range = text.range(of: ":blobcat:"),
   let glyph = AdaptiveImageGlyphForge.makeGlyph(
     imageData: pngData,
     contentIdentifier: stableID),
   let run = AttributedString(adaptiveImageGlyph: glyph) {
  text.replaceSubrange(range, with: run)
}
```

## AppKit

AppKit text views render adaptive image glyphs when a TextKit 2 `NSTextView`
opts in:

```swift
textView.importsGraphics = true
textView.textStorage?.setAttributedString(NSAttributedString(text))
```

`NSTextInputClient.supportsAdaptiveImageGlyph` is the read-only capability
flag; `importsGraphics` is the switch to set. Use an `NSTextView` when testing
the AppKit rendering path.

## Scope and caveats

AdaptiveGlyphKit is not a Genmoji generator. It reproduces an undocumented
content shape: a HEIC whose TIFF `DocumentName` carries the identifier and whose
`ImageDescription` carries the optional accessibility text. A future OS could
change what `NSAdaptiveImageGlyph(imageContent:)` accepts.

The package emits one bounded HEIC representation with alpha. It does not
reproduce private sizing or alignment metadata, so baseline or optical alignment
may differ from system Genmoji at extreme sizes. All glyph builders return `nil`
on rejection, and the high-level attributed-string functions return readable
fallback text. Never assume glyph construction is guaranteed.

## License

MIT. See [LICENSE](LICENSE).

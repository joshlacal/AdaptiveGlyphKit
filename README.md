# AdaptiveGlyphKit

Render **existing artwork as an inline adaptive image glyph** in Apple text —
flowing inside a sentence like Genmoji, sized to the surrounding text, scaling
with Dynamic Type, carrying an accessibility description.

`NSAdaptiveImageGlyph` is the system type behind Genmoji and custom stickers.
Apple ships no API to build one from your own artwork — its initializer only
accepts data the system itself produced. AdaptiveGlyphKit is an **experimental
compatibility bridge**: it reproduces the minimal shape that
`NSAdaptiveImageGlyph(imageContent:)` accepts, so a PNG (or any
`ImageIO`-decodable image) can be turned into glyph content and dropped into a
SwiftUI `Text`, `UITextView`, or `NSTextView`.

```swift
import AdaptiveGlyphKit

// One call, always safe: renders the glyph, or the fallback text if anything fails.
Text(.adaptiveImageGlyph(
  from: pngData,
  contentIdentifier: stableID,             // the glyph cache key — stable & unique
  accessibilityDescription: "A round blue cat",
  fallback: ":blobcat:"))
```

To splice a glyph into existing text, replace a range with a glyph run:

```swift
var body = AttributedString("hello :blobcat: world")
if let r = body.range(of: ":blobcat:"),
   let glyph = AdaptiveImageGlyphForge.makeGlyph(imageData: pngData, contentIdentifier: stableID),
   let run = AttributedString(adaptiveImageGlyph: glyph) {
  body.replaceSubrange(r, with: run)
}
Text(body)
```

## Installation

```swift
.package(url: "https://github.com/joshlacal/AdaptiveGlyphKit.git", from: "0.1.0")
```

Platforms: iOS 18 · iPadOS 18 · macOS 15 · Mac Catalyst 18 · tvOS 18 ·
visionOS 2 · watchOS 11. No third-party dependencies.

## API

**High-level (recommended, always returns something usable):**

- `AttributedString.adaptiveImageGlyph(from:contentIdentifier:accessibilityDescription:fallback:maximumDimension:) -> AttributedString`
  — forges and inlines a glyph, or returns the `fallback` text on any failure.

**Low-level:**

- `AdaptiveImageGlyphForge.makeGlyph(imageData:contentIdentifier:accessibilityDescription:maximumDimension:) -> NSAdaptiveImageGlyph?`
- `AdaptiveImageGlyphForge.makeGlyph(cgImage:contentIdentifier:accessibilityDescription:) -> NSAdaptiveImageGlyph?`
- `AdaptiveImageGlyphForge.makeGlyph(imageContent:) -> NSAdaptiveImageGlyph?` — rebuild from cached bytes.
- `AdaptiveImageGlyphForge.makeImageContent(imageData:…) throws -> Data` — the forged HEIC bytes, for caching (throws `GlyphForgeError`).
- `AttributedString(adaptiveImageGlyph:) -> AttributedString?` — a single-character (`\u{FFFC}`) glyph run.

Source images are normalized for EXIF orientation and downsampled so the longer
edge is at most `maximumDimension` (default 512 px), bounding memory/CPU for
large or remote images.

## AppKit

Everything works on macOS. AppKit text views render adaptive image glyphs only
when they opt in — set `importsGraphics` on a TextKit 2 `NSTextView`:

```swift
textView.importsGraphics = true            // enables adaptive image glyphs (macOS 15+)
if let glyph = AdaptiveImageGlyphForge.makeGlyph(imageData: pngData, contentIdentifier: stableID),
   let run = AttributedString(adaptiveImageGlyph: glyph) {
  textView.textStorage?.setAttributedString(NSAttributedString(run))
}
```

(`NSTextInputClient.supportsAdaptiveImageGlyph` is the read-only capability flag;
`importsGraphics` is the switch you set.) Note: SwiftUI's `ImageRenderer` does not
rasterize adaptive image glyphs on macOS, so snapshot-testing them there needs an
`NSTextView`; live rendering in a real text view is unaffected.

## `contentIdentifier` matters

`contentIdentifier` becomes the glyph's `contentIdentifier`, which the text
system uses as a **cache key**. Give each distinct image a **stable, unique**
identifier (e.g. a UUIDv5 derived from a content hash or source URL). Reusing one
identifier for different images, or colliding with a real Genmoji's identifier,
will confuse the glyph cache.

## Scope & caveats

This is an **experimental compatibility bridge**, not a Genmoji generator:

- The data shape `NSAdaptiveImageGlyph(imageContent:)` accepts is **not public
  API**. AdaptiveGlyphKit reproduces it (a HEIC whose TIFF `DocumentName` carries
  the identifier and `ImageDescription` the accessibility text). A future OS
  could change what the initializer accepts.
- It produces a **single HEIC representation** (with alpha), which the system
  scales. This matches what Apple's own Genmoji actually ship (a single ~320 px
  image + alpha); AdaptiveGlyphKit uses 512 px. Transparency is preserved and a
  single representation scales cleanly across Dynamic Type sizes (both verified
  in tests), so multi-resolution isn't needed for inline use. What's *not*
  reproduced is the format's sizing/alignment metadata, so baseline/optical
  alignment may differ slightly from a true Genmoji at extreme sizes.
- Because acceptance is undocumented, **degrade gracefully**: `makeGlyph`
  returns `nil` and `AttributedString(adaptiveImageGlyph:)` returns `nil` on
  failure, and the high-level `adaptiveImageGlyph(from:…fallback:)` returns your
  text. Never assume a glyph is guaranteed.

## Related work

- [Customoji](https://github.com/YusukeSano/customoji) — generates multiple
  resolutions, square-crops, typed errors, sync/async, `NSAttributedString`
  decompose/recompose. Heavier; `UIImage`/`NSImage`-only input.
- [Zenmoji](https://github.com/noppefoxwolf/Zenmoji) — compact multi-resolution
  container; iOS-only, no accessibility description, minimal error handling.

AdaptiveGlyphKit differentiates as the **small, dependency-free,
`Data`/`CGImage`-first, fallback-safe** option with a Swift `AttributedString`
API and verified SwiftUI + AppKit rendering across six Apple platform families.
If you need true multi-resolution content today, prefer Customoji.

## License

MIT (see [LICENSE](LICENSE)).

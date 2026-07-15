import AdaptiveGlyphKit
import CoreGraphics

func mustBeUnavailable(_ image: CGImage) {
  _ = AdaptiveImageGlyphForge.makeGlyph(
    cgImage: image,
    contentIdentifier: "watch-negative")
}

import AdaptiveGlyphKit
import Foundation

func compileSupportedWatchSurface(_ data: Data) {
  if let glyph = AdaptiveImageGlyphForge.makeGlyph(imageContent: data) {
    _ = AttributedString(adaptiveImageGlyph: glyph)
  }
  _ = AttributedString.adaptiveImageGlyph(
    imageContent: data,
    fallback: ":blue-circle:")
}

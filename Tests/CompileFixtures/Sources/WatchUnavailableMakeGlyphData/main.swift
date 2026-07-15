import AdaptiveGlyphKit
import Foundation

func mustBeUnavailable(_ data: Data) {
  _ = AdaptiveImageGlyphForge.makeGlyph(
    imageData: data,
    contentIdentifier: "watch-negative")
}

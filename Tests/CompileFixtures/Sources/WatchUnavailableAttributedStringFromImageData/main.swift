import AdaptiveGlyphKit
import Foundation

func mustBeUnavailable(_ data: Data) {
  _ = AttributedString.adaptiveImageGlyph(
    from: data,
    contentIdentifier: "watch-negative",
    fallback: ":blue-circle:")
}

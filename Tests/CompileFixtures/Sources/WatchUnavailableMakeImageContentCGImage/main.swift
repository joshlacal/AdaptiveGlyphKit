import AdaptiveGlyphKit
import CoreGraphics

func mustBeUnavailable(_ image: CGImage) throws {
  _ = try AdaptiveImageGlyphForge.makeImageContent(
    cgImage: image,
    contentIdentifier: "watch-negative")
}

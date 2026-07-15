import AdaptiveGlyphKit
import Foundation

func mustBeUnavailable(_ data: Data) throws {
  _ = try AdaptiveImageGlyphForge.makeImageContent(
    imageData: data,
    contentIdentifier: "watch-negative")
}

import Foundation
import ImageIO
import Testing
@testable import AdaptiveGlyphKit

@Suite("Pre-forged image content policy")
struct ImageContentPolicyTests {
  @Test("accepts the project-owned adaptive glyph")
  func acceptsOwnedFixture() throws {
    let data = try GlyphFixture.data(named: "project-owned-blue-glyph", extension: "heic")
    let glyph = try #require(AdaptiveImageGlyphForge.makeGlyph(imageContent: data))
    #expect(glyph.contentIdentifier == GlyphFixture.identifier)
    #expect(glyph.contentDescription == GlyphFixture.accessibilityDescription)
  }

  @Test(
    "rejects malformed and bounded-resource violations",
    arguments: [
      ("wrong-type", "png"),
      ("nine-representations", "heic"),
      ("edge-1025", "heic"),
      ("two-1024-representations", "heic"),
    ])
  func rejectsStructuralViolation(name: String, extension ext: String) throws {
    let data = try GlyphFixture.data(named: name, extension: ext)
    #expect(AdaptiveImageGlyphForge.makeGlyph(imageContent: data) == nil)
  }

  @Test("rejects empty and one-MiB-plus-one input")
  func rejectsByteBounds() {
    #expect(AdaptiveImageGlyphForge.makeGlyph(imageContent: Data()) == nil)
    #expect(
      AdaptiveImageGlyphForge.makeGlyph(
        imageContent: Data([0x00, 0x01, 0x02, 0x03])) == nil)
    #expect(
      AdaptiveImageGlyphForge.makeGlyph(
        imageContent: Data(
          repeating: 0,
          count: AdaptiveImageGlyphForge.maximumImageContentByteCount + 1)) == nil)
  }

  @Test("integer metadata must be integral and bounded")
  func validatesIntegerMetadata() {
    #expect(AdaptiveImageGlyphContentValidator.integralPixelDimension(NSNumber(value: 1)) == 1)
    #expect(AdaptiveImageGlyphContentValidator.integralPixelDimension(NSNumber(value: 1_024)) == 1_024)
    for value: NSNumber in [
      NSNumber(value: 0),
      NSNumber(value: -1),
      NSNumber(value: 1.5),
      NSNumber(value: 1_025),
      NSNumber(value: Double.nan),
      NSNumber(value: UInt64.max),
    ] {
      #expect(AdaptiveImageGlyphContentValidator.integralPixelDimension(value) == nil)
    }
  }

  @Test("missing width or height metadata fails closed")
  func rejectsMissingDimensions() {
    #expect(
      AdaptiveImageGlyphContentValidator.pixelDimensions(from: [:]) == nil)
    #expect(
      AdaptiveImageGlyphContentValidator.pixelDimensions(
        from: [kCGImagePropertyPixelWidth: NSNumber(value: 128)]) == nil)
    #expect(
      AdaptiveImageGlyphContentValidator.pixelDimensions(
        from: [kCGImagePropertyPixelHeight: NSNumber(value: 128)]) == nil)
  }

  @Test("pixel arithmetic rejects multiplication and addition overflow")
  func rejectsArithmeticOverflow() {
    #expect(
      AdaptiveImageGlyphContentValidator.addingPixels(
        width: Int.max, height: 2, to: 0) == nil)
    #expect(
      AdaptiveImageGlyphContentValidator.addingPixels(
        width: 1, height: 1, to: Int.max) == nil)
  }
}

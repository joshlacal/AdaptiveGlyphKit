import CoreGraphics
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import AdaptiveGlyphKit

#if canImport(UIKit)
  import UIKit
#elseif canImport(AppKit)
  import AppKit
#endif

@Suite("AdaptiveImageGlyphForge")
struct AdaptiveImageGlyphForgeTests {

  /// A blue-circle PNG at `size`×`size`, drawn with CoreGraphics so the test is
  /// platform-independent (no UIKit/AppKit rendering).
  static func samplePNG(size: Int = 128) -> Data {
    let ctx = CGContext(
      data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.setFillColor(CGColor(red: 0.1, green: 0.4, blue: 0.95, alpha: 1))
    let inset = CGFloat(size) * 0.0625
    ctx.fillEllipse(in: CGRect(x: inset, y: inset,
      width: CGFloat(size) - 2 * inset, height: CGFloat(size) - 2 * inset))
    let cg = ctx.makeImage()!
    let out = NSMutableData()
    let dest = CGImageDestinationCreateWithData(out, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, cg, nil)
    CGImageDestinationFinalize(dest)
    return out as Data
  }

  @Test("forges an accepted glyph and round-trips the identifier")
  func forgesAcceptedGlyphWithIdentifier() throws {
    let id = "6C7E1A2B-0000-4AAA-8BBB-1234567890AB"
    let glyph = try #require(
      AdaptiveImageGlyphForge.makeGlyph(imageData: Self.samplePNG(), contentIdentifier: id),
      "expected the forged glyph to be accepted by NSAdaptiveImageGlyph")
    #expect(glyph.contentIdentifier == id)
  }

  @Test("round-trips the accessibility description into contentDescription")
  func roundTripsDescription() throws {
    let glyph = try #require(
      AdaptiveImageGlyphForge.makeGlyph(
        imageData: Self.samplePNG(),
        contentIdentifier: "6C7E1A2B-0000-4AAA-8BBB-1234567890AC",
        accessibilityDescription: "a round blue emoji"))
    #expect(glyph.contentDescription == "a round blue emoji")
  }

  @Test("returns nil for non-image data rather than trapping")
  func returnsNilForGarbage() {
    let glyph = AdaptiveImageGlyphForge.makeGlyph(
      imageData: Data([0x00, 0x01, 0x02, 0x03]),
      contentIdentifier: "x")
    #expect(glyph == nil)
  }

  @Test("makeImageContent throws cannotDecodeImage for non-image data")
  func throwsForGarbage() {
    #expect(throws: GlyphForgeError.cannotDecodeImage) {
      try AdaptiveImageGlyphForge.makeImageContent(
        imageData: Data([0x00, 0x01, 0x02, 0x03]), contentIdentifier: "x")
    }
  }

  @Test("forges from a CGImage directly")
  func forgesFromCGImage() throws {
    let source = try #require(CGImageSourceCreateWithData(Self.samplePNG() as CFData, nil))
    let cg = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
    let id = "11112222-0000-4333-8444-555566667777"
    let glyph = try #require(AdaptiveImageGlyphForge.makeGlyph(cgImage: cg, contentIdentifier: id))
    #expect(glyph.contentIdentifier == id)
  }

  @Test("cached image content round-trips through makeGlyph(imageContent:)")
  func imageContentRoundTrips() throws {
    let id = "AAAA1111-0000-4BBB-8CCC-DDDDEEEEFFFF"
    let content = try AdaptiveImageGlyphForge.makeImageContent(
      imageData: Self.samplePNG(), contentIdentifier: id, accessibilityDescription: "desc")
    let glyph = try #require(AdaptiveImageGlyphForge.makeGlyph(imageContent: content))
    #expect(glyph.contentIdentifier == id)
    #expect(glyph.contentDescription == "desc")
  }

  @Test("downsamples oversized images to the pixel cap")
  func downsamplesLargeImages() throws {
    let big = Self.samplePNG(size: 2048)
    let content = try AdaptiveImageGlyphForge.makeImageContent(
      imageData: big, contentIdentifier: "cap-test", maximumDimension: 256)
    let source = try #require(CGImageSourceCreateWithData(content as CFData, nil))
    let decoded = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
    #expect(decoded.width <= 256 && decoded.height <= 256,
      "expected downsample to <=256, got \(decoded.width)x\(decoded.height)")
  }

  @Test("rejects non-forged image content (exercises the nil path)")
  func rejectsNonForgedContent() {
    // Both garbage bytes and a plain (un-forged) PNG must be rejected by the OS
    // and returned as nil — this covers the load-bearing NSAdaptiveImageGlyph
    // rejection branch that the other tests never reach.
    #expect(AdaptiveImageGlyphForge.makeGlyph(imageContent: Data([0x00, 0x01, 0x02, 0x03])) == nil)
    #expect(AdaptiveImageGlyphForge.makeGlyph(imageContent: Self.samplePNG()) == nil)
  }

  @Test("non-finite / overflowing maximumDimension does not trap")
  func nonFiniteMaximumDimension() throws {
    for dim in [CGFloat.infinity, .greatestFiniteMagnitude, .nan] {
      let data = try AdaptiveImageGlyphForge.makeImageContent(
        imageData: Self.samplePNG(), contentIdentifier: "dim-test", maximumDimension: dim)
      #expect(!data.isEmpty)
    }
  }
}

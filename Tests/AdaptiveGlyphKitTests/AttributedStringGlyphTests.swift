import CoreGraphics
import SwiftUI
import Testing
@testable import AdaptiveGlyphKit

@Suite("AttributedString+Glyph")
@MainActor
struct AttributedStringGlyphTests {

  #if !os(watchOS)
  private func sampleGlyph() throws -> NSAdaptiveImageGlyph {
    try #require(
      AdaptiveImageGlyphForge.makeGlyph(
        imageData: AdaptiveImageGlyphForgeTests.samplePNG(),
        contentIdentifier: "9A11B2C3-0000-4DDD-8EEE-abcdefabcdef",
        accessibilityDescription: "sample"))
  }

  @Test("uses the object-replacement character as its single glyph run")
  func usesObjectReplacementCharacter() throws {
    let s = try #require(AttributedString(adaptiveImageGlyph: try sampleGlyph()))
    #expect(String(s.characters) == "\u{FFFC}")
  }

  @Test("convenience returns readable fallback text on failure")
  func convenienceFallsBackToText() {
    let s = AttributedString.adaptiveImageGlyph(
      from: Data([0x00, 0x01, 0x02, 0x03]),  // not an image
      contentIdentifier: "x",
      fallback: ":blobcat:")
    #expect(String(s.characters) == ":blobcat:")
  }

  @Test("convenience produces a glyph run on success")
  func convenienceProducesGlyph() {
    let s = AttributedString.adaptiveImageGlyph(
      from: AdaptiveImageGlyphForgeTests.samplePNG(),
      contentIdentifier: "CAFE0001-0000-4AAA-8BBB-000000000001",
      accessibilityDescription: "cat",
      fallback: ":blobcat:")
    // Success path yields the single-character glyph run, not the fallback.
    #expect(String(s.characters) == "\u{FFFC}")
  }
  #endif

  @Test("pre-forged convenience returns readable fallback text on failure")
  func preForgedConvenienceFallsBackToText() {
    let s = AttributedString.adaptiveImageGlyph(
      imageContent: Data([0x00, 0x01, 0x02, 0x03]),
      fallback: ":blobcat:")
    #expect(String(s.characters) == ":blobcat:")
  }

  #if !os(watchOS)
  @Test("pre-forged convenience produces a glyph run on success")
  func preForgedConvenienceProducesGlyph() throws {
    let content = try AdaptiveImageGlyphForge.makeImageContent(
      imageData: AdaptiveImageGlyphForgeTests.samplePNG(),
      contentIdentifier: "CAFE0002-0000-4AAA-8BBB-000000000002",
      accessibilityDescription: "cat")
    let s = AttributedString.adaptiveImageGlyph(
      imageContent: content,
      fallback: ":blobcat:")
    #expect(String(s.characters) == "\u{FFFC}")
  }
  #endif

  // ImageRenderer rasterizes adaptive image glyphs on iOS but not on macOS;
  // macOS rendering is covered by `AppKitRenderTests` (NSTextView) instead.
  #if os(iOS)
    @Test("SwiftUI Text renders the glyph inline")
    func rendersInSwiftUIText() throws {
      let glyphString = try #require(AttributedString(adaptiveImageGlyph: try sampleGlyph()))
      let plain = coloredPixels(of: Text(AttributedString("\u{FFFC}")).font(.system(size: 40)))
      let withGlyph = coloredPixels(of: Text(glyphString).font(.system(size: 40)))
      #expect(withGlyph > plain + 300,
        "expected the glyph to render (glyph=\(withGlyph) px, plain=\(plain) px)")
    }

    /// Rasterize a view and count chromatic (colored, non-transparent) pixels.
    private func coloredPixels(of view: some View) -> Int {
      let renderer = ImageRenderer(content: view.frame(width: 120, height: 60).background(.white))
      renderer.scale = 2
      guard let cg = renderer.cgImage else { return -1 }
      let w = cg.width, h = cg.height, bpr = w * 4
      var buf = [UInt8](repeating: 0, count: bpr * h)
      let ctx = CGContext(
        data: &buf, width: w, height: h, bitsPerComponent: 8, bytesPerRow: bpr,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
      ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
      var colored = 0, i = 0
      while i < buf.count {
        let r = buf[i], g = buf[i + 1], b = buf[i + 2], a = buf[i + 3]
        if a > 40, Int(max(r, max(g, b))) - Int(min(r, min(g, b))) > 24 { colored += 1 }
        i += 4
      }
      return colored
    }
  #endif
}

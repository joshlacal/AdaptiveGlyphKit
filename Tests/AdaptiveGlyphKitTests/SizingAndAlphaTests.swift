import CoreGraphics
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import AdaptiveGlyphKit

#if canImport(UIKit)
  import UIKit
#endif

@Suite("Sizing & transparency")
struct SizingAndAlphaTests {

  /// Forged glyph content must keep an alpha channel and a transparent corner —
  /// emoji have transparent backgrounds, so a flattened box would be a bug.
  @Test("forged content preserves transparency")
  func preservesAlpha() throws {
    // samplePNG() draws a blue circle on a transparent background.
    let content = try AdaptiveImageGlyphForge.makeImageContent(
      imageData: AdaptiveImageGlyphForgeTests.samplePNG(size: 256),
      contentIdentifier: "alpha-test")
    let source = try #require(CGImageSourceCreateWithData(content as CFData, nil))
    let cg = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))

    let hasAlpha = ![.none, .noneSkipLast, .noneSkipFirst].contains(cg.alphaInfo)
    #expect(hasAlpha, "forged HEIC dropped its alpha channel (alphaInfo=\(cg.alphaInfo.rawValue))")

    // Sample the top-left corner — should be (near) transparent.
    let w = cg.width, h = cg.height
    var px: [UInt8] = [0, 0, 0, 0]
    let ctx = CGContext(
      data: &px, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    // Draw the image so its top-left corner lands on our 1×1 context.
    ctx.draw(cg, in: CGRect(x: 0, y: 1 - CGFloat(h), width: CGFloat(w), height: CGFloat(h)))
    #expect(px[3] < 40, "expected a transparent corner, got alpha=\(px[3])")
  }

  #if os(iOS)
    /// One representation should scale to different point sizes (not just inline).
    @Test("a single representation scales across point sizes")
    @MainActor
    func scalesAcrossSizes() throws {
      let glyph = try #require(AdaptiveImageGlyphForge.makeGlyph(
        imageData: AdaptiveImageGlyphForgeTests.samplePNG(size: 256),
        contentIdentifier: "size-test"))
      let run = try #require(AttributedString(adaptiveImageGlyph: glyph))

      let small = renderedGlyphPixels(run, pointSize: 17, box: CGSize(width: 60, height: 40))
      let large = renderedGlyphPixels(run, pointSize: 120, box: CGSize(width: 240, height: 200))
      // The glyph should occupy meaningfully more pixels at the larger size.
      #expect(small > 50, "glyph did not render small (px=\(small))")
      #expect(large > small * 4, "glyph did not scale up (small=\(small), large=\(large))")
    }

    @MainActor
    private func renderedGlyphPixels(_ run: AttributedString, pointSize: CGFloat, box: CGSize) -> Int {
      let renderer = ImageRenderer(
        content: SwiftUIText(run).font(.system(size: pointSize)).frame(width: box.width, height: box.height))
      renderer.scale = 1
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

#if os(iOS)
  import SwiftUI
  private func SwiftUIText(_ s: AttributedString) -> Text { Text(s) }
#endif

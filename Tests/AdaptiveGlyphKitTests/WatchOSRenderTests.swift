#if os(watchOS)
  import CoreGraphics
  import SwiftUI
  import Testing
  @testable import AdaptiveGlyphKit

  @Suite("watchOS rendering")
  @MainActor
  struct WatchOSRenderTests {
    @Test("SwiftUI Text renders the owned glyph distinctly from both controls")
    func rendersDifferentially() throws {
      let data = try GlyphFixture.data(
        named: "project-owned-blue-glyph", extension: "heic")
      let glyph = try #require(AdaptiveImageGlyphForge.makeGlyph(imageContent: data))
      let run = try #require(AttributedString(adaptiveImageGlyph: glyph))

      let glyphCoverage = coverage(of: Text(run))
      let blankCoverage = coverage(of: Text(AttributedString("\u{FFFC}")))
      let fallbackCoverage = coverage(of: Text(AttributedString(":blue:")))

      print(
        "watchOS differential coverage: "
          + "glyph.blue=\(glyphCoverage.blue) glyph.alpha=\(glyphCoverage.alpha) "
          + "blank.blue=\(blankCoverage.blue) blank.alpha=\(blankCoverage.alpha) "
          + "fallback.blue=\(fallbackCoverage.blue) fallback.alpha=\(fallbackCoverage.alpha)")

      #expect(glyphCoverage.blue > blankCoverage.blue + 300)
      #expect(glyphCoverage.alpha > blankCoverage.alpha + 300)
      #expect(glyphCoverage.blue > fallbackCoverage.blue + 300)
      #expect(abs(glyphCoverage.alpha - fallbackCoverage.alpha) > 300)
    }

    private func coverage(of text: Text) -> (blue: Int, alpha: Int) {
      let renderer = ImageRenderer(
        content: text.font(.system(size: 40)).frame(width: 128, height: 64))
      renderer.scale = 2
      guard let image = renderer.cgImage else { return (-1, -1) }
      let width = image.width
      let height = image.height
      let bytesPerRow = width * 4
      var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)
      let context = CGContext(
        data: &pixels,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
      context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

      var blue = 0
      var alpha = 0
      for offset in stride(from: 0, to: pixels.count, by: 4) {
        let red = Int(pixels[offset])
        let green = Int(pixels[offset + 1])
        let blueChannel = Int(pixels[offset + 2])
        let alphaChannel = Int(pixels[offset + 3])
        if alphaChannel > 40 { alpha += 1 }
        if alphaChannel > 40, blueChannel > red + 40, blueChannel > green + 20 {
          blue += 1
        }
      }
      return (blue, alpha)
    }
  }
#endif

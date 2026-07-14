#if os(macOS)
  import AppKit
  import CoreGraphics
  import Testing
  @testable import AdaptiveGlyphKit

  @Suite("AppKit rendering")
  @MainActor
  struct AppKitRenderTests {

    private func sampleGlyph() throws -> NSAdaptiveImageGlyph {
      try #require(
        AdaptiveImageGlyphForge.makeGlyph(
          imageData: AdaptiveImageGlyphForgeTests.samplePNG(),
          contentIdentifier: "AC0FFEE0-0000-4AAA-8BBB-000011112222",
          accessibilityDescription: "sample"))
    }

    /// Render an attributed string in an `NSTextView` (TextKit 2 + importsGraphics)
    /// offscreen and count chromatic pixels.
    private func renderPixels(_ attributed: NSAttributedString) -> Int {
      let frame = NSRect(x: 0, y: 0, width: 160, height: 60)
      let textView = NSTextView(frame: frame)
      textView.importsGraphics = true
      textView.backgroundColor = .white
      textView.font = .systemFont(ofSize: 40)
      textView.textStorage?.setAttributedString(attributed)

      let window = NSWindow(
        contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
      window.contentView = textView
      textView.layoutSubtreeIfNeeded()

      guard let rep = textView.bitmapImageRepForCachingDisplay(in: textView.bounds) else { return -1 }
      textView.cacheDisplay(in: textView.bounds, to: rep)
      guard let cg = rep.cgImage else { return -1 }

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

    @Test("NSTextView renders a forged glyph")
    func nsTextViewRenders() throws {
      let glyph = try sampleGlyph()
      let ns = NSMutableAttributedString(string: "\u{FFFC}",
        attributes: [.font: NSFont.systemFont(ofSize: 40)])
      ns.addAttribute(.adaptiveImageGlyph, value: glyph, range: NSRange(location: 0, length: 1))

      let blank = renderPixels(NSAttributedString(string: "\u{FFFC}",
        attributes: [.font: NSFont.systemFont(ofSize: 40)]))
      let withGlyph = renderPixels(ns)
      #expect(withGlyph > blank + 300,
        "expected the glyph to render in NSTextView (glyph=\(withGlyph) px, blank=\(blank) px)")
    }

    @Test("AttributedString(adaptiveImageGlyph:) round-trips through NSTextView on macOS")
    func bridgeRendersInNSTextView() throws {
      let glyph = try sampleGlyph()
      let bridged = NSAttributedString(try #require(AttributedString(adaptiveImageGlyph: glyph)))
      let blank = renderPixels(NSAttributedString(string: "\u{FFFC}",
        attributes: [.font: NSFont.systemFont(ofSize: 40)]))
      let withGlyph = renderPixels(bridged)
      #expect(withGlyph > blank + 300,
        "expected AttributedString(adaptiveImageGlyph:) to render on macOS (glyph=\(withGlyph) px, blank=\(blank) px)")
    }
  }
#endif

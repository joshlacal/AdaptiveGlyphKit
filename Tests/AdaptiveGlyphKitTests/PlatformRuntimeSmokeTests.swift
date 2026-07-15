#if !os(watchOS)
  import Foundation
  import Testing
  @testable import AdaptiveGlyphKit

  @Suite("Platform runtime smoke")
  struct PlatformRuntimeSmokeTests {
    @Test("forges, consumes, and bridges on this runtime")
    func forgeConsumeRuntimeSmoke() throws {
      let source = EncodingTestFixtures.solidImage(width: 192, height: 128)
      let content = try AdaptiveImageGlyphForge.makeImageContent(
        cgImage: source,
        contentIdentifier: "adaptiveglyphkit.runtime-smoke",
        accessibilityDescription: "Runtime smoke")
      let glyph = try #require(AdaptiveImageGlyphForge.makeGlyph(imageContent: content))
      #expect(glyph.contentIdentifier == "adaptiveglyphkit.runtime-smoke")
      #expect(glyph.contentDescription == "Runtime smoke")
      let run = try #require(AttributedString(adaptiveImageGlyph: glyph))
      #expect(String(run.characters) == "\u{FFFC}")
    }
  }
#endif

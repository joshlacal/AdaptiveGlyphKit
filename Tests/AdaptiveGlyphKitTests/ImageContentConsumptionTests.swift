import Foundation
import Testing
@testable import AdaptiveGlyphKit

@Suite("Pre-forged content consumption")
struct ImageContentConsumptionTests {
  @Test("round-trips identifier, description, and U+FFFC bridge")
  func consumesOwnedFixture() throws {
    let data = try GlyphFixture.data(named: "project-owned-blue-glyph", extension: "heic")
    let glyph = try #require(AdaptiveImageGlyphForge.makeGlyph(imageContent: data))
    #expect(glyph.contentIdentifier == GlyphFixture.identifier)
    #expect(glyph.contentDescription == GlyphFixture.accessibilityDescription)
    let run = try #require(AttributedString(adaptiveImageGlyph: glyph))
    #expect(String(run.characters) == "\u{FFFC}")
  }

  @Test("system rejection of preflight-passing content returns nil")
  func systemRejectionReturnsNil() throws {
    // A structurally valid single-representation HEIC with no TIFF DocumentName
    // passes the bounded preflight but is rejected by NSAdaptiveImageGlyph
    // itself — the only fixture that reaches the system-rejection branch.
    let data = try GlyphFixture.data(named: "no-document-name", extension: "heic")
    #expect(AdaptiveImageGlyphContentValidator.accepts(data))
    #expect(AdaptiveImageGlyphForge.makeGlyph(imageContent: data) == nil)
    let fallback = AttributedString.adaptiveImageGlyph(
      imageContent: data, fallback: ":fallback:")
    #expect(String(fallback.characters) == ":fallback:")
  }

  @Test("bounded convenience returns exact readable fallback")
  func exactFallback() {
    let fallback = ":project-blue:"
    let rejected = AttributedString.adaptiveImageGlyph(
      imageContent: Data(repeating: 0, count: 1_048_577),
      fallback: fallback)
    #expect(String(rejected.characters) == fallback)
  }
}

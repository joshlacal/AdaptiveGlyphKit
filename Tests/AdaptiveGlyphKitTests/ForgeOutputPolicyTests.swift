import Foundation
import Testing
@testable import AdaptiveGlyphKit

@Suite("Forge output policy")
struct ForgeOutputPolicyTests {
  @Test("512-pixel high-entropy content is consumable when returned")
  func highEntropy512() throws {
    let image = EncodingTestFixtures.deterministicNoiseImage(size: 512, seed: 0xA11CE)
    let content = try AdaptiveImageGlyphForge.makeImageContent(
      cgImage: image,
      contentIdentifier: "noise-512")
    #expect(content.count <= AdaptiveImageGlyphForge.maximumImageContentByteCount)
    #expect(AdaptiveImageGlyphForge.makeGlyph(imageContent: content) != nil)
  }

  @Test("oversized encoded output reports the distinct error")
  func rejectsOversizedOutput() {
    let oversized = Data(
      repeating: 0,
      count: AdaptiveImageGlyphForge.maximumImageContentByteCount + 1)
    #expect(throws: GlyphForgeError.outputExceedsConsumerLimits) {
      try AdaptiveImageGlyphForge.validatedEncodedOutput(oversized)
    }
  }

  @Test("1,024-pixel high-entropy input never escapes the consumer policy")
  func highEntropy1024() {
    let image = EncodingTestFixtures.deterministicNoiseImage(size: 1_024, seed: 0xB10E)
    do {
      let content = try AdaptiveImageGlyphForge.makeImageContent(
        cgImage: image,
        contentIdentifier: "noise-1024")
      #expect(content.count <= AdaptiveImageGlyphForge.maximumImageContentByteCount)
      #expect(AdaptiveImageGlyphForge.makeGlyph(imageContent: content) != nil)
    } catch {
      #expect(error as? GlyphForgeError == .outputExceedsConsumerLimits)
    }
  }
}

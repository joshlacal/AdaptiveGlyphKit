import CoreGraphics
import Testing
@testable import AdaptiveGlyphKit

#if !os(watchOS)
@Suite("Forge dimension policy")
struct ForgeDimensionPolicyTests {
  @Test(
    "normalizes hostile dimensions without trapping",
    arguments: [
      (CGFloat.nan, 1_024),
      (CGFloat.infinity, 1_024),
      (-CGFloat.infinity, 1_024),
      (CGFloat.greatestFiniteMagnitude, 1_024),
      (CGFloat.zero, 1),
      (CGFloat(-50), 1),
      (CGFloat(0.75), 1),
      (CGFloat(1.75), 1),
      (CGFloat(512.75), 512),
      (CGFloat(1_025), 1_024),
      (CGFloat(512), 512),
    ])
  func normalizes(input: CGFloat, expected: Int) {
    #expect(AdaptiveImageGlyphForge.normalizedPixelDimension(input) == expected)
  }

  @Test("both Data and CGImage inputs honor the same 1,024-pixel ceiling")
  func boundsBothPaths() throws {
    let source = EncodingTestFixtures.solidImage(width: 2_048, height: 1_536)
    let png = try EncodingTestFixtures.pngData(from: source)
    let fromData = try AdaptiveImageGlyphForge.makeImageContent(
      imageData: png,
      contentIdentifier: "data-cap",
      maximumDimension: .greatestFiniteMagnitude)
    let fromCG = try AdaptiveImageGlyphForge.makeImageContent(
      cgImage: source,
      contentIdentifier: "cg-cap",
      maximumDimension: .greatestFiniteMagnitude)
    let dataMaximumEdge = try EncodingTestFixtures.maximumEdge(of: fromData)
    let cgMaximumEdge = try EncodingTestFixtures.maximumEdge(of: fromCG)
    #expect(dataMaximumEdge == 1_024)
    #expect(cgMaximumEdge == 1_024)
  }

  @Test("CGImage resizing floors scaled edges, keeps them positive, and never upscales")
  func resizePolicy() throws {
    let thin = EncodingTestFixtures.solidImage(width: 2_048, height: 3)
    let resized = try #require(
      AdaptiveImageGlyphForge.resizedImage(thin, maximumPixelDimension: 1_024))
    #expect(resized.width == 1_024)
    #expect(resized.height == 1)

    let small = EncodingTestFixtures.solidImage(width: 17, height: 9)
    let notUpscaled = try #require(
      AdaptiveImageGlyphForge.resizedImage(small, maximumPixelDimension: 1_024))
    #expect(notUpscaled.width == 17)
    #expect(notUpscaled.height == 9)
  }
}
#endif

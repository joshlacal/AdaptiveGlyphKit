import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import AdaptiveGlyphKit

@Suite("Pre-forged image content policy")
struct ImageContentPolicyTests {
  private static func blueCircle(width: Int, height: Int) throws -> CGImage {
    let context = try #require(
      CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    let bounds = CGRect(x: 0, y: 0, width: width, height: height)
    context.clear(bounds)
    context.setFillColor(CGColor(red: 0.1, green: 0.4, blue: 0.95, alpha: 1))
    context.fillEllipse(in: bounds.insetBy(dx: bounds.width / 16, dy: bounds.height / 16))
    return try #require(context.makeImage())
  }

  private static func adaptiveGlyphContent(
    representationSizes: [(width: Int, height: Int)]
  ) throws -> Data {
    let output = NSMutableData()
    let destination = try #require(
      CGImageDestinationCreateWithData(
        output,
        UTType.heic.identifier as CFString,
        representationSizes.count,
        nil))
    let properties: [CFString: Any] = [
      kCGImagePropertyTIFFDictionary: [
        kCGImagePropertyTIFFDocumentName: GlyphFixture.identifier,
        kCGImagePropertyTIFFImageDescription: GlyphFixture.accessibilityDescription,
      ] as [CFString: Any]
    ]
    for size in representationSizes {
      CGImageDestinationAddImage(
        destination,
        try blueCircle(width: size.width, height: size.height),
        properties as CFDictionary)
    }
    try #require(CGImageDestinationFinalize(destination))
    return output as Data
  }

  private static func imageSource(for data: Data) throws -> CGImageSource {
    try #require(
      CGImageSourceCreateWithData(
        data as CFData,
        [kCGImageSourceShouldCache: false] as CFDictionary))
  }

  private static func representationDimensions(
    in source: CGImageSource
  ) throws -> [(width: Int, height: Int)] {
    var dimensions: [(width: Int, height: Int)] = []
    for index in 0 ..< CGImageSourceGetCount(source) {
      let properties = try #require(
        CGImageSourceCopyPropertiesAtIndex(
          source,
          index,
          [kCGImageSourceShouldCache: false] as CFDictionary) as? [CFString: Any])
      dimensions.append(
        try #require(AdaptiveImageGlyphContentValidator.pixelDimensions(from: properties)))
    }
    return dimensions
  }

  @Test("public limits remain exact")
  func publicLimitsRemainExact() {
    #expect(AdaptiveImageGlyphForge.maximumImageContentByteCount == 1_048_576)
    #expect(AdaptiveImageGlyphForge.maximumForgePixelDimension == 1_024)
  }

  @Test("accepts the project-owned adaptive glyph")
  func acceptsOwnedFixture() throws {
    let data = try GlyphFixture.data(named: "project-owned-blue-glyph", extension: "heic")
    #expect(AdaptiveImageGlyphContentValidator.accepts(data))
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
    #expect(AdaptiveImageGlyphContentValidator.accepts(data) == false)
    #expect(AdaptiveImageGlyphForge.makeGlyph(imageContent: data) == nil)
  }

  @Test("accepts exactly one MiB of structurally valid content")
  func acceptsExactByteLimit() throws {
    var data = try GlyphFixture.data(named: "project-owned-blue-glyph", extension: "heic")
    try #require(data.count < AdaptiveImageGlyphForge.maximumImageContentByteCount)
    data.append(
      Data(
        repeating: 0,
        count: AdaptiveImageGlyphForge.maximumImageContentByteCount - data.count))
    let source = try Self.imageSource(for: data)
    let dimensions = try Self.representationDimensions(in: source)
    let dimension = try #require(dimensions.first)

    #expect(data.count == 1_048_576)
    #expect(dimensions.count == 1)
    #expect(dimension.width == 512)
    #expect(dimension.height == 512)
    #expect(AdaptiveImageGlyphContentValidator.accepts(data))
  }

  @Test("accepts exactly eight representations")
  func acceptsEightRepresentations() throws {
    let data = try Self.adaptiveGlyphContent(
      representationSizes: Array(repeating: (width: 128, height: 128), count: 8))
    let source = try Self.imageSource(for: data)
    let dimensions = try Self.representationDimensions(in: source)

    #expect(data.count <= AdaptiveImageGlyphForge.maximumImageContentByteCount)
    #expect(dimensions.count == 8)
    #expect(dimensions.allSatisfy { $0.width == 128 && $0.height == 128 })
    #expect(AdaptiveImageGlyphContentValidator.accepts(data))
  }

  @Test("accepts exactly the cumulative pixel limit")
  func acceptsExactCumulativePixelLimit() throws {
    let data = try Self.adaptiveGlyphContent(
      representationSizes: Array(repeating: (width: 512, height: 512), count: 4))
    let source = try Self.imageSource(for: data)
    let dimensions = try Self.representationDimensions(in: source)
    let cumulativePixels = dimensions.reduce(0) { total, dimension in
      total + dimension.width * dimension.height
    }

    #expect(data.count <= AdaptiveImageGlyphForge.maximumImageContentByteCount)
    #expect(dimensions.count == 4)
    #expect(dimensions.allSatisfy { $0.width == 512 && $0.height == 512 })
    #expect(cumulativePixels == 1_048_576)
    #expect(AdaptiveImageGlyphContentValidator.accepts(data))
  }

  @Test("accepts one 1024 by 1024 representation end to end")
  func acceptsSingleMaximumDimensionEndToEnd() throws {
    let data = try Self.adaptiveGlyphContent(
      representationSizes: [(width: 1_024, height: 1_024)])
    let source = try Self.imageSource(for: data)
    let dimensions = try Self.representationDimensions(in: source)
    let dimension = try #require(dimensions.first)

    #expect(dimensions.count == 1)
    #expect(dimension.width == 1_024)
    #expect(dimension.height == 1_024)
    #expect(AdaptiveImageGlyphContentValidator.accepts(data))
    let glyph = try #require(AdaptiveImageGlyphForge.makeGlyph(imageContent: data))
    #expect(glyph.contentIdentifier == GlyphFixture.identifier)
    #expect(glyph.contentDescription == GlyphFixture.accessibilityDescription)
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
    for value: Any in [
      NSNumber(value: 0),
      NSNumber(value: -1),
      NSNumber(value: 1.5),
      NSNumber(value: 1_025),
      NSNumber(value: UInt64.max),
    ] {
      #expect(AdaptiveImageGlyphContentValidator.integralPixelDimension(value) == nil)
    }
  }

  @Test("Boolean, non-numeric, and non-finite metadata fails closed")
  func rejectsNonNumericMetadata() {
    #expect(
      AdaptiveImageGlyphContentValidator.integralPixelDimension(
        NSNumber(value: true)) == nil)
    #expect(AdaptiveImageGlyphContentValidator.integralPixelDimension("128") == nil)
    #expect(
      AdaptiveImageGlyphContentValidator.integralPixelDimension(
        NSNumber(value: Double.nan)) == nil)
    #expect(
      AdaptiveImageGlyphContentValidator.integralPixelDimension(
        NSNumber(value: Double.infinity)) == nil)
    #expect(
      AdaptiveImageGlyphContentValidator.integralPixelDimension(
        NSNumber(value: -Double.infinity)) == nil)
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

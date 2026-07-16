import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

#if canImport(UIKit)
  import UIKit
#elseif canImport(AppKit)
  import AppKit
#endif

/// Errors thrown while encoding glyph image content.
public enum GlyphForgeError: Error, Equatable, Sendable {
  /// The provided data/image could not be decoded by ImageIO.
  case cannotDecodeImage
  /// HEIC encoding of the glyph image content failed.
  case encodingFailed
  /// Encoded output exceeds the package's bounded consumer policy.
  case outputExceedsConsumerLimits
}

/// Turns arbitrary images into `NSAdaptiveImageGlyph` content.
///
/// `NSAdaptiveImageGlyph` normally only accepts image data the system itself
/// produced (Genmoji, system stickers). This type reproduces the minimal shape
/// that `NSAdaptiveImageGlyph(imageContent:)` accepts — a single-representation
/// HEIC whose TIFF `DocumentName` carries the identifier and `ImageDescription`
/// the accessibility text — so existing artwork can be rendered inline as an
/// adaptive image glyph.
///
/// - Important: This is an **experimental compatibility bridge**. The acceptance
///   criteria are undocumented, and this produces a *single* HEIC representation
///   rather than the full multi-resolution content Apple's own tooling emits.
///   Glyph builders return `nil` (never trap) when the OS rejects the data;
///   always treat `nil` as "fall back to text".
///
/// Source-image entry points are compile-time unavailable on watchOS. Forge on
/// an encoding-capable platform and transfer the bounded `imageContent` bytes
/// for watchOS consumption. Decode, resize, encode, validate, and glyph parsing
/// are synchronous operations; prepare or cache their results away from UI
/// rendering callbacks.
public enum AdaptiveImageGlyphForge {

  /// Default maximum pixel dimension for the longer edge of forged glyph content.
  /// Adaptive image glyphs render at text size, so a modest cap keeps memory and
  /// CPU bounded for large or remote source images.
  public static let defaultMaximumDimension: CGFloat = 512

  /// Maximum accepted byte count for pre-forged adaptive image glyph content.
  public static let maximumImageContentByteCount: Int = 1_048_576

  /// Maximum accepted pixel dimension for each forged glyph representation.
  public static let maximumForgePixelDimension: CGFloat = 1_024

  // MARK: Image content (HEIC bytes)

  /// Encode glyph image content from source image data.
  ///
  /// ImageIO decodes the data, normalizes EXIF orientation, and downsamples
  /// without upscaling. The longer-edge default is 512 pixels, and every caller
  /// value is hard-clamped to the shared 1,024-pixel forge ceiling. This
  /// synchronous source-image API is compile-time unavailable on watchOS.
  ///
  /// - Throws: ``GlyphForgeError/cannotDecodeImage``, ``GlyphForgeError/encodingFailed``,
  ///   or ``GlyphForgeError/outputExceedsConsumerLimits``.
  /// - Returns: HEIC bytes suitable for `NSAdaptiveImageGlyph(imageContent:)`.
  @available(
    watchOS, unavailable,
    message: "Forge on an encoding-capable platform, then pass imageContent."
  )
  public static func makeImageContent(
    imageData: Data,
    contentIdentifier: String,
    accessibilityDescription: String? = nil,
    maximumDimension: CGFloat = defaultMaximumDimension
  ) throws -> Data {
    let maximumPixelDimension = normalizedPixelDimension(maximumDimension)
    guard let cgImage = normalizedImage(
      from: imageData,
      maximumPixelDimension: maximumPixelDimension)
    else {
      throw GlyphForgeError.cannotDecodeImage
    }
    return try makeImageContent(
      cgImage: cgImage,
      contentIdentifier: contentIdentifier,
      accessibilityDescription: accessibilityDescription,
      maximumDimension: CGFloat(maximumPixelDimension))
  }

  /// Encode glyph image content from an already-decoded image.
  ///
  /// This path performs no EXIF work and never upscales. When the image exceeds
  /// the requested bound, it uses CoreGraphics to resize it. The longer-edge
  /// default is 512 pixels, and every caller value is hard-clamped to the shared
  /// 1,024-pixel forge ceiling. This synchronous source-image API is
  /// compile-time unavailable on watchOS.
  ///
  /// - Throws: ``GlyphForgeError/encodingFailed`` or
  ///   ``GlyphForgeError/outputExceedsConsumerLimits``.
  @available(
    watchOS, unavailable,
    message: "Forge on an encoding-capable platform, then pass imageContent."
  )
  public static func makeImageContent(
    cgImage: CGImage,
    contentIdentifier: String,
    accessibilityDescription: String? = nil,
    maximumDimension: CGFloat = defaultMaximumDimension
  ) throws -> Data {
    let maximumPixelDimension = normalizedPixelDimension(maximumDimension)
    guard let image = resizedImage(
      cgImage,
      maximumPixelDimension: maximumPixelDimension)
    else {
      throw GlyphForgeError.encodingFailed
    }
    let out = NSMutableData()
    guard let dest = CGImageDestinationCreateWithData(
      out, UTType.heic.identifier as CFString, 1, nil) else {
      throw GlyphForgeError.encodingFailed
    }
    // TIFF DocumentName is the field NSAdaptiveImageGlyph reads as its
    // contentIdentifier and requires for acceptance; ImageDescription becomes
    // the contentDescription.
    var tiff: [CFString: Any] = [kCGImagePropertyTIFFDocumentName: contentIdentifier]
    if let accessibilityDescription {
      tiff[kCGImagePropertyTIFFImageDescription] = accessibilityDescription
    }
    let properties: [CFString: Any] = [kCGImagePropertyTIFFDictionary: tiff]
    CGImageDestinationAddImage(dest, image, properties as CFDictionary)
    guard CGImageDestinationFinalize(dest) else { throw GlyphForgeError.encodingFailed }
    return try validatedEncodedOutput(out as Data)
  }

  // MARK: Glyphs (nil on any failure)

  /// Forge an adaptive image glyph from source image data.
  ///
  /// ImageIO decodes the data and normalizes EXIF orientation before bounded
  /// encoding. The longer-edge default is 512 pixels and hard-clamps at 1,024;
  /// the image is never upscaled. Returns `nil` if decoding, encoding,
  /// preflight, or system acceptance fails. This synchronous source-image API
  /// is compile-time unavailable on watchOS.
  @available(
    watchOS, unavailable,
    message: "Forge on an encoding-capable platform, then pass imageContent."
  )
  public static func makeGlyph(
    imageData: Data,
    contentIdentifier: String,
    accessibilityDescription: String? = nil,
    maximumDimension: CGFloat = defaultMaximumDimension
  ) -> NSAdaptiveImageGlyph? {
    guard let content = try? makeImageContent(
      imageData: imageData,
      contentIdentifier: contentIdentifier,
      accessibilityDescription: accessibilityDescription,
      maximumDimension: maximumDimension) else { return nil }
    return makeGlyph(imageContent: content)
  }

  /// Forge an adaptive image glyph from an already-decoded `CGImage`.
  ///
  /// This path performs no EXIF work, never upscales, and uses CoreGraphics
  /// resizing only when the source exceeds the selected bound. The longer-edge
  /// default is 512 pixels and hard-clamps at 1,024. Returns `nil` if encoding,
  /// preflight, or system acceptance fails. This synchronous source-image API
  /// is compile-time unavailable on watchOS.
  @available(
    watchOS, unavailable,
    message: "Forge on an encoding-capable platform, then pass imageContent."
  )
  public static func makeGlyph(
    cgImage: CGImage,
    contentIdentifier: String,
    accessibilityDescription: String? = nil,
    maximumDimension: CGFloat = defaultMaximumDimension
  ) -> NSAdaptiveImageGlyph? {
    guard let content = try? makeImageContent(
      cgImage: cgImage,
      contentIdentifier: contentIdentifier,
      accessibilityDescription: accessibilityDescription,
      maximumDimension: maximumDimension) else { return nil }
    return makeGlyph(imageContent: content)
  }

  /// Build a glyph from bounded pre-forged adaptive-glyph content.
  ///
  /// This accepts externally forged data and reconstructs glyphs from cached
  /// bytes; neither origin bypasses preflight. Input must be nonempty and no
  /// larger than 1,048,576 bytes, have type
  /// `NSAdaptiveImageGlyph.contentType`, and contain one to eight
  /// representations. Every representation must have integral width and height
  /// from 1 through 1,024 pixels. Cumulative pixels must not exceed 1,048,576,
  /// using checked arithmetic.
  ///
  /// The 1 MiB bound is AdaptiveGlyphKit's intentional 0.1.0 policy, not a
  /// documented Apple limit. There is no caller-selectable unlimited sentinel.
  /// The `contentIdentifier` and `contentDescription` are read from the bytes.
  /// Structural parsing and glyph parsing are synchronous; validate and cache
  /// reusable content outside rendering callbacks.
  public static func makeGlyph(imageContent: Data) -> NSAdaptiveImageGlyph? {
    guard AdaptiveImageGlyphContentValidator.accepts(imageContent) else { return nil }
    // The Obj-C initializer returns nil (bridged into a non-optional Swift type)
    // when it rejects the data; wrap in `Optional` to observe that without trapping.
    guard let glyph = Optional(NSAdaptiveImageGlyph(imageContent: imageContent)) else { return nil }
    return glyph
  }

  // MARK: Encoding policy

  static func normalizedPixelDimension(_ maximumDimension: CGFloat) -> Int {
    guard maximumDimension.isFinite else {
      return Int(maximumForgePixelDimension)
    }
    let clamped = min(max(maximumDimension, 1), maximumForgePixelDimension)
    return Int(clamped.rounded(.down))
  }

  static func resizedImage(
    _ image: CGImage,
    maximumPixelDimension: Int
  ) -> CGImage? {
    guard maximumPixelDimension >= 1 else { return nil }
    let sourceMaximumDimension = max(image.width, image.height)
    guard sourceMaximumDimension > maximumPixelDimension else { return image }

    let scale = CGFloat(maximumPixelDimension) / CGFloat(sourceMaximumDimension)
    let width = max(1, Int((CGFloat(image.width) * scale).rounded(.down)))
    let height = max(1, Int((CGFloat(image.height) * scale).rounded(.down)))
    guard
      let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
      let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else {
      return nil
    }
    let bounds = CGRect(
      x: 0,
      y: 0,
      width: CGFloat(width),
      height: CGFloat(height))
    context.interpolationQuality = .high
    context.clear(bounds)
    context.draw(image, in: bounds)
    return context.makeImage()
  }

  static func validatedEncodedOutput(_ output: Data) throws -> Data {
    guard AdaptiveImageGlyphContentValidator.accepts(output) else {
      throw GlyphForgeError.outputExceedsConsumerLimits
    }
    return output
  }

  // MARK: Private

  /// Decode `imageData`, apply EXIF orientation, and downsample so the longer
  /// edge is at most `maximumPixelDimension` (never upscaling).
  private static func normalizedImage(
    from imageData: Data,
    maximumPixelDimension: Int
  ) -> CGImage? {
    guard let source = CGImageSourceCreateWithData(imageData as CFData, nil) else { return nil }
    let options: [CFString: Any] = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true, // bakes in EXIF orientation
      kCGImageSourceShouldCacheImmediately: true,
      kCGImageSourceThumbnailMaxPixelSize: maximumPixelDimension,
    ]
    return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
  }
}

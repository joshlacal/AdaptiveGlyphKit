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

  /// Encode glyph image content from source image data, normalizing EXIF
  /// orientation and downsampling so the longer edge is at most `maximumDimension`.
  ///
  /// - Throws: ``GlyphForgeError/cannotDecodeImage`` or ``GlyphForgeError/encodingFailed``.
  /// - Returns: HEIC bytes suitable for `NSAdaptiveImageGlyph(imageContent:)`.
  public static func makeImageContent(
    imageData: Data,
    contentIdentifier: String,
    accessibilityDescription: String? = nil,
    maximumDimension: CGFloat = defaultMaximumDimension
  ) throws -> Data {
    guard let cgImage = normalizedImage(from: imageData, maximumDimension: maximumDimension) else {
      throw GlyphForgeError.cannotDecodeImage
    }
    return try makeImageContent(
      cgImage: cgImage,
      contentIdentifier: contentIdentifier,
      accessibilityDescription: accessibilityDescription)
  }

  /// Encode glyph image content from an already-decoded, already-normalized image.
  ///
  /// - Throws: ``GlyphForgeError/encodingFailed``.
  public static func makeImageContent(
    cgImage: CGImage,
    contentIdentifier: String,
    accessibilityDescription: String? = nil
  ) throws -> Data {
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
    CGImageDestinationAddImage(dest, cgImage, properties as CFDictionary)
    guard CGImageDestinationFinalize(dest) else { throw GlyphForgeError.encodingFailed }
    return out as Data
  }

  // MARK: Glyphs (nil on any failure)

  /// Forge an adaptive image glyph from source image data.
  ///
  /// Normalizes orientation and downsamples to `maximumDimension`. Returns `nil`
  /// if decoding, encoding, or system acceptance fails.
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

  /// Forge an adaptive image glyph from an already-normalized `CGImage`.
  public static func makeGlyph(
    cgImage: CGImage,
    contentIdentifier: String,
    accessibilityDescription: String? = nil
  ) -> NSAdaptiveImageGlyph? {
    guard let content = try? makeImageContent(
      cgImage: cgImage,
      contentIdentifier: contentIdentifier,
      accessibilityDescription: accessibilityDescription) else { return nil }
    return makeGlyph(imageContent: content)
  }

  /// Rebuild a glyph from previously forged image content (e.g. from a cache).
  ///
  /// The `contentIdentifier`/`contentDescription` are read back out of the bytes,
  /// so nothing is lost round-tripping through storage.
  public static func makeGlyph(imageContent: Data) -> NSAdaptiveImageGlyph? {
    guard AdaptiveImageGlyphContentValidator.accepts(imageContent) else { return nil }
    // The Obj-C initializer returns nil (bridged into a non-optional Swift type)
    // when it rejects the data; wrap in `Optional` to observe that without trapping.
    guard let glyph = Optional(NSAdaptiveImageGlyph(imageContent: imageContent)) else { return nil }
    return glyph
  }

  // MARK: Private

  /// Decode `imageData`, apply EXIF orientation, and downsample so the longer
  /// edge is at most `maximumDimension` (never upscaling).
  private static func normalizedImage(from imageData: Data, maximumDimension: CGFloat) -> CGImage? {
    guard let source = CGImageSourceCreateWithData(imageData as CFData, nil) else { return nil }
    // Clamp to a finite, in-range value before `Int(...)` — a non-finite or
    // overflowing `maximumDimension` (e.g. `.infinity`/`.nan` as a "no cap"
    // sentinel) would otherwise trap.
    let clamped = maximumDimension.isFinite ? min(max(maximumDimension, 1), 8192) : 8192
    let options: [CFString: Any] = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true, // bakes in EXIF orientation
      kCGImageSourceShouldCacheImmediately: true,
      kCGImageSourceThumbnailMaxPixelSize: Int(clamped.rounded()),
    ]
    return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
  }
}

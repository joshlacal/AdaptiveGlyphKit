import Foundation

#if canImport(UIKit)
  import UIKit
#elseif canImport(AppKit)
  import AppKit
#endif

public extension AttributedString {

  /// The object-replacement character a glyph run substitutes for. Adaptive
  /// image glyphs render *only* over this character.
  static let glyphPlaceholder = "\u{FFFC}"

  /// A single-character attributed run that renders `glyph` inline.
  ///
  /// The run's character is `\u{FFFC}` (the object-replacement character) — the
  /// only character an adaptive image glyph renders over. Accessibility text
  /// comes from the glyph's own `contentDescription`. SwiftUI `Text`,
  /// `UITextView`, and (with `importsGraphics`) `NSTextView` render it inline,
  /// sized to the surrounding font.
  ///
  /// Fails (returns `nil`) if the glyph attribute cannot be bridged into an
  /// `AttributedString` — so callers can substitute readable text rather than an
  /// invisible placeholder.
  init?(adaptiveImageGlyph glyph: NSAdaptiveImageGlyph) {
    let ns = NSMutableAttributedString(string: AttributedString.glyphPlaceholder)
    ns.addAttribute(
      .adaptiveImageGlyph, value: glyph,
      range: NSRange(location: 0, length: (AttributedString.glyphPlaceholder as NSString).length))
    #if canImport(UIKit)
      guard let bridged = try? AttributedString(ns, including: \.uiKit) else { return nil }
    #elseif canImport(AppKit)
      guard let bridged = try? AttributedString(ns, including: \.appKit) else { return nil }
    #else
      return nil
    #endif
    self = bridged
  }

  /// Forge an inline adaptive image glyph from image data, **falling back to
  /// readable text** whenever anything fails (decoding, encoding, system
  /// acceptance, or attribution).
  ///
  /// This is the recommended high-level entry point: it always returns a usable
  /// `AttributedString`, never an invisible placeholder.
  ///
  /// ```swift
  /// Text(.adaptiveImageGlyph(
  ///   from: pngData,
  ///   contentIdentifier: stableID,
  ///   accessibilityDescription: "A round blue cat",
  ///   fallback: ":blobcat:"))
  /// ```
  ///
  /// - Parameters:
  ///   - imageData: Any image data decodable by ImageIO.
  ///   - contentIdentifier: A stable, unique identifier (the glyph cache key).
  ///   - accessibilityDescription: Accessibility text for the glyph.
  ///   - fallback: Text to render if a glyph can't be produced.
  ///   - maximumDimension: Longer-edge pixel cap for the source image.
  static func adaptiveImageGlyph(
    from imageData: Data,
    contentIdentifier: String,
    accessibilityDescription: String? = nil,
    fallback: String,
    maximumDimension: CGFloat = AdaptiveImageGlyphForge.defaultMaximumDimension
  ) -> AttributedString {
    guard
      let glyph = AdaptiveImageGlyphForge.makeGlyph(
        imageData: imageData,
        contentIdentifier: contentIdentifier,
        accessibilityDescription: accessibilityDescription,
        maximumDimension: maximumDimension),
      let run = AttributedString(adaptiveImageGlyph: glyph)
    else {
      return AttributedString(fallback)
    }
    return run
  }
}

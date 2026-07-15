import Foundation
import ImageIO

#if canImport(UIKit)
  import UIKit
#elseif canImport(AppKit)
  import AppKit
#endif

enum AdaptiveImageGlyphContentValidator {
  static let maximumRepresentationCount = 8
  static let maximumRepresentationPixelDimension = 1_024
  static let maximumCumulativePixelCount = 1_048_576

  static func accepts(_ imageContent: Data) -> Bool {
    guard !imageContent.isEmpty else { return false }
    guard imageContent.count <= AdaptiveImageGlyphForge.maximumImageContentByteCount else {
      return false
    }

    let options = [kCGImageSourceShouldCache: false] as CFDictionary
    guard let source = CGImageSourceCreateWithData(imageContent as CFData, options) else {
      return false
    }
    guard
      let sourceType = CGImageSourceGetType(source),
      sourceType as String == NSAdaptiveImageGlyph.contentType.identifier
    else {
      return false
    }

    let count = CGImageSourceGetCount(source)
    guard (1 ... maximumRepresentationCount).contains(count) else { return false }

    var totalPixels = 0
    for index in 0 ..< count {
      guard
        let properties = CGImageSourceCopyPropertiesAtIndex(
          source, index, options) as? [CFString: Any],
        let dimensions = pixelDimensions(from: properties),
        let nextTotal = addingPixels(
          width: dimensions.width, height: dimensions.height, to: totalPixels),
        nextTotal <= maximumCumulativePixelCount
      else {
        return false
      }
      totalPixels = nextTotal
    }
    return true
  }

  static func integralPixelDimension(_ value: Any?) -> Int? {
    guard let number = value as? NSNumber else { return nil }
    guard CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
    let raw = number.doubleValue
    guard raw.isFinite, raw.rounded(.towardZero) == raw else { return nil }
    guard raw >= 1, raw <= Double(maximumRepresentationPixelDimension) else {
      return nil
    }
    return Int(raw)
  }

  static func pixelDimensions(
    from properties: [CFString: Any]
  ) -> (width: Int, height: Int)? {
    guard
      let width = integralPixelDimension(properties[kCGImagePropertyPixelWidth]),
      let height = integralPixelDimension(properties[kCGImagePropertyPixelHeight])
    else {
      return nil
    }
    return (width, height)
  }

  static func addingPixels(width: Int, height: Int, to total: Int) -> Int? {
    let (area, areaOverflow) = width.multipliedReportingOverflow(by: height)
    guard !areaOverflow else { return nil }
    let (sum, sumOverflow) = total.addingReportingOverflow(area)
    guard !sumOverflow else { return nil }
    return sum
  }
}

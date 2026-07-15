import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum EncodingTestFixtureError: Error {
  case couldNotCreateImageSource
  case couldNotCreatePNGDestination
  case couldNotDecodeImage
  case couldNotFinalizePNG
}

enum EncodingTestFixtures {
  static func solidImage(width: Int, height: Int) -> CGImage {
    let context = CGContext(
      data: nil,
      width: width,
      height: height,
      bitsPerComponent: 8,
      bytesPerRow: width * 4,
      space: CGColorSpace(name: CGColorSpace.sRGB)!,
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.setFillColor(CGColor(red: 0.1, green: 0.4, blue: 0.95, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    return context.makeImage()!
  }

  static func deterministicNoiseImage(size: Int, seed: UInt64) -> CGImage {
    precondition(size > 0)
    var state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed
    var pixels = [UInt8](repeating: 0, count: size * size * 4)
    for offset in stride(from: 0, to: pixels.count, by: 4) {
      state ^= state >> 12
      state ^= state << 25
      state ^= state >> 27
      let value = state &* 0x2545_F491_4F6C_DD1D
      pixels[offset] = UInt8(truncatingIfNeeded: value)
      pixels[offset + 1] = UInt8(truncatingIfNeeded: value >> 8)
      pixels[offset + 2] = UInt8(truncatingIfNeeded: value >> 16)
      pixels[offset + 3] = 255
    }

    let provider = CGDataProvider(data: Data(pixels) as CFData)!
    return CGImage(
      width: size,
      height: size,
      bitsPerComponent: 8,
      bitsPerPixel: 32,
      bytesPerRow: size * 4,
      space: CGColorSpace(name: CGColorSpace.sRGB)!,
      bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
      provider: provider,
      decode: nil,
      shouldInterpolate: false,
      intent: .defaultIntent)!
  }

  static func pngData(from image: CGImage) throws -> Data {
    let output = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(
      output, UTType.png.identifier as CFString, 1, nil)
    else {
      throw EncodingTestFixtureError.couldNotCreatePNGDestination
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
      throw EncodingTestFixtureError.couldNotFinalizePNG
    }
    return output as Data
  }

  static func maximumEdge(of data: Data) throws -> Int {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
      throw EncodingTestFixtureError.couldNotCreateImageSource
    }
    guard let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
      throw EncodingTestFixtureError.couldNotDecodeImage
    }
    return max(image.width, image.height)
  }
}

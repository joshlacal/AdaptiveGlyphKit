#!/usr/bin/env swift

import CoreGraphics
import CryptoKit
import Darwin
import Foundation
import ImageIO
import UniformTypeIdentifiers

let sourceRevision = "770ece8e1797adc91a0e7e88506712cc8f292557"
let sourceArtwork =
  "Original solid-blue circle drawn by the AdaptiveGlyphKit fixture generator."
let generatorPlatform = ProcessInfo.processInfo.operatingSystemVersionString
let semanticIdentifier = "adaptiveglyphkit.project-owned.blue-circle.v1"
let semanticDescription = "Project-owned blue circle"
let generatorCommand =
  "xcrun swift Scripts/generate-test-fixtures.swift Tests/AdaptiveGlyphKitTests/Fixtures"

struct FixtureRecord: Encodable {
  let path: String
  let byteCount: Int
  let sha256: String
}

struct FixtureProvenance: Encodable {
  let adaptiveGlyphKitSourceRevision: String
  let sourceArtwork: String
  let generatorPlatform: String
  let generatorCommand: String
  let semanticIdentifier: String
  let semanticDescription: String
  let fixtures: [FixtureRecord]
}

enum FixtureGenerationError: Error {
  case cannotCreateImage(size: Int)
  case cannotCreateDestination(type: String)
  case cannotFinalizeDestination(type: String)
}

func solidBlueCircle(size: Int) throws -> CGImage {
  guard
    let context = CGContext(
      data: nil,
      width: size,
      height: size,
      bitsPerComponent: 8,
      bytesPerRow: size * 4,
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
  else {
    throw FixtureGenerationError.cannotCreateImage(size: size)
  }

  let bounds = CGRect(x: 0, y: 0, width: size, height: size)
  context.clear(bounds)
  context.setAllowsAntialiasing(true)
  context.setShouldAntialias(true)
  context.setFillColor(CGColor(red: 0.1, green: 0.4, blue: 0.95, alpha: 1))
  let inset = CGFloat(size) / 16
  context.fillEllipse(in: bounds.insetBy(dx: inset, dy: inset))

  guard let image = context.makeImage() else {
    throw FixtureGenerationError.cannotCreateImage(size: size)
  }
  return image
}

let tiffProperties: [CFString: Any] = [
  kCGImagePropertyTIFFDocumentName: semanticIdentifier,
  kCGImagePropertyTIFFImageDescription: semanticDescription,
]
let glyphProperties: [CFString: Any] = [
  kCGImagePropertyTIFFDictionary: tiffProperties,
]

func encode(
  images: [CGImage],
  as type: UTType,
  properties: [CFString: Any]? = glyphProperties
) throws -> Data {
  let output = NSMutableData()
  guard
    let destination = CGImageDestinationCreateWithData(
      output, type.identifier as CFString, images.count, nil)
  else {
    throw FixtureGenerationError.cannotCreateDestination(type: type.identifier)
  }
  for image in images {
    CGImageDestinationAddImage(destination, image, properties as CFDictionary?)
  }
  guard CGImageDestinationFinalize(destination) else {
    throw FixtureGenerationError.cannotFinalizeDestination(type: type.identifier)
  }
  return output as Data
}

func sha256(of data: Data) -> String {
  SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

guard CommandLine.arguments.count == 2 else {
  fputs("usage: xcrun swift Scripts/generate-test-fixtures.swift OUTPUT_DIRECTORY\n", stderr)
  exit(64)
}

let outputDirectory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(
  at: outputDirectory,
  withIntermediateDirectories: true)

let artwork512 = try solidBlueCircle(size: 512)
let artwork128 = try solidBlueCircle(size: 128)
let artwork1024 = try solidBlueCircle(size: 1_024)
let artwork1025 = try solidBlueCircle(size: 1_025)

let generatedFixtures: [(path: String, data: Data)] = [
  ("project-owned-blue-glyph.heic", try encode(images: [artwork512], as: .heic)),
  ("wrong-type.png", try encode(images: [artwork512], as: .png)),
  ("nine-representations.heic", try encode(images: Array(repeating: artwork128, count: 9), as: .heic)),
  ("edge-1025.heic", try encode(images: [artwork1025], as: .heic)),
  ("two-1024-representations.heic", try encode(images: [artwork1024, artwork1024], as: .heic)),
  // Passes the bounded preflight (valid single-representation HEIC) but omits
  // the TIFF DocumentName, so NSAdaptiveImageGlyph itself rejects it. This is
  // the only fixture that exercises the system-rejection branch.
  ("no-document-name.heic", try encode(images: [artwork512], as: .heic, properties: nil)),
]

for fixture in generatedFixtures {
  try fixture.data.write(to: outputDirectory.appendingPathComponent(fixture.path), options: .atomic)
}

let provenance = FixtureProvenance(
  adaptiveGlyphKitSourceRevision: sourceRevision,
  sourceArtwork: sourceArtwork,
  generatorPlatform: generatorPlatform,
  generatorCommand: generatorCommand,
  semanticIdentifier: semanticIdentifier,
  semanticDescription: semanticDescription,
  fixtures: generatedFixtures.map {
    FixtureRecord(path: $0.path, byteCount: $0.data.count, sha256: sha256(of: $0.data))
  })
let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
let provenanceData = try encoder.encode(provenance)
try provenanceData.write(
  to: outputDirectory.appendingPathComponent("provenance.json"),
  options: .atomic)

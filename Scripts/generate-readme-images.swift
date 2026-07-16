#!/usr/bin/env swift

// Renders the README example images on macOS. Self-contained like
// generate-test-fixtures.swift: it reproduces the minimal forged content shape
// (HEIC + TIFF DocumentName) instead of importing the package, then renders
// real adaptive image glyphs offscreen through TextKit 2.
//
// usage: DEVELOPER_DIR=<Xcode> xcrun swift Scripts/generate-readme-images.swift docs/images

import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let identifier = "adaptiveglyphkit.readme.blue-cat.v1"
let accessibilityDescription = "A round blue cat"

enum ImageGenerationError: Error {
  case cannotCreateContext
  case cannotEncode
  case glyphRejected
  case cannotSnapshot
}

// MARK: Project-owned artwork: a round blue cat with alpha

func blueCat(size: Int) throws -> CGImage {
  guard
    let context = CGContext(
      data: nil,
      width: size,
      height: size,
      bitsPerComponent: 8,
      bytesPerRow: size * 4,
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
  else { throw ImageGenerationError.cannotCreateContext }

  let s = CGFloat(size)
  context.clear(CGRect(x: 0, y: 0, width: s, height: s))
  context.setAllowsAntialiasing(true)
  context.setShouldAntialias(true)

  let body = CGColor(red: 0.18, green: 0.45, blue: 0.95, alpha: 1)
  let dark = CGColor(red: 0.06, green: 0.13, blue: 0.32, alpha: 1)
  let blush = CGColor(red: 1.0, green: 0.55, blue: 0.62, alpha: 1)

  // Ears
  context.setFillColor(body)
  for (a, b, c) in [
    (CGPoint(x: 0.14, y: 0.62), CGPoint(x: 0.20, y: 0.97), CGPoint(x: 0.44, y: 0.78)),
    (CGPoint(x: 0.86, y: 0.62), CGPoint(x: 0.80, y: 0.97), CGPoint(x: 0.56, y: 0.78)),
  ] {
    context.beginPath()
    context.move(to: CGPoint(x: a.x * s, y: a.y * s))
    context.addLine(to: CGPoint(x: b.x * s, y: b.y * s))
    context.addLine(to: CGPoint(x: c.x * s, y: c.y * s))
    context.closePath()
    context.fillPath()
  }

  // Body
  context.fillEllipse(in: CGRect(x: 0.08 * s, y: 0.06 * s, width: 0.84 * s, height: 0.80 * s))

  // Eyes
  context.setFillColor(dark)
  context.fillEllipse(in: CGRect(x: 0.30 * s, y: 0.42 * s, width: 0.09 * s, height: 0.13 * s))
  context.fillEllipse(in: CGRect(x: 0.61 * s, y: 0.42 * s, width: 0.09 * s, height: 0.13 * s))

  // Blush
  context.setFillColor(blush)
  context.fillEllipse(in: CGRect(x: 0.20 * s, y: 0.30 * s, width: 0.12 * s, height: 0.07 * s))
  context.fillEllipse(in: CGRect(x: 0.68 * s, y: 0.30 * s, width: 0.12 * s, height: 0.07 * s))

  // Mouth
  context.setStrokeColor(dark)
  context.setLineWidth(0.02 * s)
  context.setLineCap(.round)
  context.beginPath()
  context.move(to: CGPoint(x: 0.42 * s, y: 0.32 * s))
  context.addQuadCurve(
    to: CGPoint(x: 0.50 * s, y: 0.28 * s), control: CGPoint(x: 0.46 * s, y: 0.27 * s))
  context.addQuadCurve(
    to: CGPoint(x: 0.58 * s, y: 0.32 * s), control: CGPoint(x: 0.54 * s, y: 0.27 * s))
  context.strokePath()

  guard let image = context.makeImage() else { throw ImageGenerationError.cannotCreateContext }
  return image
}

// MARK: Forge the minimal accepted content shape

func forgedContent(_ image: CGImage) throws -> Data {
  let output = NSMutableData()
  guard
    let destination = CGImageDestinationCreateWithData(
      output, UTType.heic.identifier as CFString, 1, nil)
  else { throw ImageGenerationError.cannotEncode }
  let tiff: [CFString: Any] = [
    kCGImagePropertyTIFFDocumentName: identifier,
    kCGImagePropertyTIFFImageDescription: accessibilityDescription,
  ]
  let properties: [CFString: Any] = [kCGImagePropertyTIFFDictionary: tiff]
  CGImageDestinationAddImage(destination, image, properties as CFDictionary)
  guard CGImageDestinationFinalize(destination) else { throw ImageGenerationError.cannotEncode }
  return output as Data
}

// MARK: Offscreen TextKit 2 rendering (same technique as AppKitRenderTests)

@MainActor
func render(lines: [(text: String, pointSize: CGFloat)], glyph: NSAdaptiveImageGlyph, width: CGFloat)
  throws -> NSBitmapImageRep
{
  let storage = NSMutableAttributedString()
  for (index, line) in lines.enumerated() {
    let font = NSFont.systemFont(ofSize: line.pointSize)
    let paragraph = NSMutableParagraphStyle()
    paragraph.paragraphSpacing = line.pointSize * 0.45
    let attributes: [NSAttributedString.Key: Any] = [
      .font: font,
      .foregroundColor: NSColor.black,
      .paragraphStyle: paragraph,
    ]
    let rendered = NSMutableAttributedString(
      string: index == 0 ? line.text : "\n" + line.text, attributes: attributes)
    rendered.mutableString.replaceOccurrences(
      of: ":blobcat:", with: "\u{FFFC}",
      range: NSRange(location: 0, length: rendered.length))
    var search = NSRange(location: 0, length: rendered.length)
    while true {
      let found = rendered.mutableString.range(of: "\u{FFFC}", range: search)
      guard found.location != NSNotFound else { break }
      rendered.addAttribute(.adaptiveImageGlyph, value: glyph, range: found)
      let next = found.location + found.length
      search = NSRange(location: next, length: rendered.length - next)
    }
    storage.append(rendered)
  }

  let padding: CGFloat = 28
  let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: width, height: 100))
  textView.importsGraphics = true
  textView.backgroundColor = .white
  textView.textContainerInset = NSSize(width: padding, height: padding)
  textView.textStorage?.setAttributedString(storage)

  // Never touch textView.layoutManager here: that silently downgrades the view
  // to TextKit 1, and adaptive image glyphs render only under TextKit 2.
  guard let textLayoutManager = textView.textLayoutManager else {
    throw ImageGenerationError.cannotSnapshot
  }
  textLayoutManager.ensureLayout(for: textLayoutManager.documentRange)
  let used = textLayoutManager.usageBoundsForTextContainer
  let frame = NSRect(x: 0, y: 0, width: width, height: ceil(used.height) + padding * 2)
  textView.frame = frame

  let window = NSWindow(
    contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
  window.contentView = textView
  textView.layoutSubtreeIfNeeded()

  guard let rep = textView.bitmapImageRepForCachingDisplay(in: textView.bounds) else {
    throw ImageGenerationError.cannotSnapshot
  }
  textView.cacheDisplay(in: textView.bounds, to: rep)
  return rep
}

func writePNG(_ rep: NSBitmapImageRep, to url: URL) throws {
  guard let data = rep.representation(using: .png, properties: [:]) else {
    throw ImageGenerationError.cannotEncode
  }
  try data.write(to: url, options: .atomic)
}

// MARK: Main

guard CommandLine.arguments.count == 2 else {
  fputs("usage: xcrun swift Scripts/generate-readme-images.swift OUTPUT_DIRECTORY\n", stderr)
  exit(64)
}
let outputDirectory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

let artwork = try blueCat(size: 512)
let content = try forgedContent(artwork)
let glyph = NSAdaptiveImageGlyph(imageContent: content)
guard unsafeBitCast(glyph, to: UInt.self) != 0 else {
  throw ImageGenerationError.glyphRejected
}

let inline = try await MainActor.run {
  try render(
    lines: [("Say hi to :blobcat: — it scales with your text.", 34)],
    glyph: glyph,
    width: 880)
}
try writePNG(inline, to: outputDirectory.appendingPathComponent("inline-glyph.png"))

let sizes = try await MainActor.run {
  try render(
    lines: [
      ("Inline :blobcat: at body size", 17),
      ("Inline :blobcat: at title size", 28),
      ("Inline :blobcat: at display size", 44),
      ("Inline :blobcat: everywhere", 64),
    ],
    glyph: glyph,
    width: 880)
}
try writePNG(sizes, to: outputDirectory.appendingPathComponent("dynamic-type.png"))

print("wrote inline-glyph.png and dynamic-type.png to \(outputDirectory.path)")

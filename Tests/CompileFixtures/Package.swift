// swift-tools-version: 6.0
import PackageDescription

let targetNames = [
  "WatchSupportedAPIs",
  "WatchUnavailableMakeImageContentData",
  "WatchUnavailableMakeImageContentCGImage",
  "WatchUnavailableMakeGlyphData",
  "WatchUnavailableMakeGlyphCGImage",
  "WatchUnavailableAttributedStringFromImageData",
]

let package = Package(
  name: "WatchOSAPISurfaceFixtures",
  platforms: [
    .watchOS(.v11),
  ],
  dependencies: [
    .package(path: "../.."),
  ],
  targets: targetNames.map { name in
    .executableTarget(
      name: name,
      dependencies: [
        .product(name: "AdaptiveGlyphKit", package: "AdaptiveGlyphKit"),
      ]
    )
  }
)

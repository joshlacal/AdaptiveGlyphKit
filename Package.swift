// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "AdaptiveGlyphKit",
  platforms: [
    .iOS(.v18),
    .macOS(.v15),
    .macCatalyst(.v18),
    .tvOS(.v18),
    .visionOS(.v2),
    .watchOS(.v11),
  ],
  products: [
    .library(name: "AdaptiveGlyphKit", targets: ["AdaptiveGlyphKit"]),
  ],
  targets: [
    .target(name: "AdaptiveGlyphKit"),
    .testTarget(name: "AdaptiveGlyphKitTests", dependencies: ["AdaptiveGlyphKit"]),
  ]
)

import Foundation

enum GlyphFixture {
  static let identifier = "adaptiveglyphkit.project-owned.blue-circle.v1"
  static let accessibilityDescription = "Project-owned blue circle"

  static func data(named name: String, extension fileExtension: String) throws -> Data {
    guard let url = Bundle.module.url(forResource: name, withExtension: fileExtension) else {
      throw CocoaError(.fileNoSuchFile)
    }
    return try Data(contentsOf: url)
  }
}

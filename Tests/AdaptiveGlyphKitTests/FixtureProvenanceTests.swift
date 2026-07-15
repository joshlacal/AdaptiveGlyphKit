import CryptoKit
import Foundation
import Testing
@testable import AdaptiveGlyphKit

struct FixtureRecord: Decodable {
  let path: String
  let byteCount: Int
  let sha256: String
}

struct FixtureProvenance: Decodable {
  let adaptiveGlyphKitSourceRevision: String
  let sourceArtwork: String
  let generatorPlatform: String
  let generatorCommand: String
  let semanticIdentifier: String
  let semanticDescription: String
  let fixtures: [FixtureRecord]
}

@Suite("Fixture provenance")
struct FixtureProvenanceTests {
  private static let expectedFixturePaths: Set<String> = [
    "project-owned-blue-glyph.heic",
    "wrong-type.png",
    "nine-representations.heic",
    "edge-1025.heic",
    "two-1024-representations.heic",
  ]

  @Test("every fixture matches its recorded byte count and SHA-256")
  func verifiesCommittedFixtures() throws {
    let provenanceData = try GlyphFixture.data(named: "provenance", extension: "json")
    let provenance = try JSONDecoder().decode(FixtureProvenance.self, from: provenanceData)
    #expect(
      provenance.adaptiveGlyphKitSourceRevision
        == "a1afe9552df4384999a736dcf24cc44d0fdc0750")
    #expect(
      provenance.sourceArtwork
        == "Original solid-blue circle drawn by the AdaptiveGlyphKit fixture generator.")
    #expect(
      !provenance.generatorPlatform.trimmingCharacters(
        in: .whitespacesAndNewlines).isEmpty)
    #expect(
      provenance.generatorCommand
        == "xcrun swift Scripts/generate-test-fixtures.swift Tests/AdaptiveGlyphKitTests/Fixtures")
    #expect(provenance.semanticIdentifier == GlyphFixture.identifier)
    #expect(provenance.semanticDescription == GlyphFixture.accessibilityDescription)

    let recordedPaths = provenance.fixtures.map(\.path)
    #expect(recordedPaths.count == Self.expectedFixturePaths.count)
    #expect(Set(recordedPaths).count == recordedPaths.count)
    #expect(Set(recordedPaths) == Self.expectedFixturePaths)

    for record in provenance.fixtures {
      #expect(record.byteCount > 0)
      #expect(record.sha256.count == 64)
      #expect(record.sha256.allSatisfy { $0.isHexDigit && !$0.isUppercase })
      let url = try #require(
        Bundle.module.url(
          forResource: URL(fileURLWithPath: record.path).deletingPathExtension().lastPathComponent,
          withExtension: URL(fileURLWithPath: record.path).pathExtension))
      let data = try Data(contentsOf: url)
      #expect(data.count == record.byteCount)
      let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
      #expect(digest == record.sha256)
    }
  }
}

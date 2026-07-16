# Changelog

## 0.1.0 - 2026-07-16

- Forge bounded adaptive image glyph content from Data and CGImage on iOS,
  macOS, Mac Catalyst, tvOS, and visionOS.
- Consume and render bounded pre-forged glyph content on watchOS 11.
- Fall back to readable attributed text when content is rejected.
- Construct glyphs through the Objective-C runtime so system-rejected content
  returns nil in Release builds instead of crashing.

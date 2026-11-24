# ``AdaptiveGlyphKit``

Render existing artwork as an inline adaptive image glyph in Apple text.

## Overview

`NSAdaptiveImageGlyph` is the system type behind Genmoji and custom stickers, but its public initializer accepts only prebuilt image content. AdaptiveGlyphKit is an experimental compatibility bridge: it forges the minimal accepted content shape on encoding-capable platforms and safely consumes bounded pre-forged content on every supported platform.

Glyphs flow inside a sentence like Genmoji, scale with Dynamic Type, and can carry an accessibility description. See the package README for installation, platform capabilities, the bounded content policy and accessibility notes.

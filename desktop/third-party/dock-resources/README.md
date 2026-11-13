<!-- SPDX-License-Identifier: MIT -->
# Dock third-party resources

The Swift loader is MIT software. Resource fonts retain OFL-1.1, with their
unchanged copyright/license notices in `Resources/Fonts`. Vendor names and marks
retain their owners' rights; they are identification, not ModelPlan artwork or
endorsement. No ModelPlan reserved-visual license applies to these assets.

The seven marks are original unaltered bytes from the approved source set;
`Resources/Marks/SOURCES.md` records their origins. The white Z.ai mark is beta-only; the other marks are not.
The consumer must explicitly choose the beta policy; the standard manifest
excludes that mark pending the separate public-release decision.

The current uncommitted font preparation uses SFNT containers of the exact WOFF2
golden inputs, using fontTools 4.60.1. Variable axes are retained. All glyph
coordinates, horizontal metrics and character mappings were compared before/after
conversion; font names and notices were preserved. The approved native design permits these exact upstream variable fonts in
addition to the default static-font pack. Source/output hashes and
the conversion description are in `Resources/manifest.json`. No system font is
installed or changed. Fonts are loaded from their verified bytes in the process.

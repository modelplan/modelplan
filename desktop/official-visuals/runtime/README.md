<!-- SPDX-License-Identifier: LicenseRef-ModelPlan-Visuals-1.0 -->
# Official runtime artwork

Copyright (c) 2026 ModelPlan. All rights reserved.

This pack is covered by the [ModelPlan Official Visuals License 1.0](../LICENSE.md)
(`LicenseRef-ModelPlan-Visuals-1.0`). It is not part of the root MIT software grant.
ModelPlan and Model Plan are marks of ModelPlan. No trademark rights are granted;
see [the trademark notice](../../../TRADEMARKS.md).

The runtime pack contains:

- **A5 recessed ignition:** day/night idle/pressed caps, raised guard, inner
  contact shadow and outer contact shadow, at 2x and 3x. Layer order is outer
  shadow, cap, inner shadow, guard. The cap occupies a 44-point square centered
  within the 52-point guard; its pressed placement adds one logical point down.
  The outer shadow uses a 56-point canvas. PNG sizes in the manifest are pixels.
- **c01 canopy:** frame colour, optical pane, window coverage, aperture and final
  joined outline coverage for the 640/890 layout tiers, at 1x and 2x. Tier names
  describe the layout, not image width. The window/aperture/outline images are
  final runtime coverage masks. Consumers use the recorded pixel dimensions.
  D74 (2026-11-08, revised by D100 on 2026-11-09): only the missing top is added to the
  shipped c01 layers. Below a seam (row 96 of the 636x244 tall canvas, row 43 of the
  636x76 compact canvas) the layers are the shipped pixels, bit for bit, placed 28 pt
  lower, but only inside x 28..608 pt: the outer 28 pt strip of each wall is rebuilt so
  the wall ends in its natural rounded edge instead of the original straight cut (the
  outer wall band is squeezed horizontally, faded in over 90 source rows). Above the
  seam the completed shoulders and top arc come from an outpainted master (Codex image
  generation, glints on the top arc removed, shoulder ledge blended), fitted to the
  shipped wall lines and cross-faded over the seam; the silhouette alpha is anti-aliased.
  The tall tier squashes the arc vertically by at most 11 percent at its very top so it
  closes inside the canvas. This art is pending owner acceptance and is not final. Layer
  names and the 1x/2x sizes are otherwise unchanged.

`manifest.json` binds every file to its SHA-256, byte size, pixel dimensions and
reserved licence. Its eight baseline records point to the exact owner-confirmed
day/night idle/pressed cap exports at both scales. They are cap-image baselines,
not whole-window or integrated-button screenshots.

`node desktop/build.mjs --official` verifies and copies this pack into the built
app's `runtime/` directory. The default community build excludes this pack.
Native Dock/cockpit consumers bind the manifest in their own integration work.

The integrity check is `node scripts/check-visual-pack.mjs`. It checks the exact
file set, hashes, dimensions, baseline associations, licence registry and public
metadata. The porthole-stills/ pack adds the approved 980 PNG stills and its own runtime
manifest, checksums and badge notice. Fonts remain separately licensed under
desktop/third-party/fonts/.

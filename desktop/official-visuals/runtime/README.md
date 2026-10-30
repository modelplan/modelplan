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

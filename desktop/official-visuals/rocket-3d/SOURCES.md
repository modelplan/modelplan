<!-- SPDX-License-Identifier: LicenseRef-ModelPlan-Visuals-1.0 -->
# Sources

The model files and `rocket-geometry.json` are are mechanical conversions of the approved pass-5 rocket (owner
2026-10-24/25), which lives on the private design branch `design/entrance-storyboard-20261025`
(commit `dc9a1b52d`) under `clients/official-visuals/rocket-3d/exports/`:

| Source GLB | SHA-256 |
| --- | --- |
| `modelplan-rocket-night-lod1.glb` | `c44667154d1366a09bdda1e288c09e3471140f52d6bf1b5b62f902e1a889137e` |
| `modelplan-rocket-day-lod1.glb` | `243ef864d791aa461093980567985e59a6f49265839b614519e8daad626725df` |

Conversion: three.js 0.186.1 `GLTFLoader` → `USDZExporter.parseAsync(scene, {maxTextureSize: 2048,
quickLookCompatible: false})` in Chromium 1117 (headless). Node names, hierarchy, anchors, metres and +Y up are
preserved; the 1024×2048 hull atlas is kept at full size. `rocket-geometry.json` is read directly from the night
GLB's `curved_canopy_glass` POSITION accessor and `anchor_window` node (both finishes share the geometry).
Owner D146 (2026-11-11, round 9): the glass in `rocket-geometry.json` was replaced by the window outline measured on
the pass-5 prototype window still (a rounded trapezoid on the capsule: bottom 12.49 m, top 13.07 m, half-widths
0.695/0.435 m along the glass arc, corner radii 0.12/0.13 m), written as its centre, a half-size ring and its edge;
`windowAnchorY` is its centre (12.78 m). The model files keep the file's window; the entrance rebuilds it in code.

The hull material masters were made with the built-in image generation tool in pass 4 (private provenance on the
design branch, `pass4/prompts.json`). The two cockpit emission textures inside the canopy are blurred crops of
October study screenshots; they are hidden behind the dark glass in the entrance.

Licence: LicenseRef-ModelPlan-Visuals-1.0 (`desktop/official-visuals/LICENSE.md`); the earlier private-only note
in the design branch's RIGHTS.md is superseded for these files by owner decision D109 (2026-11-09).

## Generated look images (owner D142, 2026-11-11)

Generated on 2026-11-11 by the M4 Codex lane's built-in image tool from the prompts in the private hand-off
`specs/v11/entrance-dev/gen-prompts-r7.md`; two candidates each, candidate `a` chosen; use approved by the owner
(D142, under the D116 allowance for generated textures). Post-processing is mechanical:

| File | Source candidate (SHA-256) | Processing |
| --- | --- | --- |
| `rocket-brushed-steel-detail.png` | `rocket-brushed-steel-detail-a.png` (`3e1b25a36229bb4a1ce2265a49a274d49a3d765c0c1eb346eda79aa15ea4de91`) | greyscale; the left and right 96 px cross-faded with the tile shifted half a width, so the horizontal wrap is seamless |
| `rocket-cockpit-interior-night.png` | `rocket-cockpit-interior-night-a.png` (`4b74e1e25a5505753d50d4bd8346124b0fc6252f883d918df5468d149fddb8cf`) | alpha dropped; cropped to x 242-1858, y 63-1217 (1617 x 1155, 7:5) to remove the window frame the image model drew round the edges (the 3D model has its own) |

The day finish uses the night cockpit image (no day variant).

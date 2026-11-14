<!-- SPDX-License-Identifier: LicenseRef-ModelPlan-Visuals-1.0 -->
# Sources

No new art was made for this pack. The files are mechanical conversions of the approved pass-5 rocket (owner
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

The hull material masters were made with the built-in image generation tool in pass 4 (private provenance on the
design branch, `pass4/prompts.json`). The two cockpit emission textures inside the canopy are blurred crops of
October study screenshots; they are hidden behind the dark glass in the entrance.

Licence: LicenseRef-ModelPlan-Visuals-1.0 (`desktop/official-visuals/LICENSE.md`); the earlier private-only note
in the design branch's RIGHTS.md is superseded for these files by owner decision D109 (2026-11-09).

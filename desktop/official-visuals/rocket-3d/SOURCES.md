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

## Hull kit (CKP-ENT-13, owner D173/D174/D176/D179, 2026-11-12)

Generated on 2026-11-12 with the built-in image generation tool (Codex `gpt-6.1-terra`, `codex exec` with the
pass-5 hull crops as reference images) from the per-kind prompts in the private hand-off `entr-d176g/`
(`entr-d176g-prompt-<kind>.txt`); the decals were made on a green key and turned into straight-alpha greyscale
(median plate tone = 128), normal and roughness maps by its `entr-d176g-process.cjs`; the day metal and the metal
roughness are derived from the night metal by its `entr-d176g-derive.cjs`. The
owner accepted the kit and the base metal on confirm card 2026-11-12/07 (D179) and dropped the capsule tags, so
the stencil label and rivet strip are not shipped. Pack processing is lossless only (same pixels, same size): the
greyscale maps are stored as grey or grey + alpha PNG and every file is recompressed.

| File | Source (SHA-256) | Processing |
| --- | --- | --- |
| `rocket-hull-decal-door-albedo.png` | `entr-d176g-door-albedo.png` (`d3f5daf5ee357bd2b94f71fbb564240e875ee7b92181ae3283adc88b62b89ea0`) | RGBA (R = G = B) to grey + alpha |
| `rocket-hull-decal-door-normal.png` | `entr-d176g-door-normal.png` (`d4f865d7ff95d275ce008f0bd45300d40c3efa183915fa11b43cdf9e24d36eb8`) | recompressed |
| `rocket-hull-decal-door-roughness.png` | `entr-d176g-door-rough.png` (`09428513fc81cb3d77a095973eb126fb6120d84f8321ccf112674db49f2a9791`) | RGB (R = G = B) to grey |
| `rocket-hull-decal-hatch-albedo.png` | `entr-d176g-hatch-albedo.png` (`4cbe472ec7384e59d10b7fcda209f6ca251fafcf99f26ef7adb3fb82a73b764c`) | RGBA (R = G = B) to grey + alpha |
| `rocket-hull-decal-hatch-normal.png` | `entr-d176g-hatch-normal.png` (`98242326d26d430c095e16467bdf88baa56b637ad1651a31918da23e5e52407a`) | recompressed |
| `rocket-hull-decal-hatch-roughness.png` | `entr-d176g-hatch-rough.png` (`5ecf49e9b89b551315d981847f1981ab9724b720f9043cb5e80263be1c73c418`) | RGB (R = G = B) to grey |
| `rocket-hull-decal-vent-albedo.png` | `entr-d176g-vent-albedo.png` (`2179cd0f5ba0080eaabe189bfca56adf169130412ffa1dea628d831cc64d1bc2`) | RGBA (R = G = B) to grey + alpha |
| `rocket-hull-decal-vent-normal.png` | `entr-d176g-vent-normal.png` (`8f91e6b55bdae8b2b5c6aa411f57166bce5336bfdd3e5a9dcd5cf541d013798d`) | recompressed |
| `rocket-hull-decal-vent-roughness.png` | `entr-d176g-vent-rough.png` (`64d2d8a61719717afd77f7be42e0e939d8bbb1547efae615f536f686ee9aae02`) | RGB (R = G = B) to grey |
| `rocket-hull-decal-plate-albedo.png` | `entr-d176g-plate-albedo.png` (`fc8dcb48e5a6f55b4cf55f464cb0810e29415b0689b7f019102c7887b3fce7ba`) | RGBA (R = G = B) to grey + alpha |
| `rocket-hull-decal-plate-normal.png` | `entr-d176g-plate-normal.png` (`537bcd300ff704ef8b7c6878de8f78c137d5e801b8004245e685450e9df05b55`) | recompressed |
| `rocket-hull-decal-plate-roughness.png` | `entr-d176g-plate-rough.png` (`f3e4b0af2977381fa72d5c78dc17fc6cfc982af97858f23d0a039539e41d58e4`) | RGB (R = G = B) to grey |
| `rocket-hull-decal-slot-albedo.png` | `entr-d176g-slot-albedo.png` (`a1eccbc225e7d748592e9dbf0d1a5527aaaaa2e0140763ee22bb486cf080eac0`) | RGBA (R = G = B) to grey + alpha |
| `rocket-hull-decal-slot-normal.png` | `entr-d176g-slot-normal.png` (`d46634ae7b3f008b3e15035d638f3097717b4607a1a188100c369fb11cc403f2`) | recompressed |
| `rocket-hull-decal-slot-roughness.png` | `entr-d176g-slot-rough.png` (`b43e90617aafa4f198ddcf5a5949e3bdb63c64ace5c982273da28cfce063792c`) | RGB (R = G = B) to grey |
| `rocket-hull-decal-panel-albedo.png` | `entr-d176g-panel-albedo.png` (`c02cec0fcffc7283af4d874d480d3fb145949b6e8dd19f6858f485e95c44e18a`) | RGBA (R = G = B) to grey + alpha |
| `rocket-hull-decal-panel-normal.png` | `entr-d176g-panel-normal.png` (`8ffe2e0996121ef2aa07796cc5aac3149cc33f65cef370c51292a861577efb6f`) | recompressed |
| `rocket-hull-decal-panel-roughness.png` | `entr-d176g-panel-rough.png` (`9bead6acf43d502bbb5e7534b14327dedcbfbbf81fc94ca29d0939357e137917`) | RGB (R = G = B) to grey |
| `rocket-hull-metal-night.png` | `entr-d176g-metal-night-a.png` (`ad7c988a2b3a52864f8cc7b22ef8403ff0f4ca9f2156659ff64b0ca0a7c248a5`) | recompressed |
| `rocket-hull-metal-day.png` | `entr-d176g-metal-day-a.png` (`93a103d6280dc4bc81cdd6d953f6ac865aea1ad929a85b522b6120ae862ea3a4`) | recompressed |
| `rocket-hull-metal-roughness.png` | `entr-d176g-metal-rough-a.png` (`c98780000512635bd04b2b9c6b18dc5e480769a5c69330aa3cce7a56c119aa1d`) | RGB (R = G = B) to grey |

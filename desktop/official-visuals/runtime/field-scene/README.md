<!-- SPDX-License-Identifier: LicenseRef-ModelPlan-Visuals-1.0 -->
# Launch-field scene (enlarged porthole)

Copyright (c) 2026 ModelPlan. All rights reserved.
ModelPlan and Model Plan are marks of ModelPlan. No trademark rights are granted.

`cockpit-scene.bundle.js` is the owner-approved 3D launch-field scene shown when the
official cockpit's porthole is enlarged (owner decision D39/D-A, 2026-11-06). It is a
minified build output only: the scene, rocket and planet sources stay private and are
not part of this repository, so it cannot be rebuilt from public sources. The
[reserved visuals licence](../../LICENSE.md) applies to the scene code; the root MIT
licence does not cover it. It bundles three.js 0.186.1 (MIT, Copyright 2010-2026
Three.js Authors); that notice is kept at the end of the file.

Rockets (owner decision D207, 2026-11-12): the scene flies the website's fleet round-four
vehicles (Falcon 9, Falcon Heavy, New Glenn, Vulcan, Long March 2F/5/3B and the Starship),
rebuilt in 3D from owner-commissioned, owner-approved renders. Their geometry is inside the
bundle; `rockets/<vehicle>-512.webp` / `-256.webp` are the albedo atlases and
`rockets/<vehicle>-mat.webp` the material atlases (roughness, metalness, heat-shield tiles).
The renders were generated for ModelPlan with an image model from written prompts, from
earlier ModelPlan concept rounds, with no stock art or downloaded references; the atlases
carry no maker marks. Maker head colours, patterns, bands and roundels are painted at runtime
from the shared maker livery table (D131) and the vendor marks the official cockpit already
ships under `assets/brands/` (third-party trademarks, nominative use). The official cockpit
build serves the atlases at `assets/art/rockets/`, the scene's base URL.

Build: esbuild 0.28.1, `--bundle --format=esm --minify --legal-comments=eof`, three
0.186.1; the four-line licence header is prepended. Export: `mountWorkbenchField`.

Loading rule: only `node desktop/cockpit/build.mjs --official` includes it, and the
cockpit page may load it only on demand when the enlarged view opens. The community
edition never contains it. Vendor marks the scene can draw on its plates are not
included here; without them the plates fall back to text.

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

Build: esbuild 0.28.1, `--bundle --format=esm --minify --legal-comments=eof`, three
0.186.1; the four-line licence header is prepended. Export: `mountWorkbenchField`.

Loading rule: only `node desktop/cockpit/build.mjs --official` includes it, and the
cockpit page may load it only on demand when the enlarged view opens. The community
edition never contains it. Vendor marks the scene can draw on its plates are not
included here; without them the plates fall back to text.

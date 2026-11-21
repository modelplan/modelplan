<!-- SPDX-License-Identifier: LicenseRef-ModelPlan-Visuals-1.0 -->
# Launch-field window (enlarged porthole)

Copyright (c) 2026 ModelPlan. All rights reserved.
ModelPlan and Model Plan are marks of ModelPlan. No trademark rights are granted.

`launch-field.js` and `launch-field.css` are the website's shared launch-field component, version 1.2.0,
in its window mode (owner decision D298, 2026-11-18): the official cockpit's enlarged field. They replace
the earlier `cockpit-scene.bundle.js` (D39/D-A, D207). The component draws the cockpit window (soft canopy,
feathered edge, inside sky), the in-field menu, the corner keys and the fly-in card, and frames the 3D field
into the window. It is a minified build output only: its sources stay private and are not part of this
repository, so it cannot be rebuilt from public sources. The [reserved visuals licence](../../LICENSE.md)
applies to its code and styles; the root MIT licence does not cover them. It bundles three.js 0.186.1 (MIT,
Copyright 2010-2026 three.js authors); its licence block is kept at the end of `launch-field.js`.

Provenance: built with `npm run build:launch-field` at component version 1.2.0. The build's own manifest
recorded these SHA-256 values before the four-line licence header above each file was added; nothing else
was changed:

- `launch-field.js` a04ace33fa0944e5bf9a9f9c5615732b8cbd624604576f4c945d2bb428aace2e (807961 bytes)
- `launch-field.css` 78356f60a8504dd78501ef8bf717c4606530a14b2b8f7f84eb63b86dba915b9e (30218 bytes)

Rockets (D207): the field flies the website's fleet round-four vehicles (Falcon 9, Falcon Heavy, New Glenn,
Vulcan, Long March 2F/5/3B and the Starship). Their geometry is inside the script;
`rockets/<vehicle>-512.webp` / `-256.webp` are the albedo atlases and `rockets/<vehicle>-mat.webp` the
material atlases (roughness, metalness, heat-shield tiles), byte-identical to the component build's own.
The renders were generated for ModelPlan with an image model from written prompts, with no stock art or
downloaded references; the atlases carry no maker marks.

The 2D fallback's sprites (`rockets/flat/<vehicle>-<maker>@2x.webp` / `@3x.webp`) are side views rendered
from the same 3D rockets with each maker's livery, byte-identical to the component build's own (which strips
their colour profiles), so their roundels may carry vendor marks, as the night
porthole stills do. Vendor marks are third-party trademarks of their owners, used only to identify each maker;
they are not covered by the reserved visuals licence. The field's own maker-logo map reads the marks from the
official cockpit's `assets/brands/` (sources in its `SOURCES.md`); a mark that does not load is left off.

Loading rule: only `node desktop/cockpit/build.mjs --official` includes it. The build moves the atlases and
sprites to `assets/art/rockets/` (the component's asset base is `./assets/`), and the field's own page
(`field.html`) imports the script only when the enlarged view opens. The community edition never contains it.

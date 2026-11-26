<!-- SPDX-License-Identifier: LicenseRef-ModelPlan-Visuals-1.0 -->
# Docking boom sources

Copyright (c) 2026 ModelPlan. The owner accepted the docking boom round 8 on 2026-11-25 (D447; one piece, no telescoping, D430; the clamp closes on a lug on the canopy frame, D439/D446). It replaces the three-section launch rack (D160/D172). The files come from the true-alpha implementation exports in the confirm folder `24-rack-launch-tower` (`v8x-open.png`, `v8x-closed.png`, `v8x-lug.png`, made from the approved `v8-open.png`, `v8-closed.png` and `v6-1-lug.png`; the closed pose without the illustrative lug bar, the lug without its canopy-frame segment). The boom is cropped to the mount plate's edges and from the plate's top edge to the clamp's bottom (x 196-826, y 72-1486 of the 1024 x 1536 canvas), the lug to its bounds (x 197-1153, y 212-766), each downscaled by half with premultiplied averaging. They remain subject to the official visual license (`../../LICENSE.md`). The packaged app ships the official cockpit bundle (the normal build has the official appearance, owner 2026-11-01), so it carries this art; the community-edition page bundle for forks excludes it.

Night art only: there is no day variant yet, and the day appearance uses the same files (acceptable for now, D447).

| File | Pixels | SHA-256 |
| --- | --- | --- |
| assets/boom-closed.png | 315x707 | `c7264bc7c375c67169dcc713addc738c70c6241986104c9e121cbec3151f34cd` |
| assets/boom-open.png | 315x707 | `45c2abc0a368ece4c7f711e2b79d71e7d636772776141571cae6a8d48f7e04cf` |
| assets/lug.png | 478x277 | `674c93b5c2dba4c82c349c2387e35b5d32b7edb7481cd84479c647c8fbc8c415` |

The native app draws the boom as wide as the widest status-item width of the session (24-96 pt) and scales its height from the art. Anchor points (fractions of the cut art) are `CockpitDockingBoom.metrics` in `CockpitLaunchRack.swift`.

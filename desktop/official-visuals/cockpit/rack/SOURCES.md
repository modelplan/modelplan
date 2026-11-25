<!-- SPDX-License-Identifier: LicenseRef-ModelPlan-Visuals-1.0 -->
# Docking boom sources

Copyright (c) 2026 ModelPlan. The owner accepted the docking boom round 8 on 2026-11-25 (D447; one piece, no telescoping, D430; the clamp closes on a lug on the canopy frame, D439/D446). It replaces the three-section launch rack (D160/D172). The files are cut from the confirm-folder art `24-rack-launch-tower` (`v8-open.png`, `v8-closed.png`, `v6-1-lug.png`, generated on #1a1d22): the boom is cropped to the mount plate's edges and from the plate's top edge to the clamp's bottom, the closed pose without the illustrative lug bar, and the lug alone. They remain subject to the official visual license (`../../LICENSE.md`). The packaged app ships the official cockpit bundle (the normal build has the official appearance, owner 2026-11-01), so it carries this art; the community-edition page bundle for forks excludes it.

Night art only: there is no day variant yet, and the day appearance uses the same files (acceptable for now, D447).

| File | Pixels | SHA-256 |
| --- | --- | --- |
| assets/boom-closed.png | 314x708 | `3c7fa5499643328b469effb7b29625250d7cc64d8bb86d77fa769b2bf8b3ae3d` |
| assets/boom-open.png | 314x708 | `e41f889917b870524f6d37b6c4730f11372d5da7497a06206d103588d031df4e` |
| assets/lug.png | 433x218 | `b4d682c0c99a95d4daed8ad3ced232e517043a71535d5bbbe9ad133d7cc290ec` |

The native app draws the boom as wide as the widest status-item width of the session (24-96 pt) and scales its height from the art. Anchor points (fractions of the cut art) are `CockpitDockingBoom.metrics` in `CockpitLaunchRack.swift`.

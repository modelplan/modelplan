<!-- SPDX-License-Identifier: LicenseRef-ModelPlan-Visuals-1.0 -->
# Cockpit throttle sources

Copyright (c) 2026 ModelPlan. The owner chose the fourth, top-down throttle (D115, 2026-11-09/10: knurled grip, gunmetal arm, chamfered slot plate, seen from straight above), the blue ghost grip for a trial (D122, 2026-11-10, drag demo `02-推杆拖动演示`) and the gold ★ tick of effort demo v8, and moved them into v1 on 2026-11-12 (D196, requirements CKP-FAD-24 and CKP-FAD-17). These rasters are re-baked from that approved scene (Three.js r160 procedural arm, cover plate and shadow over the generated plate and grip art, the demo's `render4`/`scene4` settings) with only the changes the v8 review asked for: the plates keep the slot capsule, its contact shadow and the engraved ticks and have transparent surroundings (the demo's plates were baked on a flat panel tone and showed a dark frame on the day cockpit); every frame of the travel is baked (33 per theme, one sprite sheet); the day ghost grip is stronger so it reads at 1x while staying translucent. They remain subject to the official visual license (`../../LICENSE.md`). The packaged app ships the official cockpit bundle (the normal build has the official appearance, owner 2026-11-01), so it carries this art; the community-edition page bundle for forks excludes it and keeps the MIT flat fader.

| File | Pixels | SHA-256 |
| --- | --- | --- |
| assets/plate-night.png | 76x268 | `11e38a42555b8f1f49e18f04dc777659b71f8d5336851e35a3813a95076bbc7e` |
| assets/plate-day.png | 76x268 | `10503b396c830a707e8011d6901f92469de3b626e3adb74704f67df24980f70e` |
| assets/lever-night.png | 128x8844 | `df31f5866e468e4b6466e309407110343a234b0c016e33d9301727efb9a49d2b` |
| assets/lever-day.png | 128x8844 | `1f23270ee54b9b58a7933ea39f26aeb08116805c754fe0dcfbc3647a0f478290` |
| assets/ghost-night.png | 104x42 | `54da2e0b674e068dc4a2b432b40b3a9d9063df6ee60c9049ae89cfc142506de2` |
| assets/ghost-day.png | 104x41 | `8108eb3f55fb06bd69b768fb0b4902f3c5a0e83bcdb8a597279409d15db3b295` |

All rasters are 2 px per point. Plate: 38x134 pt, slot centre on the middle column, detents (Max..Low) 24.25 pt apart with Max 16.5 pt below the top. Lever: 33 frames of 64x134 pt stacked top to bottom, frame i = grip at -48.5 + 97 i / 32 pt from the High row (0 = Low, 8 = Med, 16 = High, 24 = XHigh, 32 = Max), lever centred horizontally. Ghost grip: 26 pt wide, tinted with the cockpit trial colour #9fd2ff. `throttle.css` is written for this page.

G3-92 (2026-11-12, owner): the lever sheets were re-baked so the arm is a real pivoting stick from the slot-centre pivot to the grip in every frame (the plate no longer hides the arm below the panel, the sliding cover is left out, and the arm metal is a little lighter so it reads in the dark slot); plates and ghosts are byte-identical to the earlier bake.

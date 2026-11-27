<!-- SPDX-License-Identifier: LicenseRef-ModelPlan-Visuals-1.0 -->
# Cockpit engine flame sources

Copyright (c) 2026 ModelPlan. The owner supplied the final blue flame set on 2026-11-26 (decision D454, "ModelPlan-蓝焰调色版.zip": full thrust 01/02/03, short flame, ember; 1040x1440 RGBA, one shared root position). Each sprite was cropped to the same box (x 170, y 283, 722x823 in the source, so the roots align) and downscaled with Lanczos to 160x182 (2x) and 80x91 (1x), the size that matches the owner's nozzle close-up at the cockpit's 2x canvas. The three full-thrust frames are joined into one strip per density (frames side by side) so the flipbook is a single image. PNGs are palette-quantised (quality 90) to stay small. They remain subject to the official visual license (`../../LICENSE.md`) and do not enter the community build, which draws no flame sprite.

| File | Size | Pixels | SHA-256 |
| --- | --- | --- | --- |
| assets/flame-ember-1x.png | 225 B | 80x91 | `14213205ebca0247e2eb2934f5643bb74058dc69cc1c734a6165d4f2b5f5145a` |
| assets/flame-ember-2x.png | 281 B | 160x182 | `f08b153f1effbfc18e2163797b13b91489f6bb7939913769578a7fc13b63db53` |
| assets/flame-full-strip-1x.png | 9897 B | 240x91 | `c2157c18b471b40332a00f2c5e7d401e5c3627c87592e00030465e9a56f42869` |
| assets/flame-full-strip-2x.png | 25372 B | 480x182 | `495eb18963c6b35c6dd8010b2b316433732da8f13532facac7a3a1a6a6edc527` |
| assets/flame-short-1x.png | 2865 B | 80x91 | `2536f53d1e12a5b747fc0af4b564d95f0bf391fdd5cb500ee71aaad9c2ab6259` |
| assets/flame-short-2x.png | 6262 B | 160x182 | `1334e28ee66bc8fe4df0d31f12ffde14cde22c70328cf0aa197653d5e78674ef` |

Used by `../bells/bells.css` (`.bz-flame`): the strip is the working thrust flipbook, short is working at lower output, ember is an idle subscription.

# ModelPlan Official Visuals License 1.0

SPDX identifier: `LicenseRef-ModelPlan-Visuals-1.0`

Copyright (c) 2026 ModelPlan. All rights reserved.

## 1. What this covers

This license covers the "Official Visuals":

- every file under `desktop/official-visuals/`, except the historical MIT material described in section 7, and
- any other file marked `SPDX-License-Identifier: LicenseRef-ModelPlan-Visuals-1.0`.

The Official Visuals are the distinctive appearance of the official ModelPlan apps and website. They include:

- graphics, images and textures;
- 3D models, materials and shader code;
- animation and motion code;
- styles, and the layout and drawing code of the dock, the cockpit and the entrance animation;
- the brand marks used in them.

As expressed in these files, this covers:

- the ignition button and its charge, countdown and ignition animation;
- the dock of engine nozzles;
- the cockpit's instruments and controls, as drawn and animated;
- the entrance animation;
- the 3D launch field scene and its models;
- the website's launch-pad visuals, once they are added here.

This license does not claim ideas, methods of operation or metaphors as such. It covers their expression in these files.

ModelPlan claims these rights only to the extent they exist under applicable law.

## 2. What you may do

You may:

1. read and study the Official Visuals in this repository;
2. build and run the official ModelPlan app from an unmodified copy of this repository, for your own use;
3. make the temporary copies that 1 and 2 need;
4. show screenshots and short excerpts for review, reporting, teaching or documentation, as `TRADEMARKS.md` and the law allow.

## 3. What you may not do without written permission

You may not:

- copy, modify, adapt, translate, distribute, sublicense or sell the Official Visuals, a substantial part of them, or a work derived from them;
- include them in any other product, fork, build, theme, service or website;
- use them to make software that imitates the appearance of the official ModelPlan app;
- use them to train, fine-tune or prompt a model to reproduce them;
- remove or change this notice or the copyright notices.

## 4. Forks and community builds

A fork or redistributed build must use the community edition, which `node desktop/build.mjs` builds by default. That edition uses the MIT community appearance.

A fork or redistributed build must not:

- include the Official Visuals; or
- present itself as the official ModelPlan app (see `TRADEMARKS.md`).

## 5. Contributions

The ModelPlan maintainers change the Official Visuals. Outside changes to these files are accepted only under a separate written agreement that gives ModelPlan the rights it needs.

## 6. No other rights

- This license grants no trademark rights and no patent rights.
- All rights not expressly granted are reserved.
- Nothing here limits:
  - the MIT, CC BY or CC BY-SA licenses of other files in this repository;
  - grants already made for previously released material;
  - rights the law gives you regardless of any license.

## 7. Historical MIT and third-party material

Some files under `desktop/official-visuals/` were released earlier in this repository under the MIT License: the initial theme (`theme.css`), the logo (`logo.svg`) and the app and tray icons (`icons/`). The exact historical content of those files keeps its MIT grant; moving it here does not revoke that grant or make it exclusive. The MIT text is in `HISTORICAL-MIT.txt`, and `source-policy.json` (`reservedVisuals.historicalMit`) lists those files with their SHA-256 hashes. Only additions and changes made to them after that release are Official Visuals.

Third-party fonts, libraries and other material keep their own licenses and notices.

## 8. Termination

Your rights under this license end automatically if you breach it. Copies you made must then be deleted.

## 9. No warranty

The Official Visuals are provided "as is", without warranty of any kind. To the extent the law allows, ModelPlan is not liable for any damages arising from them.

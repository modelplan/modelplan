# Licensing map

This repository contains different kinds of material. A single badge does not relicense everything.

- **Software:** MIT (`LICENSE`, and `codex/LICENSE`), including the public publication reader, CLI, plugin/desktop functional code and neutral community UI. Dependencies retain their own notices. The CLI's native quota readers port parts of CodexBar's providers (MIT, Copyright (c) 2026 Peter Steinberger; `LICENSES/CodexBar-MIT.txt`), named in each ported file with its upstream revision. The Kiro reader follows Pulse's ACP route (Apache-2.0, Copyright (c) 2026 qunqin24; `LICENSES/Pulse-Apache-2.0.txt`).
- **Open data:** per-file SPDX licenses in `data/manifest.json`; see `data/LICENSE`. ModelPlan's new original-data publication uses CC BY-SA 4.0; previous CC BY 4.0 grants remain valid and third-party material keeps its terms. The transition does not create copyright over unprotectable facts.
- **Historical public visuals:** versions already released under MIT retain that grant. Their use does not imply official affiliation.
- **Official visuals:** the official desktop appearance (graphics, materials, 3D, animation and drawing code, brand marks) lives in `desktop/official-visuals/` under the [ModelPlan Official Visuals License 1.0](desktop/official-visuals/LICENSE.md) (`LicenseRef-ModelPlan-Visuals-1.0`, text also in `LICENSES/`); it is not MIT. You may read it and build the official app from an unmodified checkout for your own use; forks and redistributed builds use the community edition. Files there whose exact content was released earlier under MIT (the initial theme, logo and icons, listed in `source-policy.json`) keep that grant. Official binaries are mixed-license; their visual license does not replace the software licenses.
- **Brand identity:** see `TRADEMARKS.md`. Brand rules do not withdraw code/asset copyright grants or restrict truthful lawful references.

Changing the current release's license policy does not recall previously distributed copies. Preserve the relevant historical and contributor notices. Add a scoped license before publishing a new material type; consult the owner when the scope is unclear.

Production scoring/recommendation source and full calibration materials are reserved in the private implementation. Public methodology documentation does not grant a license to that private source. Historical grants for already distributed copies remain unaffected.

API access is separate from the limited open-data package; see [API data policy](docs/api-data-policy.md). Do not infer a blanket data license from a public endpoint or the software MIT license.

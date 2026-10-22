<!-- SPDX-License-Identifier: LicenseRef-ModelPlan-Visuals-1.0 -->
# Official visuals

The appearance of the official Model Plan desktop app: theme, logo, branding and icons. Later also the dock and cockpit view and drawing modules and the art.

**Not MIT.** These files are under the [Model Plan Official Visuals License 1.0](LICENSE.md) (`LicenseRef-ModelPlan-Visuals-1.0`): you may read them and build the official app from an unmodified checkout for your own use, but not copy them into another product, fork or build. The rest of the repository keeps its own licenses.

Historical MIT material keeps its grant. `theme.css` (the historical `codex/ui/kit/tokens.css`, `codex/ui/kit/components.css` and desktop `style.css`, joined under a one-line notice), `logo.svg` and `icons/` were released here under MIT before they moved into this folder; their exact historical content stays MIT ([`HISTORICAL-MIT.txt`](HISTORICAL-MIT.txt)). `source-policy.json` lists them with their hashes under `reservedVisuals.historicalMit`. A later change to one of them is reserved: remove the file from that list and give it the SPDX header (or, for a binary, list it under `reservedVisuals.binaries`); the historical portion stays MIT.

## Build

```sh
cd desktop
npm run build              # community edition (the default; never reads this folder)
npm run build:official     # official edition from this folder
```

The official build copies `LICENSE.md` into the app as `VISUAL-LICENSE.md`. Forks and redistributed builds use the community edition.

## Rules

- Text files carry `SPDX-License-Identifier: LicenseRef-ModelPlan-Visuals-1.0` (JSON files as a key). Binaries are listed with their SHA-256 in `source-policy.json` (`reservedVisuals.binaries`).
- New official visuals go here, nowhere else. `node scripts/check-source-policy.mjs` enforces it.
- Changes come from the Model Plan maintainers (see section 5 of the license).

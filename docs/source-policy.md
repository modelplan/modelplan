# Public source and distribution policy

Owner-authorized source split, tracked in the private implementation issue #506. This public document contains only the public development contract.

| Material                                                                                                           | Canonical location                                  | Terms / rule                                                                                                                                                     |
| ------------------------------------------------------------------------------------------------------------------ | --------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| CLI, plugins, Skill, generic desktop functionality                                                                 | This repository                                     | MIT software; public standard hosted CI                                                                                                                          |
| Publication reader | `reader/` | MIT; validates/caches published results, no scoring or calibration engine |
| Formula explanations, source weights and result evidence | Methodology docs and published result metadata | Public disclosure; not a license to private production implementation |
| Production scoring/recommendation implementation, full calibration and model entry/exit | Private production repository | Reserved source; no public engine/parameter snapshot export |
| Community appearance                                                                                               | `desktop/app/style.css`                             | MIT; independently buildable, neutral default                                                                                                                    |
| Official brand and distinctive visuals, 3D/material/animation and drawing source | `desktop/official-visuals/` | Model Plan Official Visuals License 1.0 (`LicenseRef-ModelPlan-Visuals-1.0`), not MIT; read and build for own use, no copying into other products or forks; historical MIT files listed in `source-policy.json` keep their grant; only the `--official` build reads it |
| Reviewed open data                                                                                                 | `data/`, one-way mirror of the reviewed publication | Per-file SPDX identifiers; CC BY-SA 4.0 for the new Model Plan original-data publication, historical CC BY 4.0 grants preserved, third-party exceptions retained |
| Raw upstream observations, source caches, collection/review/publishing/deployment implementation and runtime state | Private producer/operations repository              | Outside this public-source contract                                                                                                                              |

## One source per module

Develop public software here, release/pin it, and let private consumers verify its commit and file hashes. A vendored release artifact in a consumer is not a second editable source: change the public source, run its tests, then refresh the pin. `codex/lib/client-reader.mjs` is a compatibility entry to `@modelplan/public-reader`; do not replace it with a privately regenerated verifier. The initial public verifier retains the same already-public implementation bytes. Modular verifier-source cleanup is future work, not an excuse to publish private builders.

Method disclosure remains public: formulas, source proportions, result evidence and validation examples. The production algorithm implementation, complete calibration records and automated entry/exit rules remain private. Public clients consume published verdicts rather than recomputing ranks. No production score engine or complete policy snapshot may be exported as a convenience module. Preserve the distinction between explaining a result and licensing its implementation.

## Official versus community builds

`node desktop/build.mjs` builds the complete community UI using system fonts, neutral styling and a generic mark, and never reads `desktop/official-visuals/`. No private checkout or credentials are required. `node desktop/build.mjs --official` (`npm run build:official`) assembles the official edition from `desktop/official-visuals/` in the checkout and copies its license into the app as `VISUAL-LICENSE.md`. Public CI may build the official edition to test it. `--visual-package <dir>` remains for an external package; it must lie outside the checkout and public CI does not supply one. Forks and redistributed builds must ship the community edition (see the visual license and `TRADEMARKS.md`). Official mixed-license distributions include the visual license and the open/third-party notices; signing, once it exists, applies only to the official build, with its secrets in a protected environment.

Already-public historical styling/logos remain under their actual historical grants; moving a copy does not revoke them. `source-policy.json` freezes previously public brand/kit assets to their reviewed hashes, so new original official visuals are routed to `desktop/official-visuals/` under the reserved license rather than accidentally licensed through a root MIT notice. Its `reservedVisuals` entry names that prefix and license, lists the exact historical MIT files kept there (initial theme, logo, icons) and the hashes of reserved binaries. Every other file there carries `SPDX-License-Identifier: LicenseRef-ModelPlan-Visuals-1.0`; none carries an MIT header. This fence does not claim ownership of general UI ideas or prohibit legal reuse of the historical MIT material.

## Data and licenses

Treat `data/manifest.json` per-file licenses as authoritative. A data license applies only to rights the publisher can grant; facts in the public domain, upstream figures and separate code/brand rights do not become exclusively owned or relicensed by an export. Preserve attribution, source, version, modification notices and third-party carve-outs. CC BY-SA does not require an unrelated consuming application to open-source its entire software, and does not prohibit commercial use.

The public data directory remains an output mirror, not a competing editing source. Correct upstream evidence through the existing data-issue/review process. A new file in a private collection is private until its export classification and rights are explicitly reviewed.

## Required gate

Run `node scripts/check-source-policy.mjs`. It checks the public-reader integrity/license manifest, the private-path exclusions, frozen legacy visual assets, the reserved official visuals (one prefix, `LICENSE.md`, SPDX headers or listed hashes, no reads from the community build), agent instruction entry points and standard hosted runner policy. Update a manifest only after auditing the actual change; do not turn off the gate to ship. A broken rule is a review item, not permission to move private content (scoring, calibration, operations) into a convenient public folder.

## API access is not the open-data license

See [API data policy](api-data-policy.md). Preserve anonymous ordinary client/Agent reads while separating API terms from the limited, explicit open-data package. Do not label all API results CC BY-SA or MIT. Respect historical and upstream grants; new service terms cannot remove them. Full production/calibration records must not reappear in future exports.

# Public source and distribution policy

Owner-authorized source split, tracked in the private implementation issue #506. This public document contains only the public development contract.

| Material                                                                                                           | Canonical location                                  | Terms / rule                                                                                                                                                     |
| ------------------------------------------------------------------------------------------------------------------ | --------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| CLI, plugins, Skill, generic desktop functionality                                                                 | This repository                                     | MIT software; public standard hosted CI                                                                                                                          |
| Supplied-input metrics/effort/frontier and verifier                                                                | `core/`                                             | MIT; explicit input/protocol/parameter requirements; hash manifest; offline/synthetic tests                                                                      |
| Community appearance                                                                                               | `desktop/app/style.css`                             | MIT; independently buildable, neutral default                                                                                                                    |
| Official brand and new distinctive visuals, 3D/material/animation source                                           | Private official visual module                      | Reserved unless a specific file says otherwise; never silently included in public source/artifacts                                                               |
| Reviewed open data                                                                                                 | `data/`, one-way mirror of the reviewed publication | Per-file SPDX identifiers; CC BY-SA 4.0 for the new Model Plan original-data publication, historical CC BY 4.0 grants preserved, third-party exceptions retained |
| Raw upstream observations, source caches, collection/review/publishing/deployment implementation and runtime state | Private producer/operations repository              | Outside this public-source contract                                                                                                                              |

## One source per module

Develop public software here, release/pin it, and let private consumers verify its commit and file hashes. A vendored release artifact in a consumer is not a second editable source: change the public source, run its tests, then refresh the pin. `codex/lib/client-reader.mjs` is a compatibility entry to `@modelplan/core/public-reader`; do not replace it with a privately regenerated verifier. The initial public verifier retains the same already-public implementation bytes. Modular verifier-source cleanup is future work, not an excuse to publish private builders.

The core computes only supplied-input results. Acquiring records, reviewing identity/protocols, constructing production candidates and publishing snapshots stay separate. Record the limitations honestly: an auditor needs equivalent lawful inputs and parameters; public toy fixtures alone do not prove live scores. Runtime clients continue to consume published verdicts rather than re-fitting ranks.

## Official versus community builds

`node desktop/build.mjs` builds the complete community UI using system fonts, neutral styling and a generic mark. No private checkout or credentials are required. `--visual-package /private/package` is an explicit official assembly input outside the public checkout. Only private trusted CI may supply it. Official mixed-license distributions must include the reserved visual notice and open/third-party notices. Public CI and public build artifacts contain only community inputs.

Already-public historical styling/logos remain under their actual historical grants; moving a copy does not revoke them. `source-policy.json` freezes previously public brand/kit assets to their reviewed hashes, so future new original official visuals are routed to the private module rather than accidentally licensed through a root MIT notice. This fence does not claim ownership of general UI ideas or prohibit legal reuse of the historical MIT material.

## Data and licenses

Treat `data/manifest.json` per-file licenses as authoritative. A data license applies only to rights the publisher can grant; facts in the public domain, upstream figures and separate code/brand rights do not become exclusively owned or relicensed by an export. Preserve attribution, source, version, modification notices and third-party carve-outs. CC BY-SA does not require an unrelated consuming application to open-source its entire software, and does not prohibit commercial use.

The public data directory remains an output mirror, not a competing editing source. Correct upstream evidence through the existing data-issue/review process. A new file in a private collection is private until its export classification and rights are explicitly reviewed.

## Required gate

Run `node scripts/check-source-policy.mjs`. It checks the public-core integrity/license manifest, the private-path exclusions, frozen legacy visual assets, agent instruction entry points and standard hosted runner policy. Update a manifest only after auditing the actual change; do not turn off the gate to ship. A broken rule is a review item, not permission to move private content into a convenient public folder.

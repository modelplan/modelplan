# Model Plan public development

This repository is the canonical source for the public clients and publication reader. Write GitHub issues, PRs, comments and commits in English; discuss with the owner in their language.

## Source, data, visual and license changes

Before adding/exporting source, changing a dependency or license, editing visual assets, or changing a workflow, read [docs/source-policy.md](docs/source-policy.md). Run `node scripts/check-source-policy.mjs` before pushing. The root MIT license covers its declared software scope; per-file data and third-party notices govern their own material.

Public clients render published verdicts. Method explanations and source weights stay public. Production scoring/recommendation implementation, full calibration records and model entry/exit automation stay private. Do not export these, client-specific scorers, raw benchmark fixtures, collection/publishing machinery or official visual packages here.

## Implementation and verification

Keep the community build complete without private files, credentials or a sibling private checkout. Run the applicable checks documented in CONTRIBUTING.md, plus `npm ci --prefix reader && npm test --prefix reader` for reader changes. Preserve generated plugin runtime bundles and dependency locks. Use standard free hosted runners; public PR code never uses private publishing runners.

Read the task's current issue/comments before editing and report concrete checks. Preserve existing MIT/CC grants and contributor/third-party notices when changing future licensing. Put new official visual creations in the private visual package; do not infer permission to publish them because code in the same product is open.

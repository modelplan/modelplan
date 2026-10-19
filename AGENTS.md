# Model Plan public development

This repository is the canonical source for the public clients and supplied-input computation core. Write GitHub issues, PRs, comments and commits in English; discuss with the owner in their language.

## Source, data, visual and license changes

Before adding/exporting source, changing a dependency or license, editing visual assets, or changing a workflow, read [docs/source-policy.md](docs/source-policy.md). Run `node scripts/check-source-policy.mjs` before pushing. The root MIT license covers its declared software scope; per-file data and third-party notices govern their own material.

Public clients render published verdicts. The public core permits independent computation/auditing with supplied inputs; do not introduce client-specific scoring, raw benchmark fixtures, collection/publishing machinery or private official visual packages here.

## Implementation and verification

Keep the community build complete without private files, credentials or a sibling private checkout. Run the applicable checks documented in CONTRIBUTING.md, plus `npm ci --prefix core && npm test --prefix core` for core changes. Preserve generated plugin runtime bundles and dependency locks. Use standard free hosted runners; public PR code never uses private publishing runners.

Read the task's current issue/comments before editing and report concrete checks. Preserve existing MIT/CC grants and contributor/third-party notices when changing future licensing. Put new official visual creations in the private visual package; do not infer permission to publish them because code in the same product is open.

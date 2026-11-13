# ModelPlan public development

This repository is the canonical source for the public clients and publication reader. Write GitHub issues, PRs, comments and commits in English; discuss with the owner in their language.

## Before you start

Decided questions are not re-derived. Read the index in [docs/adr/README.md](docs/adr/README.md) and the ADRs that touch your task; if your plan contradicts one, name it and ask the owner before acting.

- Design and visual work takes maker colours from `desktop/cockpit/src/livery-table.ts` only ([ADR 0007](docs/adr/0007-maker-colours-one-table.md)); a test fails on hard-coded maker colours elsewhere.
- Reader, detection and metric work follows a reference app and names it in the PR's `Reference:` line ([ADR 0008](docs/adr/0008-reference-apps-for-readers.md)).

## Source, data, visual and license changes

Before adding/exporting source, changing a dependency or license, editing visual assets, or changing a workflow, read [docs/source-policy.md](docs/source-policy.md). Run `node scripts/check-source-policy.mjs` before pushing. The root MIT license covers its declared software scope; per-file data and third-party notices govern their own material.

Public clients render published verdicts. Method explanations and source weights stay public. Production scoring/recommendation implementation, full calibration records and model entry/exit automation stay private. Do not export these, client-specific scorers, raw benchmark fixtures or collection/review/publishing/deployment machinery here.

## Implementation and verification

Keep the community build complete without private files, credentials or a sibling private checkout. Run the applicable checks documented in CONTRIBUTING.md, plus `npm ci --prefix reader && npm test --prefix reader` for reader changes. Preserve generated plugin runtime bundles and dependency locks. Hosted runners are the default; owner-only Mac checks may use the pinned reusable workflow under [the Mac CI admission contract](docs/mac-ci.md). Public PR code never uses private publishing runners.

Read the task's current issue/comments before editing and report concrete checks. Preserve existing MIT/CC grants and contributor/third-party notices when changing future licensing. Official visuals live in `desktop/official-visuals/` under their reserved license (`LicenseRef-ModelPlan-Visuals-1.0`, not MIT); put new official visual creations there and nowhere else, with the SPDX header or a listed hash. Unreleased designs (studies and prototypes) stay out of this repository until the owner releases them. Scoring, calibration and operations stay private.

<!-- SPDX-License-Identifier: MIT -->
# Full-cockpit visual check (D489)

Owner decision D489 (2026-11-28): the full-cockpit visual check no longer compares against committed baseline
images. The four shared `cockpit-baselines/webkit-linux-arm64/full-*.png` files are gone; every visual PR used to
regenerate them, so parallel visual PRs conflicted and had to land one at a time.

## What CI does

The `visual` job of `U11 cockpit web` (`.github/workflows/u11-cockpit.yml`) runs whenever that workflow runs (cockpit,
cockpit tests, official visuals, fonts, app-cli schema, source policy) and in merge-queue groups that change those paths.

1. It checks out two trees on one ARM runner:
   - pull request: the subject is the PR merge ref and the base is its first parent, which is the main tip the merge
     ref was built on. The diff is this PR's change on current main only. A main-only change since the PR branched
     does not show up as a reverse change, which it would if the base were the plain merge base.
   - merge group: the group commit against `merge_group.base_sha`.
2. It renders the four scenes `full-{day,night}-{en,zh-CN}` (636x951 CSS px, reduced motion, fixed clock, the
   synthetic visual fixture) in both trees with the same Playwright and WebKit build. The base tree uses the subject's
   `node_modules`. The scene spec is `desktop/tests/cockpit/browser/visual-scenes.spec.mjs`; a base made before D489,
   which has no spec, renders with the subject's copy.
3. `desktop/tests/cockpit/visual-diff.mjs` diffs each pair the way the retired baselines were compared: Playwright's
   pixelmatch at threshold 0.2, anti-aliased pixels ignored, zero changed pixels allowed. Changed pixels within 6 px of
   each other form one box. For each box the job records how many of its pixels fall in each Visual-change area.
4. Output:
   - the job summary: a table per scene with boxes, pixel counts and areas, plus a preview of the gate's decision
     against the PR body the run saw;
   - the artifact `cockpit-visual-diff-<sha>`: `<scene>.base.png`, `<scene>.head.png`, `<scene>.diff.png` (the head
     greyed, changed pixels red, each box outlined in magenta) and `report.json`;
   - five notice annotations (one `D489 cockpit visual` meta record, one `D489 cockpit visual scene` record per
     scene), each under GitHub's 4096-character limit. When a scene has too many boxes, the smallest fold into one
     box. Their per-area counts stay exact, so the decision does not change.

Once main's merge gate judges these reports, the job fails only when a render or the diff itself breaks, and
`modelplan-gates` decides whether the change is allowed.

**Rollout guard (strict mode).** The job reads main's `scripts/merge-gates/rules.mjs` through the contents API. Until
that file carries the exact line `export const VISUAL_DIFF_MARKER = "D489-v1";`, or when it cannot be read, the job is
strict: any changed pixel fails the job, as the retired baselines did. This closes the mixed-revision gap: a merge group
with this change and an undeclared visual change, judged by a main that still runs the old evaluator (which ignores the
report), fails on the job itself.

## The rule (modelplan-gates)

`scripts/merge-gates/visual.mjs`, called from `rules.mjs`, reads the annotations of the newest green `U11 cockpit web`
run for the head:

- Every changed pixel must lie inside the union of the areas declared on a `Visual-change:` line of the PR body. The
  line takes area names or aliases separated by commas or spaces, and `none` declares nothing. Each area is widened by
  the map's margin (2 px).
- With no `Visual-change:` line, nothing is declared, so any visual change fails.
- A failing gate names the scenes, the boxes (`x,y wxh (n px)`) and the areas each box falls in, or `no area`. The full
  list is in the visual job's summary.
- Override: a comment from the trusted account with a line `VISUAL-ACCEPT @ <full head sha>`, the same trust rule as
  the other gate markers, accepts every change at that head. A new push needs a new accept.
- Editing the PR body or posting the accept re-evaluates the gate without a new render (merge-gates probe and the
  `issue_comment` trigger).
- Merge group: the group commit's diff against the queue base may change only the union of its PRs' declared areas,
  unless one of them has a VISUAL-ACCEPT at its head.
- A PR run made before D489 landed has no visual job and is not judged at PR level; its merge group's run has the job.
- The report is bound to the comparison the gate computes now (R11 ruling, amended). There is no ancestry proof and no
  search over earlier merges.
  - PR: the report's head must be the PR head and the run must be that head's run; otherwise the gate is PENDING
    ("visual report is for another base — re-run U11"). A report for the PR head against a base other than the current
    merge ref's first parent is judged normally (declarations and accepts apply). The status notes "report base <8> ≠
    current base <8>; the merge queue re-checks against the exact base", so PRs do not stall after every main move.
  - Merge group: the base is `merge_group.base_sha`, read from the queue branch name
    `gh-readonly-queue/main/pr-<n>-<base sha>`, and the head is the group commit. Any other report FAILS the group.
  - A merge group never reuses a PR's visual report. queue-scope's `visual` output runs the visual job whenever the
    group changes a watched path against `merge_group.base_sha`, even when the group tree equals the PR head tree
    (a head can revert a change main made after the PR's own run). The gate checks the same diff itself. A group
    that changes a watched path without a visual report bound to its base fails: no run, no visual job, or a skipped
    one.

The job runs the PR's own code, like today's WebKit job. A PR that changes the diff script, the scene spec or the
workflow is reviewed as such.

## The area map

`desktop/tests/cockpit/visual-areas.json` maps area names (and aliases) to rects in the 636x951 scene: `canopy`
(window), `strip` (header), `band` (engine table), `session-lamps`, `session-cards`, `grip` (levers, faders), `mfd`
(big-screen), `tape`, `base` (bells, flames) and `hull` (frame, side walls, boosters, seams). Together the areas cover
the whole scene (a unit test checks this).

At diff time an area is its committed rects plus the live box of every match of its CSS selectors, measured in both
the base and the head render (`<scene>.areas.json`). Each match keeps its own box: the two side boosters are two hull
boxes, never one box spanning the deck. The capture spec fails if a measured box of one area reaches the centre of
another area's box. An area that moves or grows in the PR is still matched.

How the rects were derived: render the scenes with
`COCKPIT_VISUAL_OUT=<dir> npx playwright test --config ../tests/cockpit/playwright.config.mjs visual-scenes.spec.mjs`
from `desktop/cockpit`, then run `node desktop/tests/cockpit/visual-diff.mjs --print-areas <dir>` to print every distinct
measured box per area over the four scenes. Round those boxes out to the frame and to the seams between sections.
The `hull` rects are the frame and seams themselves.

To add or split an area, edit the map in its own small PR. Areas and aliases must be unique, rects must lie inside the
scene, and the areas must still cover the whole scene.

## Running it locally

From `desktop/cockpit`, one spec at a time and under `nice`:

```
COCKPIT_VISUAL_OUT=/tmp/v/head nice npx playwright test --config ../tests/cockpit/playwright.config.mjs visual-scenes.spec.mjs
```

Do the same in a worktree of the base, with its `desktop/cockpit/node_modules` linked to this checkout's, then:

```
node desktop/tests/cockpit/visual-diff.mjs --base /tmp/v/base --head /tmp/v/head --out /tmp/v/diff \
  --base-sha <base> --subject-sha <head> --body-file <PR body> [--main-rules-file <rules.mjs>]
```

Without `GITHUB_TOKEN` or `--main-rules-file` the local run is strict.

## Baselines kept

- `desktop/official-visuals/dock/RegressionBaselines/` (native Dock): these come from the native macOS renderer, which
  this Linux job cannot render base-vs-head. They change rarely (two commits since 2026-11-14 against 70 for the
  cockpit baselines), and the in-flight cockpit visual PRs do not touch them.
- The visual pack's approved art exports (`manifest.baselines`, ignition caps): these are art, not screenshots, and
  owner-approved per image.
- `cockpit-baselines/` stays the Playwright snapshot path for images that are not shared, such as the pending zoom
  baselines (`cockpit-zoom-baselines.pending.json`).

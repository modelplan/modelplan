<!-- SPDX-License-Identifier: MIT -->
# Hosted test build walkthrough

A low-cost look at a packaged owner test app. It launches the real app on a disposable hosted Mac,
walks a fixed script with real pointer input, and writes screenshots and a manifest that a person or a
vision model can compare with the prototype. It uses no model and no accounts. It is an early look, not
acceptance: real readers, real tools and device checks stay with the booked runs in [SKILL.md](../SKILL.md).

## Run it

```sh
gh workflow run test-build-walkthrough.yml -R modelplan/modelplan -f ref=<branch or commit> [-f run_id=<desktop run>]
```

The workflow looks for the artifact `native-app-test-<sha>` from a `desktop.yml` run with
`owner_test=true`. It checks that the run is `desktop.yml` at that commit and checks the inner zip against
`BUILD.txt`. With no live artifact (they last three days), it packages the ref with `--owner-test` itself.
The result is the artifact `walkthrough-<sha>`, kept seven days. The job fails when any step or check did
not pass; the artifact uploads either way.

## Why a separate hosted workflow

`trusted-mac.yml` is pinned and its runner group change needs the owner. A `macos-15` hosted runner is free
here and has what the walkthrough needs: a logged-in window server, Accessibility and screen capture already
granted to the job's shell, and a paravirtual Metal device. It needs no booking, guardian or release, because
nothing else shares the machine and it is discarded afterwards. For the same reason `walkthrough.py` refuses
to run unless `RUNNER_ENVIRONMENT` is `github-hosted`: it posts real input.

The default display is 1024x768, too short to open the porthole. The tool switches to the largest listed mode
first. Hosted modes are 1x only, so pictures are not Retina; compare layout, colour and state, not fine edges.
Do not click the wallpaper in a step: macOS then sweeps every window aside, the widget too.

## Synthetic readers

The packaged app has no scenario input, so the profile is seeded through the files the bundled CLI already
reads, in a fresh `HOME` (`CFFIXED_USER_HOME` too):

- `.config/modelplan/local.json`: declared plans, as the Dock real-server journeys write it.
- `Library/Caches/modelplan/observed/codex-account.json`: a Codex reading, bound to a real `consent grant`
  of `codex.runtime_usage` in that profile, as `DockQuotaWindowsRealServerTests` writes it.

`seed.json` holds the invented values. No credential exists in the profile, so no reader can reach a provider,
and the runner's Keychain is empty. Never put real readings here.

Before the walk the tool runs `modelplan sync`, because the app's normal entry does not fetch public data by
itself (see `publication-fresh-profile` below). That is the only network use, and it is public data.

## Files

| File | Purpose |
|---|---|
| `steps.json` | The fixed script: per step the actions, what to expect, what to compare with, and scripted checks |
| `seed.json` | Invented readings (synthetic leg) |
| `seed-dogfood.json` | Realistic invented readings, the step subset and the zh-Hans target names (dogfood legs) |
| `dogfood_seed.py` | Builds and writes the dogfood seed's files; tested in `tests/test_walkthrough.py` |
| `walkthrough.py` | Runner, checks, manifest. Pure parts are tested in `tests/test_walkthrough.py` |
| `walkthrough_input.swift` | Reads windows and accessibility for one PID, posts mouse and keys, measures a picture |

## Feature journeys

Steps named `j-*` walk the prototype's interaction journeys (tab scope, MFD pages, option keys, press a fader strip,
return from a comparison, ALERT lamp, Esc order). They carry few hard checks on purpose: each step's `tree.json` is
compared with the prototype journey by a separate feature checker (PASS / BROKEN / MISSING per feature). Targets accept
`label^:` (starts with) and `label~:` (contains), both matching the label or the title like `label:`; `clickFirst` clicks the first of several targets that is on screen.

## Output

`manifest.json` has `sourceSHA`, `artifact`, `host` (display, permissions and GPU; no user name) and:

- `steps[]`: `step`, `title`, `expected`, `prototype`, `status` (`pass`, `fail`, `not-run`, `skipped`), `reason`,
  `seconds` (how long the step took), `measures` (numbers a step records, below), `file` (full screen), `crop`
  (the named surface, when there is one), `window` (for steps whose `shot` names one: the app window holding that
  surface, captured alone with its alpha by `screencapture -o -l`, with its `bounds`; the visual comparison against
  the prototype reads it, so a clear window is transparent there and an opaque backing is not) and `tree`
  (accessibility state then). `skipped` means this host cannot
  walk the step, such as a display mode it does not offer; it does not fail the job.
- `checks[]`: `check`, `status`, `detail`. These need no judgement.

`pass` on a step means only that its actions ran and its scripted checks held. Whether the picture looks right
is the reviewer's call: compare `file`/`crop` with `expected` and `prototype`. A failed step is still
photographed. A step whose `requires` did not pass is `not-run`, never inferred. `SUMMARY.md` is the same table
for people and is also the job summary.

`differsFrom` and `matches` compare a crop with the crop of an earlier step by changed-pixel share, kept under
`measures`. An `await` with `timed` records `secondsTo:<target>`: compare `cockpit-reopen` with `cockpit-open` for
the second open (G3-42). `setDisplay` records the display it set and `fits` the frame it measured.

Step checks beyond presence: `cardNamed` (the open card carries the name of the ring `clickRing` clicked),
`collapsed` (the remembered window is gone or less than half its area), `allOnScreen` (every match lies on the
screen, for the help map), `fits` (inside the visible area between the menu bar and the Dock, for the cockpit at
1440x900 and 1470x956; hosted modes are 1x and list neither, so 1440x900 is walked at 1600x900, the same height, and 1470x956 is skipped). `noGaps` scans the step's `window` capture (so the step must name one) for a see-through
hairline inside the silhouette: the first fully opaque row down to the last row that is 90 % opaque must be opaque across
at least 80 % of the central 60 % width (`silhouette_gaps.py`; the browser spec `shutter-closed-no-gap` applies the same rule). It reads
the window's alpha, so it works on the black hosted desktop. The `brightDesktop` action (best effort, `osascript`) also sets a
light desktop picture before the shutter step so the plain screenshot shows such a gap too.

`seed.json` has one declared ring at 0%, so the widget, the collapsed sliver, the card and the cockpit are all
photographed with an exhausted subscription. A hidden menu bar icon is not walked here: a hosted display has no
notch, so nothing can cover the icon. Each step may name its owner ledger `requirement`.

Scripted checks: `publication-sync`, `launch`, `reader-first-reading` (seconds to the first reading on the widget),
`alive-after-walk`, `widget-ax-frames`, `doctor-readers` (`modelplan doctor readers` before shutdown, kept as
`doctor-readers.json`), `reader-refresh-timing` (`--refresh`), `quit` (through the real menu item, no signal),
`restart-launch`, `restart-no-first-run`, `restart-widget-place` (edge, width and centre along the edge; not height), `restart-station-late` (info: height differs after relaunch, a station appeared late, G3-36 family), `restart-readings`, `restart-quit`,
`no-crash-report`.

Status `info` records a fact without passing or failing the job:

- `publication-fresh-profile`: a second profile that nothing syncs gets 120 seconds with the app running and
  the cockpit open; records whether public data arrived and what the cockpit shows (`fresh-profile-cockpit.png`).
- `restart-first-use-hint`: whether a new window appeared within 15 seconds of the relaunch.

`widget-ax-frames` carries the evidence for mirrored frames: the frame the app reports for the critical ring,
red pixels there and at its reflection, what the accessibility hit test answers at both, and from `ring-card-map`
which card opens at each painted and each reported position. When frames are mirrored the tool reflects them
before pointing, and stops doing so by itself once the app reports true frames.

## Dogfood seed (owner build 6, 2026-11-27)

The owner found about 30 problems in the first hour of build 6. The synthetic walk could not see them: tidy data
(`synthetic-ok`, short names, one bank), a black notch-less desktop, English only, and nobody comparing the pictures
with the approved designs. Every run of this workflow therefore has three legs in parallel (same wall time):

| Leg | Seed | Language | Steps | Artifact |
|---|---|---|---|---|
| `synthetic` | `seed.json` | en | every step without `profiles` | `walkthrough-<sha>` |
| `dogfood-zh` | `seed-dogfood.json` | zh-Hans | `walk.only` of the seed | `walkthrough-dogfood-zh-<sha>` |
| `dogfood-en` | `seed-dogfood.json` | en | `walk.only` of the seed | `walkthrough-dogfood-en-<sha>` |

The dogfood legs are `continue-on-error`: their pictures are evidence for the coordinator's vision review (a step
they could not walk shows there as a gap), not a pass/fail of the run. The fourth job, `notch-geometry`, is below.

`seed-dogfood.json` holds, all invented and written through the files the bundled CLI reads:

- Codex Pro 100 (`plan: prolite`) with a five-hour window at 15 % (red), a weekly window at 59 % with fixed reset
  (amber run-out forecast), one banked reset expiring in 29 days (`credits`, identity observed) and 1,865 points
  (`usageCredits`).
- A GLM Max plan (`zhipu-global-max`, declared in `local.json`) with five-hour, weekly (22 %, red) and monthly windows
  and two reset chances expiring within 48 hours. Substitute: the real ZCode reading needs a live call to z.ai, so the
  ZCode reader itself is not exercised; the monthly window stands in for the MCP limit.
- Claude Code with an `apiKeyHelper` login (unsupported), a `kiro-cli` that answers with unparsable text (cannot parse),
  and Antigravity `not_supported_yet` (`observed/antigravity-v1.json`): three unreadable subscriptions.
- Six Codex sessions over five models plus a Codex Auto Review session (`codex-auto-review`), with long paths: the
  home directory itself, Codex scratch chats under `~/Documents/Codex/<date>/<slug>`, a `~/.codex/worktrees/<uuid>`
  worktree. Live ones are rewritten to end "now" by the `d-freshen` step (`freshenSessions`), because the live strip
  counts only sessions active in the last five minutes.
- A 30-day Codex history over four models and four project paths, imported before launch with
  `modelplan history --import --first-run --offline` (the first-run import path).
- Reset news: an announced reset credit (AIHot link) and a confirmed one, added to the synced public data after
  `modelplan sync` (`add_reset_events`: the client object, manifest and state are re-addressed exactly as the CLI
  verifies them; when the manifest's identity cannot be reproduced nothing is changed and the check
  `dogfood-reset-events` says why).
- The Resources plugin is on by default in the packaged app; nothing to seed.
- `walk.brightDesktop` sets the light desktop picture before the first step, so every shot shows seams and halos as
  the owner sees them. `walk.skipFreshProfile` skips the 120-second fresh-profile probe (the synthetic leg keeps it).

Times in seed files are `@now`, `@now-90m`, `@now+3d` (minutes, hours, days) or minutes from the walk's start. The
zh-Hans leg launches the app with `-AppleLanguages (zh-Hans)`. `walk.targets` replaces whole target strings per
language: the cockpit labels in zh-Hans (checked against the cockpit's own string tables by the tests) and the Codex
tab, whose realistic name is not `Codex`. Dogfood-only steps carry `"profiles": ["dogfood"]`: `d-card-second` (the
GLM card), `d-freshen`, `d-mfd-calendar` and `d-mfd-resources`. Zoom: `air-1440x900` and `air-1470x956` walk the
cockpit's Auto size; hosted Macs offer neither size, so they run at 1600x900 and 1280x960 (same height, so the same fit). The Auto size of a notched 1470x956 Air itself
(85 % capped by the height) is covered by `ShellLayoutTests` below.

### Two displays and the notch

Neither can be real on a hosted Mac. The `notch-geometry` job of this workflow runs the synthetic geometry tests at
the build's own commit beside the walk, and the coordinator's build gate requires it:

- `ShellLayoutTests` (Auto size and cap, the notched 13-inch Air at 956 points, the status item hidden behind the notch)
- `CockpitScreenSelectionTests` (the click's display wins, a second display, one size on every display, Auto and the cap across displays, remembered origins)
- `CockpitCatchZoneDisplayTests` (catch zone and Put back after a cross-display drop)
- `CockpitLaunchRackEntryTests` (a hidden status item opens under the notch's right edge, or right of the menu bar centre without a notch)
- `CockpitSnapGuideDisplayTests` (snap guides per display, when present at the commit)
- `CockpitGeometryTests` in `ModelPlanCockpitShell` (containment across display origins, sizes and preferences)

### What happens to the pictures

The coordinator downloads the run, builds a review pack (each dogfood shot beside the approved design of the same
surface, the decisions and a checklist: seams and transparency, clipped text or an ellipsis, overlaps, misalignment,
wrong order or emphasis, stale wording, decision conformance) and has one reviewer go through it. Findings become
owner-report rows that block the next owner build until they are fixed or deferred. That part lives with the
coordinator, not in this repository, because the approved designs are private.


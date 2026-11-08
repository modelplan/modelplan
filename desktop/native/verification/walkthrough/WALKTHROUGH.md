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
| `seed.json` | Invented readings |
| `walkthrough.py` | Runner, checks, manifest. Pure parts are tested in `tests/test_walkthrough.py` |
| `walkthrough_input.swift` | Reads windows and accessibility for one PID, posts mouse and keys, measures a picture |

## Output

`manifest.json` has `sourceSHA`, `artifact`, `host` (display, permissions and GPU; no user name) and:

- `steps[]`: `step`, `title`, `expected`, `prototype`, `status` (`pass`, `fail`, `not-run`, `skipped`), `reason`,
  `seconds` (how long the step took), `measures` (numbers a step records, below), `file` (full screen), `crop`
  (the named surface, when there is one) and `tree` (accessibility state then). `skipped` means this host cannot
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
1440x900 and 1470x956; hosted modes are 1x and list neither, so 1440x900 is walked at 1600x900, the same height, and 1470x956 is skipped).

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

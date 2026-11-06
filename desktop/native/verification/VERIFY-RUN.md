<!-- SPDX-License-Identifier: MIT -->
# Scripted verify run: preflight, step files and the output contract

Verification plan v2 (owner-approved 2026-11-05), sections 4 and 5. M0 owns the verification skill;
the coordinator (Claude) reviews changes. Everything in [SKILL.md](SKILL.md) still applies: booking,
guardian, release with the coordinator GO, `packaged_candidate.py`, one controller per booking, at most
1200 s per booked segment and `finish --cleaned` only on confirmed closure. `verify-run.py` only chains
those helpers; it does not replace them.

```sh
python3 desktop/native/verification/bin/verify-run.py \
  --batch MANIFEST.json --lane V1 --layout single --scenarios D-01,V-01,D-14 \
  --out EXCHANGE/batch-NNN/V1 --artifacts-dir ARTIFACTS --scratch-parent LOCAL_SCRATCH
```

`--out` is on the shared exchange disk and must be new or empty, and outside any git checkout.
`--scratch-parent` is local disk (leases use `flock`). `MODELPLAN_BOOKING_LEDGER` and
`MODELPLAN_VERIFICATION_HOST` are set as in SKILL.md. The run asks nothing. A missing precondition
makes that ID `NOT-RUN reason=...` and the run goes on with the next ID.

## Manifest

```json
{
  "schemaVersion": 1, "batch": "batch-001", "profile": "synthetic",
  "integrationSHA": "<40 hex>", "tree": "<40 hex>",
  "prs": [{"pr": 551, "head": "<40 hex>", "ids": ["D-01", "V-01"]}],
  "artifacts": {"release": {"name": "native-app-unverified-<integrationSHA>", "digest": "sha256:<64 hex>"}},
  "coordinatorGo": "https://github.com/OWNER/REPO/issues/N#issuecomment-ID",
  "approval": "https://github.com/OWNER/REPO/issues/N#issuecomment-ID"
}
```

- `artifacts` maps a flavour (`release`, `test`, `verify`) to the GitHub artifact name and its GitHub
  `digest`. Optional per entry: `job` (producing job, default `app-smoke` for `desktop.yml`),
  `bundleIdentifier`, `exactArm64: true` (after #498).
- Download each artifact unmodified to `ARTIFACTS/<name>.zip`:
  `gh api repos/modelplan/modelplan/actions/artifacts/<artifact id>/zip > ARTIFACTS/<name>.zip`.
  The GitHub digest covers that archive. Inside it, `BUILD.txt` (#551 format: `sourceSHA=`, `runID=`,
  `runAttempt=`, optional `flavour=`, then `<sha256>  ModelPlan-Community-native.zip`) covers the inner zip.
- One coordinator GO URL covers the whole batch; every MacCI segment's `release.py --coordinator-go`
  uses it. The lane still opens the comment once and confirms it is the coordinator's GO for this batch.
  An M1 batch (dev Mac) instead carries `approval`, the https URL of the coordinator's OK comment, and
  releases with `release.py --approval`: `release.py` refuses a coordinator GO on the dev Mac, so a
  mixed-up argument can never release there.
- `profile` is `synthetic` or `real` (below). Preflight records it in `preflight.json`.

## Preflight (`bin/preflight.py`, PF-01..PF-12)

Runs first and writes `preflight.json`: one PASS or FAIL per check, unknown counts as FAIL, and any
FAIL stops the run before booking (every ID becomes `NOT-RUN reason=preflight-PF-nn...`).

| Check | What it refuses |
|---|---|
| PF-01 | Any name but `native-app-(unverified\|test\|verify)-<sha>` for this flavour and SHA: the legacy Tauri `Model-Plan-Community-macOS-arm64-unsigned`, any `.dmg`, any other name |
| PF-02 | A run outside `modelplan/modelplan`, a workflow other than `desktop.yml`, `v1-test-build.yml` or `verify-batch.yml`, a run `head_sha` other than the expected SHA, a producing job that did not succeed, an expired artifact, an archive holding anything but `BUILD.txt` and the inner zip |
| PF-03 | sha256 of the archive differing from the manifest or GitHub digest; inner zip differing from `BUILD.txt` |
| PF-04 | `BUILD.txt` `sourceSHA` (or `flavour`) differing from the expected head; the bundle's own `Info.plist` `ModelPlanPublicSource` (the built checkout's `git rev-parse HEAD`) missing or differing from that label, e.g. a pull_request merge-commit build labelled with the PR head; a PR head that moved or is not an ancestor of the integration SHA |
| PF-05 | Not exactly one top-level `.app`; a symlink leaving it |
| PF-06 | `CFBundleExecutable` not `ModelPlanCommunity`, a non-Mach-O executable, no arm64 slice, another bundle ID |
| PF-07 | A missing SwiftPM resource bundle (cockpit bundle too for test/verify), not exactly one `zai-white.svg`, `Helpers/modelplan` not matching `Resources/modelplan.sha256` |
| PF-08 | `ModelPlanCockpitEntryEnabled` not false (release) or true (test), the VF marker `ModelPlanVerificationFlavour` outside the verify flavour, any Sparkle framework or feed key |
| PF-09 | `codesign --verify --deep --strict` failing (ad-hoc accepted; kind recorded) |
| PF-10 | An ID not at tier T3/T4 in `scenario-tiers.tsv`, or without a valid step file, both read from the control revision (`--control-ref`, default `origin/main`), or whose layout, flavour or profile does not match. Refused IDs are NOT-RUN; the rest continue |
| PF-11 | `MODELPLAN_VERIFICATION_HOST` not matching the lane (V1 = `macci`, M1 = `dev-mac`); display count, scales or arrangement not matching `layouts.json`; Dock position or auto-hide, Reduce Motion, appearance, VoiceOver or the menu-bar item owners (`menuExtras`: owner-name window counts, names only) away from the recorded baseline — no third-party or name-bearing menu extra may be present, so none can enter a captured menu bar |
| PF-12 | A ModelPlan process or a CI job already running, stale candidate scratch (synthetic), under 8 GiB free, another started GUI booking |

Checks that need macOS tools (ditto, codesign, the display probe) FAIL with `requires-macos` on any other
host. Tests inject a fake host; a real run never passes them by default.

## Step files (`scenarios/<ID>.json`)

```json
{
  "schemaVersion": 1, "id": "V-01", "spec": "spec-visuals", "summary": "...",
  "flavours": ["release", "test"], "profiles": ["synthetic", "real"], "layout": "any",
  "launch": "running", "estimatedSeconds": 60, "systemSettings": ["appearance"],
  "steps": [{"name": "light", "action": "capture-menubar", "width": 480, "height": 40}],
  "review": "What the coordinator judges from the images."
}
```

- `launch`: `fresh` needs the first look after a fresh launch, so it starts its own segment; `running`
  shares a segment. Segments are grouped by flavour and kept within 1200 s including 180 s overhead.
- `layout`: `single`, `abc` or `any`. `profiles`: which of `synthetic` and `real` may run it.
- `systemSettings`: every setting a step changes; the run restores each one after the ID and records it.
- Actions: `wait-window` (`timeoutSeconds`, optional `budgetSeconds`: an owned window must appear;
  later than the budget is REVIEW, none is FAIL), `expect-no-window` (`timeoutSeconds`),
  `capture-window` (owned-window PNG and AX tree through `tools/u14/macos_ax.swift`),
  `capture-menubar` (`width`, `height` declared for review only: the crop is the candidate's OWN
  status item, from accessibility on the candidate PID — the probe's `statusItem` bounds; without
  them the step is NOT-RUN, never a broad system-region crop; the AX position is already top-left
  global coordinates, used unchanged for `screencapture -R`, and a rectangle outside the main
  display's menu bar is refused),
  `set-appearance` (`value`), `status-menu` (`item`, `menuAction`), `relaunch`, `dwell` (`seconds`).
- Before every step the runner re-reads the authoritative supervisor state (stop file, lease
  identity, revocation or takeover, guardian heartbeat, deadline — the same verdict launch.py's
  own supervisor applies), and again after every blocking call (AX probe, bounds probe, dwell)
  immediately before the next capture or settings action and before the ID may complete: once it
  stops, the ID is NOT-RUN, a probe that was in flight is discarded, the segment aborts, and only
  bounded cleanup and the recorded baseline restoration follow. The boundary is explicit:
  authority is re-checked after the last blocking observation (including the final dialog query
  and baseline restoration) and before the ID's result and receipt are written; any STOP observed
  up to that point makes the ID NOT-RUN `supervisor-*` and the run exit 2.
- A failed baseline restoration is a machine assertion: the ID ends FAIL
  (`restore-failed-...`), the run exits non-zero and no later segment starts until the lane
  re-establishes and re-records the baseline.
- Not yet wired, so NOT-RUN with the reason: `status-menu` (needs the test-build arrival observer and
  `pointer_drive --status-menu-plan`; Hide/Show have no fixed action ID), `relaunch` (packaged_candidate
  removes the synthetic HOME after one launch), `set-appearance` unless the host has a recorded Automation
  grant for System Events (`MODELPLAN_VERIFICATION_APPEARANCE_SWITCH=granted`); without it the switch would
  raise a TCC prompt, which the run never clicks.

## Profiles and isolation

`synthetic` (default): a fresh synthetic HOME per segment. This statement goes verbatim into every README:

> Synthetic HOME and CFFIXED_USER_HOME under run scratch; no consent grant exists, so no personal reader
> starts; no Keychain, credential or owner profile is read; network to providers is not used. The run never
> clicks consent, Keychain, password, TCC or Gatekeeper dialogs (I-01/I-05/S-12/S-13 only in an
> owner-approved run). Any system dialog: record its title as text, do not image it, mark the scenario
> NOT-RUN and stop the segment. Any real account name, email or quota on screen: stop, delete that segment's
> images, report.

The run enforces it: any window of a system dialog process stops the run (ISOLATION FAIL), and an email
address or this host user's name in a captured AX tree deletes the images and stops the run.

`real` (owner decision 2026-11-05): the test Mac's own accounts on the M1 or V1 host only. ModelPlan's own
consent may be granted and its Keychain prompts accepted (grant them once while preparing the host; a
Keychain prompt during a run makes that ID NOT-RUN). Its README starts with a PRIVATE EVIDENCE notice and
carries the real-account statement instead: images and receipts may show real account data, stay on the
shared disk only and must never be attached to or quoted in public PRs. **Gap:** the shared launch helpers
(`admission.py`, `launch.py`, `packaged_candidate.py`) admit only `profile: synthetic`, so a real-profile
segment is NOT-RUN (`real-profile-launch-not-supported-by-shared-helpers`) until those helpers gain a
reviewed real-profile mode.

## Outputs

- `preflight.json`, `README.md` (candidate identity, layout, segments and closure, system settings before
  and after, isolation statement, deviations, results) and `results.txt`, one line per requested ID:
  `PASS|FAIL|REVIEW|NOT-RUN <ID> @ <integration sha> flavour=<f> layout=<l> evidence=<ID>/ reason=<...>`
- `<ID>/NN-<step>.png` and `<ID>/receipt.json` (steps, timings, probe outcomes, restores).
- PASS and FAIL come only from machine assertions. REVIEW means the criterion is visual and the coordinator
  decides; the coordinator then posts the `VERIFIED:` lines. Exit status: 0 complete, 1 preflight failed,
  2 stopped on the stop list (system dialog, account data, guardian stop or unconfirmed closure).

<!-- SPDX-License-Identifier: MIT -->
# U5 real-input Drive

This is an additional native-verification scenario, not a replacement Launch/guardian/Cleanup runner. Its subject is the ordinary app built from the U5 PR head with the reviewed native CLI **v0.5.48** pin and helper identity. The U11a host, a stand-alone pointer probe, direct handler calls and hitTest checks are not substitutes for this candidate.

## Prepare before launch

1. Wait for the native pin/identity change to merge; merge main normally into the U5 branch. Pin source, app executable, package, bundled helper and structural synthetic profile hashes. Verify the helper against the updated native pin. The old v0.5.46 pin cannot satisfy this scenario.
2. Use the existing `tools/u14/shape_home.py` structural builder with `fixtures/u5-synthetic-shape.json` and its `coexistence` / `corrupt-beta07` preference cases for synthetic legacy official/community Settings and independent Core data. The descriptor contains no account/tool inputs and denies every listed consent tool. Bind all app-support/cache/tmp/engine paths to that profile. Never copy an owner profile; no owner account, Keychain or credential access is allowed. If isolation cannot be established, do not launch.
3. Create a fresh independent run/epoch folder under the approved `modelplan/handoffs/20261030-u5/` batch, with README and file list. Keep evidence until owner-confirmed cleanup. Stop if the shared disk is absent or a write is refused; do not create an alternate exchange location.
4. Use the unchanged matching lease/release identity, fresh guardian heartbeat, absolute deadline <=1200 seconds and owner stop hook. That deadline includes launch, Doctor, actions, waits, restart and cleanup. Validate through shared Launch; a dry run is not a GUI result. Announce the actual start on the authoritative coordination task before launch.

## Doctor and input

Use `doctor.py observation.json --scenario native-dock --output doctor.json` with actual timestamped native observations. Native Dock requires running/disk/lease plus visible, on-screen frame and non-activating panel. Key/active/WebKit observations remain separate and are not blanket requirements. A key Dock contradicts a non-activating receipt. Cockpit uses `cockpit` (including a scoped positive WebKit PID); Settings uses `settings` (key + visible). Never fill observation flags from expectations. Any unmet Doctor requirement means not-run for that attempt; do not proceed with input.

Use the approved Computer Use or actual OS input capability against the owned candidate. Retain delivered-action receipts and the resulting native/visible state. Keep captures limited to the synthetic candidate; use bounded structured receipts when a screenshot could include unrelated content. Do not capture the desktop or real account windows. No repeated activation or background process discovery is permitted.

## Scenarios

- **Pointer entry:** move from outside into the actual wake region; correlate delivered movement, entry and dwell reveal with the mounted `PulsePanelPointerSurface`/entry/probe path. Reveal remains non-activating.
- **Sampler:** leave the expanded surface, observe sample/grace/collapse, then re-enter. Use the production timer and actual pointer; a fake point callback is L1 evidence only.
- **Display following:** use another physical display if available, check actual following and held-press/no-jump then release/retry. Preserve saved intent. A missing second display or input capability is unsupported; synthetic display geometry is not a physical pass.
- **Presence/login stubs:** use candidate-bound app/service stubs to exercise shared full-window presence, no activation on restoration, explicit login request and truthful requiresApproval. Never toggle real login items or Keychain. A stand-alone mock unit test is not candidate-bound L2 evidence; absent candidate hooks stay not-run.
- **Atomic migration:** retain synthetic legacy before-state hashes, observe candidate migration, compare the new settings/core and unchanged old files, restart the owned candidate, and verify restored placement/core plus no app-consent promotion. Missing joint entry integration stays explicit; source-only planner tests cannot establish this physical scenario.

The assertion/route IDs are in `u5-real-input-scenario.json`. For each attempted case, record the actual native observation, input method, delivered-input and observed-result confirmations, at least two scoped action/state evidence files, and every measured assertion. False measured assertions are fail; absent prerequisites/evidence are not-run. Use unsupported/timeout explicitly where appropriate.

## Cleanup and evidence

Quit the owned app through delivered input. Use the unchanged shared Cleanup with registered process start identities, verify closure, release this run's resources/lease and announce end + cleaned. Stop on owner takeover, stop-hook, stale guardian or deadline; never renew/retry automatically. Do not claim cleanup without closure receipts.

`bin/evidence-u5.py --receipts receipts.json --batch <approved-run-folder>` derives per-case outcomes and delegates manifest/hash generation to shared Evidence. It requires the source/app/package/profile/helper pins, native v0.5.48, matching lease/watchdog/stop, candidate start and owned cleanup. Missing/failed Doctor or direct handler/hitTest input cannot pass. Unit tests of the qualifier use mock receipts and are not a real-input run. Normal-entry/Core/service adapter integration and owner L3 remain distinct completion edges.

Test builds may enable `MODELPLAN_U5_REAL_INPUT`. The retained production Host then installs `U5RealInputObservation`, emitting actual owned-window/input/sample receipts and honoring the same lease/stop paths. A test-only entry callback is compiled out without this flag. The observer uses a neutral owned backdrop, no global input/process discovery, and requires the configured synthetic HOME to match Foundation's resolved HOME. Candidate-local commands may exercise only the explicitly stubbed presence/login and atomic backend cases; they are labelled `candidate-test-command` and never qualify as physical pointer input. The three pointer cases still require actual OS-delivered input. Neither a standalone unit test nor an unbound command can qualify.

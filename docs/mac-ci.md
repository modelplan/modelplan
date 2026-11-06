# Trusted Mac checks

Hosted runners remain the default. `MAC_CI_RUNNER_V2` now has a split mode: the
value `split` runs a fixed, balanced task set (below) on the dedicated ordinary
(non-GUI) Mac runners while every other Mac job stays on GitHub-hosted runners,
so both pools work at the same time and no job runs twice. The value
`self-hosted` keeps only the original four tasks (`native`, `native-headless`,
`transport`, `sequences`) on the dedicated runners — it deliberately does NOT
enable the newer tasks. `hosted`, an unset or any other value keeps everything
hosted: that is the fallback when the dedicated runner is offline. An external
fork, another actor or rerun actor, a draft PR, an unsupported event, or a
switch value that does not name a task's pool uses hosted runners. Commit author
text is not an identity check. The allowlisted account is `guanbear` (GitHub
user ID `11829005`).

## Admission boundary

Callers use the fully qualified `trusted-mac.yml` reference at an immutable
commit. Local `./.github/workflows/...` references are not equivalent: on a PR
they load the PR's definition. The runner group must allow only jobs defined in
that exact reusable workflow commit, for this repository. Do not enable all
workflows or wildcard PR refs to make a queue move. Updating the definition
requires reviewing a new pin and updating the group restriction together.

The reusable workflow accepts a fixed task selector and OS selector, not shell
commands, checkout paths, credentials, environment overrides or arbitrary refs.
Checkout uses the caller's GitHub-provided subject SHA with persisted Git
credentials disabled. Signing and publication stay hosted; the ad-hoc neutral
packaging lanes (`u10-candidate`, `distribution`) joined the reusable workflow
on 2026-11-06 because they carry no signing secrets and need no GUI. macOS 14
is not tested in CI and not guaranteed (2026-11-02).

## The split task set (2026-11-06)

Under `MAC_CI_RUNNER_V2=split` the dedicated ordinary runners take:
`native` (GUI label), `native-headless`, `transport`, `sequences`,
`u11-native` (U11 native cockpit), `dock-host-port` (Dock host port seam),
`u14-drive` (engine Drive L1, macOS leg), `u10-candidate` (U10 candidate
interface) and `distribution` (macOS distribution). The split was balanced on
two days of measured medians so neither pool becomes the new bottleneck, and
hosted minutes drop by the moved jobs' share. Callers route through
`trusted-mac.yml`; the `U14 macOS skeleton` job cannot join because its
evidence capture needs a window server (`tools/u14/macos_runner.py` writes
`window.png`/`ax-tree.json`), and it stays hosted. One check name changes:
the Dock host port seam's job is now `contracts (dock host port)` (the U10
workflow already owns a `contracts` check name); every other moved job keeps
its legacy check name.

The runner's pre-job gate separately checks authenticated owner identity,
repository, event, PR head repository and PR author. `github.workflow_ref` is
the **caller** identity when a reusable workflow is used. It must not be
misrepresented as proof of the reusable definition; the runner group's
server-side workflow restriction supplies that boundary.

## Graphical checks

Native checks create actual AppKit windows. They stay hosted until
`MAC_CI_GUI=enabled` is set after a graphical-session probe passes. Only one
runner in a shared desktop session receives the `modelplan-mac-gui` capability
label, so GUI jobs serialize without cancelling pending checks. Other jobs can
use both ordinary `modelplan-mac` instances. This label is a routing capability,
not permission to approve system prompts or access real user data.

The native suite runs as two parallel legs. `task: native` keeps the GUI
label and runs everything that may need a window server. `task: native-headless`
uses the ordinary label and runs the app-integration XCTest classes listed in
`desktop/native/tools/ci/native-test-partition.json`, plus the pure contract,
logic and packaging-binary checks. The list is opt-in: a new class runs on the
GUI leg until it is added. `native_test_partition.py check` (Linux and both Mac
legs) refuses a listed class whose source uses window-server APIs or builds a
Dock/entry factory without `createsNativePanels: false`. Each leg derives its
share from the same `swift test list`, runs it with one shared selector
(`--filter` on one leg, `--skip` on the other) and then verifies from the XCTest
log that it executed exactly its share. Only skips named in `allowedSkips`, each
tied to one leg, are accepted, so a test cannot pass by skipping on the wrong leg.

The desktop workflow's `mac_ci_probe=true` dispatch runs only a probe. Its
`mac_ci_probe_mode` selects `cli` or `gui`. The owner can use this narrow dispatch
to validate the runner without changing the general switch or launching all
product checks. Acceptance must verify the assigned runner identity and the
probe result; an online status alone is insufficient.

## Migration

Keep the legacy `MAC_CI_RUNNER` unset or `hosted`. The versioned switch prevents
old PR workflow definitions from requesting a group that no longer admits their
direct jobs. Old queued runs retain their original workflow and resolved runner
selector: update the PR branch workflow before triggering a new run; simply
rerunning the old run is not a migration.

## Scratch and recovery

After a synthetic evidence upload produces an artifact ID, the job writes a
receipt in its runner temporary directory. The completion hook checks the run
ID, attempt, and job before pruning generated compiler products. A missing or
mismatched receipt skips pruning. The workflows remove their own scratch only
when the upload produced an artifact. Cleanup preserves dependency checkouts.
Hosted fallback is selected
before a job is queued: changing a variable does not retarget an existing queued
job, and offline self-hosted jobs do not automatically migrate to hosted runners.
Recover only the affected jobs after confirming ownership and delivery state.

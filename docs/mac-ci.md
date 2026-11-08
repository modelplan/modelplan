# Trusted Mac checks

Hosted runners remain the default. The `MAC_CI_RUNNER_V2=self-hosted` repository
variable opts the owner's same-repository checks into the dedicated Mac group.
An external fork, another actor or rerun actor, a draft PR, an unsupported event,
or an unset/other switch value uses hosted runners. Commit author text is not an
identity check. The allowlisted account is `guanbear` (GitHub user ID `11829005`).

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
credentials disabled. Signing, publication and packaging stay hosted; the
macOS 14 is not tested in CI and not guaranteed (2026-11-02).

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

Since D62 (2026-11-08) every non-GUI task (`native-headless`, `transport`, `sequences`, `probe`, `u11-native`)
asks for `modelplan-mac-nongui` instead of the plain `modelplan-mac`, and refuses to start on a runner whose
name contains `gui`. The GUI Mac also carries `modelplan-mac`, so the plain label used to send headless jobs
there while GUI jobs waited. Only the non-GUI Macs carry `modelplan-mac-nongui`.

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

## GUI leg on hosted Macs

Hosted macOS runners have a real WindowServer session. `MAC_CI_GUI_POOL=hosted` (or a `desktop` dispatch with
`gui_pool=hosted`) splits the GUI leg in two (owner D62, 2026-11-08): `native-hosted-gui` runs the
`hosted-gui` leg on hosted `macos-15`, and `native-owner-gui` runs only the `ownerGui` classes of
`native-test-partition.json` on the owner's GUI Mac. `native_test_partition.py` derives both from the same
listed suite and verifies each, so together they are exactly the old GUI leg. A class goes on `ownerGui` when it
cannot finish on a hosted Mac, for example because it waits for a Keychain or activation prompt that nobody
answers there. Unset, the whole GUI leg runs on the GUI Mac as before.

## Ordinary owner Macs for headless workflows

`MAC_CI_NONGUI=enabled` (owner D62, 2026-11-08) moves the `u11-native` task of `trusted-mac.yml` to the
owner's ordinary Macs. It routes to the label `modelplan-mac-nongui`, which only the non-GUI runners carry,
so the GUI Mac is never selected; the job also refuses to start on a runner whose name contains `gui`.
The owner gate is the same as above. Unset or any other value, or an outside actor, uses hosted `macos-15`,
the oldest supported macOS. `U11 native cockpit` calls the task at a pinned commit, so enabling it needs
that commit admitted by the runner group as well.

On a reused Mac the job keeps everything it writes in its runner temp: `HOME`, `CFFIXED_USER_HOME`,
`TMPDIR`, the XDG, Codex, Claude, ModelPlan, Go and npm caches are redirected there, the checkout keeps no
credentials, and a final step removes `.tmp` and `node_modules` whatever the result. The runner empties its
temp directory around each job, and the next checkout cleans the workspace.

The packaged-app walkthrough (`test-build-walkthrough.yml`) stays hosted: it needs a logged-in window
server, Accessibility and screen capture, and posts real pointer input, which an ordinary owner Mac either
lacks or shares with the GUI Mac's session.

## Test build walkthrough

`test-build-walkthrough.yml` is a separate manual workflow on a hosted `macos-15`: it never uses the
pinned reusable workflow or the dedicated group. It walks a packaged owner test app with synthetic
data and uploads screenshots and a manifest. See
[WALKTHROUGH.md](../desktop/native/verification/walkthrough/WALKTHROUGH.md).

## Merge queue

A PR does not have to merge `main` before it lands. The queue builds "PR + latest
`main`" and the `modelplan-gates` status on that commit requires `ci` and `desktop`
to pass there (`QUEUE_WORKFLOWS` in `scripts/merge-gates/rules.mjs`). `desktop`'s
`queue-scope` job applies the workflow's pull-request path list, because
`merge_group` has no paths filter, and skips the jobs when the group changes none
of those paths or its tree equals the PR head. Otherwise `app`, `shell`,
`native-partition`, `app-smoke` and `native-headless` run on the group commit. The
pinned `trusted-mac.yml` has no `merge_group` route to the self-hosted group, so
`native-headless` falls through to a hosted Mac there. Routing it to the dedicated
group needs a new pin and a runner-group update together, as above. The GUI leg and
the path-scoped `u*` workflows do not run in the queue.

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

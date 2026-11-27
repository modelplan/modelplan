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

## Runner acceptance smoke (owner exception, D353)

A new or standby Mac is validated with `runner-smoke.yml` before it gets a production label. The runner carries only
a temporary `smoke-arm64-N` label, which no other workflow may name (`scripts/workflow-policy.mjs`). This is an
owner-approved exception to the rule above: the `modelplan-mac` runner group also admits
`modelplan/modelplan/.github/workflows/runner-smoke.yml@refs/heads/main` (D330), because a direct dispatch is pinned to a
branch, not a commit. The workflow starts only from `workflow_dispatch` by the owner account, from main's definition, builds
only `main` or a `refs/tags/` tag, and holds a read-only token with no secrets. After the owner adds the group entry, check
that a branch copy, another workflow and a non-owner dispatch or rerun get no smoke runner.

Register the runner under the opaque name `smoke-arm64-N` (the same N as its label), never the default host name: GitHub
records the registered name in public job metadata before any step runs. The workflow's first step refuses any other name
without printing it, so the timing table can name the runner safely. The policy check also rejects any other workflow whose
`runs-on` is an expression that is not a literal `strategy.matrix` key (an input-driven or `fromJSON` matrix fails closed).

## Graphical checks

Native checks create actual AppKit windows. They stay hosted until
`MAC_CI_GUI=enabled` is set after a graphical-session probe passes. Only one
runner in a shared desktop session receives the `modelplan-mac-gui` capability
label, so GUI jobs serialize without cancelling pending checks. Other jobs can
use both ordinary `modelplan-mac` instances. This label is a routing capability,
not permission to approve system prompts or access real user data.

Since D62 (2026-11-08) every non-GUI task (`transport`, `sequences`, `probe`, `u11-native`)
asks for `modelplan-mac-nongui` instead of the plain `modelplan-mac`, and refuses to start on a runner whose
name contains `gui`. The GUI Mac also carries `modelplan-mac`, so the plain label used to send headless jobs
there while GUI jobs waited. Only the non-GUI Macs carry `modelplan-mac-nongui`.

D198 (2026-11-12): `native-headless` is the exception. It runs on a GitHub-hosted Mac (`macos-latest`, from
the caller's `os` input) for pull_request, push, workflow_dispatch and merge_group alike, because the
self-hosted non-GUI pool was too slow to carry the PR-time leg. The shared `runs-on` expression excludes
the task from the owner-Mac branch (`inputs.task != 'native-headless'`). The D94 "Refuse the GUI Mac" step
stays; it is harmless on a hosted runner. Only the GUI legs (`native`, `native-owner-gui`, `gui-probe`) use
the GUI Mac.

D246 (2026-11-13, REVERTED 2026-11-21: the merge queue is hosted again, because the single non-GUI Mac queued it ~50 min; a merge-queue-only guard step requires Xcode 26.6 (17F113)): in the merge queue only, `native-headless` went back to the non-GUI Macs
(`modelplan-mac-nongui`, under the same owner gate and `MAC_CI_RUNNER_V2 == 'self-hosted'`), because hosted
macOS allows five concurrent jobs and queue groups waited behind PR runs while those Macs sat idle. The
expression admits it with `(inputs.task != 'native-headless' || github.event_name == 'merge_group')` and the
queue clause (`refs/heads/gh-readonly-queue/main/` only). A merge-queue group contains only PRs that were
enqueued, so no unreviewed head reaches those Macs. pull_request, push and dispatch runs stay hosted (D198).
When `MAC_CI_RUNNER_V2` is not `self-hosted` or the owner gate does not match, the queue leg falls back to
hosted `macos-latest`; an offline non-GUI pool makes it wait, not fall back. `app-smoke` stays on hosted
`macos-latest` in every event: it launches the packaged AppKit app, and the non-GUI Macs run their runner in
the `System` launchd domain with no window-server session.

### Lending gui-2 to non-GUI jobs (D94)

Owner decision D94 (2026-11-09) lets the second GUI runner help with non-GUI work when no GUI work needs it.
The "Refuse the GUI Mac" step that opens every non-GUI job still refuses a runner whose name contains `gui`,
with one exception: the runner named exactly `modelplan-mac-gui-2` is accepted while the repository variable
`MAC_GUI_LEND` is `enabled`. `modelplan-mac-arm64-1` is the V1 verification host and is refused by name
whatever the switch says; it is never lent. `scripts/workflow-policy.mjs` (`guiGuardProblems`) compares the
step line for line, so a wider pattern, a default-on switch or a missing V1 refusal fails source policy.

The coordinator's lending script runs every 5 minutes. When no GUI job is queued or running and at least
three non-GUI jobs are queued, it sets `MAC_GUI_LEND=enabled` and adds the `modelplan-mac-nongui` label to
`modelplan-mac-gui-2` (runner id 263). As soon as a GUI job is queued it removes the label and sets
`MAC_GUI_LEND=disabled`; a non-GUI job already running there finishes (at most 30 minutes, the longest non-GUI job timeout). It never touches
`modelplan-mac-arm64-1` (runner id 76). Changing labels needs an org runner-admin token, which the
coordinator holds; GitHub Actions never sees it.

The guard lives in `trusted-mac.yml`, so the change needs new caller pins. Before the pin PR merges, the
owner adds the new ref (`modelplan/modelplan/.github/workflows/trusted-mac.yml@<commit>`) under the
organization's Settings, Actions, Runner groups, `modelplan-mac`, allowed workflows. Keep the old refs
until the PR has merged, and merge it with a merge commit so the pinned commit stays reachable.

The native suite runs as two parallel legs. `task: native` keeps the GUI
label and runs everything that may need a window server. `task: native-headless`
runs on a hosted Mac (D198; also in the merge queue, D246 reverted) and runs the app-integration XCTest classes listed in
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

`MAC_CI_GUI_POOL=auto` (owner D480, 2026-11-27) chooses per run. The `gui-pool` job in `desktop.yml` reads
`GET /orgs/modelplan/actions/runners` and picks the owner's GUI Mac (the whole leg in `native`) when a runner
labelled `modelplan-mac-gui` is online and not busy, otherwise the hosted split above. It falls back to the
hosted split when the `MAC_RUNNER_STATUS_TOKEN` secret is missing (fork, not set up) or the API call fails. The
runner can turn busy between that read and the job's start; the `native` job then queues on it, which is
accepted. A `gui_pool=hosted` or `gui_pool=owner-mac` dispatch input still overrides the variable, and
`modelplan-gates` passes on either pool (`native` green, or `native-hosted` and `native-owner-gui` both green;
the other side is skipped). Note that the hosted split still runs the `ownerGui` classes on the GUI Mac.

Owner setup for `auto`: create a fine-grained personal access token with resource owner `modelplan` and only the
organization permission "Self-hosted runners: read" (no repository access), then run
`gh secret set MAC_RUNNER_STATUS_TOKEN -R modelplan/modelplan` (it prompts for the value) and
`gh variable set MAC_CI_GUI_POOL -R modelplan/modelplan --body auto`.

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

## Cockpit perf measurement

The `perf` job of `desktop.yml` (WP-17, CKP-SHELL-19/53/54, G3-123) runs on a hosted `macos-15` when the workflow is dispatched
with `perf=true` (`gh workflow run desktop.yml -R modelplan/modelplan --ref <branch or main> -f perf=true`); that dispatch skips
every other job, and a PR or the merge queue never runs it. It builds the official cockpit and the synthetic-test CLI, runs
`CommunityCockpitEntryTests/testWP17CockpitMeasurement` (skipped unless `MODELPLAN_PERF_OUT` is set) and turns the app's own
timing lines into `perf-summary.json` and `perf-summary.md` with `desktop/native/tools/perf/perf_report.py` (median, p90 and n
per section, printed against the budgets in the step summary, uploaded as the `wp17-perf-<sha>` artifact). It reports only
and fails only when fewer than 10 samples (60 idle seconds) were taken. A run on the GUI Mac needs a new `trusted-mac.yml`
task (its GUI leg compiles without the test SPI) and so a new pin and runner-group entry, as above.

## Nightly GUI run (D169, D193)

The scheduled GUI run on `main` goes to the GUI Macs (`modelplan-mac-gui`) like the merge queue, not to hosted
`macos-latest`: on a hosted Mac the full suite hit the 70 minute job limit three nights running, while it takes 13 to
33 minutes on ours. A scheduled run's actor is whoever last changed the cron (the merge-queue bot), so the owner-actor
gate of the route cannot hold for it. The route therefore admits, as an alternative to the owner gate, only a
`schedule` event on `refs/heads/main` whose `github.workflow_ref` is
`modelplan/modelplan/.github/workflows/desktop.yml@refs/heads/main`, whose `github.event.schedule` is the nightly
cron `23 9 * * *`, for the `native` and `native-owner-gui` tasks. The GUI VMs' local admission check (workflow-source
and account checks before a job starts, not in this repository) must carry the same exception, validated from the
workflow ref and schedule field rather than the actor, before the runner group allows the pinned reference. There is no hosted fallback: if no GUI Mac is
online, the nightly waits in the queue.

## Merge queue

A PR does not have to merge `main` before it lands. The queue builds "PR + latest
`main`" and the `modelplan-gates` status on that commit requires `ci`, `desktop` and
the Linux path-scoped `u11-cockpit`, `official-visuals`, `u11a-aggregate`, `u14-harness`
and `transport-fuzz` workflows to pass there (`QUEUE_WORKFLOWS` in `scripts/merge-gates/rules.mjs`). `desktop`'s
`queue-scope` job applies the workflow's pull-request path list, because
`merge_group` has no paths filter, and skips the jobs when the group changes none
of those paths or its tree equals the PR head. Otherwise `app`, `shell`,
`native-partition`, `app-smoke` and `native-headless` run on the group commit. The
pinned `trusted-mac.yml` routes only the GUI tasks of a `merge_group` run to the self-hosted
group, and `native-headless` hosted like every other event (D198; D246 reverted). The full GUI leg runs in the
queue whenever the group changes a desktop path, even when its tree equals the PR head (D169,
below); the five Linux workflows have their own `queue-scope` job and no Mac job.

## Affected GUI tests on PRs, full suite in the queue and nightly (D169)

Owner decision D169 (2026-11-11). `pull_request` events never start a GUI leg; a ready PR head gets
`native-headless`, `app-smoke` and the Linux jobs. The coordinator's dispatcher starts the GUI leg
with a `desktop` dispatch (`gui=true`), one at a time. On an ordinary branch that dispatch runs
only the app-integration GUI classes related to the branch's changes against its merge base with
`main`: `desktop/native/tools/ci/gui_test_selection.py` (tests: `test_gui_test_selection.py`)
selects the classes declared in or extended by a changed test file, the classes whose test files
name a top-level declaration of a changed Swift file, and the classes whose test files spell a
changed repository path. Anything it cannot place selects the full share: workflow files, any
`Package.swift`/`Package.resolved`, the partition and the selector, test fixtures, deleted Swift
files, non-Swift files in the Swift package graph, a Swift file no GUI test names (headless-only users do
not count), a selection that
covers 60% or more of the GUI classes, an empty diff, or any selector error. `gui_full=true` on the
dispatch forces the full share. The other GUI-job steps (native package tests, settings tests, Dock,
window and shell checks) always run whole.

The narrowed list reaches `trusted-mac.yml` as the `gui_classes` input. The reusable workflow
accepts it only on a `workflow_dispatch` of a branch other than `main` or `release*`, checks it
against `full`, `none` or a comma-separated list of identifiers, and passes it to
`native_test_partition.py --only`, which keeps the leg's own share of the list (it never widens the
leg) and verifies that exactly that narrowed share ran. Every other run (merge queue, nightly,
push, `main`/release dispatch) runs and verifies the whole share whatever the caller passes.

The compile check is build plus touched classes: for `ModelPlanAppIntegration` (about 540 window-style cases,
longer than the compile Mac's 45 minute limit) it builds the tests and runs only the classes declared in the
test files the PR touches (at most 8, otherwise build-tests only). The full suite is the job of the GUI and
headless legs, not of the compile check.

A selection is a speed-up for the PR round, not the merge gate. The merge queue runs the full GUI
leg on the group commit, and `desktop` must pass there before anything reaches `main`; the
coordinator's gate still requires a successful GUI leg at the PR head. A `schedule` run at 09:23
UTC runs the full GUI leg on `main` (and nothing else); it is skipped when a nightly at the same `main`
commit already passed or is still queued or running. `trusted-mac.yml` admits `merge_group` (queue branches of `main`) and
`schedule` (`main`) runs to the owner's Macs for the GUI tasks only, under the same owner gate.

Non-UI Swift tests are not skipped on the strength of a Mac compile lane's earlier pass at the same
head (D169 item 3 was dropped): those lanes run on agent-operated machines, and nothing they report
(a comment, a file, or a signature made with a key on that machine) can be verified as untampered
by CI. Only GitHub-produced results count.

### macOS legs on pull requests (D254)

Hosted macOS gives 5 concurrent jobs, so a pull request starts a Mac job only when it changes something that job
tests. Every PR-triggered Mac workflow either has a `pull_request` `paths` list that ends in `'!**/*.md'`, or gates
each Mac job on a scope output (`desktop.yml` `pr-scope`, `ci.yml` and `repo-checks.yml` `mac-scope` and `notices-mac`).
`merge_group`, `push`, `schedule` and `workflow_dispatch` are never filtered and keep the full suite. A workflow or
job a PR does not trigger needs no stub: `merge-gates` counts only runs that exist (plus the `ci` anchor) and a skipped
job is green. `trusted-mac.yml` stays untouched; the filters live in its callers. Concurrency cancels only
`pull_request` runs of the same PR (`workflow-policy.test.mjs` enforces both rules).

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

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

After synthetic evidence uploads succeed, checks acknowledge
`MODELPLAN_CI_ARTIFACTS_UPLOADED=1` for the completion hook. Missing acknowledgment
retains the failure scene. Cleanup preserves the temporary root and dependency
checkouts, bounding only generated compiler products. Hosted fallback is selected
before a job is queued: changing a variable does not retarget an existing queued
job, and offline self-hosted jobs do not automatically migrate to hosted runners.
Recover only the affected jobs after confirming ownership and delivery state.

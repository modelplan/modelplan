# Real CLI and app journey in CI

The `e2e-journey` workflow builds the CLI and Community app from one clean checkout. Both CLI architectures carry the checked-in version plus `+e2e.<source>` build metadata. The packager uses unverified identity metadata; it does not mint a reviewed release identity. The provider is a synthetic Codex installation behind the existing `MODELPLAN_CODEX` and `CODEX_HOME` seams, answering the real stdio app-server protocol. Runtime network access is denied, HOME and tool directories are synthetic, and no login/credential is needed.

The app starts through `CommunityApp` → `CommunityApplicationFactory.makeDelegate` → the retained normal runtime/Settings backend/Dock. The driver uses the actual first-run `SettingsConnectionController` request/confirmation methods. Native panels are disabled through the existing production factory argument, so the normal store uses its ordinary desktop poll rather than its visible-account refresh shortcut. No clock/floor override, direct refresh command, observed-cache write, alternate transport or canned app snapshot makes the journey pass.

The six `e2e step N PASS|FAIL <facts>` lines cover detection in real first-run controls, confirmed consent, CLI background provider invocation followed by a later app snapshot, a verified subscription with the fixture's 37% value, confirmed revoke and value withdrawal, then unreadable-provider presentation with a reason and reachable Settings next step. Failures remain failures, including on current main. Artifacts contain bounded aggregate observations and fixed human UI copy, not raw provider/CLI responses, emails or subscription identifiers.

## Hooks requiring M4/M0 review

All app hooks are inside `#if DEBUG && MODELPLAN_E2E_JOURNEY` and require both `MODELPLAN_APP_SMOKE=1` and `MODELPLAN_E2E_JOURNEY=1`:

- `CommunityJourneyCI` and `CommunityApplicationFactory.makeConsentPort` admit the real consent port only in this explicit debug CI build. Release identity verification is unchanged.
- `CommunityApp` selects the production factory's existing headless panel option, keeps the real first-run controller hidden through its existing surface factory, and starts the driver alongside normal app startup.
- `StaticDockPreviewHost` exposes read-only observations of its actual rendered model, feed timestamp and reason/next-step rows.
- `E2EJourney` drives only the retained UI controller and changes only the synthetic provider's mode file. It never asks the CLI to refresh or edits a ModelPlan cache.

`package-neutral.sh --e2e-journey` explicitly builds debug with the macro and unverified metadata. Ordinary release and ordinary debug builds do not include the hooks. Even a release build accidentally receiving the macro excludes them because `DEBUG` is false. The existing release app-smoke launcher deliberately sets the journey environment flag as a negative control: its real unverified consent API must stay disabled and the existing 13 assertions must pass.

CLIJIT owns the app–CLI schemas/generated fixtures. Coordination is in the shared integration discussion; this harness consumes actual binary output rather than hand-written CLI snapshots. Updating the CLI contract belongs with its schema/fixture changes. This CI path qualifies synthetic data flow only; it does not certify owner accounts, official art or physical interactions.

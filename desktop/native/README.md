# Neutral Swift port scaffold

Generic MIT Swift package with a macOS 14 deployment minimum. No official visual source, private producer, scorer or personal fixture is needed. This is a neutral data/lifecycle implementation, not a replacement desktop release.

`ModelPlanCore` contains typed schema-1 personal and flattened publication feeds, exact-ID/units joins, exact harness aliases, nullable quantities, ratio-of-sums generation rates, observation-scoped expiry latches, a bounded one-child transport, an in-memory scheduler/store and app-owned UI preferences. Explicit `validUntil: null` means no clock-only deadline; an absent field is unknown. Publication read timestamps are diagnostics, not invented server-verification timestamps. No local recommendation/scoring engine is included. Historical generation summaries require an explicit source scope and return an unattributed source-wide type; current subscription bindings never assign historical ownership.

`ModelPlanShell` defines a presentation-only provider seam and an independently buildable neutral AppKit default. The app owns commands, scheduling, window policy and routing. Private visual providers are separate implementations; none is shipped here. `ModelPlanCommunity` is a neutral accessory app with a status/error surface and an explicit bilingual Intel warning. After the full-toolchain and packaged-access checks, the normal app now runs the hash-pinned bundled helper through the store; it never opens harness data itself. There is no shell/PATH or unverified-helper fallback.

The host reports actual Dock (including the collapsed sliver) and cockpit visibility to `SnapshotStore.setSurfacesVisible(dock:cockpit:)`. While either is visible and the store is awake, a due personal read first runs `quota --refresh-account --quiet` through the same single-child slot. This existing synchronous command asks Codex's app-server using Codex's own login; the app receives no credentials. Attempts are spaced by at least five monotonic minutes, including failures, manual refreshes and brief resumes. The initial visible read and due resumes refresh first. The transport allows 20 seconds around the CLI's existing 15-second Codex request limit. Refresh output is not a feed; errors do not change store feeds/diagnostics or prevent the subsequent `desktop --json --read-only`. Hidden UI never starts an account refresh; sleep/lock cancels work through the existing lifecycle transaction. Optional readers are not enabled. Companions can implement `CommunityCompanionVisibility` to report their native visibility; absent reports default to hidden.

`LifecycleCoordinator` combines independent sleep, screen sleep, lock, user-session and display pause reasons. A wake cannot clear a lock or inactive user session. Deadline invalidation precedes restoration, including a forward/backward clock jump while paused. Display removal cancels old work and coalesces recovery; ordinary app deactivation does not suspend the reader. Quit waits for child reaping. `SystemEvents` connects AppKit workspace/screen/clock notifications to this same transaction. Distributed screen-lock names are best-effort OS conventions, not a documented security boundary; actual lock/user-switch/hot-plug delivery still needs supported-runtime proof. No system lock, permission or login setting is changed by the code or its automated checks.

## Reproduce the nonvisual checks

The package uses a Swift tools 5.9 manifest. Current integration checks use Xcode 26.6 (17F113), Swift 6.3.3 and SDK 26.5 on Apple silicon. Instruments 16.0 and the separately installed Metal component 32023.883 were verified. Select the reviewed Xcode for each build with `DEVELOPER_DIR`; no script switches the global developer directory. This build evidence does not substitute for running on macOS 14.

```sh
swift run --package-path desktop/native ModelPlanContractChecks
swift run --package-path desktop/native ModelPlanRunLoopChecks
swift run --package-path desktop/native ModelPlanShellChecks /tmp/neutral-error.png
python3 desktop/native/tools/check-fixture-manifests.py
node scripts/check-source-policy.mjs
```

Fake-process checks use the existing system Python, fixed read and account-refresh arguments, helper-hash rejection, a real pipe cap, TERM/KILL cancellation and owned-PID reaping checks. Eight synthetic case directories contain personal/public or explicit unavailable inputs, expected facts, clock actions and hashes. Shell checks inject notification centers through the real adapter and export a direct native rendering of the synthetic error view. This is not a screen capture or physical input test.

## Local test package

`consent-cli-pin.json` is the single source for the native CLI version, archive SHA-256s and extracted Darwin thin-binary SHA-256s (`sourceSHA256ByArchitecture`). Archive, thin-binary and post-sign universal-helper hashes describe different bytes. After reviewing a pin update, run `python3 desktop/native/tools/generate-consent-cli-identity.py` from the repository root and commit the generated Swift constants and U5 scenario requirement. Python identity/candidate tooling reads the pin directly. The distribution test suite checks every current declaration against it and runs the generator with `--check`. Historical captures retain their original release identities. Runtime admission requires both thin-binary hashes and refuses the legacy single-architecture plist key.

Obtain the arm64/amd64 CLI archives and `checksums.txt` selected by `desktop/native/consent-cli-pin.json`, which is reviewed with the native consent identity rather than following plugin upgrades. Pass their directory and a **new** output directory to `desktop/native/tools/package-neutral.sh`. It verifies archive hashes, compiles both architectures, merges app/helper slices, includes MIT/CLI third-party notices, and ad-hoc signs with Hardened Runtime and no App Sandbox entitlement. This is not Developer ID signing/notarisation; the test bundle ID is provisional. Apple silicon is the runtime target. Intel is untested and is labelled "Intel 未测试，3D 效果可能卡顿 / Intel untested; 3D may stutter".

For arbitrary CI/non-release source builds, pass `--unverified` as the packager's third argument. This explicitly selects the identity writer's `--mode unverified`: helper hashes and signing remain checked, but release version/source-helper admission fields are omitted (and stale fields removed), so the real consent port stays unverified with no API actions. The app-smoke job uses the current plugin CLI pin in this mode and `check-app-smoke.py --expect-unverified` asserts the actual first-run screen's human unverified-build guidance. Release distribution keeps the default `release` mode and the reviewed native pin; an unverified helper identity remains a hard packaging failure, with no automatic fallback.

```sh
python3 desktop/native/tools/check-packaged-access.py "/path/ModelPlan Community.app" /new/receipt-directory
```

This supplemental app-launched probe verifies synthetic observed, missing and Unix-denied paths without changing TCC, and checks that read-only fixture homes remain unchanged. CLI version is read from `desktop`'s `cliVersion`; the app never adds a `version` fallback. The normal visible runtime separately refreshes the CLI-owned Codex account cache as described above; this direct read-only access probe does not. Public `publication --json` may maintain the CLI-owned public cache; `desktop --json --read-only` and offline publication create no cache. The app stores neither raw personal output nor a parallel personal-history database.

The explicit `--runtime-probe <synthetic-home> <receipt-path> <1–120 seconds>` app mode exercises the normal runtime with isolated paths. It writes aggregate counts/timings, exact whitelisted command arguments, single-child/cancellation state and main-run-loop heartbeat gaps. It does not log raw payloads, identities, labels or stderr. `tools/measure-runtime.py` prepares its own synthetic homes, performs three bounded runs and identifies only owned children with the bundled executable path. `tools/measure-neutral.py` measures the pre-runner accessory baseline. CPU uses cumulative `proc_pid_rusage` time converted with `mach_timebase_info`, divided by monotonic elapsed time; footprint is recorded in bytes. Sampling peaks are estimates, not proof that shorter spikes did not occur. Probe heartbeat overhead is included and must not be called normal-app idle cost.

## Acceptance boundary

The current source passes 20 contract groups, eight case-manifest integrity checks, the nested common-run-loop deadline check and AppKit adapter/error-view checks. A universal, Hardened Runtime ad-hoc test package passes synthetic read-only helper access and offline-publication checks. Local receipts separately pin the toolchain, binary hashes, cold/idle baseline and integrated child/UI measurements. App/helper deployment and source receipts are separate from a release.

Still required: real macOS 14 runtime coverage and physical lock/sleep/user-switch/display/input proof. Injected notifications and a main-run-loop heartbeat do not prove those interactions or first physical pixels. Signing/notarisation is later distribution work. No WebKit/RealityKit field, entrance, appearance batch, login item, permission change or release is implemented here.


## Community Settings composition

The packaged neutral entry is now the upper `ModelPlanCommunityApp` product in `ModelPlanAppIntegration`. It injects the existing Settings store/editor/window host into the reusable root `ModelPlanCommunityHost`, so the root never depends back on Settings. The legacy `ModelPlanCommunity` product and its explicit probe arguments remain available. The helper transport, lifecycle and probes have one implementation in the shared host. Builds/tests do not launch or package the app; actual visual/physical acceptance remains B25. Normal Settings opens are explicit user actions; restore/programmatic paths do not activate. No login/reader/notification/updater operation is enabled by the entry wiring.

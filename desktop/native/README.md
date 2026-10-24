# Neutral Swift port scaffold

Generic MIT Swift package with a macOS 14 deployment minimum. No official visual source, private producer, scorer or personal fixture is needed. This is a pre-integration scaffold, not a replacement desktop release.

`ModelPlanCore` contains typed schema-1 personal and flattened publication feeds, exact-ID/units joins, exact harness aliases, nullable quantities, ratio-of-sums generation rates, observation-scoped expiry latches, a bounded one-child transport, an in-memory scheduler/store and app-owned UI preferences. Explicit `validUntil: null` means no clock-only deadline; an absent field is unknown. Publication read timestamps are diagnostics, not invented server-verification timestamps. No local recommendation/scoring engine is included. Historical generation summaries require an explicit source scope and return an unattributed source-wide type; current subscription bindings never assign historical ownership.

`ModelPlanShell` defines a presentation-only provider seam and an independently buildable neutral AppKit default. The app owns commands, scheduling, window policy and routing. Private visual providers are separate implementations; none is shipped here. `ModelPlanCommunity` is a neutral accessory app with a status surface and an explicit Intel warning. Production CLI wiring is intentionally not enabled until the packaged-access and full-toolchain prerequisites are accepted. The explicit `--access-probe <synthetic-home> <receipt-path>` test mode runs the bundled read-only helper in isolated test paths.

## Reproduce the nonvisual checks

The package uses a Swift tools 5.9 manifest. The current supplemental checks used CLT Swift 6.2.3 and SDK 26.2 on Apple silicon; that does not pin or substitute a complete Xcode/Instruments/Metal toolchain.

```sh
swift run --package-path desktop/native ModelPlanContractChecks
swift run --package-path desktop/native ModelPlanRunLoopChecks
python3 desktop/native/tools/check-fixture-manifests.py
node scripts/check-source-policy.mjs
```

The executable check targets avoid an XCTest dependency on a CLT-only installation. Fake-process checks use the existing system Python, fixed read-only arguments, a real pipe cap, TERM/KILL cancellation and owned-PID reaping checks. Eight synthetic case directories contain personal/public or explicit unavailable inputs, expected facts, clock actions and hashes. No physical UI, visual, minimum-runtime or performance acceptance is inferred from them.

## Local test package

Obtain the official v0.5.35 arm64/amd64 CLI archives and `checksums.txt`. Pass their directory and a **new** output directory to `desktop/native/tools/package-neutral.sh`. It verifies archive hashes, compiles both architectures, merges app/helper slices, includes MIT/CLI third-party notices, and ad-hoc signs with Hardened Runtime and no App Sandbox entitlement. This is not Developer ID signing/notarisation; the test bundle ID is provisional. Apple silicon is the runtime target. Intel is untested and is labelled "Intel 未测试，3D 效果可能卡顿 / Intel untested; 3D may stutter".

```sh
python3 desktop/native/tools/check-packaged-access.py "/path/Model Plan Community.app" /new/receipt-directory
```

This supplemental app-launched probe verifies synthetic observed, missing and Unix-denied paths without changing TCC, and checks that read-only fixture homes remain unchanged. CLI version is read from `desktop`'s `cliVersion`; the app never adds a `version` or mutating command fallback. Public `publication --json` may maintain the CLI-owned public cache; `desktop --json --read-only` and offline publication create no cache. The app stores neither raw personal output nor a parallel personal-history database.

## Acceptance boundary

The current source passes 18 contract groups, eight case-manifest integrity checks and the nested common-run-loop deadline check. A universal, Hardened Runtime ad-hoc test package passes synthetic read-only helper access and offline-publication checks. App/helper deployment and source receipts are separate from a release.

Still required: full Xcode/Instruments/Metal pin, real macOS 14 runtime coverage, native focus/error-surface proof, actual lock/sleep/display event delivery and application wiring, and measured child-family/UI/resource budgets. No WebKit/RealityKit field, entrance, appearance batch, login item, permission change or release is implemented by this scaffold.

# Neutral Swift port scaffold (work in progress)

Generic MIT Swift package. macOS 14 deployment minimum. Public canonical base v0.5.35; no official visual source, private producer, scorer or personal fixture is needed. No login-item, permission, network-setting or model configuration changes.

This is an independent **pre-wiring** scaffold, not a completed desktop replacement. The full Xcode/Instruments/Metal toolchain and packaged read-only access receipt are prerequisites to wiring the production runner. CLT compilation is not that acceptance. Do not start visual batches or field/RealityKit work from this scaffold.

- `ModelPlanCore`: typed schema-1 personal and flattened publication feeds; nullable quantities; exact-ID join and exact harness aliases; ratio-of-sums generation rate; observation-scoped expiry latches; one-child bounded process transport; deadline-aware in-memory store and app-owned UI preferences.
- `ModelPlanCommunity`: neutral accessory app, no WebKit or RealityKit imports/allocations. `--access-probe <synthetic-home> <receipt-path>` launches only its bundled CLI with isolated test paths. It does not load real personal paths in that test mode.
- `ModelPlanContractChecks`: reproducible synthetic checks without an XCTest dependency. Uses only the existing system Python for fake CLI processes.

With a compatible full Xcode selected for this process (set `DEVELOPER_DIR` rather than changing global settings):

```sh
swift run --package-path desktop/native -c release ModelPlanContractChecks
swift build --package-path desktop/native -c release --product ModelPlanCommunity
```

For the local universal test package, obtain the official v0.5.35 arm64/amd64 CLI archives and `checksums.txt`. Pass their directory and a **new** output directory to `desktop/native/tools/package-neutral.sh`. The script verifies hashes, compiles both architectures, merges app/helper slices and ad-hoc signs with Hardened Runtime. This is **not Developer ID signing/notarisation**. The test bundle ID is provisional. Apple silicon is the runtime target; Intel is untested and must be labelled "Intel 未测试，3D 效果可能卡顿 / Intel untested; 3D may stutter".

No public remote publication is authorized for this work-in-progress branch. Private handoff will contain an applyable patch and pinned base/source hashes, not a competing editable implementation copy.

## Current validation boundary

Initial CLT build and 12 synthetic contract groups passed before a subsequent DTO preservation correction. The corrected source must be rebuilt/retested. The initial universal packaging attempt compiled both architecture products but failed on a nested archive path; that path is corrected, and packaging must be rerun. Build caches were intentionally removed to free disk space for Xcode. No packaged access/denial receipt, full-toolchain profiling, physical UI input or macOS 14 runtime acceptance is claimed. Production app wiring stays off until B01 prerequisites pass.

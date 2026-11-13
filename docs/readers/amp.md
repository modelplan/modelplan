<!-- SPDX-License-Identifier: MIT -->
# Amp reader card

- Reviewed ModelPlan source: `61ef253f0667a5e10a2c438212757775e116559a`; [production.go](https://github.com/modelplan/modelplan/blob/61ef253f0667a5e10a2c438212757775e116559a/cli/internal/localusage/production.go), [history_adapters.go](https://github.com/modelplan/modelplan/blob/61ef253f0667a5e10a2c438212757775e116559a/cli/internal/localusage/history_adapters.go), [amp.go](https://github.com/modelplan/modelplan/blob/61ef253f0667a5e10a2c438212757775e116559a/cli/internal/quota/amp.go).
- Scope: `amp.local_history`; no compiled Amp balance/runtime scope. Scope authority, catalogue presence and account membership are separate.
- Review date: 2026-10-29. Public-source inspection only; no real data, credentials, installed runtime execution or live vendor request. This docs change enables no reader and changes no default.

- Vendor source: [Amp threads](https://ampcode.com/docs/threads), [balance command](https://ampcode.com/docs/pricing), [update-check configuration](https://ampcode.com/docs/cli/settings) (checked on the review date; product/command context, not a stable private-store schema).
- References compared: [Pulse@78eddaaf](https://github.com/qunqin24/Pulse/blob/78eddaaf9f19bc17c5a5446aee8d98724961b8f9/Sources/Pulse/Usage/Readers/AmpSessionReader.swift) (Apache-2.0), [CodexBar@ee890b5f](https://github.com/steipete/CodexBar/blob/ee890b5f392e70d6e20162d3e95cf9f1be265b60/Sources/CodexBarCore/Providers/Amp/AmpCLIProbe.swift) (MIT). The existing [Amp balance audit](https://github.com/modelplan/modelplan/blob/61ef253f0667a5e10a2c438212757775e116559a/docs/amp-reader-audit.md) records the held command audit.

## Data

The admitted local scope reads assistant-message native input/output/cache-read/cache-write counters, reported model and reported timestamp from thread JSON. No sum reconstructs billed total, price, allowance or balance; missing fields stay unknown. The separate held `amp usage --no-color` helper parses native USD pools, keeping included/free allowance and paid balance separate. A money balance is not token history or subscription membership.

- [Pulse@78eddaaf](https://github.com/qunqin24/Pulse/blob/78eddaaf9f19bc17c5a5446aee8d98724961b8f9/Sources/Pulse/Usage/Readers/AmpSessionReader.swift): local message usage plus other thread-cost evidence and deduplication. ModelPlan selects native counters only; cost conversion and extra sources are not adopted.
- [CodexBar@ee890b5f](https://github.com/steipete/CodexBar/blob/ee890b5f392e70d6e20162d3e95cf9f1be265b60/Sources/CodexBarCore/Providers/Amp/AmpCLIProbe.swift): runs the owning CLI's `usage` command and parses displayed balances. Its process success is not a native-executable no-refresh/write audit and cannot admit ModelPlan's held helper.

## Candidate paths

| Path | Carrier | Auth | Endpoint status | Side effects | Red-line check |
| --- | --- | --- | --- | --- | --- |
| Local thread JSON | L | none | Undocumented local format | Bounded reads; ModelPlan cache writes only | Chosen token-history scope |
| Owning CLI balance text | Subprocess; no structured R RPC contract | runtime | Documented command, internal HTTP unknown | Startup/auth/update/state effects need artifact audit | Held/not-read; not a compiled balance scope |
| Credential HTTP / browser fallback | H / S | O / C | Different capabilities | Extracts credentials or adds requests | Rejected |

## Incidents and pitfalls

- A transcript event, cumulative total and monetary estimate must not be counted as interchangeable measurements. → [TestHistoryAdaptersPreserveNativeCounters](https://github.com/modelplan/modelplan/blob/61ef253f0667a5e10a2c438212757775e116559a/cli/internal/localusage/history_incremental_test.go) (`TestHistoryAdaptersPreserveNativeCounters`) and [TestHistoryChangedSnapshotsAndUnallocatedDay](https://github.com/modelplan/modelplan/blob/61ef253f0667a5e10a2c438212757775e116559a/cli/internal/localusage/history_incremental_test.go) (`TestHistoryChangedSnapshotsAndUnallocatedDay`).
- Auditing a wrapper/path is insufficient when an installed binary can be replaced. → [TestAmpExecutesSealedBytesAfterPathReplacement](https://github.com/modelplan/modelplan/blob/61ef253f0667a5e10a2c438212757775e116559a/cli/internal/quota/amp_exec_linux_test.go) (`TestAmpExecutesSealedBytesAfterPathReplacement`); immutable bytes solve execution binding, not runtime side effects.

## Choice

- Local L/none is standard, pre-selected in the compiled first-run definition (`defaultCheck: true`), subject to an actual local grant/privacy choice. It grants no account/balance route.
- Read `${XDG_DATA_HOME}/amp/threads/T-*.json`, default `~/.local/share/amp/threads/T-*.json`, at that exact directory depth. Accept assistant messages with messageId and usage; skip other shapes. No thread API, sync, execute mode, hook or runtime launch is used for history.
- Licence: existing Go reader and audit remain unchanged. Upstream comparisons introduce no copied code/fixture; Pulse Apache-2.0 and CodexBar MIT retain their own terms.

### Local read boundary

No HTTP method, host, path or header is used by this scope; no owning runtime is launched. Authentication is none. Only the selected local record paths are admitted; browser/auth stores, unrelated global configuration, symlink escapes and subagent discovery are excluded. Selected numeric/model/time fields are decoded; surrounding source JSON may contain conversation content, which is not copied into the retained history DTO.

The incremental engine has a shared provider lock and five-minute attempt floor; failures back off 10/20/40/60 minutes. It caps directory enumeration at 4,096 entries and 256 source files, with 8-MiB per-file work and a 32-MiB read budget. Immutable files are skipped; complete-line cursors and keyed records survive restart/rotation without counting data twice. Discovery or byte limits leave coverage partial/unknown. Cache-only reads do no source I/O. Refresh never renews a credential or edits the tool's files; only ModelPlan's consent/key/cache/gate files are written.

### Held balance helper

`RefreshAmp` is a separate helper with no production caller outside its tests in this main pin. It requires explicit `AmpAccess`, supported login/privacy and an audited native executable SHA-256; no audited shipped artifact is supplied by this review. On Linux the existing implementation seals an anonymous in-memory snapshot and executes those verified bytes. Other platforms fail closed without an equivalent primitive.

Only `amp usage --no-color`, no stdin, no prompt/thread/session command; fixed update-disable/no-color/locale settings, an eight-second timeout and 64-KiB output bound. No HTTP host/path/header set inside Amp is certified. `AMP_SKIP_UPDATE_CHECK` addresses updates, not credential refresh or startup writes. The previous static package review names version `0.0.1793104576-gc52692`; it is not a reviewed installed native artifact/hash or an observed safety run. Keep this path held until the missing versioned side-effect audit and provider request budget are supplied.

## Tests

- Fixtures: [TestHistoryAdaptersPreserveNativeCounters](https://github.com/modelplan/modelplan/blob/61ef253f0667a5e10a2c438212757775e116559a/cli/internal/localusage/history_incremental_test.go) (`TestHistoryAdaptersPreserveNativeCounters`), [TestHistoryJSONLIncrementalTruncationAndRotation](https://github.com/modelplan/modelplan/blob/61ef253f0667a5e10a2c438212757775e116559a/cli/internal/localusage/history_incremental_test.go) (`TestHistoryJSONLIncrementalTruncationAndRotation`), [TestHistoryConsentProviderGateAndUnsafePaths](https://github.com/modelplan/modelplan/blob/61ef253f0667a5e10a2c438212757775e116559a/cli/internal/localusage/history_incremental_test.go) (`TestHistoryConsentProviderGateAndUnsafePaths`), [TestProductionHistoryForgetKeepsOtherToolsAndGate](https://github.com/modelplan/modelplan/blob/61ef253f0667a5e10a2c438212757775e116559a/cli/internal/localusage/production_test.go) (`TestProductionHistoryForgetKeepsOtherToolsAndGate`).
- Held-helper seams: [TestAmpAdmissionAuditAndCache](https://github.com/modelplan/modelplan/blob/61ef253f0667a5e10a2c438212757775e116559a/cli/internal/quota/amp_test.go) (`TestAmpAdmissionAuditAndCache`), [TestAmpUnsupportedLoginAndWrapper](https://github.com/modelplan/modelplan/blob/61ef253f0667a5e10a2c438212757775e116559a/cli/internal/quota/amp_test.go) (`TestAmpUnsupportedLoginAndWrapper`), [TestAmpCommandNoInputUpdatesOrThread](https://github.com/modelplan/modelplan/blob/61ef253f0667a5e10a2c438212757775e116559a/cli/internal/quota/amp_test.go) (`TestAmpCommandNoInputUpdatesOrThread`), [TestAmpExecutesSealedBytesAfterPathReplacement](https://github.com/modelplan/modelplan/blob/61ef253f0667a5e10a2c438212757775e116559a/cli/internal/quota/amp_exec_linux_test.go) (`TestAmpExecutesSealedBytesAfterPathReplacement`). Injected subprocesses do not certify a real Amp runtime.
- Red lines: fixture canaries and keyed caches cover selected-field privacy, consent/revoke, path limits and retained attempt gates. A native full-writer/OS audit is not claimed. No credential/HTTP/Keychain capability is granted by the local scope.
- Owner-shaped case: XDG/default root, changed thread snapshots, partial/missing model/time/counters, replayed IDs, multiple profiles, source bounds, revoke/Forget and retained gate. Any future balance audit must bind the exact native bytes and cover startup, auth expiry, error text and vendor traffic.

## Known gaps and unknowns

The balance audit gap is reported as P1 **already held**, not as active admitted runtime traffic. The local record schema can change; missing count fields remain unknown. No runtime safety pass, real-account balance, native UI, device L2 or L3 is established here.

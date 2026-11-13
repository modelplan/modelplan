<!-- SPDX-License-Identifier: MIT -->
# Droid reader card

- Reviewed ModelPlan source: `61ef253f0667a5e10a2c438212757775e116559a`; [production.go](https://github.com/modelplan/modelplan/blob/61ef253f0667a5e10a2c438212757775e116559a/cli/internal/localusage/production.go), [history_adapters.go](https://github.com/modelplan/modelplan/blob/61ef253f0667a5e10a2c438212757775e116559a/cli/internal/localusage/history_adapters.go), [history_incremental.go](https://github.com/modelplan/modelplan/blob/61ef253f0667a5e10a2c438212757775e116559a/cli/internal/localusage/history_incremental.go).
- Scope: `droid.local_history`. Scope authority, catalogue presence and account membership are separate.
- Review date: 2026-10-29. Public-source inspection only; no real data, credentials, installed runtime execution or live vendor request. This docs change enables no reader and changes no default.

- Vendor source: [Factory individual usage documentation](https://docs.factory.com/pricing/individuals) (checked on the review date; describes account limits, not a stable session-settings schema).
- References compared: [Pulse@78eddaaf](https://github.com/qunqin24/Pulse/blob/78eddaaf9f19bc17c5a5446aee8d98724961b8f9/Sources/Pulse/Usage/Readers/DroidSessionReader.swift) (Apache-2.0), [tokscale@669fdaee](https://github.com/junhoyeo/tokscale/blob/669fdaeec54502a30468adbfa97789bb7ee2b762/crates/tokscale-core/src/sessions/droid.rs) (MIT).

## Data

Own-session cumulative `tokenUsage` counters: input, output, cache read, cache creation and thinking tokens. No total is manufactured and overlapping buckets are not summed into a bill. Historical model and day remain **unallocated/unknown**; the settings' current model, file mtime and transcript guesses are not attached to old cumulative counts. Inclusive/child-session totals are not added to the own-session value. This scope reports no Factory subscription quota, rate-limit window, credit balance or plan.

- [Pulse@78eddaaf](https://github.com/qunqin24/Pulse/blob/78eddaaf9f19bc17c5a5446aee8d98724961b8f9/Sources/Pulse/Usage/Readers/DroidSessionReader.swift): distinguishes aggregate settings usage from tokenless transcript replies; applies its own historical/time and counter semantics. ModelPlan keeps its stricter undated/unallocated representation and does not distribute a total over replies.
- [tokscale@669fdaee](https://github.com/junhoyeo/tokscale/blob/669fdaeec54502a30468adbfa97789bb7ee2b762/crates/tokscale-core/src/sessions/droid.rs): reads settings and can inspect a sibling transcript/model or filesystem timestamp. Those extra inference paths are not adopted by this reader.

## Candidate paths

| Path | Carrier | Auth | Endpoint status | Side effects | Red-line check |
| --- | --- | --- | --- | --- | --- |
| Own-session settings totals | L | none | Undocumented local schema | Bounded source reads and ModelPlan cache writes | Chosen, with unknown day/model preserved |
| Transcript/model/mtime allocation | L | none | Different evidence | Could invent historical provenance | Rejected |
| Factory account/billing/runtime read | H / R | O / runtime | Separate capability | Auth/network/startup effects need separate review | Not part of this scope |

## Incidents and pitfalls

- Current-model and filesystem timestamps cannot date cumulative token totals. Inclusive child data would double count own-session totals. → [TestHistoryAdaptersPreserveNativeCounters](https://github.com/modelplan/modelplan/blob/61ef253f0667a5e10a2c438212757775e116559a/cli/internal/localusage/history_incremental_test.go) (`TestHistoryAdaptersPreserveNativeCounters`) checks unknown model/time and own-session counters.
- Replacing a settings snapshot must replace its keyed cumulative row, not add another copy. → [TestHistoryChangedSnapshotsAndUnallocatedDay](https://github.com/modelplan/modelplan/blob/61ef253f0667a5e10a2c438212757775e116559a/cli/internal/localusage/history_incremental_test.go) (`TestHistoryChangedSnapshotsAndUnallocatedDay`).

## Choice

- L/none, standard, pre-selected first-run definition (`defaultCheck: true`), with the local grant and privacy gates still required. No account authority follows from this checkbox.
- Read only `~/.factory/sessions/<project>/<session>.settings.json`, at the compiled one-directory depth. Decode selected `tokenUsage` fields; exclude sibling conversation JSONL and `inclusiveTokenUsage`/child-inclusive aggregates. Preserve explicit undated/unallocated output rather than borrowing provenance.
- Licence: schema/behavior comparison only. This card adds no upstream code or fixture and changes no grant, dependency or notice; Pulse Apache-2.0 and Tokscale MIT remain their own sources.

### Local read boundary

No HTTP method, host, path or header is used by this scope; no owning runtime is launched. Authentication is none. Only the selected local record paths are admitted; browser/auth stores, unrelated global configuration, symlink escapes and subagent discovery are excluded. Selected numeric/model/time fields are decoded; surrounding source JSON may contain conversation content, which is not copied into the retained history DTO.

The incremental engine has a shared provider lock and five-minute attempt floor; failures back off 10/20/40/60 minutes. It caps directory enumeration at 4,096 entries and 256 source files, with 8-MiB per-file work and a 32-MiB read budget. Immutable files are skipped; complete-line cursors and keyed records survive restart/rotation without counting data twice. Discovery or byte limits leave coverage partial/unknown. Cache-only reads do no source I/O. Refresh never renews a credential or edits the tool's files; only ModelPlan's consent/key/cache/gate files are written.

## Tests

- Fixtures: [TestHistoryAdaptersPreserveNativeCounters](https://github.com/modelplan/modelplan/blob/61ef253f0667a5e10a2c438212757775e116559a/cli/internal/localusage/history_incremental_test.go) (`TestHistoryAdaptersPreserveNativeCounters`), [TestHistoryChangedSnapshotsAndUnallocatedDay](https://github.com/modelplan/modelplan/blob/61ef253f0667a5e10a2c438212757775e116559a/cli/internal/localusage/history_incremental_test.go) (`TestHistoryChangedSnapshotsAndUnallocatedDay`), [TestHistoryConsentProviderGateAndUnsafePaths](https://github.com/modelplan/modelplan/blob/61ef253f0667a5e10a2c438212757775e116559a/cli/internal/localusage/history_incremental_test.go) (`TestHistoryConsentProviderGateAndUnsafePaths`), [TestHistoryRollbackCorruptGateAndNoTimestampGuess](https://github.com/modelplan/modelplan/blob/61ef253f0667a5e10a2c438212757775e116559a/cli/internal/localusage/history_incremental_test.go) (`TestHistoryRollbackCorruptGateAndNoTimestampGuess`), [TestProductionHistoryForgetKeepsOtherToolsAndGate](https://github.com/modelplan/modelplan/blob/61ef253f0667a5e10a2c438212757775e116559a/cli/internal/localusage/production_test.go) (`TestProductionHistoryForgetKeepsOtherToolsAndGate`).
- Red lines: synthetic canaries/path traps check selected-field privacy and no guessed model/day; shared-gate/Forget cases retain the attempt reservation. No runtime, browser, Keychain, credential file or remote endpoint is used by this path. Exhaustive native filesystem/output-writer observation is not-run.
- Owner-shaped case: one-project depth, cumulative total grows/shrinks/replaces, unknown counters, huge/malformed snapshots, missing model/time, child-inclusive fields present, symlink/denied root, multiple processes, revoke/reset and Forget without resetting the gate.

## Known gaps and unknowns

The vendor documentation does not promise this local file schema. Current real subscription limits cannot be inferred from historical session tokens. Per-model/per-day history is unavailable from these selected snapshots, and remains explicitly unallocated. Current-native compatibility, OS/UI behavior, owner-shaped L2 and L3 are not-run; no compatibility or safety claim is upgraded by writing this card.

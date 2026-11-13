<!-- SPDX-License-Identifier: MIT -->
# Qwen Code reader card

- Reviewed ModelPlan source: `61ef253f0667a5e10a2c438212757775e116559a`; [qwen.go](https://github.com/modelplan/modelplan/blob/61ef253f0667a5e10a2c438212757775e116559a/cli/internal/localusage/qwen.go), [production.go](https://github.com/modelplan/modelplan/blob/61ef253f0667a5e10a2c438212757775e116559a/cli/internal/localusage/production.go), [history_adapters.go](https://github.com/modelplan/modelplan/blob/61ef253f0667a5e10a2c438212757775e116559a/cli/internal/localusage/history_adapters.go).
- Scope: `qwen.local_history`. Scope authority, catalogue presence and account membership are separate.
- Review date: 2026-10-29. Public-source inspection only; no real data, credentials, installed runtime execution or live vendor request. This docs change enables no reader and changes no default.

- Vendor source: [qwen-code@70be140e](https://github.com/QwenLM/qwen-code/blob/70be140e148f8fc7527cc51717603a6dd84abc19/packages/core/src/services/chatRecordingService.ts) and [Storage](https://github.com/QwenLM/qwen-code/blob/70be140e148f8fc7527cc51717603a6dd84abc19/packages/core/src/config/storage.ts) (Apache-2.0). Public CLI source inspected as a file-format reference, not executed.
- References compared: [Pulse@78eddaaf](https://github.com/qunqin24/Pulse/blob/78eddaaf9f19bc17c5a5446aee8d98724961b8f9/Sources/Pulse/Usage/Readers/QwenSessionReader.swift) (Apache-2.0), [tokscale@669fdaee](https://github.com/junhoyeo/tokscale/blob/669fdaeec54502a30468adbfa97789bb7ee2b762/crates/tokscale-core/src/sessions/qwen.rs) (MIT).

## Data

Assistant ChatRecords' `usageMetadata`: prompt, candidates/output, cached-content, thoughts, tool-use prompt and declared total token counts, with native model and timestamp. Buckets can overlap; do not sum them into billed total, cost or quota. Preserve missing fields as unknown. Early Gemini-style snapshots are normalized separately. No account quota, plan, credit balance, login state or paid usage is inferred from session logs.

- Vendor source, pinned above: project-scoped chats and append-only recording with selected assistant usage fields. ModelPlan reads existing records; it does not start the service or invoke SDK/session/daemon APIs.
- [Pulse@78eddaaf](https://github.com/qunqin24/Pulse/blob/78eddaaf9f19bc17c5a5446aee8d98724961b8f9/Sources/Pulse/Usage/Readers/QwenSessionReader.swift): local assistant records with additional accounting/partition checks. Its disjoint or priced rollups are not assumed by this native-bucket reader.
- [tokscale@669fdaee](https://github.com/junhoyeo/tokscale/blob/669fdaeec54502a30468adbfa97789bb7ee2b762/crates/tokscale-core/src/sessions/qwen.rs): project ChatRecord JSONL parser; its timestamp fallbacks and other aggregation choices are not authority to fill missing native fields here.

## Candidate paths

| Path | Carrier | Auth | Endpoint status | Side effects | Red-line check |
| --- | --- | --- | --- | --- | --- |
| Existing JSONL and legacy snapshot | L | none | Public emitter source; local compatibility format | Bounded reads; ModelPlan cache writes | Chosen native token history |
| Status line / newly installed hook | J | none | Separate producer | Changes another tool's configuration | Not installed by this reader |
| Qwen server/CLI or cloud quota/cookie API | R / H / S | runtime / O / C | Different capability | Auth, session, remote calls or browser access | Excluded from local scope |

## Incidents and pitfalls

- Modern Qwen uses assistant `uuid`/usageMetadata JSONL rather than only legacy Gemini snapshots. → [TestQwenNativeJSONLPrivacyDedupeAndIndependentConsent](https://github.com/modelplan/modelplan/blob/61ef253f0667a5e10a2c438212757775e116559a/cli/internal/localusage/qwen_test.go) (`TestQwenNativeJSONLPrivacyDedupeAndIndependentConsent`) and [TestQwenDefaultOffOverrideAndLegacySnapshot](https://github.com/modelplan/modelplan/blob/61ef253f0667a5e10a2c438212757775e116559a/cli/internal/localusage/qwen_test.go) (`TestQwenDefaultOffOverrideAndLegacySnapshot`).
- Incomplete trailing lines, rotation and overlapping token buckets must not create duplicate or invented counts. → [TestHistoryJSONLIncrementalTruncationAndRotation](https://github.com/modelplan/modelplan/blob/61ef253f0667a5e10a2c438212757775e116559a/cli/internal/localusage/history_incremental_test.go) (`TestHistoryJSONLIncrementalTruncationAndRotation`) and [TestQwenUnknownHistoryBoundsAndStops](https://github.com/modelplan/modelplan/blob/61ef253f0667a5e10a2c438212757775e116559a/cli/internal/localusage/qwen_test.go) (`TestQwenUnknownHistoryBoundsAndStops`).

## Choice

- L/none, standard, pre-selected in the compiled first-run definition (`defaultCheck: true`). An actual local grant/configuration is still required. The existing Qwen local enable setting is an independent veto; legacy default-off and `MODELPLAN_QWEN=off` are preserved.
- Default root `~/.qwen`; an absolute `MODELPLAN_QWEN_HOME` selects a literal local root. Admit `projects/<project>/chats/*.jsonl`, `tmp/<project>/chats/*.jsonl` and legacy `<project>/chats/*.jsonl`, plus `session-*.json` snapshots in those layouts. No arbitrary path or recursive auth/config scan.
- Licence: preserve the vendor's Apache-2.0 and existing contributor notices; Pulse Apache-2.0 and Tokscale MIT are comparison sources. This documentation introduces no copied code, fixture, dependency or licence change.

### Local read boundary

No HTTP method, host, path or header is used by this scope; no owning runtime is launched. Authentication is none. Only the selected local record paths are admitted; browser/auth stores, unrelated global configuration, symlink escapes and subagent discovery are excluded. Selected numeric/model/time fields are decoded; surrounding source JSON may contain conversation content, which is not copied into the retained history DTO.

The incremental engine has a shared provider lock and five-minute attempt floor; failures back off 10/20/40/60 minutes. It caps directory enumeration at 4,096 entries and 256 source files, with 8-MiB per-file work and a 32-MiB read budget. Immutable files are skipped; complete-line cursors and keyed records survive restart/rotation without counting data twice. Discovery or byte limits leave coverage partial/unknown. Cache-only reads do no source I/O. Refresh never renews a credential or edits the tool's files; only ModelPlan's consent/key/cache/gate files are written.

## Tests

- Fixtures: [TestQwenNativeJSONLPrivacyDedupeAndIndependentConsent](https://github.com/modelplan/modelplan/blob/61ef253f0667a5e10a2c438212757775e116559a/cli/internal/localusage/qwen_test.go) (`TestQwenNativeJSONLPrivacyDedupeAndIndependentConsent`), [TestQwenUnknownHistoryBoundsAndStops](https://github.com/modelplan/modelplan/blob/61ef253f0667a5e10a2c438212757775e116559a/cli/internal/localusage/qwen_test.go) (`TestQwenUnknownHistoryBoundsAndStops`), [TestQwenDefaultOffOverrideAndLegacySnapshot](https://github.com/modelplan/modelplan/blob/61ef253f0667a5e10a2c438212757775e116559a/cli/internal/localusage/qwen_test.go) (`TestQwenDefaultOffOverrideAndLegacySnapshot`), [TestHistoryJSONLIncrementalTruncationAndRotation](https://github.com/modelplan/modelplan/blob/61ef253f0667a5e10a2c438212757775e116559a/cli/internal/localusage/history_incremental_test.go) (`TestHistoryJSONLIncrementalTruncationAndRotation`), [TestHistoryConsentProviderGateAndUnsafePaths](https://github.com/modelplan/modelplan/blob/61ef253f0667a5e10a2c438212757775e116559a/cli/internal/localusage/history_incremental_test.go) (`TestHistoryConsentProviderGateAndUnsafePaths`), [TestHistoryForgetProfileRetainsProviderGate](https://github.com/modelplan/modelplan/blob/61ef253f0667a5e10a2c438212757775e116559a/cli/internal/localusage/history_incremental_test.go) (`TestHistoryForgetProfileRetainsProviderGate`).
- Red lines: selected-field canary/privacy, independent consent, safe literal paths, complete-line cursors, bounds and retained gates are tested with synthetic records. No credential import, refresh process, paid call or browser/Keychain route exists in this scope. Full native all-writer/OS observation is not-run.
- Owner-shaped case: modern/legacy layout, custom absolute root, local off versus shared allow, duplicate/replaced/truncated JSONL, missing/zero/negative counters, native overlaps, unknown model/day, byte/discovery limits, revoke/reset and Forget across clients.

## Known gaps and unknowns

Source revisions do not establish every installed version's format. Cumulative context usage is not subscription quota; cached/reasoning/tool fields may overlap other native buckets. Missing counters, time and model stay unknown. No daemon/session call or hook is authorized by this card, and no native/UI, owner-shaped L2 or L3 acceptance is claimed.

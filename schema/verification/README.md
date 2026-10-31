<!-- SPDX-License-Identifier: MIT -->
# U6 verification receipt contract

These Draft 2020-12 schemas describe only what the U6 Dock/menu drive emits and consumes, as specified by
`desktop/native/verification/U6-DockMenu-Drive.md`: "Evidence and timing contract (C2.4)" as amended by
"Contract revision C2.6", with the C2.7 §D call window (C2.7 wins where they differ). They follow the [App–CLI contract](../app-cli/README.md)
pattern: versioned schemas, fixtures with recorded provenance, a drift check, and contract tests. `common.json`
holds the shared identity, clock and code definitions.

C2.6 F keeps the producers' current receipt shapes, so the schemas describe the App's native envelope and
pointer_drive's rows as written today. Where a producer still has to change for C2.6, it is listed under
[Producer changes required by C2.6](#producer-changes-required-by-c26); where `bin/evidence-u6.py` must change, under
[evidence-u6 changes required by C2.6](#evidence-u6-changes-required-by-c26). Nothing here changes a producer.

| Schema | Batch file | Producer | Consumers |
| --- | --- | --- | --- |
| [native-row.json](native-row.json) + one schema per kind in `x-kinds` ([native/](native/)) | `native-observations.jsonl` | `U6DriveGuard.emitObject` (test build) | drive-u6, u6-pointer-plan, capture/reset/action tools, evidence-u6, replay |
| [pointer-receipt.json](pointer-receipt.json) | `dock-pointer.jsonl`, `status-pointer.jsonl`, `status-pointer-clear.jsonl` | `bin/pointer_drive.swift` | u6-pointer-plan, evidence-u6, replay |
| [capture-receipt.json](capture-receipt.json) (`u6-capture/1`) | `dock-capture.json` | `U6/capture_owned.py` | evidence-u6, replay |
| [consent-reset.json](consent-reset.json) (`consent-reset/1`) | `consent-reset.json` | `U6/consent_reset.py` | evidence-u6, replay |
| [u6-actions.json](u6-actions.json) (`u6-actions/1`) | `operator-finish.json` | `U6/action_runner.py` | drive-u6, evidence-u6, replay |
| [runtime-calls.json](runtime-calls.json) (`runtime-calls/1`, per line) | `runtime-calls.jsonl` (+ `runtimeCallsSHA256` in `result.json`) | the seeded Copilot stub, copied by Drive (C2.6 C-D; pending, M4) | evidence-u6, replay |
| [launch-cleanup.json](launch-cleanup.json) (`launch-cleanup/1`) | `launch-cleanup.json` | `bin/check_launch_cleanup.py` | evidence-u6, replay |
| [replay-context.json](replay-context.json) (`u6-replay-context/1`) | replay input only | derived from the run files (subject, lease, seed title hash, HOME hash, manifest and launched pins) | replay |

Native kinds (`event`): `started`, `doctor` (guard tick, not a step input), `dock-surface-frame`,
`status-item-frame`, `menu-begin`, `menu-end` (`cause` with `clearID` iff `clear`), `menu-private-title-visible`
(`titleSHA256`, `privateItemIDs`), `status-menu-action-arrived`, `refresh` (flat; `requested` | `completed` |
`accepted` | `failed` | `deferred` | `abandoned`), `clear-initiated`, `accepted-clear`, `menu-scrubbed` (per session, per
recorded item), `stop-or-lease-expired` / `owner-preempted` (one schema; only the first satisfies step 8) and
`terminate-completed`.

## Encoding, versioning and compatibility

- **Native rows (C2.6 F)** are the App's envelope: `runID`, `epoch`, `pid`, `seq` (integer ≥ 1, strictly
  increasing per process), `mono` (fractional `ProcessInfo.systemUptime`), `at` (UNIX seconds, informational),
  `event`, `timestamp` (= `at`, informational) and `checks` {the kind's fields}. `refresh` rows are flat with
  `kind: "refresh"`. The App's extra identity fields (`instanceID`, `subjectPID`, `menuInstanceID`,
  `nativeUptimeSeconds`) are allowed and never decide. A row carries exactly one of the two encodings.
- **Refresh (C2.6 D):** `requested` carries `rowsSequenceBefore`, `copilotAccountsBefore` and the
  `engineRequestID` the handler sends; `accepted` carries the same `engineRequestID` and `dispositions` (scope → `scheduled` | `cooldown` | `read_only` | `offline` |
  `policy_pending`; `copilot.runtime_usage` required), copied from that call's own reply; `completed` carries
  `rowsSequenceAfter`, `copilotAccountsAfter` and `readingSHA256` ([Reading digest](#reading-digest)); `failed` a §5 `reason`;
  `deferred` nothing more; `abandoned` a `cause` (`deadline` | `stop`). Every phase carries R, A's `sessionID` and
  `menuObjectID`.
- **Runtime calls (C2.6 D):** one `runtime-calls/1` object per line (`runID`, `epoch` from the stub's seeded
  binding, `method`, `pid`, `ppid`, `mono`, `seq`). Drive records the copy's SHA-256 in `result.json` as
  `runtimeCallsSHA256` (binding decision).
- **Pointer rows** are pointer_drive's: `event` names the row, posted rows carry `kind` (`move` | `click`), the
  C2.4 binding (`runID`, `epoch`, `targetPID`, numeric `mono`, `at`) and its `subjectPID`, `uptimeSeconds`, ISO
  `timestamp`. The permission row is written without run binding and is never evidence.
- **Protocol (C2.6 F).** `started.checks.protocol` is optional; absent (the App today) means `u6-native/1`. Any other
  version makes the native stream unusable: NOT-RUN `unknown`.
- **Frozen meanings.** Identity (run/epoch/PID binding, `menuObjectID` vs `sessionID`, `requestId`, `clearID`),
  clocks and ordering (`seq` within the app, `mono` across processes, `at`/`timestamp` never), the reset
  correlation pair, the retained-item proof and every outcome/reason vocabulary are frozen for a protocol version;
  changing one needs a new version with producer, schema, fixtures and consumers in one reviewed change.
- **Closed objects.** Every object (including `checks`) is `additionalProperties: false`; a new field lands in the
  schema and fixtures with the producer. A schema-invalid receipt is NOT-RUN (C2.6 F).
- Free engine/exception text never appears; reasons use `common.json#/$defs/scenarioReason` (C2.4 §5 plus
  C2.6 D `cooldown`).

## Three checks

`desktop/native/verification/tests/test_u6_receipt_schema.py` (stdlib only; `U6/receipt_schema.py` implements
exactly the keyword subset these schemas use and refuses any other keyword):

1. **Shape.** Every schema is Draft 2020-12, closed and resolvable; every native kind schema carries the envelope
   (or, for `refresh`, the flat form). All positive fixtures validate, every schema has a positive instance, and
   removing any required identity, clock, session, reset-pair, disposition or item-proof field is rejected. For
   `launch-cleanup/1` the schema's keys equal `check_launch_cleanup.KEYS`/`CHECKS`/`TIMING`, receipts from the real
   `check()` satisfy both the schema and `validate_receipt`, and over a mutation matrix the two agree on shape.
2. **Meaning.** `U6/replay.py` is a pure offline oracle (no GUI, process, clock or writes) that reduces a batch
   through C2.4/C2.6 to per-step outcomes, independent of `bin/evidence-u6.py`. Each negative trace asserts its
   exact step outcomes, scenario reason and deciding assertion, and that every other step passes.
3. **Invocation.** The replay CLI runs on the committed batches. Every one of the 96 traces the oracle judges
   also runs through the real `bin/evidence-u6.py --config --batch --package --kit-manifest` on the same batch
   bytes; `synthetic_batch.kit_batch()` adds only what the final entry reads beyond the batch (subject
   registration, `launch.json`, `prepared.json`, `synthetic-seed.json`, pointer plans, the menu helper's
   `menu-drive.jsonl`, `run.json`, a launched bundle, a pinned package zip and a kit manifest, as in
   `test_u6_evidence_chain.py`). Overall outcomes are compared.

## Replay oracle decisions

- Rows bind on (`runID`, `epoch`, `pid`) of the registered subject; others are ignored. Among the subject's rows,
  a schema-invalid row, a missing first `started` row, an unsupported protocol, an unparsable or truncated line
  makes the native stream unusable (NOT-RUN; C2.6 F): steps 1–6 and 8 are NOT-RUN and step 10 reports the cause. A
  non-increasing `seq` or decreasing `mono` is a contradiction: step 10 FAIL (C2.6 F).
- Duplicates are contradictions (FAIL): a second Refresh arrival in A, a second `requested` for R, a second
  terminal for R anywhere in the log (codex-kit-12), a second `accepted-clear` or `menu-scrubbed` for the clear.
- Step 3 (C2.6 D): an arrival after `menu-end(A)` is FAIL; `copilotAccountsBefore` ≠ 0 is FAIL; a second
  `accepted` or terminal for R is FAIL; a terminal outside 60 s of `requested` is NOT-RUN `timeout`; `failed` is
  FAIL with its reason; `abandoned` is NOT-RUN `timeout` (deadline) or `not-delivered` (stop). `deferred` and
  `completed` need one `accepted` between `requested` and the terminal (else NOT-RUN `accepted-missing`) whose
  `engineRequestID` equals `requested`'s (else FAIL `accepted-other-engine-request`, C2.7 D: another call's or a
  cached reply; an `accepted` for another session is NOT-RUN `accepted-stale`).
  `deferred` is NOT-RUN with the reason of the Copilot disposition (`cooldown` → `cooldown`; `read_only`,
  `offline` → `engine-disabled`; `policy_pending` → `consent-required`; `scheduled` would contradict it: FAIL).
  `completed` passes only when `accepted` scheduled Copilot (else FAIL), the projection qualifies
  (`copilotAccountsAfter` = 1, `readingSHA256` = the seed's, `rowsSequenceAfter` > n; a mismatch or more than one
  account is FAIL), the runtime-call copy exists, matches `result.json`'s `runtimeCallsSHA256` and every line is
  schema-valid and this run's (else NOT-RUN), no `account.getQuota` precedes `requested` (else FAIL: a preseeded
  log lands here too) and an `account.getQuota` call lies strictly between `requested` and `completed` (else
  FAIL); it may precede `accepted`, because production wakes the worker before returning the reply (C2.7 D). Earlier unrelated projections leave no row and are ignored.
- Step 6: C2.4's explicit FAIL predicates (B ended before `clear-initiated`; a later end of B without
  `cause: clear` and the same `clearID`; a recorded private item missing from or still private in `menu-scrubbed`;
  private content in the current menu; a seed-hash title for B or a later session after `accepted-clear`) are
  evaluated first and dominate. Then C2.6 E: `accepted-clear` or `menu-scrubbed` more than 5 s after
  `clear-initiated` is FAIL `timeout` (`clear-late`). Missing or unbound receipts are NOT-RUN, including B not in
  `openSessionIDs` or `scrubbedSessionIDs` (macrev-332-8). The clear is the first `clear-initiated` after B's title.
- Step 7 (C2.6 F): any non-pass claim of the runner (`steps` or `outcome`) is NOT-RUN with the runner's bounded
  `reason`; a claim never proves PASS. The finish record must follow the step 1–6 receipts and precede the stop row.
- Step 9: missing, schema-invalid, other-run or other-lease-window receipts are NOT-RUN and ignored (step 8 then
  lacks `subjectGone`); `ok: false` is NOT-RUN (macrev-332-5); a well-formed receipt that contradicts itself
  (`closure-failures-`, `-ok-`, `-time-`, `-window-inconsistent`) is FAIL `closure-inconsistent` (C2.6 F); a late
  closure or a start before the lease (`lease_window_ok` false) is FAIL `out-of-window` (C2.4 §4).
- Step 10: manifest pins different from the launched pins is FAIL (C2.4 §6).
- Overall: FAIL if any step fails, else NOT-RUN if any step is not run, else PASS.
- codex-kit-11 (exclusive final inventory) concerns `inventory_evidence.py`'s writes, not receipt meaning.

## Reading digest

`readingSHA256` (in `completed` and in `synthetic-seed.json`) is the SHA-256 of the UTF-8 canonical JSON (sorted
keys, separators `,` and `:`, no whitespace, non-ASCII kept) of the single Copilot account of the accepted
projection:

```
{"route": account.route, "plan": account.plan.id,
 "windows": [for every window, sorted by id: {"id", "limitKey", "poolKey",
             "remainingBp": round(remainingPercent * 100) as an integer, or null,
             "resetsAt": integer UNIX seconds, or null}]}
```

`round` is half away from zero (Swift `rounded()`; `synthetic_batch._basis_points`), applied to the scaled
double. `synthetic_batch.reading_sha256` is the reference; `test_reading_digest_vector` pins this vector:

```
account (projection):
{"route": "runtime", "plan": {"id": "copilot-pro"}, "windows": [
  {"id": "premium_interactions", "limitKey": "premium_interactions", "poolKey": "copilot",
   "remainingPercent": 62.5, "resetsAt": "2099-01-01T00:00:00Z"},
  {"id": "chat", "limitKey": "chat", "poolKey": "copilot", "remainingPercent": null, "resetsAt": null}]}
canonical bytes:
{"plan":"copilot-pro","route":"runtime","windows":[{"id":"chat","limitKey":"chat","poolKey":"copilot","remainingBp":null,"resetsAt":null},{"id":"premium_interactions","limitKey":"premium_interactions","poolKey":"copilot","remainingBp":6250,"resetsAt":4070908800}]}
readingSHA256:
c0ee46c2388e4722f519508dc441af086db96fe31cd3c4597d2392e9410589e4
```

The traces' seed reading (`SEED_READING_ACCOUNT`, one window at 75 % resetting 2099-01-01) hashes to
`803ad776281b661c306df2b0ce57dd330915d673d3c1950c7604a25122a63d3e`.

## Replay outcomes

| Trace | Source | Non-PASS steps (outcome / reason / detail) | Overall |
|---|---|---|---|
| `valid` | C2.4/C2.6 | none | pass |
| `valid-interleaved` (begin during press, terminal before end(A), no optional end(B), item deallocated, foreign-PID rows) | codex-kit-5, -12; macrev-332-10 | none | pass |
| `delayed-clear` (scrub 190 s after initiation) | codex-kit-3, C2.6 E | 6 FAIL / timeout / `clear-late` | fail |
| `production-handler-bypassed` | macrev-332-4, codex-kit-4 | 3 NOT-RUN / not-delivered / `requested-missing` | not-run |
| `separate-client-request` | macrev-332-4 | 3 FAIL / unknown / `requested-duplicate` | fail |
| `closure-missing` | macrev-332-5, codex-kit-1 | 8 NOT-RUN / not-delivered / `subject-not-gone`; 9 NOT-RUN / not-delivered / `closure-missing` | not-run |
| `closure-failed` | macrev-332-5 | 9 NOT-RUN / unknown / `closure-not-ok` | not-run |
| `closure-other-run` | macrev-332-5 | 8 NOT-RUN / not-delivered / `subject-not-gone`; 9 NOT-RUN / wrong-subject / `closure-other-run` | not-run |
| `closure-inconsistent` | macrev-332-5, SKILLS-CONSULT 7 | 8 NOT-RUN / not-delivered / `subject-not-gone`; 9 FAIL / unknown / `closure-inconsistent` | fail |
| `closure-truncated` | macrev-332-5 | 8 NOT-RUN / not-delivered / `subject-not-gone`; 9 NOT-RUN / unknown / `closure-malformed` | not-run |
| `clear-click-after-clear` | macrev-332-8 | 6 NOT-RUN / not-delivered / `clear-initiated-missing` | not-run |
| `clear-of-another-instance` | macrev-332-8 | 6 NOT-RUN / wrong-subject / `menu-b-not-open-at-clear` | not-run |
| `pointer-for-another-pid` | macrev-332-10, codex-kit-5 | 2 NOT-RUN / not-delivered / `click-missing`; 3,4,5,6 NOT-RUN `prerequisite-not-met` | not-run |
| `menu-begin-from-another-pid` | macrev-332-10, codex-kit-2 | 2 NOT-RUN / out-of-window / `menu-begin-out-of-window`; 3,4,5,6 NOT-RUN `prerequisite-not-met` | not-run |
| `menu-b-closed-before-clear` | macrev2-332-1, macrev-332-10 | 6 FAIL / unknown / `menu-b-ended-before-clear` | fail |
| `single-closed-menu-clear` | macrev2-332-1, codex-kit-3 | 4 NOT-RUN / not-delivered / `click-missing`; 5,6 NOT-RUN `prerequisite-not-met` | not-run |
| `stale-title-after-clear` | macrev-332-10, codex-kit-3 | 6 FAIL / unknown / `title-after-clear` | fail |
| `private-item-unreported` | macrev-332-10 | 6 FAIL / unknown / `private-item-unreported` | fail |
| `retained-original-item-private` | codex-kit-3 (C2 wrong-PASS trace) | 6 FAIL / unknown / `private-item-retained` | fail |
| `current-menu-still-private` | macrev-332-10 | 6 FAIL / unknown / `private-content-present` | fail |
| `reset-receipt-missing` | macrev-332-12, codex-kit-8 | 6 NOT-RUN / not-delivered / `reset-missing` | not-run |
| `reset-failed` | macrev-332-12, codex-kit-8 | 6 NOT-RUN / unknown / `reset-failed` | not-run |
| `reset-other-run` | macrev-332-12 | 6 NOT-RUN / wrong-subject / `reset-other-run` | not-run |
| `reset-other-home` | macrev-332-12 (wrong operation) | 6 NOT-RUN / wrong-subject / `reset-unbound` | not-run |
| `reset-other-helper` | macrev-332-12, codex-kit-10 | 6 NOT-RUN / wrong-subject / `reset-unbound` | not-run |
| `same-generation-other-store-epoch` | codex-kit-8, SKILLS-CONSULT 7 | 6 NOT-RUN / wrong-subject / `pair-mismatch` | not-run |
| `same-store-epoch-other-generation` | codex-kit-8 | 6 NOT-RUN / wrong-subject / `pair-mismatch` | not-run |
| `clear-initiated-other-pair` | codex-kit-8 | 6 NOT-RUN / wrong-subject / `pair-mismatch` | not-run |
| `accepted-clear-other-pair` | codex-kit-8 | 6 NOT-RUN / wrong-subject / `pair-mismatch` | not-run |
| `clear-initiated-outside-reset-window` | codex-kit-8 | 6 NOT-RUN / out-of-window / `clear-initiated-out-of-window` | not-run |
| `old-accepted-clear-shape` | macrev-332-14 | 10 NOT-RUN / unknown / `native-row-malformed`; 1,2,3,4,5,6,8 NOT-RUN `native-unusable` | not-run |
| `flat-c2.4-rows` | C2.6 F (the App envelope is the format) | 10 NOT-RUN / unknown / `native-row-malformed`; 1,2,3,4,5,6,8 NOT-RUN `native-unusable` | not-run |
| `closure-observed-after-expiry` | macrev-332-15, codex-kit-9 | 9 FAIL / out-of-window / `closure-late` | fail |
| `subject-started-before-lease` | codex-kit-9 | 9 FAIL / out-of-window / `closure-late` | fail |
| `closure-other-lease-window` | codex-kit-9, C2.6 F | 8 NOT-RUN / not-delivered / `subject-not-gone`; 9 NOT-RUN / wrong-subject / `lease-window-mismatch` | not-run |
| `physical-receipts-missing-runner-says-pass` | codex-kit-1 | 1 NOT-RUN / not-delivered / `dock-move-missing` | not-run |
| `capture-file-name-only` | codex-kit-5 | 1 NOT-RUN / not-delivered / `capture-missing` | not-run |
| `capture-bound-to-other-frame` | codex-kit-5 | 1 NOT-RUN / wrong-subject / `capture-unbound` | not-run |
| `capture-hash-mismatch` | codex-kit-5 | 1 FAIL / unknown / `capture-hash-mismatch` | fail |
| `dock-frame-late` | codex-kit-5 | 1 NOT-RUN / out-of-window / `dock-frame-out-of-window` | not-run |
| `menu-begin-before-button-down` | codex-kit-5 | 2 NOT-RUN / out-of-window / `menu-begin-out-of-window`; 3,4,5,6 NOT-RUN `prerequisite-not-met` | not-run |
| `menu-begin-after-click-deadline` | codex-kit-5 | 2 NOT-RUN / out-of-window / `menu-begin-out-of-window`; 3,4,5,6 NOT-RUN `prerequisite-not-met` | not-run |
| `foreign-pid-for-every-row` | codex-kit-2 | 10 NOT-RUN / not-delivered / `started-missing`; 1,2,3,4,5,6,8 NOT-RUN `native-unusable` | not-run |
| `descending-seq` | codex-kit-2 | 10 FAIL / unknown / `native-order-contradiction`; 1,2,3,4,5,6,8 NOT-RUN `native-unusable` | fail |
| `duplicate-seq` | codex-kit-2, SKILLS-CONSULT 7 | 10 FAIL / unknown / `native-order-contradiction`; 1,2,3,4,5,6,8 NOT-RUN `native-unusable` | fail |
| `truncated-native-record` | codex-kit-2, SKILLS-CONSULT 7 | 10 NOT-RUN / unknown / `native-truncated`; 1,2,3,4,5,6,8 NOT-RUN `native-unusable` | not-run |
| `unsupported-native-protocol` | SKILLS-CONSULT 1 | 10 NOT-RUN / unknown / `protocol-unsupported`; 1,2,3,4,5,6,8 NOT-RUN `native-unusable` | not-run |
| `native-observations-missing` | codex-kit-1 | 10 NOT-RUN / not-delivered / `native-missing`; 1,2,3,4,5,6,8 NOT-RUN `native-unusable` | not-run |
| `terminate-before-stop` | codex-kit-2 | 8 NOT-RUN / not-delivered / `terminate-missing` | not-run |
| `terminate-completed-missing` | C2.4 step 8 | 8 NOT-RUN / not-delivered / `terminate-missing` | not-run |
| `stop-row-from-another-pid` | codex-kit-2 | 8 NOT-RUN / not-delivered / `stop-missing` | not-run |
| `owner-preempted-instead-of-stop` | codex-kit-2 | 8 NOT-RUN / unknown / `owner-preempted` | not-run |
| `refresh-terminal-late` | codex-kit-4 | 3 NOT-RUN / timeout / `terminal-late` | not-run |
| `refresh-terminal-missing` | codex-kit-4 | 3 NOT-RUN / timeout / `terminal-missing` | not-run |
| `refresh-arrival-duplicate` | codex-kit-4 | 3 FAIL / unknown / `arrival-duplicate` | fail |
| `refresh-terminal-duplicate` | codex-kit-4, codex-kit-12 | 3 FAIL / unknown / `terminal-duplicate` | fail |
| `refresh-terminal-duplicate-outside-window` | codex-kit-12 | 3 FAIL / unknown / `terminal-duplicate` | fail |
| `refresh-failed` | C2.4 step 3 | 3 FAIL / engine-error / `refresh-failed` | fail |
| `refresh-rows-unchanged` | C2.4 step 3, C2.6 D (completed without the qualifying projection) | 3 FAIL / unknown / `projection-not-qualifying` | fail |
| `deferred-cooldown` | C2.6 D (deferred cooldown) | 3 NOT-RUN / cooldown / `refresh-deferred` | not-run |
| `deferred-read-only` | C2.6 D (deferred read_only) | 3 NOT-RUN / engine-disabled / `refresh-deferred` | not-run |
| `deferred-offline` | C2.6 D (deferred offline) | 3 NOT-RUN / engine-disabled / `refresh-deferred` | not-run |
| `deferred-policy-pending` | C2.6 D (deferred policy_pending) | 3 NOT-RUN / consent-required / `refresh-deferred` | not-run |
| `refresh-abandoned-deadline` | C2.6 D (watchdog deadline; also the unrelated-only advance: no completed) | 3 NOT-RUN / timeout / `refresh-abandoned-deadline` | not-run |
| `refresh-abandoned-stop` | C2.6 D (watchdog stop) | 3 NOT-RUN / not-delivered / `refresh-abandoned-stop` | not-run |
| `accepted-missing` | C2.6 D (no per-call reply) | 3 NOT-RUN / not-delivered / `accepted-missing` | not-run |
| `accepted-stale-snapshot` | C2.7 D FAIL: "`accepted` with another `engineRequestID`" (a stale scheduled value) | 3 FAIL / unknown / `accepted-other-engine-request` | fail |
| `accepted-duplicate` | C2.6 D, C2.6 F | 3 FAIL / unknown / `accepted-duplicate` | fail |
| `copilot-accounts-before-nonzero` | C2.6 D (not a first attempt) | 3 FAIL / unknown / `copilot-accounts-before` | fail |
| `completed-on-unrelated-projection` | C2.6 D (unrelated-only advance reported as completed) | 3 FAIL / unknown / `projection-not-qualifying` | fail |
| `completed-other-reading` | C2.6 D (readingSHA256 mismatch) | 3 FAIL / unknown / `projection-not-qualifying` | fail |
| `completed-two-accounts` | C2.6 D (more than one Copilot account) | 3 FAIL / unknown / `projection-not-qualifying` | fail |
| `unrelated-then-valid` | C2.6 D (earlier unrelated projections are ignored) | none | pass |
| `copilot-not-scheduled-but-completed` | C2.6 D, C2.6 F | 3 FAIL / unknown / `copilot-not-scheduled` | fail |
| `stub-call-missing` | C2.6 D | 3 FAIL / unknown / `quota-call-missing` | fail |
| `quota-call-after-completed` | C2.6 D | 3 FAIL / unknown / `quota-call-missing` | fail |
| `quota-call-before-accepted` | C2.7 D (the worker is woken before the reply returns) | none | pass |
| `call-before-requested` | C2.7 D | 3 FAIL / unknown / `call-before-requested` | fail |
| `connect-before-accepted` | C2.6 D (connect before the reply) | none | pass |
| `auth-before-accepted-is-legal` | C2.6 coordinator clarification (only quota is ordered after accepted) | none | pass |
| `accepted-other-engine-request` | C2.7 D FAIL: "`accepted` with another `engineRequestID`" | 3 FAIL / unknown / `accepted-other-engine-request` | fail |
| `runtime-calls-preseeded` | C2.6 C-D (the log must be absent in the seed) | 3 FAIL / unknown / `call-before-requested` | fail |
| `runtime-calls-foreign` | C2.6 D, C2.4 section 1 | 3 NOT-RUN / wrong-subject / `runtime-calls-foreign` | not-run |
| `runtime-calls-missing` | C2.6 D | 3 NOT-RUN / not-delivered / `runtime-calls-missing` | not-run |
| `runtime-calls-digest-mismatch` | C2.6 D | 3 NOT-RUN / not-delivered / `runtime-calls-undigested` | not-run |
| `runtime-calls-undigested` | C2.6 D (result.json without the digest) | 3 NOT-RUN / not-delivered / `runtime-calls-undigested` | not-run |
| `accepted-clear-late` | C2.6 E | 6 FAIL / timeout / `clear-late` | fail |
| `menu-scrubbed-late` | C2.6 E | 6 FAIL / timeout / `clear-late` | fail |
| `menu-a-ended-before-arrival` | codex-kit-12 | 3 FAIL / unknown / `arrival-after-menu-end` | fail |
| `menu-b-reuses-session-a` | codex-kit-6 | 4 NOT-RUN / wrong-subject / `session-reused`; 5,6 NOT-RUN `prerequisite-not-met` | not-run |
| `click-b-before-a-ended` | C2.4 step 4 | 4 NOT-RUN / out-of-window / `click-b-before-a-ended`; 5,6 NOT-RUN `prerequisite-not-met` | not-run |
| `title-hash-not-seed` | C2.4 step 5 | 5 NOT-RUN / wrong-subject / `title-hash-mismatch`; 6 NOT-RUN `prerequisite-not-met` | not-run |
| `title-only-in-session-a` | C2.4 steps 5-6 | 5 NOT-RUN / not-delivered / `title-missing`; 6 NOT-RUN `prerequisite-not-met` | not-run |
| `finish-missing` | codex-kit-7 | 7 NOT-RUN / not-delivered / `finish-missing` | not-run |
| `runner-reported-failure` | codex-kit-7 | 7 NOT-RUN / not-delivered / `runner-reported-fail` | not-run |
| `runner-reported-not-run` | codex-kit-7 (what U6/action_runner.py writes on a failed action) | 7 NOT-RUN / not-delivered / `runner-reported-not-run` | not-run |
| `finish-before-receipts` | codex-kit-7 | 7 NOT-RUN / out-of-window / `finish-before-receipts` | not-run |
| `engine-pin-changed` | codex-kit-10 | 10 FAIL / unknown / `pin-changed` | fail |

## Fixtures and provenance

`fixtures/batches/valid` and `fixtures/batches/valid-interleaved` are complete batches with their
`context.json`; [fixtures/provenance.json](fixtures/provenance.json) records each file's schema, producer and
status. Real producers (`generated: true`): `launch-cleanup.json` (the real `check_launch_cleanup.check()` on a
synthetic closed run with a fixed lease clock) and, since C2.6 F, `dock-capture.json`, `consent-reset.json` and
`operator-finish.json`, written by `U6/capture_owned.py`, `U6/consent_reset.py` and `U6/action_runner.py` on the
trace's native rows up to that moment, with fakes only for admission/subject identity, `screencapture`, the
helper process and the uptime clock (`synthetic_batch.shipped_receipts`; the reset's `homeSHA256` of the temporary
HOME path is rebased to the context's). `test_fixture_receipts_are_the_shipped_writers_output` keeps the in-memory
traces equal to them. Authored (`pending-producer-capture`): native rows (Swift App), pointer rows (Swift
pointer_drive), `runtime-calls.jsonl` and `result.json` (stub writer and Drive copy, not written yet). Negative traces are mutations in
the test file with independently stated expectations.

Regenerate (the drift test compares byte for byte):

```sh
python3 -B desktop/native/verification/U6/synthetic_batch.py --write schema/verification/fixtures
```

Swift captures still to add (then flip those entries to `generated: true`): native rows via
`swift test --package-path desktop/native/ModelPlanAppIntegration --filter U6ReceiptFixtureCaptureTests` (the
`emitObject` serializer with injected uptime, clock and IDs) and pointer rows via `pointer_drive
--fixture-receipts <plan>` (`PointerDrive.append` with an injected clock, posting nothing).

## Producer changes required by C2.6

Against #332 6a063beb (`U6DriveGuard.swift`, `pointer_drive.swift` unchanged since 8f857aa6; line numbers there).

Closed by C2.6 F (the schemas adopt the current shapes): the former items 1–4, 6, 9, 10 and 12 (envelope, no
`protocol`, `instanceID`/`subjectPID`/`menuInstanceID`/`nativeUptimeSeconds`, pointer `event`/`kind`, ISO
`timestamp`, unbound permission and `postEvents-not-granted` rows). Done earlier: 7 (deadline anchored at
`requested` `mono`) and 11 (click `mono` sampled at the posts).

App (`desktop/native/ModelPlanAppIntegration/Sources/ModelPlanAppIntegration/U6DriveGuard.swift`):

1. **C2.6 D, `requested`** (`:156-157`): add `copilotAccountsBefore` (Copilot accounts in the last accepted
   projection with sequence ≤ n) and the `engineRequestID` of the call it is about to make.
2. **C2.6 D, `accepted`**: new row from the completion of that `refresh/request` call (the same
   `engineRequestID`, `dispositions` from the per-call reply), before any terminal.
3. **C2.6 D, terminals** (`:158-189`): `completed` only for an accepted projection with sequence > n showing the
   seed's Copilot reading (`copilotAccountsAfter`, `readingSHA256`, its `rowsSequenceAfter`), ignoring other
   advances; `deferred` when `accepted` does not schedule Copilot; the watchdog writes `abandoned` (`deadline` /
   `stop`, the former item 13), never `failed`/`timeout`; `failed` only for a production error (`:168`).
4. **Former item 5** (`:102`, `:142`, `:299`): an untracked end, arrival or scrub writes `sessionID: ""` /
   `menuObjectID: ""`, which fails the schema and makes the whole native stream NOT-RUN. Skip the row instead.
5. **Former item 8** (`:91`): `privateItemIDs` lists only `menu.items[0]`; C2.4 step 5 asks for every item object
   showing private content.

Seed and Drive (C2.6 C-D):

6. The seeded stub appends `runtime-calls/1` lines to `$HOME/.modelplan-stub/runtime-calls.jsonl` with its seeded
   run binding; the log is absent in the seed (`prepare_config.py`, stub).
7. `drive-u6.py`: before removing HOME, copy it to `$BATCH/runtime-calls.jsonl` and record its SHA-256 in
   `result.json` (`runtimeCallsSHA256`).

Observation, outside the schema: with the guard attached, `EngineDockMenuApplication.swift:126-133` skips
`composition.refresh` when no arrival context is seen within 0.5 s (no `requested` → NOT-RUN).

## evidence-u6 changes required by C2.7

Current integration is **incomplete; no runnable kit or GO**. The legacy C2.3 fixtures are retired with
replacement coverage as explained below. Producer fixture capture, head-built package-level CI proof and
the complete cooldown regression are still pending. The divergence table
below records the historical baseline (6a063beb); `test_disagreement_table_is_exact` keeps each expected outcome
as a regression against both the independent oracle and the final CLI.

**Closed since #332 a1d746fc** (`DISAGREEMENTS` is empty; every trace still runs through the real CLI):

- `accepted-stale-snapshot`, `accepted-other-engine-request`: `accepted.engineRequestID` ≠ `requested`'s →
  FAIL. C2.7 D FAIL: "`accepted` with another `engineRequestID`".
- `quota-call-before-accepted`: an `account.getQuota` call between `requested` and `accepted` is legal → PASS
  C2.7 D PASS: "`account.getQuota` with `mono` after
  `requested` and before `completed` (... the call may precede `accepted`)"; FAIL only "an `account.getQuota`
  call logged before `requested`".

Coordinator clarifications applied after the pinned oracle branch (C2.6; C2.7 supersedes the call window):
requested and accepted must share the pre-send engineRequestID; the result digest key is runtimeCallsSHA256. readingSHA256 replaces accountIDSHA256 and
fingerprints exactly one accepted Copilot account's route, plan.id and windows sorted by id.
Each window contributes id, limitKey, poolKey, remainingBp (integer, nearest with ties away
from zero) and resetsAt (integer UNIX seconds), preserving nulls. Sorted-key compact UTF-8
JSON is hashed. Read-time fields are excluded. The Python/Swift fixed vector is
92c7f08d9a030f3b6d3409c7698da1b5d0454f773983308d20c7908eb3841a4e. `U6/reading_fingerprint.py` also reproduces
the [Reading digest](#reading-digest) vector (c0ee46c2…) and the traces' seed reading (803ad776…).

`bin/evidence-u6.py` / `U6/evidence_chain.py` at #332 6a063beb (unchanged since 8f857aa6) agree with the oracle on
68 of 96 traces; the 28 below (plus `quota-call-before-accepted` and M4's `accepted-other-engine-request`) were
the historical baseline. All listed evaluator changes now have passing exact-outcome regressions:

1. Closure of another run → NOT-RUN, not FAIL (`validate_receipt(closure, run, epoch)`'s `closure-other-run`
   is raised as a contradiction).
2. Closure whose `leaseNotBefore`/`leaseExpiresAt` differ from `expectedLease` → NOT-RUN (not compared today).
3. Validate every receipt against `schema/verification` (closed `checks`): a schema-invalid row → NOT-RUN.
4. `started.checks.protocol` other than `u6-native/1` → NOT-RUN `unknown`.
5. Non-increasing `seq` / decreasing `mono` → FAIL (`native_rows` raises Missing today).
6. Refresh arrival after A's `menu-end` → FAIL (today NOT-RUN: `end_a` lookup requires `seq` > arrival).
7. Terminal beyond 60 s → NOT-RUN `timeout` (today FAIL `out-of-window`).
8. C2.6 D: read `accepted` (one, between `requested` and the terminal, not reused), `copilotAccountsBefore` = 0,
   `deferred` (NOT-RUN by disposition: `cooldown`, `engine-disabled`, `consent-required`), `abandoned` (NOT-RUN
   `timeout` / `not-delivered`), the `engineRequestID` echo (a mismatch is FAIL, C2.7 D), the qualifying `completed` (`copilotAccountsAfter` = 1, `readingSHA256`,
   advance; else FAIL, including today's NOT-RUN for an unchanged sequence), and `$BATCH/runtime-calls.jsonl`
   against `result.json`'s `runtimeCallsSHA256` and the run binding (else NOT-RUN), no `account.getQuota` before `requested` and
   `account.getQuota` between `requested` and `completed` (else FAIL; C2.7 D); add `cooldown` to `CODES`.
9. C2.6 E: `accepted-clear` and `menu-scrubbed` within 5 s of `clear-initiated`, late → FAIL `timeout`.

| Trace | Oracle (C2.7) | evidence-u6 | Deciding text |
| --- | --- | --- | --- |
| `closure-other-run` | not-run | fail | C2.6 F: "A receipt that fails its schema, names another run/epoch/PID or lease window → NOT-RUN" |
| `closure-other-lease-window` | not-run | pass | C2.6 F: "A receipt that fails its schema, names another run/epoch/PID or lease window → NOT-RUN" |
| `old-accepted-clear-shape` | not-run | pass | C2.6 F: "A receipt that fails its schema, names another run/epoch/PID or lease window → NOT-RUN" (closed checks schema) |
| `unsupported-native-protocol` | not-run | pass | C2.6 F: "An unknown native protocol version → NOT-RUN unknown" |
| `descending-seq` | fail | not-run | C2.6 F: "Two valid receipts that contradict each other (including ... descending/duplicate seq) → FAIL" |
| `duplicate-seq` | fail | not-run | C2.6 F: "Two valid receipts that contradict each other (including ... descending/duplicate seq) → FAIL" |
| `menu-a-ended-before-arrival` | fail | not-run | C2.4 step 3: "menu-end for A ... must follow the action arrival"; C2.4 step 10: "contradiction → FAIL" |
| `refresh-terminal-late` | not-run | fail | C2.6 D: "Exactly one terminal row for R within 60 s"; NOT-RUN: "no terminal" |
| `refresh-rows-unchanged` | fail | not-run | C2.6 D FAIL: "completed without the qualifying projection or without a matching account.getQuota call" |
| `accepted-missing` | not-run | pass | C2.6 D NOT-RUN: "no accepted, or a missing/foreign/undigested runtime-call receipt" |
| `accepted-stale-snapshot` | fail | pass | C2.7 D FAIL: "`accepted` with another `engineRequestID`" |
| `accepted-other-engine-request` | fail | not-run | C2.7 D FAIL: "`accepted` with another `engineRequestID`" |
| `accepted-duplicate` | fail | pass | C2.6 F: "Two valid receipts that contradict each other (including ... descending/duplicate seq) → FAIL" |
| `copilot-accounts-before-nonzero` | fail | pass | C2.6 D FAIL: "copilotAccountsBefore ≠ 0" |
| `completed-on-unrelated-projection` | fail | pass | C2.6 D FAIL: "completed without the qualifying projection or without a matching account.getQuota call" |
| `completed-other-reading` | fail | pass | C2.6 D FAIL: "completed without the qualifying projection or without a matching account.getQuota call" |
| `completed-two-accounts` | fail | pass | C2.6 D (binding decision): copilotAccountsAfter must be 1 |
| `copilot-not-scheduled-but-completed` | fail | pass | C2.6 D PASS needs accepted "scheduled"; C2.6 F: "Two valid receipts that contradict each other (including ... descending/duplicate seq) → FAIL" |
| `stub-call-missing` | fail | pass | C2.6 D FAIL: "completed without the qualifying projection or without a matching account.getQuota call" |
| `quota-call-after-completed` | fail | pass | C2.6 D FAIL: "completed without the qualifying projection or without a matching account.getQuota call" |
| `call-before-requested` | fail | pass | C2.7 D FAIL: an account.getQuota call before requested |
| `quota-call-before-accepted` | pass | fail | C2.7 D PASS: "account.getQuota with mono after requested and before completed (... the call may precede accepted)" |
| `runtime-calls-preseeded` | fail | pass | C2.7 D FAIL: an account.getQuota call before requested; C2.6 C: "The log is absent in the seed" |
| `runtime-calls-foreign` | not-run | pass | C2.6 D NOT-RUN: "no accepted, or a missing/foreign/undigested runtime-call receipt" |
| `runtime-calls-missing` | not-run | pass | C2.6 D NOT-RUN: "no accepted, or a missing/foreign/undigested runtime-call receipt" |
| `runtime-calls-digest-mismatch` | not-run | pass | C2.6 D NOT-RUN: "no accepted, or a missing/foreign/undigested runtime-call receipt" |
| `runtime-calls-undigested` | not-run | pass | C2.6 D NOT-RUN: "no accepted, or a missing/foreign/undigested runtime-call receipt" |
| `delayed-clear` | fail | pass | C2.6 E: "accepted-clear and menu-scrubbed for B within 5 s of clear-initiated. Late → FAIL timeout" |
| `accepted-clear-late` | fail | pass | C2.6 E: "accepted-clear and menu-scrubbed for B within 5 s of clear-initiated. Late → FAIL timeout" |
| `menu-scrubbed-late` | fail | pass | C2.6 E: "accepted-clear and menu-scrubbed for B within 5 s of clear-initiated. Late → FAIL timeout" |

The oracle also differs on reasons and on which step it names (evidence-u6 reports the first failing step only);
only overall outcomes are compared.

## Run

### Retired C2.3 fixture tests

The coordinator explicitly allowed making the four legacy failures pass or retiring them with a reason.
`verification/test_u6_evidence_chain.py` and `verification/test_u6_evidence.py` are retired: their C2.3
positive fixture has no C2.7 requested/accepted correlation or reading/stub proof, and its abbreviated
native rows fail the closed schema before their intended corruption is evaluated. Their non-PASS-only
mutation checks are superseded by the complete C2.7 matrix in `tests/test_u6_receipt_schema.py`, which
requires the exact independently specified PASS/FAIL/NOT-RUN for every trace through the real final CLI.
This includes the legacy closure contradictions, late clear, unchanged rows, wrong PID, missing input,
wrong frame, duplicate terminal, wrong reset correlation, private retained item and stale-title cases.
`test_u6_final_manifest.py` retains the final-manifest pins, wrong bundle member and caller-boolean tests.
Retirement is not a passing result for the old tests, and no expected outcome in the replacement matrix
is weakened.

```sh
python3 -B -m unittest discover -s desktop/native/verification/tests -p 'test_u6_receipt_schema.py'
python3 -B desktop/native/verification/U6/replay.py --context schema/verification/fixtures/batches/valid/context.json \
  --batch schema/verification/fixtures/batches/valid
```

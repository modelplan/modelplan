<!-- SPDX-License-Identifier: MIT -->
# U6 verification receipt contract

These Draft 2020-12 schemas describe only what the U6 Dock/menu drive emits and consumes, as specified by
`desktop/native/verification/U6-DockMenu-Drive.md`, section "Evidence and timing contract (C2.4)". They follow
the [App–CLI contract](../app-cli/README.md) pattern: versioned schemas, fixtures with recorded provenance, a
drift check, and contract tests. `common.json` holds the shared identity, clock and code definitions.

Where the current Swift or Python differs from C2.4, the schemas follow C2.4; each difference is listed under
[Required producer changes](#required-producer-changes) with its status at the merged #332 head (8f857aa6).
Nothing here changes a producer.

| Schema | Batch file | Producer | Consumers |
| --- | --- | --- | --- |
| [native-row.json](native-row.json) + one schema per kind in `x-kinds` ([native/](native/)) | `native-observations.jsonl` | `U6DriveGuard.emitObject` (test build) | drive-u6, u6-pointer-plan, evidence-u6, evidence_receipt, replay |
| [pointer-receipt.json](pointer-receipt.json) | `dock-pointer.jsonl`, `status-pointer.jsonl`, `status-pointer-clear.jsonl` | `bin/pointer_drive.swift` | u6-pointer-plan, evidence, replay |
| [capture-receipt.json](capture-receipt.json) (`u6-capture/1`) | `dock-capture.json` | `U6/capture_owned.py` | evidence, replay |
| [consent-reset.json](consent-reset.json) (`consent-reset/1`) | `consent-reset.json` | `U6/consent_reset.py` | evidence, replay |
| [u6-actions.json](u6-actions.json) (`u6-actions/1`) | `operator-finish.json` | `U6/action_runner.py` | drive-u6, evidence, replay |
| [launch-cleanup.json](launch-cleanup.json) (`launch-cleanup/1`) | `launch-cleanup.json` | `bin/check_launch_cleanup.py` | evidence-u6, evidence_receipt, replay |
| [replay-context.json](replay-context.json) (`u6-replay-context/1`) | replay input only | derived from the run files (subject, lease, seed title hash, HOME hash, manifest and launched pins) | replay |

Native kinds: `started`, `doctor` (guard tick, not a step input), `dock-surface-frame`, `status-item-frame`,
`menu-begin`, `menu-end` (`cause` with `clearID` iff `clear`), `menu-private-title-visible` (`titleSHA256`,
`privateItemIDs`), `status-menu-action-arrived`, `refresh` (`requested` | `completed` | `failed`),
`clear-initiated`, `accepted-clear`, `menu-scrubbed` (per session, per recorded item), `stop-or-lease-expired` /
`owner-preempted` (one schema; only the first satisfies step 8) and `terminate-completed`.

## Versioning and compatibility

Every native row is one flat object: the envelope `runID`, `epoch`, `pid`, `seq` (integer ≥ 1, strictly
increasing per process), `mono` (fractional `ProcessInfo.systemUptime` seconds), `at` (UNIX seconds, informational
only) and `kind`, plus that kind's fields. Pointer rows carry `kind`, `runID`, `epoch`, `targetPID`, `mono`, `at`.
Each stream names its protocol once (`started.protocol` = `u6-native/1`, `pointer-host-permission.protocol` =
`u6-pointer/1`); each single-object receipt names its `schema`.

- **Frozen meanings.** Identity (run/epoch/PID binding, `menuObjectID` vs `sessionID`, `requestId`, `clearID`),
  clocks and ordering (`seq` within the app, `mono` across processes, `at` never), the reset correlation pair
  (`storeEpochAfter`, `generationAfter`), the retained-item proof and every outcome/reason vocabulary are frozen
  for a protocol version. Changing any of them, or the meaning of an existing field, needs a new version
  (`u6-native/2`, `consent-reset/2`, …) with the producer, schema, fixtures and consumers changed in one reviewed
  change. A stream of an unsupported version can never satisfy acceptance (the replay reports NOT-RUN).
- **Additive metadata.** Objects are closed (`additionalProperties: false`): an optional field is added to the
  schema and fixtures in the same change as the producer. Until then the replay treats the row as malformed and
  fails closed, so a producer cannot silently drift.
- **Unknown kinds** pass the envelope only and never satisfy a step.
- Free engine/exception text never appears; reasons use `common.json#/$defs/scenarioReason` (C2.4 §5).

## Three checks

`desktop/native/verification/tests/test_u6_receipt_schema.py` (stdlib only; the repository has no `jsonschema`
dependency, so `desktop/native/verification/U6/receipt_schema.py` implements exactly the keyword subset these
schemas use and refuses any other keyword):

1. **Shape.** Every schema is Draft 2020-12, closed and resolvable; every native kind schema carries the envelope.
   All positive fixtures validate, every schema has a positive instance, and removing any required identity,
   clock, session, reset-pair or item-proof field is rejected. For `launch-cleanup/1` the schema's keys equal
   `check_launch_cleanup.KEYS`/`CHECKS`/`TIMING`, receipts from the real `check()` (closed, failed controller,
   missing statuses, late closure, start before lease) satisfy both the schema and `validate_receipt`, and over a
   mutation matrix a schema rejection always implies a validator rejection while every validator shape code implies
   a schema rejection; the remaining codes (`closure-*-inconsistent`) are meaning, judged by the validator.
2. **Meaning.** `desktop/native/verification/U6/replay.py` is a pure offline oracle (no GUI, process, clock or
   writes) that reduces a batch through C2.4 to per-step outcomes. It is independent of `bin/evidence-u6.py`.
   Each negative trace asserts its exact step outcomes, scenario reason and deciding assertion, and that every other
   step passes; key assertions were mutation-checked (removing one makes a named trace fail).
3. **Invocation.** The replay CLI runs on the committed batches. Every trace the oracle judges (both positive
   batches, `delayed-clear` and every negative trace) also runs through the real `bin/evidence-u6.py --config
   --batch --package --kit-manifest`: `synthetic_batch.kit_batch()` renders the same trace in the head's encoding
   (legacy native envelope, pointer `event`/`kind`, `menu-drive.jsonl`, the subject registration, `launch.json`,
   `prepared.json`, `synthetic-seed.json`, pointer plans, `run.json`, a launched bundle, a pinned package zip and
   a kit manifest, built like `test_u6_evidence_chain.py`). Overall outcomes are compared; each divergence is in
   the table under [evidence-u6 disagreements](#evidence-u6-disagreements).

## Replay oracle decisions where C2.4 is silent

- Rows bind on (`runID`, `epoch`, `pid`) of the registered subject; others are ignored. Among the subject's rows,
  a malformed row (schema), a missing first `started` row, an unsupported protocol, an unparsable or truncated line
  makes the native stream unusable: steps 1–6 and 8 are NOT-RUN and step 10 reports the cause. A non-increasing
  `seq` or decreasing `mono` is a contradiction: step 10 FAIL.
- Duplicates are contradictions (FAIL): a second Refresh arrival in A, a second `requested` for R, a second
  terminal for R anywhere in the log (codex-kit-12), a second `accepted-clear` or `menu-scrubbed` for the clear.
- Step 3: an arrival after `menu-end(A)` is FAIL; `completed` with `rowsSequenceAfter` ≤ `rowsSequenceBefore` is
  NOT-RUN ("unchanged empty state never passes"); a terminal outside 60 s of `requested` is NOT-RUN `timeout`.
- Step 6: C2.4's explicit FAIL predicates (B ended before `clear-initiated`; a later end of B without
  `cause: clear` and the same `clearID`; a recorded private item missing from or still private in `menu-scrubbed`;
  private content in the current menu; a seed-hash title for B or a later session after `accepted-clear`) are
  evaluated first and dominate. Missing or unbound receipts are NOT-RUN, including B not in `openSessionIDs` or
  `scrubbedSessionIDs` (macrev-332-8 asks for NOT-RUN). The clear is the first `clear-initiated` after B's title.
- Step 7 takes the runner's worst claimed outcome over `steps` and `outcome` (a claim never proves PASS), with the
  runner's bounded `reason`; the finish record must follow the step 1–6 receipts and precede the stop row.
- Step 9: missing, malformed (schema or a `validate_receipt` shape code), other-run and `ok: false` receipts are
  NOT-RUN (macrev-332-5). A well-formed receipt that contradicts itself (`closure-failures-inconsistent`,
  `-ok-`, `-time-`, `-window-inconsistent`) is FAIL `closure-inconsistent` (step 10: "contradiction → FAIL"; changed
  after the 8f857aa6 differential, where evidence-u6 reports FAIL). A lease window different from the run's, or `lease_window_ok` false (late closure or
  start before the lease), is FAIL `out-of-window` (macrev-332-15, codex-kit-9). Step 8 needs `subjectGone` from a
  valid, run-bound receipt.
- Step 10: manifest pins different from the launched pins is FAIL (C2.4 §6).
- Overall: FAIL if any step fails, else NOT-RUN if any step is not run, else PASS.
- **Open contract point:** C2.4 bounds `clear-initiated` against the helper window ("`mono` in [`startMono`,
  `endMono` + 5 s]") but sets no completion bound for `accepted-clear`/`menu-scrubbed` (codex-kit-3 timing,
  KIT-REVIEW C2.2 amendment 1). The oracle follows C2.4 and only orders them after `clear-initiated` (by `seq`), so a
  scrub 190 s later passes step 6; `test_contract_gap_delayed_clear_still_passes_under_c2_4` documents the PASS.
  evidence-u6 has no bound either (`delayed-clear` passes both). Only the shipped action runner bounds it in
  practice (it waits 5 s for `accepted-clear`, then 5 s for `menu-scrubbed`, else NOT-RUN step 7). Recommended
  amendment: `0 ≤ mono(accepted-clear) − mono(clear-initiated) ≤ 5` and `menu-scrubbed` within the same 5 s, late
  → FAIL `timeout` (the private menu demonstrably stayed populated after the reset; unlike a missing refresh
  terminal this is product behaviour, not missing evidence), absent → NOT-RUN. 5 s matches the existing
  clear-initiated slack and the runner's waits; the scrub is synchronous on the main thread (≈ 50 ms in the traces).
- codex-kit-11 (exclusive final inventory) concerns `inventory_evidence.py`'s writes, not receipt meaning; it is not
  a replay trace.

## Replay outcomes

| Trace | Source | Non-PASS steps (outcome / reason / detail) | Overall |
|---|---|---|---|
| `valid` | C2.4 | none | pass |
| `valid-interleaved` (begin during press, terminal before end(A), no optional end(B), item deallocated, foreign-PID rows) | codex-kit-5, -12; macrev-332-10 | none | pass |
| `delayed-clear` (scrub 190 s after initiation) | codex-kit-3 timing, open | none (C2.4 sets no bound) | pass |
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
| `current-legacy-envelope` | macrev-332-10, macrev-332-14, codex-kit-2 | 10 NOT-RUN / unknown / `native-row-malformed`; 1,2,3,4,5,6,8 NOT-RUN `native-unusable` | not-run |
| `closure-observed-after-expiry` | macrev-332-15, codex-kit-9 | 9 FAIL / out-of-window / `closure-late` | fail |
| `subject-started-before-lease` | codex-kit-9 | 9 FAIL / out-of-window / `closure-late` | fail |
| `closure-other-lease-window` | codex-kit-9 | 9 FAIL / unknown / `lease-window-mismatch` | fail |
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
| `refresh-rows-unchanged` | C2.4 step 3 (unchanged empty state) | 3 NOT-RUN / unknown / `rows-unchanged` | not-run |
| `menu-a-ended-before-arrival` | codex-kit-12 | 3 FAIL / unknown / `arrival-after-menu-end` | fail |
| `menu-b-reuses-session-a` | codex-kit-6 | 4 NOT-RUN / wrong-subject / `session-reused`; 5,6 NOT-RUN `prerequisite-not-met` | not-run |
| `click-b-before-a-ended` | C2.4 step 4 | 4 NOT-RUN / out-of-window / `click-b-before-a-ended`; 5,6 NOT-RUN `prerequisite-not-met` | not-run |
| `title-hash-not-seed` | C2.4 step 5 | 5 NOT-RUN / wrong-subject / `title-hash-mismatch`; 6 NOT-RUN `prerequisite-not-met` | not-run |
| `title-only-in-session-a` | C2.4 steps 5-6 | 5 NOT-RUN / not-delivered / `title-missing`; 6 NOT-RUN `prerequisite-not-met` | not-run |
| `finish-missing` | codex-kit-7 | 7 NOT-RUN / not-delivered / `finish-missing` | not-run |
| `runner-reported-failure` | codex-kit-7 | 7 FAIL / not-delivered / `runner-reported-fail` | fail |
| `runner-reported-not-run` (what `action_runner.py` writes on a failed action) | codex-kit-7 | 7 NOT-RUN / not-delivered / `runner-reported-not-run` | not-run |
| `finish-before-receipts` | codex-kit-7 | 7 NOT-RUN / out-of-window / `finish-before-receipts` | not-run |
| `engine-pin-changed` | codex-kit-10 | 10 FAIL / unknown / `pin-changed` | fail |

## Fixtures and provenance

`fixtures/batches/valid` and `fixtures/batches/valid-interleaved` are complete batches with their
`context.json`. [fixtures/provenance.json](fixtures/provenance.json) records each file's schema, producer and
status. `launch-cleanup.json` is `generated: true`: the real `check_launch_cleanup.check()` on a synthetic closed
run with a fixed lease clock. The native, pointer, capture, reset and finish files are `generated: false,
pending-producer-capture`: native and pointer rows are authored to the flat C2.4 encoding the producers do not
write yet; capture, reset and finish mirror the shipped writers' field sets but are not captured from them (their
writers read the legacy native envelope, so a capture waits for producer change 1). Negative traces are mutations in the test file with independently stated expectations; no verdict is derived
from the oracle.

Regenerate (the drift test compares byte for byte):

```sh
python3 -B desktop/native/verification/U6/synthetic_batch.py --write schema/verification/fixtures
```

Capture commands M4 should add, so the positive files come from the shipped serializers with injected
deterministic clocks and IDs (then flip each entry to `generated: true` and keep the drift test):

- native rows: `swift test --package-path desktop/native/ModelPlanAppIntegration --filter U6ReceiptFixtureCaptureTests`
  — drives the U6DriveGuard row serializer (factored so uptime, clock, UUID and object IDs are injectable) through
  the C2.4 sequence and writes `native-observations.jsonl` for both batches;
- pointer rows: `pointer_drive --fixture-receipts <plan>` — writes a plan's rows through `PointerDrive.append`
  with an injected uptime/clock, posting no event and querying no permission (runs in the existing macOS
  pointer-helper job);
- capture, consent-reset and finish receipts: a `--fixture` mode of each shipped wrapper (`consent-reset` around a
  fake helper printing the real `{storeEpoch, generation}` output).


## Fixtures and provenance

`fixtures/batches/valid` and `fixtures/batches/valid-interleaved` are complete batches with their
`context.json`. [fixtures/provenance.json](fixtures/provenance.json) records each file's schema, producer and
status. `launch-cleanup.json` is `generated: true`: the real `check_launch_cleanup.check()` on a synthetic closed
run with a fixed lease clock. The native, pointer, capture, reset and finish files are `generated: false,
pending-producer-capture`: they are authored to the C2.4 shapes because their producers do not emit those shapes
yet. Negative traces are mutations in the test file with independently stated expectations; no verdict is derived
from the oracle.

Regenerate (the drift test compares byte for byte):

```sh
python3 -B desktop/native/verification/U6/synthetic_batch.py --write schema/verification/fixtures
```

Capture commands M4 should add, so the positive files come from the shipped serializers with injected
deterministic clocks and IDs (then flip each entry to `generated: true` and keep the drift test):

- native rows: `swift test --package-path desktop/native/ModelPlanAppIntegration --filter U6ReceiptFixtureCaptureTests`
  — drives the U6DriveGuard row serializer (factored so uptime, clock, UUID and object IDs are injectable) through
  the C2.4 sequence and writes `native-observations.jsonl` for both batches;
- pointer rows: `pointer_drive --fixture-receipts <plan>` — writes a plan's rows through `PointerDrive.append`
  with an injected uptime/clock, posting no event and querying no permission (runs in the existing macOS
  pointer-helper job);
- capture, consent-reset and finish receipts: a `--fixture` mode of each shipped wrapper (`consent-reset` around a
  fake helper printing the real `{storeEpoch, generation}` output).

## Required producer changes

Status at the merged #332 head 8f857aa6 (first listed against a98b25a3). Line numbers are at 8f857aa6.

Swift (`desktop/native/ModelPlanAppIntegration/Sources/ModelPlanAppIntegration/U6DriveGuard.swift` unless noted):

1. **Open.** `:250-262` `emitObject` still writes `{…envelope, event, timestamp, checks:{…}}` for every kind
   except `refresh` (`:255-257`). Write one flat object: envelope + `kind` + the kind's fields; drop `event`,
   `timestamp`, `checks`. C2.4 names the fields, not their nesting, so this is the schemas' encoding choice; but
   until it lands (or the schemas adopt the envelope, a coordinator decision) the oracle cannot judge a real head
   batch (`test_oracle_refuses_the_head_native_encoding`). Every consumer at the head reads the envelope
   consistently (`evidence_chain.py`, `u6-pointer-plan.py`, `consent_reset.py`, `capture_owned.py`,
   `action_runner.py`, `drive-u6.py:109`, `:117`), so changing it is one coordinated producer+consumer change.
2. **Open.** `:71` `started` carries no `protocol: "u6-native/1"`.
3. **Open.** `:86-88` `menu-begin` still carries `instanceID` and `subjectPID`.
4. **Open.** `:95` `menu-private-title-visible` and `:104` `menu-end` still carry `instanceID`.
5. **Open.** `:102` (untracked end) and `:142` (arrival) still write `sessionID: ""`; `:299` `menuObjectID: ""` in
   `menu-scrubbed`.
6. **Open.** `:140` `status-menu-action-arrived` still adds `menuInstanceID`; `MenuContract.swift:43-48` still
   writes `subjectPID`/`nativeUptimeSeconds` and `:56-74` `matches` reads them.
7. **Done.** `:155-183` one deadline anchored at the `requested` row's `systemUptime` (`requestedMono + 60`) across
   RPC and row advancement; `:187` writes at most one terminal per request (codex-kit-12). **New finding (13).**
8. **Open.** `:91` still records only `menu.items[0]` (now only when its title contains the seed title).
13. **New.** `:158-163` the watchdog writes a terminal `failed` / `timeout` when no terminal arrived in 60 s, and
    also as soon as `isLive()` turns false (stop file, lease, heartbeat) before 60 s. C2.4 step 3 says "no terminal
    → NOT-RUN; `failed` → FAIL", so a slow engine becomes FAIL rather than NOT-RUN, and a run stopped early reports
    a `timeout` that did not happen. Recommended: write no terminal row on deadline or stop (the 60 s rule already
    yields NOT-RUN `timeout`), or a coordinator ruling that `failed`/`timeout` counts as NOT-RUN.

Swift (`desktop/native/verification/bin/pointer_drive.swift`):

9. **Open.** `:68-70` `pointer-host-permission` still `event`, ISO `timestamp`, no run binding or `protocol`.
10. **Partly done.** `:136`, `:146` move/button rows now carry `targetPID`, numeric `mono` and `at` (C2.4 §1
    fields present). Encoding still differs from the schema: the row name is in `event`, `kind` is `move`/`click`,
    and `subjectPID`, `uptimeSeconds` and the ISO `timestamp` remain.
11. **Done.** `:109-114` samples `downMono` before the press and `upMono` after the release, then records, so a menu
    beginning during the press is inside `[down, up + 3 s]`.
12. **Partly done.** `:157`, `:236` `pointer-result` rows carry `runID`, `epoch`, `targetPID`, `mono`, `at` (still
    `event`, not `kind`); `:121` (`postEvents-not-granted`) carries none of them.

New producers: **done.** `U6/capture_owned.py` (`u6-capture/1`), `U6/consent_reset.py` (`consent-reset/1`, its
own receipt, never redirected stdout) and `U6/action_runner.py` (`u6-actions/1`, exclusive create) shipped. Their
schemas now follow the shipped field sets: capture writes no `at` (C2.4 does not list one); the reset receipt adds
`targetPID`, `menuObjectID`, `sessionID`, `operation`, `outcome`, `reason` (optional; the oracle does not decide on
them); the finish record is `{pid, mono, steps: {dock, menuA, refresh, menuB, privateTitle, trackedClear}, outcome,
reason}`. The shipped runner writes `not-run` (never `fail`) for a failed action.

Observation, outside the schema: with the guard attached, `EngineDockMenuApplication.swift:126-133` still skips
`composition.refresh` when no arrival context is seen within 0.5 s (25 × 20 ms); harmless for U6 evidence (no
`requested` → NOT-RUN) but it differs from the release handler.

## evidence-u6 disagreements

The a98b25a3 consumer checklist (legacy reader, old scrub fields, ignored sessions, list-index ordering, caller
booleans, closure validation, unbounded reasons) is done in `U6/evidence_chain.py`, apart from encoding (item 1)
and one item: it reports the first failing step, not per-step outcomes (C2.4 steps 1–10). It also requires inputs
C2.4 does not name (`menu-drive.jsonl` arrival result, a `pointer-result posted` row, pointer plans, the reset
receipt's `targetPID`/`sessionID` = B/`operation`/`outcome`, `launch.json`, `prepared.json`,
`synthetic-seed.json`); `kit_batch` supplies them as the head's producers write them.

At 8f857aa6 both former expected failures agree (valid batch: pass/pass; Refresh `failed`: fail/fail), as do 60 of
the 69 traces. The nine overall-outcome divergences (`EvidenceU6CLITests.DISAGREEMENTS`; expected failures only
where evidence-u6 is wrong):

| Trace | Oracle | evidence-u6 | Right | C2.4 |
| --- | --- | --- | --- | --- |
| `closure-other-run` | not-run | fail | oracle | §1: "every receipt must match this run's runID/epoch … Others are ignored." |
| `closure-other-lease-window` | fail | pass | oracle | step 9: "this run's ids" (lease identity includes notBefore/expiresAt); §4: "the closure receipt inside the lease window". evidence-u6 never compares the receipt's lease window with the run's. |
| `descending-seq`, `duplicate-seq` | fail | not-run | oracle | §1: "`seq` (integer, strictly increasing per process)"; step 10: "contradiction → FAIL" |
| `refresh-terminal-late` | not-run | fail | oracle | step 3: "exactly one terminal row for R within 60 s …"; "no terminal → NOT-RUN" |
| `menu-a-ended-before-arrival` | fail | not-run | oracle | step 3: "`menu-end` for A … must follow the action arrival"; step 10: "contradiction → FAIL" |
| `old-accepted-clear-shape` | not-run | pass | policy | C2.4 lists required fields only; the closed schemas reject the extra legacy fields (Versioning) |
| `unsupported-native-protocol` | not-run | pass | policy | C2.4 defines no protocol field; it is the schemas' versioning rule (item 2) |
| `runner-reported-failure` | fail | not-run | silent | step 7: "a finish record with the failure" assigns no outcome; the shipped runner never writes `fail` |

`closure-inconsistent` disagreed too (oracle NOT-RUN, evidence-u6 FAIL). Step 10 says "contradiction → FAIL", so
the oracle now reports FAIL `closure-inconsistent` for a well-formed, self-contradictory closure, and they agree.

## Run

```sh
python3 -B -m unittest discover -s desktop/native/verification/tests -p 'test_u6_receipt_schema.py'
python3 -B desktop/native/verification/U6/replay.py --context schema/verification/fixtures/batches/valid/context.json \
  --batch schema/verification/fixtures/batches/valid
```
## Run

```sh
python3 -B -m unittest discover -s desktop/native/verification/tests -p 'test_u6_receipt_schema.py'
python3 -B desktop/native/verification/U6/replay.py --context schema/verification/fixtures/batches/valid/context.json \
  --batch schema/verification/fixtures/batches/valid
```

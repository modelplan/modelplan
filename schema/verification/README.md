<!-- SPDX-License-Identifier: MIT -->
# U6 verification receipt contract

These Draft 2020-12 schemas describe only what the U6 Dock/menu drive emits and consumes, as specified by
`desktop/native/verification/U6-DockMenu-Drive.md`, section "Evidence and timing contract (C2.4)". They follow
the [App–CLI contract](../app-cli/README.md) pattern: versioned schemas, fixtures with recorded provenance, a
drift check, and contract tests. `common.json` holds the shared identity, clock and code definitions.

Where the current Swift or Python differs from C2.4, the schemas follow C2.4; each difference is listed under
[Required producer changes](#required-producer-changes). Nothing here changes a producer.

| Schema | Batch file | Producer | Consumers |
| --- | --- | --- | --- |
| [native-row.json](native-row.json) + one schema per kind in `x-kinds` ([native/](native/)) | `native-observations.jsonl` | `U6DriveGuard.emitObject` (test build) | drive-u6, u6-pointer-plan, evidence-u6, evidence_receipt, replay |
| [pointer-receipt.json](pointer-receipt.json) | `dock-pointer.jsonl`, `status-pointer.jsonl`, `status-pointer-clear.jsonl` | `bin/pointer_drive.swift` | u6-pointer-plan, evidence, replay |
| [capture-receipt.json](capture-receipt.json) (`u6-capture/1`) | `dock-capture.json` | capture wrapper (M4, not yet in the kit) | evidence, replay |
| [consent-reset.json](consent-reset.json) (`consent-reset/1`) | `consent-reset.json` | helper wrapper (M4, not yet in the kit) | evidence, replay |
| [u6-actions.json](u6-actions.json) (`u6-actions/1`) | `operator-finish.json` | action runner (M4, not yet in the kit) | drive-u6, evidence, replay |
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
3. **Invocation.** The replay CLI runs on the committed batches; the real `bin/evidence-u6.py` CLI runs on the valid
   batch and two negative batches, recording its disagreements as expected failures (below).

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
- Step 7 takes the runner's worst claimed outcome (a claim never proves PASS); the finish record must follow the
  step 1–6 receipts and precede the stop row.
- Step 9: missing, malformed or self-contradictory (`validate_receipt`), other-run and `ok: false` receipts are
  NOT-RUN (macrev-332-5); a lease window different from the run's, or `lease_window_ok` false (late closure or
  start before the lease), is FAIL `out-of-window` (macrev-332-15, codex-kit-9). Step 8 needs `subjectGone` from a
  valid, run-bound receipt.
- Step 10: manifest pins different from the launched pins is FAIL (C2.4 §6).
- Overall: FAIL if any step fails, else NOT-RUN if any step is not run, else PASS.
- **Open contract point:** C2.4 bounds `clear-initiated` against the helper window but sets no completion bound
  for `accepted-clear`/`menu-scrubbed` (codex-kit-3 timing, KIT-REVIEW C2.2 amendment 1). The oracle follows C2.4;
  `test_contract_gap_delayed_clear_still_passes_under_c2_4` documents the PASS and flips once the contract adds it.
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
| `closure-inconsistent` | macrev-332-5, SKILLS-CONSULT 7 | 8 NOT-RUN / not-delivered / `subject-not-gone`; 9 NOT-RUN / unknown / `closure-malformed` | not-run |
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
| `finish-before-receipts` | codex-kit-7 | 7 NOT-RUN / out-of-window / `finish-before-receipts` | not-run |
| `engine-pin-changed` | codex-kit-10 | 10 FAIL / unknown / `pin-changed` | fail |

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

Swift (`desktop/native/ModelPlanAppIntegration/Sources/ModelPlanAppIntegration/U6DriveGuard.swift` unless noted):

1. `:237-249` `emitObject` writes `{…envelope, event, timestamp, checks:{…}}` for every kind except `refresh`
   (`:242-244`). Write one flat object: envelope + `kind` + the kind's fields; drop `event`, `timestamp`, `checks`.
2. `:66` `started` carries `protocol: "u6-native/1"`.
3. `:81-83` `menu-begin`: drop `instanceID` and `subjectPID` (the envelope `pid` binds the subject).
4. `:90` `menu-private-title-visible` and `:99` `menu-end`: drop `instanceID`.
5. `:97` and `:137`: an untracked end or arrival writes `sessionID: ""`; never emit an empty session (skip the row);
   likewise `:286` `menuObjectID: ""` in `menu-scrubbed`.
6. `:134-138` `status-menu-action-arrived`: drop `menuInstanceID`; the fields from
   `desktop/native/verification/StatusMenu/Sources/ModelPlanMenuVerification/MenuContract.swift:43-48` drop
   `subjectPID` and `nativeUptimeSeconds` (envelope `pid`/`mono`). `MenuContract.swift:50-74` (`object`,
   `matches`, used by `bin/status_menu_drive.swift:132`) must read the flat row (`kind`, `pid`, `mono`).
7. `:162-171` the refresh wait starts a new 60 s wall-clock deadline after the RPC returns (`:164`). Anchor one
   deadline at the `requested` row's `mono` across RPC and row advancement (C2.4 step 3, codex-kit-4); a later
   terminal is NOT-RUN `timeout` in the replay.
8. `:86` records only `menu.items[0]`; `privateItemIDs` must list every item object showing private content.

Swift (`desktop/native/verification/bin/pointer_drive.swift`):

9. `:67-71` `pointer-host-permission`: `kind` (not `event`), `protocol: "u6-pointer/1"`, `runID`, `epoch`,
   `targetPID`, numeric `mono`/`at` (no ISO `timestamp`).
10. `:134-136` `mouse-moved-posted` and `:143-147` button rows: `kind`, `targetPID` (not `subjectPID`), `mono`
    (not `uptimeSeconds`), numeric `at` (not an ISO string rounded to seconds).
11. `:103-113` `click` posts down and up, then samples uptime when recording (`:111-112`), so `down.mono` is later
    than the actual press and a menu that begins during the press precedes it (false NOT-RUN under step 2's
    `[down, up + 3 s]`). Sample uptime at each post inside the `ButtonGuard` critical section, record afterwards.
12. `:119`, `:154`, `:231` `pointer-result` rows: `kind` plus `runID`, `epoch`, `targetPID`, `mono`, `at`.

New producers (M4): capture receipt (`u6-capture/1`), helper wrapper (`consent-reset/1`; never redirected helper
stdout), action-runner finish record (`u6-actions/1`, exclusive create).

Observation, outside the schema: with the guard attached, `EngineDockMenuApplication.swift:120-133` skips
`composition.refresh` entirely when no arrival context is seen within 0.5 s; harmless for U6 evidence (no
`requested` → NOT-RUN) but it differs from the release handler.

## Required consumer changes and evidence-u6 disagreements

Python readers of the legacy envelope must read the flat rows: `bin/drive-u6.py:102` and `:110` (`event`),
`bin/u6-pointer-plan.py:13-25` and `:54-70` (`event`, `checks`, `subjectPID`, ISO `timestamp` at `:63`; also the
C2.4 intervals: move→frame ≤ 5 s, `[down, up + 3 s]`, B's down after end(A)), `U6/evidence_receipt.py:48`, `:74`,
`:87` (`event`, `timestamp`).

`bin/evidence-u6.py` (the final entry point) disagrees with the oracle; `EvidenceU6CLITests` runs the real CLI:

| Batch | Oracle | evidence-u6 | Test |
| --- | --- | --- | --- |
| complete valid C2.4 batch | pass | not-run | `test_valid_batch` (expected failure) |
| Refresh `failed` (`engine-error`) | fail (step 3) | not-run | `test_refresh_failed_batch` (expected failure) |
| `launch-cleanup.json` missing | not-run | not-run | `test_closure_missing_batch` (agrees) |

Causes, for M4's integration checklist (`bin/evidence-u6.py`):

1. `:24-50` reads the legacy `event`/`checks` envelope and `instanceID`/`menuInstanceID`/`subjectPID`; C2.4 rows
   are flat with `menuObjectID`/`sessionID` and envelope `pid`.
2. `:45-49` requires the old `scrubbedInstanceIDs`/`oldItemTitlesScrubbed`/`oldItemPrivateAttributesScrubbed`
   (macrev-332-14); no `clearID`, reset pair, `menu-scrubbed` item proof or post-clear title check.
3. `:26-49` ignores `menu-end`, sessions A/B, `menu-private-title-visible` and `clear-initiated` (macrev2-332-1,
   macrev-332-8, codex-kit-3).
4. `:24-56` orders by list index and binds only run/epoch: no `pid`, `seq` or `mono` (codex-kit-2), no 60 s window,
   and duplicate `requested` rows overwrite each other (codex-kit-4).
5. `:5`, `:83-85` take Dock/menu/quit/title gates from caller booleans and two file names; pointer, capture,
   consent-reset, finish receipts and pins are never read (codex-kit-1, -7, -8, -10).
6. `:6-14` checks closure `schema`/`ok`/`failures` but not `validate_receipt` or `lease_window_ok`: a
   self-contradictory or late closure passes (macrev-332-5, -15, codex-kit-9).
7. `:63-64` forwards any non-empty `failed.reason` string, not the bounded §5 list (macrev2-332-3).
8. One scenario outcome, not per-step outcomes (C2.4 steps 1–10).

When evidence-u6 adopts the C2.4 reduction, the two expected failures become unexpected successes: remove the
decorators and add the replay's negative traces to its CLI tests.

## Run

```sh
python3 -B -m unittest discover -s desktop/native/verification/tests -p 'test_u6_receipt_schema.py'
python3 -B desktop/native/verification/U6/replay.py --context schema/verification/fixtures/batches/valid/context.json \
  --batch schema/verification/fixtures/batches/valid
```

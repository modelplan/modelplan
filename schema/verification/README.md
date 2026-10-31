<!-- SPDX-License-Identifier: MIT -->
# U6 verification receipt contract

These Draft 2020-12 schemas describe only what the U6 Dock/menu drive emits and consumes, as specified by
`desktop/native/verification/U6-DockMenu-Drive.md`: "Evidence and timing contract (C2.4)" as amended by
"Contract revision C2.5" (C2.5 wins where they differ). They follow the [App–CLI contract](../app-cli/README.md)
pattern: versioned schemas, fixtures with recorded provenance, a drift check, and contract tests. `common.json`
holds the shared identity, clock and code definitions.

C2.5 F keeps the producers' current receipt shapes, so the schemas describe the App's native envelope and
pointer_drive's rows as written today. Where a producer still has to change for C2.5, it is listed under
[Producer changes required by C2.5](#producer-changes-required-by-c25); where `bin/evidence-u6.py` must change, under
[evidence-u6 changes required by C2.5](#evidence-u6-changes-required-by-c25). Nothing here changes a producer.

| Schema | Batch file | Producer | Consumers |
| --- | --- | --- | --- |
| [native-row.json](native-row.json) + one schema per kind in `x-kinds` ([native/](native/)) | `native-observations.jsonl` | `U6DriveGuard.emitObject` (test build) | drive-u6, u6-pointer-plan, capture/reset/action tools, evidence-u6, replay |
| [pointer-receipt.json](pointer-receipt.json) | `dock-pointer.jsonl`, `status-pointer.jsonl`, `status-pointer-clear.jsonl` | `bin/pointer_drive.swift` | u6-pointer-plan, evidence-u6, replay |
| [capture-receipt.json](capture-receipt.json) (`u6-capture/1`) | `dock-capture.json` | `U6/capture_owned.py` | evidence-u6, replay |
| [consent-reset.json](consent-reset.json) (`consent-reset/1`) | `consent-reset.json` | `U6/consent_reset.py` | evidence-u6, replay |
| [u6-actions.json](u6-actions.json) (`u6-actions/1`) | `operator-finish.json` | `U6/action_runner.py` | drive-u6, evidence-u6, replay |
| [runtime-calls.json](runtime-calls.json) (`u6-runtime-calls/1`) | `runtime-calls.json` | Drive's copy of the stub log (C2.5 D; pending, M4) | evidence-u6, replay |
| [launch-cleanup.json](launch-cleanup.json) (`launch-cleanup/1`) | `launch-cleanup.json` | `bin/check_launch_cleanup.py` | evidence-u6, replay |
| [replay-context.json](replay-context.json) (`u6-replay-context/1`) | replay input only | derived from the run files (subject, lease, seed title hash, HOME hash, manifest and launched pins) | replay |

Native kinds (`event`): `started`, `doctor` (guard tick, not a step input), `dock-surface-frame`,
`status-item-frame`, `menu-begin`, `menu-end` (`cause` with `clearID` iff `clear`), `menu-private-title-visible`
(`titleSHA256`, `privateItemIDs`), `status-menu-action-arrived`, `refresh` (flat; `requested` | `completed` |
`failed` | `deferred` | `abandoned`), `clear-initiated`, `accepted-clear`, `menu-scrubbed` (per session, per
recorded item), `stop-or-lease-expired` / `owner-preempted` (one schema; only the first satisfies step 8) and
`terminate-completed`.

## Encoding, versioning and compatibility

- **Native rows (C2.5 F)** are the App's envelope: `runID`, `epoch`, `pid`, `seq` (integer ≥ 1, strictly
  increasing per process), `mono` (fractional `ProcessInfo.systemUptime`), `at` (UNIX seconds, informational),
  `event`, `timestamp` (= `at`, informational) and `checks` {the kind's fields}. `refresh` rows are flat with
  `kind: "refresh"`. The App's extra identity fields (`instanceID`, `subjectPID`, `menuInstanceID`,
  `nativeUptimeSeconds`) are allowed and never decide. A row carries exactly one of the two encodings.
- **Refresh (C2.5 D):** `requested` carries `rowsSequenceBefore`, `dispositions` (scope → `scheduled` |
  `cooldown` | `read_only` | `offline` | `policy_pending`; `copilot.runtime_usage` required) and `copilotRow`
  (`absent` | `present`, before); `completed` carries `rowsSequenceAfter` and `copilotRow` (after); `failed` a §5
  `reason`; `deferred` nothing more; `abandoned` a `cause` (`deadline` | `stop`). The encoding of "copilotRow absent →
  present" as a before/after pair is this schema's choice; M4 implements it or proposes another in the same change.
- **Pointer rows** are pointer_drive's: `event` names the row, posted rows carry `kind` (`move` | `click`), the
  C2.4 binding (`runID`, `epoch`, `targetPID`, numeric `mono`, `at`) and its `subjectPID`, `uptimeSeconds`, ISO
  `timestamp`. The permission row is written without run binding and is never evidence.
- **Protocol (C2.5 F).** `started.checks.protocol` is optional; absent (the App today) means `u6-native/1`. Any other
  version makes the native stream unusable: NOT-RUN `unknown`.
- **Frozen meanings.** Identity (run/epoch/PID binding, `menuObjectID` vs `sessionID`, `requestId`, `clearID`),
  clocks and ordering (`seq` within the app, `mono` across processes, `at`/`timestamp` never), the reset
  correlation pair, the retained-item proof and every outcome/reason vocabulary are frozen for a protocol version;
  changing one needs a new version with producer, schema, fixtures and consumers in one reviewed change.
- **Closed objects.** Every object (including `checks`) is `additionalProperties: false`; a new field lands in the
  schema and fixtures with the producer. A schema-invalid receipt is NOT-RUN (C2.5 F).
- Free engine/exception text never appears; reasons use `common.json#/$defs/scenarioReason` (C2.4 §5 plus
  C2.5 D `cooldown`).

## Three checks

`desktop/native/verification/tests/test_u6_receipt_schema.py` (stdlib only; `U6/receipt_schema.py` implements
exactly the keyword subset these schemas use and refuses any other keyword):

1. **Shape.** Every schema is Draft 2020-12, closed and resolvable; every native kind schema carries the envelope
   (or, for `refresh`, the flat form). All positive fixtures validate, every schema has a positive instance, and
   removing any required identity, clock, session, reset-pair, disposition or item-proof field is rejected. For
   `launch-cleanup/1` the schema's keys equal `check_launch_cleanup.KEYS`/`CHECKS`/`TIMING`, receipts from the real
   `check()` satisfy both the schema and `validate_receipt`, and over a mutation matrix the two agree on shape.
2. **Meaning.** `U6/replay.py` is a pure offline oracle (no GUI, process, clock or writes) that reduces a batch
   through C2.4/C2.5 to per-step outcomes, independent of `bin/evidence-u6.py`. Each negative trace asserts its
   exact step outcomes, scenario reason and deciding assertion, and that every other step passes.
3. **Invocation.** The replay CLI runs on the committed batches. Every one of the 80 traces the oracle judges
   also runs through the real `bin/evidence-u6.py --config --batch --package --kit-manifest` on the same batch
   bytes; `synthetic_batch.kit_batch()` adds only what the final entry reads beyond the batch (subject
   registration, `launch.json`, `prepared.json`, `synthetic-seed.json`, pointer plans, the menu helper's
   `menu-drive.jsonl`, `run.json`, a launched bundle, a pinned package zip and a kit manifest, as in
   `test_u6_evidence_chain.py`). Overall outcomes are compared.

## Replay oracle decisions

- Rows bind on (`runID`, `epoch`, `pid`) of the registered subject; others are ignored. Among the subject's rows,
  a schema-invalid row, a missing first `started` row, an unsupported protocol, an unparsable or truncated line
  makes the native stream unusable (NOT-RUN; C2.5 F): steps 1–6 and 8 are NOT-RUN and step 10 reports the cause. A
  non-increasing `seq` or decreasing `mono` is a contradiction: step 10 FAIL (C2.5 F).
- Duplicates are contradictions (FAIL): a second Refresh arrival in A, a second `requested` for R, a second
  terminal for R anywhere in the log (codex-kit-12), a second `accepted-clear` or `menu-scrubbed` for the clear.
- Step 3 (C2.5 D): an arrival after `menu-end(A)` is FAIL; a terminal outside 60 s of `requested` is NOT-RUN
  `timeout`; `failed` is FAIL with its reason; `deferred` is NOT-RUN `cooldown`; `abandoned` is NOT-RUN `timeout`
  (deadline) or `not-delivered` (stop); `completed` without an advance is NOT-RUN `rows-unchanged`. An advance
  passes only with `copilotRow` absent → present, Copilot `scheduled` and `account.getQuota` in this run's
  `runtime-calls.json`. Otherwise: the row already present before → NOT-RUN `copilot-row-preexisting` (the seed
  broke C2.5 C, so the step proves nothing); Copilot not scheduled → FAIL `copilot-not-scheduled` (the advance
  contradicts the disposition); no Copilot row or no stub call → FAIL `unrelated-advance`; the call log missing,
  schema-invalid or of another run → NOT-RUN. The log must come from this run's fresh HOME: a seed that already
  holds `runtime-calls` would let a stale `account.getQuota` count (C2.5 C keeps it out of the seed).
- Step 6: C2.4's explicit FAIL predicates (B ended before `clear-initiated`; a later end of B without
  `cause: clear` and the same `clearID`; a recorded private item missing from or still private in `menu-scrubbed`;
  private content in the current menu; a seed-hash title for B or a later session after `accepted-clear`) are
  evaluated first and dominate. Then C2.5 E: `accepted-clear` or `menu-scrubbed` more than 5 s after
  `clear-initiated` is FAIL `timeout` (`clear-late`). Missing or unbound receipts are NOT-RUN, including B not in
  `openSessionIDs` or `scrubbedSessionIDs` (macrev-332-8). The clear is the first `clear-initiated` after B's title.
- Step 7 (C2.5 F): any non-pass claim of the runner (`steps` or `outcome`) is NOT-RUN with the runner's bounded
  `reason`; a claim never proves PASS. The finish record must follow the step 1–6 receipts and precede the stop row.
- Step 9: missing, schema-invalid, other-run or other-lease-window receipts are NOT-RUN and ignored (step 8 then
  lacks `subjectGone`); `ok: false` is NOT-RUN (macrev-332-5); a well-formed receipt that contradicts itself
  (`closure-failures-`, `-ok-`, `-time-`, `-window-inconsistent`) is FAIL `closure-inconsistent` (C2.5 F); a late
  closure or a start before the lease (`lease_window_ok` false) is FAIL `out-of-window` (C2.4 §4).
- Step 10: manifest pins different from the launched pins is FAIL (C2.4 §6).
- Overall: FAIL if any step fails, else NOT-RUN if any step is not run, else PASS.
- codex-kit-11 (exclusive final inventory) concerns `inventory_evidence.py`'s writes, not receipt meaning.

## Replay outcomes

| Trace | Source | Non-PASS steps (outcome / reason / detail) | Overall |
|---|---|---|---|
| `valid` | C2.4/C2.5 | none | pass |
| `valid-interleaved` (begin during press, terminal before end(A), no optional end(B), item deallocated, foreign-PID rows) | codex-kit-5, -12; macrev-332-10 | none | pass |
| `delayed-clear` (scrub 190 s after initiation) | codex-kit-3, C2.5 E | 6 FAIL / timeout / `clear-late` | fail |
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
| `flat-c2.4-rows` | C2.5 F (the App envelope is the format) | 10 NOT-RUN / unknown / `native-row-malformed`; 1,2,3,4,5,6,8 NOT-RUN `native-unusable` | not-run |
| `closure-observed-after-expiry` | macrev-332-15, codex-kit-9 | 9 FAIL / out-of-window / `closure-late` | fail |
| `subject-started-before-lease` | codex-kit-9 | 9 FAIL / out-of-window / `closure-late` | fail |
| `closure-other-lease-window` | codex-kit-9, C2.5 F | 8 NOT-RUN / not-delivered / `subject-not-gone`; 9 NOT-RUN / wrong-subject / `lease-window-mismatch` | not-run |
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
| `refresh-deferred` | C2.5 D (Copilot cooldown) | 3 NOT-RUN / cooldown / `refresh-deferred` | not-run |
| `refresh-abandoned-deadline` | C2.5 D (watchdog deadline) | 3 NOT-RUN / timeout / `refresh-abandoned-deadline` | not-run |
| `refresh-abandoned-stop` | C2.5 D (watchdog stop) | 3 NOT-RUN / not-delivered / `refresh-abandoned-stop` | not-run |
| `unrelated-sequence-advance` | C2.5 D | 3 FAIL / unknown / `unrelated-advance` | fail |
| `stub-call-missing` | C2.5 D | 3 FAIL / unknown / `unrelated-advance` | fail |
| `runtime-calls-missing` | C2.5 D | 3 NOT-RUN / not-delivered / `runtime-calls-missing` | not-run |
| `runtime-calls-other-run` | C2.5 D, C2.4 section 1 | 3 NOT-RUN / wrong-subject / `runtime-calls-unbound` | not-run |
| `copilot-not-scheduled-but-completed` | C2.5 D | 3 FAIL / unknown / `copilot-not-scheduled` | fail |
| `copilot-row-preexisting` | C2.5 C-D (seed carries no Copilot reading) | 3 NOT-RUN / unknown / `copilot-row-preexisting` | not-run |
| `accepted-clear-late` | C2.5 E | 6 FAIL / timeout / `clear-late` | fail |
| `menu-scrubbed-late` | C2.5 E | 6 FAIL / timeout / `clear-late` | fail |
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
synthetic closed run with a fixed lease clock) and, since C2.5 F, `dock-capture.json`, `consent-reset.json` and
`operator-finish.json`, written by `U6/capture_owned.py`, `U6/consent_reset.py` and `U6/action_runner.py` on the
trace's native rows up to that moment, with fakes only for admission/subject identity, `screencapture`, the
helper process and the uptime clock (`synthetic_batch.shipped_receipts`; the reset's `homeSHA256` of the temporary
HOME path is rebased to the context's). `test_fixture_receipts_are_the_shipped_writers_output` keeps the in-memory
traces equal to them. Authored (`pending-producer-capture`): native rows (Swift App), pointer rows (Swift
pointer_drive) and `runtime-calls.json` (Drive's stub-log copy, not written yet). Negative traces are mutations in
the test file with independently stated expectations.

Regenerate (the drift test compares byte for byte):

```sh
python3 -B desktop/native/verification/U6/synthetic_batch.py --write schema/verification/fixtures
```

Swift captures still to add (then flip those entries to `generated: true`): native rows via
`swift test --package-path desktop/native/ModelPlanAppIntegration --filter U6ReceiptFixtureCaptureTests` (the
`emitObject` serializer with injected uptime, clock and IDs) and pointer rows via `pointer_drive
--fixture-receipts <plan>` (`PointerDrive.append` with an injected clock, posting nothing).

## Producer changes required by C2.5

Against #332 6a063beb (`U6DriveGuard.swift`, `pointer_drive.swift` unchanged since 8f857aa6; line numbers there).

Closed by C2.5 F (the schemas adopt the current shapes): the former items 1–4, 6, 9, 10 and 12 (envelope, no
`protocol`, `instanceID`/`subjectPID`/`menuInstanceID`/`nativeUptimeSeconds`, pointer `event`/`kind`, ISO
`timestamp`, unbound permission and `postEvents-not-granted` rows). Done earlier: 7 (deadline anchored at
`requested` `mono`) and 11 (click `mono` sampled at the posts).

App (`desktop/native/ModelPlanAppIntegration/Sources/ModelPlanAppIntegration/U6DriveGuard.swift`):

1. **C2.5 D, `requested`** (`:156-157`): add `dispositions` (the engine's per-scope `refresh/request` reply,
   `copilot.runtime_usage` included) and `copilotRow` (`absent` | `present` before the request).
2. **C2.5 D, `completed`** (`:179`): add `copilotRow` after; write `deferred` (no advance; Copilot not
   `scheduled`) instead of waiting for an advance that cannot come.
3. **C2.5 D, watchdog** (`:158-163`, `:183`, the former item 13): on the 60 s deadline write `abandoned` with
   `cause: "deadline"`, on `isLive()` turning false write `abandoned` with `cause: "stop"`; never `failed`/`timeout`.
   `failed` stays for the production result only (`:168`).
4. **Former item 5** (`:102`, `:142`, `:299`): an untracked end, arrival or scrub writes `sessionID: ""` /
   `menuObjectID: ""`, which fails the schema and makes the whole native stream NOT-RUN. Skip the row instead.
5. **Former item 8** (`:91`): `privateItemIDs` lists only `menu.items[0]`; C2.4 step 5 asks for every item object
   showing private content.

Drive (`desktop/native/verification/bin/drive-u6.py`, C2.5 D):

6. Before removing HOME, copy `$HOME/runtime-calls` to `$BATCH/runtime-calls.json` as `u6-runtime-calls/1`
   (`runID`, `epoch`, `sourceSHA256` of the raw log, `calls` = its lines), exclusive create, and record the SHA-256
   in `result.json`.

Observation, outside the schema: with the guard attached, `EngineDockMenuApplication.swift:126-133` skips
`composition.refresh` when no arrival context is seen within 0.5 s (no `requested` → NOT-RUN).

## evidence-u6 changes required by C2.5

`bin/evidence-u6.py` / `U6/evidence_chain.py` at #332 6a063beb (unchanged since 8f857aa6) agree with the oracle on
63 of 80 traces. The 17 below are `expectedFailure` in `EvidenceU6CLITests` (C2.5 G.3 asks for none);
`test_disagreement_table_is_exact` pins both outcomes. Required changes, for M4:

1. Closure of another run → NOT-RUN, not FAIL (`validate_receipt(closure, run, epoch)`'s `closure-other-run`
   is raised as a contradiction).
2. Closure whose `leaseNotBefore`/`leaseExpiresAt` differ from `expectedLease` → NOT-RUN (not compared today).
3. Validate every receipt against `schema/verification` (closed `checks`): a schema-invalid row → NOT-RUN.
4. `started.checks.protocol` other than `u6-native/1` → NOT-RUN `unknown`.
5. Non-increasing `seq` / decreasing `mono` → FAIL (`native_rows` raises Missing today).
6. Refresh arrival after A's `menu-end` → FAIL (today NOT-RUN: `end_a` lookup requires `seq` > arrival).
7. Terminal beyond 60 s → NOT-RUN `timeout` (today FAIL `out-of-window`).
8. C2.5 D: read `dispositions`, `copilotRow`, `deferred` (NOT-RUN `cooldown`), `abandoned` (NOT-RUN `timeout` /
   `not-delivered`) and `$BATCH/runtime-calls.json`; PASS only with Copilot `scheduled`, absent → present and
   `account.getQuota`; an unrelated advance or a missing call → FAIL; a missing or other-run call log → NOT-RUN;
   add `cooldown` to `CODES`.
9. C2.5 E: `accepted-clear` and `menu-scrubbed` within 5 s of `clear-initiated`, late → FAIL `timeout`.

| Trace | Oracle (C2.5) | evidence-u6 | Deciding text |
| --- | --- | --- | --- |
| `closure-other-run` | not-run | fail | C2.5 F: "A receipt that fails its schema, names another run/epoch/PID or lease window → NOT-RUN" |
| `closure-other-lease-window` | not-run | pass | C2.5 F: "A receipt that fails its schema, names another run/epoch/PID or lease window → NOT-RUN" |
| `old-accepted-clear-shape` | not-run | pass | C2.5 F: "A receipt that fails its schema, names another run/epoch/PID or lease window → NOT-RUN" (closed checks schema) |
| `unsupported-native-protocol` | not-run | pass | C2.5 F: "An unknown native protocol version → NOT-RUN unknown" |
| `descending-seq` | fail | not-run | C2.5 F: "Two valid receipts that contradict each other (including ... descending/duplicate seq) → FAIL" |
| `duplicate-seq` | fail | not-run | C2.5 F: "Two valid receipts that contradict each other (including ... descending/duplicate seq) → FAIL" |
| `menu-a-ended-before-arrival` | fail | not-run | C2.4 step 3: "menu-end for A ... must follow the action arrival"; C2.4 step 10: "contradiction → FAIL" |
| `refresh-terminal-late` | not-run | fail | C2.5 D NOT-RUN: "no terminal" within 60 s of requested |
| `unrelated-sequence-advance` | fail | pass | C2.5 D FAIL: "a sequence advance without the Copilot row/stub call" |
| `stub-call-missing` | fail | pass | C2.5 D FAIL: "a sequence advance without the Copilot row/stub call" |
| `copilot-not-scheduled-but-completed` | fail | pass | C2.5 D PASS: "completed, rowsSequenceAfter > n, dispositions[copilot.runtime_usage] = scheduled, copilotRow absent → present, and the stub's call log shows account.getQuota"; the completed advance contradicts cooldown |
| `copilot-row-preexisting` | not-run | pass | C2.5 D PASS: "completed, rowsSequenceAfter > n, dispositions[copilot.runtime_usage] = scheduled, copilotRow absent → present, and the stub's call log shows account.getQuota"; C2.5 C: the seed has no Copilot reading |
| `runtime-calls-missing` | not-run | pass | C2.5 D PASS: "completed, rowsSequenceAfter > n, dispositions[copilot.runtime_usage] = scheduled, copilotRow absent → present, and the stub's call log shows account.getQuota"; evidence-u6 reads $BATCH/runtime-calls.json |
| `runtime-calls-other-run` | not-run | pass | C2.5 F: "A receipt that fails its schema, names another run/epoch/PID or lease window → NOT-RUN" |
| `delayed-clear` | fail | pass | C2.5 E: "accepted-clear and menu-scrubbed for B within 5 s of clear-initiated. Late → FAIL timeout" |
| `accepted-clear-late` | fail | pass | C2.5 E: "accepted-clear and menu-scrubbed for B within 5 s of clear-initiated. Late → FAIL timeout" |
| `menu-scrubbed-late` | fail | pass | C2.5 E: "accepted-clear and menu-scrubbed for B within 5 s of clear-initiated. Late → FAIL timeout" |

The oracle also differs on reasons and on which step it names (evidence-u6 reports the first failing step only);
only overall outcomes are compared.

## Run

```sh
python3 -B -m unittest discover -s desktop/native/verification/tests -p 'test_u6_receipt_schema.py'
python3 -B desktop/native/verification/U6/replay.py --context schema/verification/fixtures/batches/valid/context.json \
  --batch schema/verification/fixtures/batches/valid
```

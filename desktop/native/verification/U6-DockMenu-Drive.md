<!-- SPDX-License-Identifier: MIT -->
# U6 Dock/menu Drive

Use the shared native-verification Launch, Doctor, guardian, Cleanup and Evidence helpers; this is an additional scenario, not a replacement runner. The subject is the ordinary ModelPlanCommunityApp route, never the U11a cockpit test host or the legacy probe executable.

## Prepare before the lease

1. Pin the source commit, test candidate binary/package hash and ordinary bundled engine hash. The candidate must contain the rows-backed normal entry. Synthetic HOME/TMPDIR contain no owner account, credential or Keychain data. Reuse the approved structural profile builder; do not copy a real profile or add a competing generator.
2. Allocate a new approved exchange batch under the approved, operator-configured handoff root, with an independent run/epoch subdirectory, README and file list. If the approved directory is absent or any write is refused, stop without a fallback location. Do not overwrite a prior batch.
3. Retain the exact start announcement on the unit's private task, matching GUI release/lease, absolute expiry of at most 1200 seconds, independent watchdog and stop-hook paths. The run's deadline includes launch, waits, action delivery and cleanup. No automatic renewal or retry.
4. Use shared `launch.py` to validate the existing run contract. Its execute route requires the matching release, fresh guardian heartbeat, exact executable hash and synthetic profile. A validation/dry run is not an App launch or Drive result.
5. U6 runs with `CONTROLLER_MODE=launch` as the `u6` entry in `bin/scenarios.json`. Its run config sets `"scenario": "u6"`, and `bin/drive-u6.py` reads the same `$RUN_CONFIG` as `launch.py`. That config's `argv` is `[binary, "--u6-drive-contract", "<scratch>/native-guard.json"]`, `syntheticHome`/`syntheticTmp` are `<scratch>/home` and `<scratch>/tmp`, `stopPath` is `<batch>/stop.json`, `preparedReceiptPath` is `<batch>/prepared.json`, and it adds `head`, `batch`, `scratch`, `locks` and `resourceRoot`. The SKILL.md launch branch dispatches through `bin/scenario.py`, which runs `drive-u6.py prepare --config "$RUN_CONFIG"` in the foreground immediately before `launch.py --execute`. Prepare rechecks admission and the binary hash, takes the slot locks once (no retry) under a per-attempt token, checks the disk floor and writes the native contract. Only on success does it write the prepared receipt. Whenever the config names `u6` or its argv carries `--u6-drive-contract`, `launch.py` refuses unless that receipt matches the run, epoch and binary and every lock it lists still carries the receipt's token. On any refusal, prepare writes no receipt, releases only the locks this invocation took and writes the stop file. In the sequence's drive slot, `scenario.py drive` runs `drive-u6.py drive --config "$RUN_CONFIG"`.
   To start from a pre-built synthetic profile (e.g. the tracked-private-menu clear scenario), build it into `<scratch>/home-seed` (Drive refuses any other seed path) before `prepare` and set `syntheticHomeSeed` to that path and `syntheticHomeSeedSHA256` to `homeseed.tree_sha256` of it in the run config. `prepare` pins the digest in its receipt; `launch.py` verifies the seed before creating anything, creates the empty HOME, copies the seed in and verifies the copy. The seed must sit in the run scratch beside `syntheticHome` and contain only directories and regular files. Each attempt builds its own seed; Drive removes it with `home`/`tmp` after observed closure.

## Drive

1. Announce window start on the authoritative unit task before launch. Stop on owner takeover or any guardian/lease/deadline failure. Do not repeatedly reclaim foreground activation.
2. Launch the actual candidate through shared Launch; `drive-u6.py drive` never starts or signals a process. It drives only the subject `launch.py` registered in `subjectPidPath`, after it checks that subject's start identity, its attached launcher and its `started` receipt for this run/epoch. It refuses when no subject is registered or the identity differs. Record owned process identity and separate active/key/visible/native-panel observations; a non-key Dock panel must not be misreported as a key-window failure. The App may request foreground activation once if the granted contract requires it.
3. Deliver real input to reveal the Dock. Capture only the owned candidate surface. Observe at least one current reading or explicit engine-provided reason; no value is invented for an empty synthetic profile.
4. After the authorized pointer_drive lands, consume the owned `status-item-frame` test receipt in AppKit screen coordinates, convert its centre to the pointer tool’s documented coordinate space, and deliver a real click to that centre. Open the actual system status-item menu, capture its reading/reason text and deliver Refresh once. Record the delivered input and visible resulting state. An unchanged empty state is not proof of a remote refresh or provider freshness. Lack of a menu input capability is unsupported, never pass.

   U6's test build also emits a `dock-surface-frame` row only for its visible painted sliver/expanded panel, with the owned `windowNumber` and CG screen rectangle; `status-item-frame` includes `cgX/cgY` from the primary AppKit screen conversion. After admitted launch, M1 runs these bounded U6-only commands while the lease and guardian remain active:

   ```sh
   python3 "$KIT/desktop/native/verification/bin/u6-pointer-plan.py" make --config "$RUN_CONFIG" --kind dock
   "$KIT/pointer_drive" --plan "$BATCH/dock-pointer-plan.json"
   python3 "$KIT/desktop/native/verification/bin/u6-pointer-plan.py" check --config "$RUN_CONFIG" --kind dock
   OWNED_WINDOW_ID=$(python3 "$KIT/desktop/native/verification/bin/u6-pointer-plan.py" window --config "$RUN_CONFIG" --kind dock)
   screencapture -x -l "$OWNED_WINDOW_ID" "$BATCH/dock-owned.png"
   python3 "$KIT/desktop/native/verification/bin/u6-pointer-plan.py" make --config "$RUN_CONFIG" --kind status
   "$KIT/pointer_drive" --plan "$BATCH/status-pointer-plan.json"
   python3 "$KIT/desktop/native/verification/bin/u6-pointer-plan.py" check --config "$RUN_CONFIG" --kind status
   python3 "$KIT/desktop/native/verification/U6/prepare_menu_plan.py" --config "$RUN_CONFIG"
   "$KIT/pointer_drive" --status-menu-plan "$BATCH/menu-plan.json"
   ```

   The Dock move is proved only by `mouse-moved-posted` followed by the same run's native `dock-surface-frame` in `expanded` state. The status click requires `mouse-button-up-posted` followed by this App's native `menu-begin`; the next named Refresh action needs its separate `status-menu-action-arrived` and `refresh` terminal row. A pointer result saying `posted` is not an arrival. `screencapture -l` targets only the App-emitted Dock panel window number; do not capture the whole desktop or an unproved status popup. If that single-window capture or any native arrival is unavailable, keep the scenario unsupported/not-run and use the run's normal stop/closure path. The menu helper's `openMenu:false` reuses the physically opened status menu and uses AXPress only on the Refresh item; the app receipt records `deliveryMethod: axpress-menu-item` with the same status-menu instance ID and request ID, never as physical item input.
5. Include the tracked-menu privacy case: require a prior synthetic private title to be visible, keep the actual status/Dock menu open or tracked, and trigger a generation/epoch clear through the matching subject's approved synthetic consent operation. Verify the old menu is dismissed/scrubbed and no previous title remains. An initially empty menu, reopening a fresh menu, or a source-only assertion cannot establish this physical case. Missing matching helper/input capability stays not-run/unsupported.
   The Refresh item action closes the first menu. M1 physically reopens the status item into a **new tracked menu instance** for the clear step; it records the actual prior synthetic title in that instance before invoking the bundled helper. The U6 pointer plan uses a fresh output file so the second physical click cannot reuse the first one's receipt:

   ```sh
   python3 -B "$KIT/desktop/native/verification/bin/u6-pointer-plan.py" make --config "$RUN_CONFIG" --kind status --purpose clear
   "$KIT/pointer_drive" --plan "$BATCH/status-pointer-clear-plan.json"
   python3 -B "$KIT/desktop/native/verification/bin/u6-pointer-plan.py" check --config "$RUN_CONFIG" --kind status --purpose clear
   python3 -B "$KIT/desktop/native/verification/U6/evidence_receipt.py" record-operator --config "$RUN_CONFIG"
   HOME="$SCRATCH/home" TMPDIR="$SCRATCH/tmp" "$APP/Contents/Helpers/modelplan" consent reset confirmed --json > "$BATCH/consent-reset.json"
   python3 -B "$KIT/check_u6_receipts.py" --config "$RUN_CONFIG" --expect tracked-clear
   ```

   M1 runs `record-operator` only after seeing the actual synthetic private title and owned Dock reading/reason, and before reset. The app's `accepted-clear` must name the menu instance that showed the prior title and scrub its retained items; no later same-run receipt or capture may show it. An optional `menu-end` within 10 seconds is useful additional evidence, never a substitute for scrubbed instances. On missing input, title, helper result or receipt, request the run's normal stop/closure and report NOT-RUN.
6. Quit the owned candidate. When Drive ends it requests the normal quit by writing the run config's `stopPath` (the same path the native contract names as `stop`): the test build's guard then calls `NSApplication.terminate` and appends its own stop row (`stop-or-lease-expired`) to the native observations. Drive records `quit` in `result.json`: `requested` (`native-contract-stop`, or `none-subject-already-exited` when the subject had already ended) and `appAcknowledged`/`appEvent` from that row only. The row proves the app began its normal terminate, not that it finished it: `launch.py` and the guardian give the subject the run config's `quitGraceSeconds` (default 5, capped at 10) to finish that quit by itself and TERM it only if it is still running afterwards; both record `quitGraceUsed`/`exitedDuringGrace`. Coordinator decision: this contract-stop quit counts as quitting through the owned application, so no Quit menu press is required; M4 adds a terminate-completed row from `applicationWillTerminate`. `launch.py` and the guardian close the subject. Drive waits for closure up to the quit grace plus 25 seconds and only observes that the registered identity is gone, and only then releases the locks carrying its prepared token and removes `home`/`tmp` (and `home-seed` when configured). While driving it keeps checking the disk floor. On a breach it writes the stop file (`resource-disk-floor`) and signals nothing. Otherwise it leaves them held and exits 3 (closure unconfirmed). After the sequence has waited for `launch.py` and the guardian, M1 runs the independent `bin/check_launch_cleanup.py --config "$RUN_CONFIG"` with the controller, guardian and scenario exit statuses (SKILL.md launch branch); it writes its `launch-cleanup/1` receipt to `<batch>/launch-cleanup.json` for `evidence-u6.py`; `book.py finish --cleaned` runs only when it exits 0, otherwise M1 posts the NEEDS-COORDINATOR line and the booking stays started. Announce window end + cleaned only after that receipt passes. Retain evidence according to the batch policy.

## Evidence and timing contract (C2.3, coordinator, 2026-10-31)

Review contract for U6-R2, revised after the C1 contract reviews (MACREV, MACREV2, an independent Codex end-to-end review) and M4's app-order findings. It replaces C1. Where the steps above and this section differ, this section wins. A step without its input, its receipts and its failure outcome is NOT-RUN, never PASS.

### 1. Records, time and binding
- **Native rows** (`$BATCH/native-observations.jsonl`, written by the app's single observation writer) carry `runID`, `epoch`, `pid`, `seq` (integer, strictly increasing per process), `mono` (seconds, `ProcessInfo.systemUptime`, fractional) and `at` (UNIX seconds, fractional, informational only).
- **Pointer receipts** (pointer_drive results) carry, per posted event, `kind`, `mono` (same system uptime clock), `at`, and echo the plan's `runID`, `epoch` and `targetPID`. The plan names the registered subject PID; a receipt for another PID or run never satisfies a step.
- **Capture receipts** name `runID`, `epoch`, `pid`, `windowNumber`, the `seq` of the native frame row it captured, `mono`, file name and SHA-256. A file name alone proves nothing.
- **Ordering:** within the app by `seq`; across processes by `mono`. "Within N s" means `0 ≤ mono(native) − mono(anchor) ≤ N` unless a step states an explicit interval, which then wins (step 2 and step 4 do). Wall time is never used for ordering.
- **Binding:** every receipt must match this run's `runID`/`epoch` and, where it names a process, the registered subject PID (from `subjectPidPath`, which also carries runID/epoch). Others are ignored.

### 2. Menu identity
`menuObjectID` is the stable identity of the production status menu (it is reused; that is the accepted production route). Each `menu-begin` mints a unique `sessionID`; sessions A and B are two physical opens of the same object. All menu rows carry `menuObjectID` and `sessionID`.

### 3. Steps

| # | Step | Input | Required receipts, in order | Failure |
|---|---|---|---|---|
| 1 | Dock reveal | pointer_drive move (physical) | `mouse-moved-posted`, then `dock-surface-frame` `expanded` within 5 s; then a capture receipt bound to that frame's `seq` | missing → NOT-RUN |
| 2 | Menu A | pointer_drive click on the owned `status-item-frame` centre (physical) | `mouse-button-down-posted`, `mouse-button-up-posted`; `menu-begin` (session A) with `mono` in the interval [button-down `mono`, button-up `mono` + 3 s] — AppKit may open the menu during the press | missing → NOT-RUN |
| 3 | Refresh | AXPress on A's Refresh item only, `openMenu:false`, `deliveryMethod: "axpress-menu-item"` | `status-menu-action-arrived` `refresh` for A; `refresh` `requested` (requestId R, `rowsSequenceBefore` n) **written by the production handler** (`composition.refresh`; no separate client request); exactly one terminal row for R within 60 s of the `requested` row's `mono`: `completed` with `rowsSequenceAfter` > n, or `failed` with a code from §5; `menu-end` for A may come before or after the terminal row (the action closes the menu; the refresh completes asynchronously), but must follow the action arrival | no terminal → NOT-RUN; `failed` → FAIL; unchanged empty state never passes |
| 4 | Menu B | pointer_drive click on the status item (physical) | button-down `mono` after A's `menu-end`; `menu-begin` (session B ≠ A, same `menuObjectID` allowed) with `mono` in [button-down `mono`, button-up `mono` + 3 s] | before A ended, or B = A → NOT-RUN |
| 5 | Private title | none | `menu-private-title-visible` for B (`titleSHA256` of the synthetic title from the seed's preparation receipt, never the text; `privateItemIDs` = identities of the exact menu-item objects showing private content, ≥ 1), after B's `menu-begin`; the app holds **weak** references to exactly those objects from this point | missing or hash ≠ seed → NOT-RUN |
| 6 | Tracked clear | the kit's helper wrapper runs the bundled `consent reset confirmed --json` with HOME/TMPDIR = this run's synthetic HOME/TMP, while B is open | wrapper receipt `$BATCH/consent-reset.json` (schema `consent-reset/1`: runID, epoch, `homeSHA256` of the synthetic HOME path, helper SHA-256, `startMono`, `endMono`, `exitCode` 0, parsed `storeEpochAfter` and `generationAfter` from the helper's JSON); app `clear-initiated` (`clearID`, `storeEpochAfter` and `generationAfter` from `EngineInvalidation.nextFloor`, open sessions) written **before** menu tracking is cancelled, with `mono` in [`startMono`, `endMono` + 5 s]; optional `menu-end` for B with `cause: "clear"` and the same `clearID`; `accepted-clear` (same `clearID`; the pair (`storeEpochAfter`, `generationAfter`) equal to the wrapper's — a generation alone can repeat across store epochs, so it never correlates on its own; `scrubbedSessionIDs` ∋ B); `menu-scrubbed` for B (same `clearID`) reporting, for **every** ID in step 5's `privateItemIDs`, either `deallocated` or `cleared` (title, attributed title, tool tip, represented object and identifier all empty), plus `privateTitlePresent: false` and `privateAttributeCount: 0` for the menu's current items; any listed ID missing from the report or still carrying private content → FAIL (macrev-332-10) | wrapper missing/failed/other run, or a (storeEpochAfter, generationAfter) mismatch → NOT-RUN; a `menu-end` for B with any other cause before `clear-initiated` → FAIL; any title row with the seed hash for B or a later session after `accepted-clear` → FAIL; session A can never satisfy steps 5–6 |
| 7 | Hand-off | the action runner, after steps 1–6 have their receipts | `$BATCH/operator-finish.json` (schema `u6-actions/1`: runID, epoch, per-step outcome) written exclusively once; Drive then writes the stop file | any action failure → the runner writes the stop file and a finish record with the failure; closure still runs |
| 8 | Quit | the run config's `stopPath` | app `stop-or-lease-expired`, `terminate-completed` (from `applicationWillTerminate`), then the registered identity gone | missing `terminate-completed` → quit NOT-RUN; closure still checked |
| 9 | Closure | `check_launch_cleanup.py` with the three supervisor statuses | `launch-cleanup.json`, schema `launch-cleanup/1`, this run's ids, `ok: true` iff every check is true, `failures` = exactly the false checks | inconsistent or not ok → do not finish; NEEDS-COORDINATOR |
| 10 | Evidence | `evidence-u6.py` final entry point | reads every receipt above itself, including `launch-cleanup.json`; caller booleans never stand in for a receipt; inventory written once, at the end | missing → NOT-RUN; contradiction → FAIL |

### 4. Time budget, quit and supervisors
- `requiredSeconds` = the scenario's action phase only (steps 1–7). Admission requires remaining lease ≥ `requiredSeconds` + `quitGraceSeconds` + 25 s (`MIN_RESERVE`), as one sum.
- After the stop file, the subject gets `quitGraceSeconds` (default 5, cap 10). Both supervisors end the grace at once on revocation, lease identity change, a stale guardian heartbeat (> 3 s), a signal to a supervisor, or when only 25 s remain before `expiresAt`; then TERM, then KILL.
- The guardian beats at least every 0.5 s during the grace. Revocation, identity change and deadline outrank an existing stop file.
- Qualification also requires the subject's start and the closure receipt inside the lease window; a late closure is a timing FAIL, reported without suppressing cleanup.

### 5. Bounded codes
Failure and engine reasons in receipts and the report use only: `engine-disabled`, `engine-error`, `consent-required`, `timeout`, `not-delivered`, `wrong-subject`, `out-of-window`, `unknown`. Free engine text never enters receipts or the report.

### 6. Pins
The kit's manifest pins the main executable, the bundled engine and the consent helper (paths inside the `.app` and SHA-256). `prepare` verifies the launched bundle's members against it before admission; the evidence records the pins; any change is FAIL.

### 7. Ownership and orchestration
- **M4:** the app rows in §1–3 (seq/mono, sessionID, `menu-private-title-visible`, `clear-initiated`, `menu-end` cause, `menu-scrubbed`, production-path refresh rows, `terminate-completed`), pointer_drive `mono`/`targetPID` echo and capture receipts, the helper wrapper, the action runner and `operator-finish.json`, `evidence-u6.py`, the named seed builder with its arguments and title hash, and the booking command with unit `U6` and scenario `U6-DockMenu-synthetic`.
- **Coordinator (shared toolchain):** the additive admission sum, the 25 s reserve cut in launch.py as well, the lease-window qualification inputs, and `launch-cleanup/1` consistency.
- **M1** runs one invocation: monitor (Drive) in the background, a bounded wait (≤ 15 s) for the native `started` row, the action runner under the same stop trap, then stop, waits, closure and finish only on a clean closure.

### 8. Merge prerequisite
#332 merges only after M1's U6-R2 run at the final head shows PASS for steps 1–6 and 8–10, or an explicit FAIL/NOT-RUN the owner accepts. Before M1 consumes the kit, an offline replay through the real final entry point must accept one complete valid trace and reject every negative trace named in the reviews.

## Evidence

`bin/evidence-u6.py` derives bounded scenario outcomes from explicit receipts and delegates file hashing/manifest generation to the unchanged shared `evidence.py`. After M1 actually observes the synthetic Dock reading/reason and private title, and **before** consent reset clears it, M1 records that scoped visual observation with `python3 -B "$KIT/desktop/native/verification/U6/evidence_receipt.py" record-operator --config "$RUN_CONFIG"`. The record includes the registered subject PID and observation time; the assembler refuses to treat it as prior-title proof if it follows the app's accepted-clear row. If the actual observation or single-owned-window capture is unavailable, do not run that confirmation command and report NOT-RUN.

After the normal stop, supervisor waits and successful independent `launch-cleanup/1` receipt, run these once in the same fresh batch:

```sh
python3 -B "$KIT/desktop/native/verification/U6/evidence_receipt.py" assemble --config "$RUN_CONFIG" --package "$KIT/ModelPlan-U6-<current-head>.zip"
python3 -B "$KIT/desktop/native/verification/bin/evidence-u6.py" --receipts "$BATCH/evidence-receipt.json" --batch "$BATCH"
python3 -B "$KIT/desktop/native/verification/U6/inventory_evidence.py" --config "$RUN_CONFIG"
```

The U6 assembler checks the run's prepared synthetic HOME digest, source head, live binary hash, kit package hash, matching launch/quit/closure rows, physical Dock/status receipts, scoped menu result, refresh terminal and old-item scrub. `durationSeconds` is the app's `started` timestamp to the independent cleanup receipt's `at`, bounded by 1200 seconds. `evidence-u6.py` writes a new manifest; `inventory_evidence.py` writes a new batch README and file list with SHA-256 for every retained evidence file. Each write is exclusive and must not be retried into the same batch. Keep screenshots, action receipts, source/package/profile bindings and cleanup in that batch. Do not upload raw engine frames, account identifiers, paths, tokens or host metadata. Missing receipts remain not-run; unavailable capabilities remain unsupported. This scenario alone cannot establish owner freshness, official appearance or L2/L3 acceptance.

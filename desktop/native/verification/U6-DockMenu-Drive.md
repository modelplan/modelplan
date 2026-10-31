<!-- SPDX-License-Identifier: MIT -->
# U6 Dock/menu Drive

Use the shared native-verification Launch, Doctor, guardian, Cleanup and Evidence helpers; this is an additional scenario, not a replacement runner. The subject is the ordinary ModelPlanCommunityApp route, never the U11a cockpit test host or the legacy probe executable.

## Prepare before the lease

The named U6 seed uses `--private-tool copilot`, not a display-title argument. After the approved structural Home builder's synthetic refresh, `U6/prepare_config.py` relocates only its generated cache into the CLI's normal HOME-based cache (`Library/Caches/modelplan` on macOS). It then runs the actual pinned helper with only PATH/HOME/TMPDIR/LANG: offline quota must contain the seeded account, and read-only/offline rows must contain that account's tool row. The title hash comes from that helper's canonical row name (the same catalogue consumed by the App), never from a second spelling in the seed builder. `U6/seed_probe.py` is the standalone non-GUI check for this seam; no Launch environment pass-through is needed.

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
   The Refresh item closes menu session A. C2.3's action runner physically opens distinct session B, checks the seed's title hash, and invokes the run-bound synthetic reset wrapper while B remains tracked. It records every action outcome in one exclusive `operator-finish.json`; on missing input, title, helper result or scrub receipt it requests the run's normal stop and records NOT-RUN. The C2.3 table below is the acceptance rule.
6. Quit the owned candidate. When Drive ends it requests the normal quit by writing the run config's `stopPath` (the same path the native contract names as `stop`): the test build's guard then calls `NSApplication.terminate` and appends its own stop row (`stop-or-lease-expired`) to the native observations. Drive records `quit` in `result.json`: `requested` (`native-contract-stop`, or `none-subject-already-exited` when the subject had already ended) and `appAcknowledged`/`appEvent` from that row only. The row proves the app began its normal terminate, not that it finished it: `launch.py` and the guardian give the subject the run config's `quitGraceSeconds` (default 5, capped at 10) to finish that quit by itself and TERM it only if it is still running afterwards; both record `quitGraceUsed`/`exitedDuringGrace`. Coordinator decision: this contract-stop quit counts as quitting through the owned application, so no Quit menu press is required; M4 adds a terminate-completed row from `applicationWillTerminate`. `launch.py` and the guardian close the subject. Drive waits for closure up to the quit grace plus 25 seconds and only observes that the registered identity is gone, and only then releases the locks carrying its prepared token and removes `home`/`tmp` (and `home-seed` when configured). While driving it keeps checking the disk floor. On a breach it writes the stop file (`resource-disk-floor`) and signals nothing. Otherwise it leaves them held and exits 3 (closure unconfirmed). After the sequence has waited for `launch.py` and the guardian, M1 runs the independent `bin/check_launch_cleanup.py --config "$RUN_CONFIG"` with the controller, guardian and scenario exit statuses (SKILL.md launch branch); it writes its `launch-cleanup/1` receipt to `<batch>/launch-cleanup.json` for `evidence-u6.py`; `book.py finish --cleaned` runs only when it exits 0, otherwise M1 posts the NEEDS-COORDINATOR line and the booking stays started. Announce window end + cleaned only after that receipt passes. Retain evidence according to the batch policy.

## Contract revision C2.6 (coordinator, 2026-10-31)

Answers MACREV's DESIGN REVIEW NEEDED at a98b25a3/8f857aa6/6a063beb and macrev-332-16/-17/-18/-21; C2.6 is C2.5 corrected by the C2.5 contract review (macrev-332-22…-26) and macrev-332-27/-28. It amends C2.4 below; where they differ, C2.6 wins. Everything in C2.4 not named here stays as written. No further U6 kit fix is reviewed against anything but C2.6.

### A. One invocation, frozen order (macrev-332-16/-17)
M1 runs the `SKILL.md` launch branch as one script per attempt, in this order and no other:
1. `book.py request` with the unit and scenario taken from the scenario registry entry for `BUILD_SCENARIO` (for `u6`: unit `U6`, scenario `U6-DockMenu-synthetic`, the same values the builder writes; macrev-332-27) → GO → fresh `RUN_ID`/`EPOCH`. From the request on, a **pre-start trap** is armed: any failure before step 4 runs `book.py withdraw` for this booking; a failed withdraw → NEEDS-COORDINATOR, never a claim of closure (macrev-332-28).
2. **Build before start.** `scenario.py build --scenario u6 --config "$BATCH/run.json" -- --run-id "$RUN_ID" --epoch "$EPOCH" …` runs `U6/prepare_config.py`. It writes `run.json` and `synthetic-seed.json`, never reads a lease, and refuses if the config, lease, release, subject registration, seed or stop path already exists. Its `expectedLease` holds only runID and epoch. A build failure exits before start through the pre-start trap: the booking is withdrawn and the next queued booking can start; nothing is stopped.
3. Read attempt paths from the config; freshness check.
4. `book.py start` (lease written to the config's `leasePath`); the stop trap replaces the pre-start trap from here on.
5. **Bind:** add the lease's `notBefore`/`expiresAt` to `expectedLease`; a different runID/epoch in the built config → stop, NEEDS-COORDINATOR.
6. Guardian (background), `release.py`.
7. `scenario.py name` must equal `u6`; `scenario.py prepare` (`drive-u6.py prepare`).
8. `launch.py --execute` (background), then `scenario.py drive` (background; Drive is the monitor and never waits on M1).
9. `scenario.py started` (≤ 15 s for the registered subject's `started` row, matched on runID/epoch/pid), then `scenario.py actions` (the action runner, background, waited on, inside the trap). Only the action runner writes `operator-finish.json`. A failed wait or action → `request_stop scenario-actions-failed`.
10. Wait for Drive (it ends on `operator-finish.json` or the stop file, requests quit and observes closure). A failed action makes the scenario status non-zero even if Drive exits 0.
11. `request_stop sequence-close`; wait for controller and guardian.
12. `check_launch_cleanup.py` with the three statuses.
13. `book.py finish --cleaned` only if 12 passes; otherwise NEEDS-COORDINATOR (with `actions=<status>`). Closure always runs.

### B. Admission (macrev-332-18)
- The full additive admission (C2.4 §4: remaining ≥ `requiredSeconds` + `quitGraceSeconds` + 25 s) runs only before the subject starts: in `drive-u6.py prepare` and in `launch.py`.
- After launch, every U6 tool (Drive's bind check, the action runner before every command, `u6-pointer-plan.py`, `capture_owned.py`, `consent_reset.py`, `prepare_menu_plan.py`) calls `admission.still_admitted`, never `load_and_admit`. It requires: the lease `expectedLease` names, a matching release, guardian true, now inside the lease window, heartbeat age ≤ 2 s, no stop file, not owner-preempted, still exclusive, the booking still started and owned, and remaining ≥ `quitGraceSeconds` + 25 s. Any miss → the tool writes the stop file and the step is NOT-RUN.

### C. Seed and normal-launch runtime (macrev2-332-4/-5, macrev-332-21)
- **Runtime:** Launch gives the subject only PATH (`/usr/bin:/bin`), HOME, TMPDIR and LANG; the App's child-env allowlist drops every `MODELPLAN_*` variable. No pass-through is added. The helper finds the Copilot runtime by its production lookup (`toolcli.Find`): `exec.LookPath` over the fixed PATH first, then `$HOME/.local/bin`, then `$HOME/bin` (macrev-332-23).
- **Selected runtime, checked before any provider call:** `prepare` (and `seed_probe.py`) refuse the attempt, without executing any candidate, unless the executable production lookup would select under the exact Launch environment is the seed's `$HOME/bin/copilot`: no `copilot` in `/usr/bin` or `/bin`, none in `$HOME/.local/bin`, and the `$HOME/bin/copilot` bytes equal the stub pinned in `synthetic-seed.json`. The check resolves paths only; it never runs a candidate.
- **First-attempt seed.** The real seed contains the synthetic Copilot stub at `$HOME/bin/copilot` (no network; fixed synthetic quota) and the `copilot.runtime_usage` grant, and **no Copilot reading and no refresh/rate-limit state**. Step 3 is therefore the first Copilot attempt, which production rate limits allow. Editing stored next-refresh/attempt times is forbidden (it forges rate-limit state), and so is waiting out the cooldown inside the lease.
- **Title:** a throwaway twin home, made by the same builder, runs the synthetic refresh and the released helper's catalogue to obtain the canonical row name (`GitHub Copilot`); only its SHA-256 goes into `synthetic-seed.json`. The twin is deleted before start and is never the launched HOME. There is no second title spelling anywhere.
- **Seed integrity:** the stub's bytes are inside the seed tree digest (`syntheticHomeSeedSHA256`); with the selection check above this proves the stub is the runtime that will run. The builder writes the stub's run binding (runID, epoch) into the seed and leaves its call log absent. `seed_probe.py` runs the actual pinned helper with exactly the four variables against the copied seed and asserts: the stub resolves, the grant is present, no Copilot reading or cooldown state exists, and the catalogue title hash matches.

### D. Step 3 Refresh (replaces C2.4 step 3's pass rule)
Rows, in this order, all carrying R, `sessionID` of A, runID and epoch (macrev-332-24):
1. `refresh` `requested` (R, `rowsSequenceBefore` n, `copilotAccountsBefore` = the number of Copilot accounts in the last accepted rows projection with sequence ≤ n; must be 0) — written by the production handler before it calls `composition.refresh`.
2. `refresh` `accepted` — written from the completion of **that** `refresh/request` call (the per-call reply, never `store.snapshot` or any cached value), with `engineRequestID` (the client's request ID for that call) and `dispositions` copied from that reply (`scope` → `scheduled` | `cooldown` | `read_only` | `offline` | `policy_pending`). It must come before any terminal row for R; a terminal without a matching `accepted` is NOT-RUN.
3. Exactly one terminal row for R within 60 s of `requested`:
   - `completed` — written by the App only when an accepted rows projection with sequence > n shows the Copilot row with `copilotAccountsAfter` ≥ 1 and the seed's synthetic account (`accountIDSHA256` from `synthetic-seed.json`; never the ID or any reading value). It records that projection's `rowsSequenceAfter`. Projections that advance for other scopes before it are ignored, not failures (macrev-332-25).
   - `deferred` — `accepted` shows `copilot.runtime_usage` not `scheduled`.
   - `abandoned` — the watchdog: `cause: "deadline"` at 60 s with no qualifying projection, or `cause: "stop"` when the run stops first. Never `failed`.
   - `failed` — only from a production refresh error.
- **Runtime-call receipt (macrev-332-26):** the stub appends one JSON line per call to `$HOME/.modelplan-stub/runtime-calls.jsonl` (schema `runtime-calls/1`: `runID`, `epoch` from its seeded binding, `method`, `pid`, `ppid`, `mono` (system uptime), `seq`). The log is absent in the seed. Before HOME is removed, Drive copies it to `$BATCH/runtime-calls.jsonl` and records its SHA-256 in `result.json`; `evidence-u6.py` verifies that digest and the binding.
- **Verdict for step 3:**
  - **PASS:** rows 1–3 present and ordered; `accepted.dispositions["copilot.runtime_usage"] = "scheduled"`; terminal `completed` with `copilotAccountsBefore` = 0, `copilotAccountsAfter` ≥ 1, matching `accountIDSHA256`, `rowsSequenceAfter` > n; and exactly the run's receipt shows `account.getQuota` with `mono` after `accepted` and before `completed`.
  - **NOT-RUN:** `deferred` (reason by disposition: `cooldown` → `cooldown`; `read_only`, `offline` → `engine-disabled`; `policy_pending` → `consent-required`), `abandoned` (deadline → `timeout`; stop → `not-delivered`), no terminal, no `accepted`, or a missing/foreign/undigested runtime-call receipt.
  - **FAIL:** `failed`; or `completed` without the qualifying projection or without a matching `account.getQuota` call (a contradiction); or `copilotAccountsBefore` ≠ 0 (the seed was not a first attempt); or a call logged before `accepted`.
- §5 gains the scenario reason `cooldown`.

### E. Clear deadline (steps 5–6)
`accepted-clear` and `menu-scrubbed` for B within 5 s of `clear-initiated` (`mono`). Late → FAIL `timeout` (private content stayed up after the reset); absent → NOT-RUN.

### F. Receipt format and verdict rules
- **Native rows keep the App's current envelope** (`{runID, epoch, pid, seq, mono, at, event, timestamp, checks:{…}}`, `refresh` as written today). `schema/verification` describes that envelope; no App row-shape change.
- A receipt that fails its schema, names another run/epoch/PID or lease window → NOT-RUN (it is ignored, C2.4 §1). Two valid receipts that contradict each other (including a self-contradicting closure receipt, or descending/duplicate `seq`) → FAIL.
- A step outcome reported by the action runner is NOT-RUN with its bounded reason; FAIL comes only from App/helper receipts or a contradiction.
- An unknown native protocol version → NOT-RUN `unknown`.

### G. Required regressions before the kit (package level)
1. **Positive, producer → final entry (CI, Linux):** head-built public CLI as the helper → real `prepare_config` → `homeseed.copy_into` → normal app-server with exactly the Launch environment → `refresh/request` → later rows sequence within 60 s with `copilot.runtime_usage` scheduled and the stub call logged → that run's rows rendered as a native trace → real `evidence-u6.py` → PASS.
2. **Negative:** the twin (refreshed) home in the same setup → Copilot `cooldown`, no advance at 61 s → NOT-RUN `cooldown`. Also: a `copilot` candidate on the fixed PATH (refused before any call, zero calls), missing stub, a preseeded/twin/foreign or pre-`accepted` runtime-call log, an unrelated-only advance (no PASS), an unrelated advance followed by the valid one (PASS), each deferred disposition, a stale `scheduled` value with no per-call `accepted`, and a watchdog stop.
3. **Offline replay:** the oracle (`U6/replay.py`) and `evidence-u6.py` agree on every trace in `tests/test_u6_receipt_schema.py`, with no `expectedFailure` left.

### H. Ownership
- **Coordinator:** A (including the registry-derived booking and the pre-start withdraw trap) and B are on `verification/shared-fixes-332` (pinned); the schema/oracle on `verification/u6-receipt-schema` (pinned, adapted to F). M4 merges both; nobody else pushes to #332.
- **M4:** C (`prepare_config.py`, `seed_probe.py`, the selection check, the stub binding and its `runtime-calls/1` writer), D (`U6DriveGuard.swift` `requested`/`accepted`/terminal rows from the per-call reply and the accepted projection, Drive's receipt copy), the six evidence-u6 disagreements the oracle lists and F's rules in `evidence-u6.py`, and G.1–G.2.
- **Reviewers** review the whole chain against C2.6 at the final head (seam table: seed → Launch env → app-server → App rows → pointer/capture/helper receipts → action runner → closure → final entry).

## Evidence and timing contract (C2.4, coordinator, 2026-10-31)

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
- `requiredSeconds` = the scenario's action phase only (steps 1–7). Launch admission requires remaining lease ≥ `requiredSeconds` + `quitGraceSeconds` + 25 s (`MIN_RESERVE`), as one sum, once. After launch, Drive and every action step use `still_admitted` instead: same lease identity and release, not revoked or stopped, fresh heartbeat, booking still started, and remaining ≥ `quitGraceSeconds` + 25 s (macrev-332-18).
- After the stop file, the subject gets `quitGraceSeconds` (default 5, cap 10). Both supervisors end the grace at once on revocation, lease identity change, a stale guardian heartbeat (> 3 s), a signal to a supervisor, or when only 25 s remain before `expiresAt`; then TERM, then KILL.
- The guardian beats at least every 0.5 s during the grace. Revocation, identity change and deadline outrank an existing stop file.
- Qualification also requires the subject's start and the closure receipt inside the lease window; a late closure is a timing FAIL, reported without suppressing cleanup.

### 5. Bounded codes
**Scenario reasons** (a step's FAIL/NOT-RUN reason in the evidence and the report) use only: `engine-disabled`, `engine-error`, `consent-required`, `timeout`, `not-delivered`, `wrong-subject`, `out-of-window`, `unknown`. **Supervisor diagnostics** (launch.py stop reasons, guardian outcomes, closure-check failure codes such as `deadline`, `lease-identity-missing`, `closure-keys`) keep each tool's own fixed code list; the evidence layer maps them to a scenario reason and never forwards anything outside those lists. Free engine or exception text never enters receipts or the report (macrev2-332-3).

### 6. Pins
The kit's manifest pins the main executable, the bundled engine and the consent helper (paths inside the `.app` and SHA-256). `prepare` verifies the launched bundle's members against it before admission; the evidence records the pins; any change is FAIL.

### 7. Ownership and orchestration
- **M4:** the app rows in §1–3 (seq/mono, sessionID, `menu-private-title-visible`, `clear-initiated`, `menu-end` cause, `menu-scrubbed`, production-path refresh rows, `terminate-completed`), pointer_drive `mono`/`targetPID` echo and capture receipts, the helper wrapper, the action runner and `operator-finish.json`, `evidence-u6.py`, the named seed builder with its arguments and title hash, and the booking command with unit `U6` and scenario `U6-DockMenu-synthetic`.
- **Coordinator (shared toolchain):** the additive admission sum, the 25 s reserve cut in launch.py as well, the lease-window qualification inputs, and `launch-cleanup/1` consistency.
- **M1** runs one invocation (the `SKILL.md` launch branch): the config builder before start, then the monitor (Drive) in the background, a bounded wait (≤ 15 s) for the native `started` row, the action runner under the same stop trap, then stop, waits, closure and finish only on a clean closure. A failed wait or action requests stop, still runs closure and does not finish.

### 8. Merge prerequisite
#332 merges only after M1's U6-R2 run at the final head shows PASS for steps 1–6 and 8–10, or an explicit FAIL/NOT-RUN the owner accepts. Before M1 consumes the kit, an offline replay through the real final entry point must accept one complete valid trace and reject every negative trace named in the reviews.

## Evidence

The scoped action runner drives only Launch's registered subject and writes one `operator-finish.json` on success or failure. It cannot finish the booking. M1 does not run it by hand: the `SKILL.md` launch branch runs the whole attempt as one script, with these U6 inputs set before it (paths are this attempt's fresh run scratch and batch; `--lease`, `--release` and `--subject-pid` must not exist yet):

```sh
RUN_CONFIG="$BATCH/run.json"; BUILD_SCENARIO=u6
BUILD_ARGS=(--scratch "$SCRATCH" --batch "$BATCH" --ledger "$MODELPLAN_BOOKING_LEDGER" \
  --lease "$SCRATCH/lease.json" --release "$SCRATCH/release.json" --subject-pid "$SCRATCH/subject.json" \
  --locks "$LOCKS" --resource-root "$RESOURCE_ROOT" --binary "$CANDIDATE_BINARY" \
  --package "$KIT/ModelPlan-U6-<current-head>.zip" --kit-manifest "$KIT/manifest.json" --head "$HEAD" --private-tool copilot)
ACTION_ARGS=(--pointer-binary "$KIT/pointer_drive")
```

The branch then runs, in order: `scenario.py build` (`U6/prepare_config.py`, before `book.py start`, so the lease path it records exists only after start), start and the `expectedLease` bind, guardian, release, `drive-u6.py prepare`, `launch.py --execute` and `drive-u6.py drive` in the background, the bounded `started` wait, `scenario.py actions` (which runs `U6/action_runner.py --pointer-binary "$KIT/pointer_drive" --config "$RUN_CONFIG"` under the same trap), then stop, the waits, `check_launch_cleanup.py` and `book.py finish` only on a clean closure. The runner and every action tool it calls check `admission.still_admitted` between steps, never the launch budget again.

M1 waits for Drive, Launch and guardian, checks `launch-cleanup/1`, and finishes only a clean booking. Then it runs the raw-receipt final entry and inventory once, with the kit's pinned package and manifest:

```sh
python3 -B "$KIT/desktop/native/verification/bin/evidence-u6.py" --config "$RUN_CONFIG" --batch "$BATCH" --package "$KIT/ModelPlan-U6-<current-head>.zip" --kit-manifest "$KIT/manifest.json"
python3 -B "$KIT/desktop/native/verification/U6/inventory_evidence.py" --config "$RUN_CONFIG"
```

`evidence-u6.py` independently reads the native, pointer, capture, helper, action, quit and closure receipts; caller booleans cannot certify them. It checks source/binary/helper/package/seed pins, native sequence and cross-process monotonic windows. The shared `evidence.py` writes a new manifest with file hashes; `inventory_evidence.py` writes a new batch README and file list once. Missing receipts remain NOT-RUN and contradictions FAIL with bounded codes. Keep only the approved synthetic batch; this scenario cannot establish owner freshness, official appearance or L2/L3 acceptance.

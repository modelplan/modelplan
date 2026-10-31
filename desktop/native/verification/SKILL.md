---
name: native-verification
description: Verify Mac app behavior on a synthetic profile, beginning with the U11a cockpit observation and budget scenario. Use for launch, preflight, evidence collection or review of a native verification attempt.
---

# Native verification (draft)

Run from the checkout root. This skill is draft until a verification run at its exact head. [Feature map](feature-map.md) is owned by integration; unknown routes remain unbound. Public inputs are neutral placeholders only; approved proprietary art is supplied locally.

## 1. Launch

Use `bin/check_inputs.py <root> <entry>` to catch missing relative modules before an attempt; this is a local link check, not a release-asset manifest gate. Use `bin/launch.py --config <run.json>` to validate an existing run contract. `--execute` starts only the explicit test executable with a fresh synthetic HOME/TMPDIR after a matching release and fresh lease. The script creates no scheduling authority. The coordinator grants the epoch and GO; M1 posts window start/end and runs `bin/guardian.py` as the independent watchdog. Owner takeover stops it. The absolute run deadline includes waiting, launch, preflight and cleanup, at most 1200 seconds. Remaining time must cover declared phases plus cleanup, with no arbitrary start cutoff. Non-GUI build/tests need no GUI lease; avoid heavy jobs during announced measurement windows.

M1 uses this exact sequence, run as one bash script per attempt (details and coordinator withdrawal are in
[`bin/BOOKINGS.md`](bin/BOOKINGS.md)). Configure `MODELPLAN_BOOKING_LEDGER` with
the shared ledger path supplied by the coordinator; there is no default. `APPROVAL_URL` must be the
https URL of the coordinator's OK comment; M1 verifies that comment before issuing
the receipt. Copy the returned booking ID into `BOOKING_ID` and the run config. Every step names its
command, the receipt that proves it, and what happens when it fails:

| Step | Receipt | On failure |
| --- | --- | --- |
| `book.py request` / `start` | booking ID; the start event, saved as the lease | before start: `withdraw`; no trap is armed yet |
| `guardian.py` (background) | `guardian: true` heartbeats in the lease; exit 0 = subject confirmed gone | admission refuses; the trap stops the attempt |
| `release.py` | the release file (never overwritten) | the trap requests stop, reaps the guardian, prints NEEDS-COORDINATOR |
| `scenario.py prepare` (registered scenario) | the prepared receipt (U6: `prepared.json` with the attempt token and locks) | prepare writes the stop file and no receipt; the trap closes the attempt |
| `launch.py --execute` (background) | the subject registration in `subjectPidPath`, bound to this run/epoch | the drive step finds no registered subject; closure check decides |
| `scenario.py drive` | its result (U6: `result.json` with `quit` and `cleanup`); exit 0 only after observed closure and released resources | `SCENARIO_STATUS` is non-zero, so the closure check fails |
| normal quit (inside the drive step) | the app's own receipt (U6: `quit.appAcknowledged`, the app's stop row) | the supervisors stop the subject; still a closure question, not a pass |
| stop, then `wait` for both supervisors | `CONTROLLER_STATUS`, `GUARDIAN_STATUS`; both print `quitGraceUsed`/`exitedDuringGrace` | a signal during the wait runs the trap |
| `check_launch_cleanup.py` (launch) / `check_drive_cleanup.py` (drive) | launch: the `launch-cleanup/1` receipt, printed and written to `launch-cleanup.json` beside `stopPath` (U6: in the batch) | no finish; post the NEEDS-COORDINATOR line |
| `book.py finish --cleaned` | the finish event | only reached when the closure check passed |

One attempt is one booking with its own attempt directory and run config: fresh `RUN_ID`/`EPOCH`, its own
lease, release, guardian, stop path, subject registration, scratch and batch. Nothing is reused from an earlier
attempt, and an existing lease/release/stop/registration path refuses the attempt. An aborted or unconfirmed
attempt is never resumed or retried in place; the booking stays started until the coordinator verifies closure
or the documented expiry recovery applies, and a new attempt books anew. The run config names every path
(`leasePath`, `releasePath`, `stopPath`, `subjectPidPath`, …); the sequence reads them from it and binds the
config's `expectedLease` to the lease this attempt started.

```sh
set -e  # any failed step stops the sequence; once the booking has started, the EXIT trap closes the attempt
export PYTHONDONTWRITEBYTECODE=1  # with python3 -B on every call: nothing writes __pycache__ into the kit
V=desktop/native/verification/bin
cfg() {  # cfg KEY [DEFAULT]: one run-config field
  python3 -B -c 'import json,sys; c=json.load(open(sys.argv[1])); print(c[sys.argv[2]] if len(sys.argv) < 4 else c.get(sys.argv[2], sys.argv[3]))' "$RUN_CONFIG" "$@"
}
python3 -B "$V/book.py" request \
  --lane M1 --unit U11a --scenario cold --minutes 20
# ... the coordinator grants GO for this booking (the queue head); set BOOKING_ID ...
RUN_ID="m1-$(uuidgen | tr 'A-Z' 'a-z')"  # fresh per attempt; book.py: printable, at most 128 characters
EPOCH=$(date -u +%Y%m%dT%H%M%SZ)
LEASE_PATH=$(cfg leasePath); RELEASE_PATH=$(cfg releasePath)
STOP_PATH=$(cfg stopPath); SUBJECT_PID_PATH=$(cfg subjectPidPath)  # the one stop path, from the run config
for f in "$LEASE_PATH" "$RELEASE_PATH" "$STOP_PATH" "$SUBJECT_PID_PATH"; do
  [ ! -e "$f" ] || { echo "attempt not fresh: use a new attempt directory and run config" >&2; exit 2; }
done
python3 -B "$V/book.py" start \
  --id "$BOOKING_ID" --lane M1 --run-id "$RUN_ID" --epoch "$EPOCH" > "$LEASE_PATH"
GUARDIAN_PID=; CONTROLLER_PID=; SCENARIO_PID=
request_stop() { (set -C; printf '{"stop": true, "reason": "%s"}\n' "$1" > "$STOP_PATH") 2>/dev/null || true; }
needs_coordinator() {
  echo "NEEDS-COORDINATOR: booking=$BOOKING_ID run=$RUN_ID epoch=$EPOCH $1; booking stays started, not finished" >&2
}
abort() {  # any exit before the closure check: request stop, then stop and reap only this attempt's children
  status=$?; trap - EXIT INT TERM HUP; set +e
  request_stop sequence-aborted
  for pid in $SCENARIO_PID $CONTROLLER_PID $GUARDIAN_PID; do kill -TERM "$pid" 2>/dev/null; done
  for pid in $SCENARIO_PID $CONTROLLER_PID $GUARDIAN_PID; do wait "$pid" 2>/dev/null; done
  needs_coordinator "aborted (status $status) before the closure check"
  exit 3
}
trap abort EXIT INT TERM HUP
python3 -B -c 'import json,sys; c=json.load(open(sys.argv[1])); l=json.load(open(sys.argv[2]))
c["expectedLease"]={k: l[k] for k in ("runID", "epoch", "notBefore", "expiresAt")}; json.dump(c, open(sys.argv[1], "w"))' \
  "$RUN_CONFIG" "$LEASE_PATH"  # bind the run config to this attempt's lease
# Guardian: heartbeat, stop/deadline, and it stops the subject on any exit path (background).
python3 -B "$V/guardian.py" --lease "$LEASE_PATH" \
  --stop "$STOP_PATH" --subject-pid-file "$SUBJECT_PID_PATH" --quit-grace "$(cfg quitGraceSeconds 5)" &
GUARDIAN_PID=$!
python3 -B "$V/release.py" \
  --lane M1 --id "$BOOKING_ID" --lease "$LEASE_PATH" \
  --approval "$APPROVAL_URL" --output "$RELEASE_PATH"
# Exactly ONE controller per booking starts subjects; the guardian's registration lock refuses a
# second one. Set CONTROLLER_MODE explicitly:
#  launch: launch.py starts the app and the scenario drives an app it did not start (e.g. drive-u6.py).
#          A scenario registered in bin/scenarios.json (run config `scenario`) runs its `prepare` in the
#          foreground first and its `drive` below; launch.py refuses a receipt scenario without its prepared
#          receipt. An unregistered launch (no `scenario`, no registered argv flag) keeps the general flow.
#  drive:  drive-scenario.py starts its own subjects (do NOT run launch.py); its cleanup result is read
#          from the batch named in $RUN_CONFIG itself
# Both stay attached and use subjectPidPath=$SUBJECT_PID_PATH from the run config.
SCENARIO=""
case "$CONTROLLER_MODE" in
  launch) SCENARIO=$(python3 -B "$V/scenario.py" name --config "$RUN_CONFIG")
          [ -z "$SCENARIO" ] || python3 -B "$V/scenario.py" prepare --config "$RUN_CONFIG"
          python3 -B "$V/launch.py" --config "$RUN_CONFIG" --execute & ;;
  drive)  python3 -B "$V/drive-scenario.py" --config "$RUN_CONFIG" & ;;
  *) echo "CONTROLLER_MODE must be launch or drive" >&2; exit 2 ;;
esac
CONTROLLER_PID=$!
SCENARIO_STATUS=0  # a registered scenario's drive exits 0 only when it observed closure
if [ -n "$SCENARIO" ]; then
  # Normal quit is the drive step's last action: it asks the owned app to quit and records the app's own
  # receipt (U6: drive-u6.py writes the stop path the native contract names; result.json `quit`).
  python3 -B "$V/scenario.py" drive --config "$RUN_CONFIG" &
  SCENARIO_PID=$!
  wait "$SCENARIO_PID" || SCENARIO_STATUS=$?
else
  : # ... in launch mode, drive the scenario against the launched subject here, ending with its normal quit ...
fi
# Close: request stop (kept when the drive step already wrote it), then wait for both supervisors.
request_stop sequence-close
set +e
wait "$CONTROLLER_PID"; CONTROLLER_STATUS=$?
wait "$GUARDIAN_PID"; GUARDIAN_STATUS=$?
trap - EXIT INT TERM HUP  # every child of this attempt has been reaped
# Record --cleaned ONLY when the independent closure check passes; otherwise do not finish at all.
CLOSURE=1
if [ "$CONTROLLER_MODE" = launch ]; then
  python3 -B "$V/check_launch_cleanup.py" --config "$RUN_CONFIG" --controller-status "$CONTROLLER_STATUS" \
    --guardian-status "$GUARDIAN_STATUS" --scenario-status "$SCENARIO_STATUS" && CLOSURE=0
elif python3 -B "$V/check_drive_cleanup.py" "$RUN_CONFIG" && [ "$GUARDIAN_STATUS" -eq 0 ] \
    && { [ "$CONTROLLER_STATUS" -eq 0 ] || [ "$CONTROLLER_STATUS" -eq 3 ]; }; then
  CLOSURE=0
fi
if [ "$CLOSURE" -eq 0 ]; then
  python3 -B "$V/book.py" finish \
    --id "$BOOKING_ID" --lane M1 --run-id "$RUN_ID" --epoch "$EPOCH" --cleaned
else
  # The booking stays started (the Mac stays held) until the coordinator verifies closure or the
  # documented expiry recovery applies. Post this line with the closure receipt above.
  needs_coordinator "closure unconfirmed: controller=$CONTROLLER_STATUS guardian=$GUARDIAN_STATUS scenario=$SCENARIO_STATUS"
fi
```

`check_launch_cleanup.py` signals and removes nothing. It prints the `launch-cleanup/1` receipt (`runID`, `epoch`, `ok`,
`checks`, `failures`, `at`, plus `stopReasonRecorded` and the lease-window inputs `leaseNotBefore`, `leaseExpiresAt`,
`subjectStartedAt`, `closedAt`, `closedWithinLease`; evidence code checks it with `validate_receipt`) and writes it atomically to `launch-cleanup.json` in the directory of `stopPath`
(U6: `<batch>/launch-cleanup.json`, read by the evidence builder); a receipt it cannot write fails the check.
`ok` holds only when: the registration names this run/epoch and its
subject and launcher identities are gone; launch.py exited 0, or 3 with a stop reason in the stop file; the
guardian and the scenario exited 0; the ledger's head booking is still started for this run/epoch (replayed
without locking or writing); no lock from the prepared receipt or under `locks` still carries this attempt's
token; `syntheticHome`, `syntheticTmp` and any `syntheticHomeSeed` are gone; the stop file exists at `stopPath`.
In launch mode, releasing locks and removing HOME/TMP/seed after observed closure is the scenario drive step's
job (U6: `drive-u6.py`); an unregistered launch has no such step, so its check fails on scratch and goes to the
coordinator.

If the booking is abandoned **before start**, use this instead of start/release/launch:

```sh
python3 -B desktop/native/verification/bin/book.py withdraw \
  --id "$BOOKING_ID" --lane M1 --reason "unit no longer ready"
```

Where writes go: the lease and the subject registration are written under `flock` (`<lease>.lock`,
`<registration>.lock`), which is only reliable on a local disk, so `leasePath` and `subjectPidPath` stay on the
test Mac's local run scratch, never on DevShared. The stop file takes no lock (its writers create it once and
readers only test that it exists), so it lives exactly where the run config's `stopPath` says (U6:
`<batch>/stop.json`); every component and this sequence use that one path. HOME/TMP/seed and lock directories
are in the run scratch; receipts, observations and results are in the batch; nothing is written into the kit
(`PYTHONDONTWRITEBYTECODE=1`, `python3 -B`). Every lease writer (the guardian, Drive's own guardian, any
revocation) goes through `guardian.update_lease`.

A new kit (another head, candidate binary or verification checkout) is admitted per attempt, never carried
over: the run config pins its head and binary hash and the coordinator's OK comment names them; resource
admission (U6: slot locks and disk floor) runs in that attempt's `prepare`; input permissions (for
`pointer_drive`) are granted out of band by the owner for that exact binary. No tool prompts for a permission,
and a missing permission is unsupported or not-run, never a pass.

Quit grace: when the stop file appears, `launch.py` and the guardian first give the registered subject up to the run
config's `quitGraceSeconds` (default 5, capped at 10) to quit by itself (for U6, the guard's `NSApplication.terminate`
on the native contract's stop path), polling its identity, and only then send TERM, then KILL, as before. Both record
`quitGraceUsed` and `exitedDuringGrace` in their output. Other stop reasons (deadline, stale heartbeat, revocation,
signals) get no grace. The guardian's cleanup reserve stays at least 25 seconds. Both supervisors end the grace (and
`launch.py` stops its child as `deadline`) once only 25 seconds remain before `expiresAt`. Admission refuses a lease
whose remaining time is below `requiredSeconds` (the action phase only) + quit grace + 25 seconds, as one sum.

Start issues one lease snapshot with the booked interval and initial heartbeat;
`bin/guardian.py` keeps that heartbeat within admission's 2-second tolerance, writes the stop file at the deadline minus a 30-second cleanup reserve (at least 25), and stops on SIGTERM; a dead guardian makes admission fail closed. The release writer refuses a lease that differs
from the started head or has expired. Only M1 writes a release, and an existing
receipt is never overwritten. Run configs supply `leasePath`, `releasePath` and
`stopPath`, plus the matching booking. Both Launch and Drive use `admission.py` to
reread these files, validate M1's approval reference, heartbeat and timing, then
check live booking ownership. Inline approval does not grant execution. A started
booking cannot be withdrawn; it requires finish or the documented expiry recovery.

Compile test observation code with `MODELPLAN_TEST_ONLY_SPI`; omit this flag in release. `Observation.swift` excludes the WebKit selector/KVC and test RAF message handler from release. Runtime opt-in alone is insufficient. The scoped SPI is limited to the measured synthetic WKWebView, never process-name discovery.

## 2. Doctor

Emit `WindowObservation.fields` with native timestamp, actual activation call, viewID and generation before applying any combined gate. `bin/doctor.py` reports running, active, key, visible, WebKit, disk and lease individually as timestamped pass/fail. A failed conjunction must retain which condition failed; it is not evidence of owner input. Record the activation call actually made, including explicit `not-invoked` when none was used. Never repeatedly steal focus.

U11a preflight is a **separate** two-second test-only WKScriptMessageHandler RAF proof. Use `VerificationFrameHandler` and `installVerificationRAFTicks`; native elapsed time and advancing frame counts must span two seconds. The preflight also closes and reopens its owned window once to catch lifetime faults before long sampling. Dispose that preflight view/process before starting the cold measurement App/baseline, so preflight cannot prewarm the baseline. A windowless cold baseline records App state without requiring key/visible window conditions; the stop hook arms only on activity actually observed in that current App process. No completed GUI receipt is required merely to schedule a future run. The admitted run collects it.

Keep per-region animation timeline controls from `animation-observer.js` as stronger complementary evidence. DOM presence and one RAF are insufficient. [Neutral controls](fixtures/animation-controls.html) qualify the mechanism; they do not substitute for the actual cockpit.

## 3. Drive

M2 owns `bin/drive-scenario.py` and its independent tests. The command orchestrates one announced epoch with an independent watchdog, separate preflight process, and three measured cycles. M1 independently checks the final closure.

First scenario: U11a, three cycles of **60s pre-open baseline → 60s open → close → 60s post-close**. Preflight two seconds is separate; all waits and cleanup stay within the absolute lease. Gate/frame/post-close evidence missing means **not-run**, never a performance-budget failure. A requested open is not confirmed active appearance. Indicator/session/HUD activity and static porthole inputs must be pinned in the subject.

For each view capture WebContent PID plus start identity; retire on replacement, teardown and `webViewWebContentProcessDidTerminate`. Bind window/frame/attribution receipts to the same viewID/generation. PID changes invalidate previous ownership. GPU/other WebKit attribution uses pre/post snapshots of the already isolated synthetic session only; `bin/attribute_webkit.py` rejects ambiguous or unattributed hosts. No unrelated process inventory or guessed PID. `top` samples only verified role PIDs; missing capability is unsupported, never zero.

## 4. Evidence

`bin/evidence.py` writes a new `manifest.json` and file hashes in the approved independent evidence batch. Bind source head, profile, scenario IDs, outcomes, attribution method, source units and actual cleanup. Reports/CSVs go only to the approved exchange batch, with README/file list; stop and report any refused write to M0, without retry. Project updates are consolidated by M0. Screenshots are synthetic and task-scoped only; no owner account data.

`bin/verify_u11a.py` checks correlated observation evidence. Reuse `scripts/u11a-aggregate.py` and `docs/u11a-aggregation.md`: App uses `native-self-counters`; attributed WebContent/GPU use genuine `top` exports. Never relabel a source or write another reducer.

The approved open budget is average App + WebContent + GPU <=10% of one core. Missing role/activation/frame/post-close coverage cannot establish a total pass. Report canonical after-close RSS differences and cycle endpoints/trend without inventing numeric memory tolerance. Energy may be unsupported. An interrupted actual attempt stays distinguishable from an unlaunched run. A merge or non-GUI check is not GUI/L2 completion.

## 5. Cleanup

M2 owns `bin/cleanup-run.py` and its tests. It quits owned processes, verifies closure, releases only this run's lease/resources and deletes only approved scratch. Retain evidence until its cleanup policy permits deletion. M2 posts start and end+cleaned receipts for the granted run; M1 checks closure independently (`bin/check_launch_cleanup.py` in launch mode, `bin/check_drive_cleanup.py` in drive mode). No automatic renewal or retry after interruption. A granted test run may request foreground activation once when needed; record the actual call, then stop on subsequent loss of activation rather than continuously reclaiming focus.

## 6. Helpers

M2 owns the whole verification skill, including Drive/Cleanup and integration; M1 independently checks post-run closure. M0 reviews and merges. Stable commands live in `bin/`; do not rewrite them in each lane.

For named status-menu actions and native arrival correlation, follow [StatusMenu/README.md](StatusMenu/README.md) before driving the item.

Non-GUI qualification:

```
python3 -m unittest discover -s desktop/native/verification -p 'test_*.py'
python3 -m unittest discover -s desktop/native/verification/tests -p 'test_*.py'
node desktop/native/verification/test-animation-observer.mjs
node desktop/native/verification/test-stable-layer.mjs
node scripts/check-source-policy.mjs
```

Drive/Evidence portions that need no GUI also belong on the standard free hosted macOS checks. Actual test-build compilation, scoped PID capability, two-second preflight, full cycles and cleanup at the submitted head remain required run evidence; their missing outcomes stay explicit.

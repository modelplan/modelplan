---
name: native-verification
description: Verify Mac app behavior on a synthetic profile, beginning with the U11a cockpit observation and budget scenario. Use for launch, preflight, evidence collection or review of a native verification attempt.
---

# Native verification (draft)

Run from the checkout root. This skill is draft until a verification run at its exact head. [Feature map](feature-map.md) is owned by integration; unknown routes remain unbound. Public inputs are neutral placeholders only; approved proprietary art is supplied locally.

## 1. Launch

Use `bin/check_inputs.py <root> <entry>` to catch missing relative modules before an attempt; this is a local link check, not a release-asset manifest gate. Use `bin/launch.py --config <run.json>` to validate an existing run contract. `--execute` starts only the explicit test executable with a fresh synthetic HOME/TMPDIR after a matching release and fresh lease. The script creates no scheduling authority. The coordinator grants the epoch and GO; M1 posts window start/end and runs `bin/guardian.py` as the independent watchdog. Owner takeover stops it. The absolute run deadline includes waiting, launch, preflight and cleanup, at most 1200 seconds. Remaining time must cover declared phases plus cleanup, with no arbitrary start cutoff. Non-GUI build/tests need no GUI lease; avoid heavy jobs during announced measurement windows.

M1 uses this exact sequence (details and coordinator withdrawal are in
[`bin/BOOKINGS.md`](bin/BOOKINGS.md)). Configure `MODELPLAN_BOOKING_LEDGER` with
the shared ledger path supplied by the coordinator; there is no default. Use the
agreed synthetic file paths and run/epoch values below. `APPROVAL_URL` must be the
https URL of the coordinator's OK comment; M1 verifies that comment before issuing
the receipt. Copy the returned booking ID into `BOOKING_ID` and the run config.

```sh
set -e  # any failed step before launch stops the sequence (no release, no launch)
python3 desktop/native/verification/bin/book.py request \
  --lane M1 --unit U11a --scenario cold --minutes 20
python3 desktop/native/verification/bin/book.py start \
  --id "$BOOKING_ID" --lane M1 --run-id "$RUN_ID" --epoch "$EPOCH" > "$LEASE_PATH"
# Guardian: heartbeat, stop/deadline, and it stops the subject on any exit path (background).
python3 desktop/native/verification/bin/guardian.py --lease "$LEASE_PATH" \
  --stop "$STOP_PATH" --subject-pid-file "$SUBJECT_PID_PATH" &
GUARDIAN_PID=$!
python3 desktop/native/verification/bin/release.py \
  --lane M1 --id "$BOOKING_ID" --lease "$LEASE_PATH" \
  --approval "$APPROVAL_URL" --output "$RELEASE_PATH"
# Launch stays attached and stops its child on the stop file, a stale heartbeat, revocation or the deadline.
# The run config sets subjectPidPath to $SUBJECT_PID_PATH.
python3 desktop/native/verification/bin/launch.py --config "$RUN_CONFIG" --execute &
LAUNCH_PID=$!
# ... drive the scenario against the launched subject ...
# Close: request stop, then wait for both supervisors. Record --cleaned ONLY when the guardian
# confirmed closure (exit 0) and launch ended normally (0) or by supervision (3); otherwise do not
# finish at all and report the run as unconfirmed for coordinator follow-up.
touch "$STOP_PATH"
set +e
wait "$LAUNCH_PID"; LAUNCH_STATUS=$?
wait "$GUARDIAN_PID"; GUARDIAN_STATUS=$?
if [ "$GUARDIAN_STATUS" -eq 0 ] && { [ "$LAUNCH_STATUS" -eq 0 ] || [ "$LAUNCH_STATUS" -eq 3 ]; }; then
  python3 desktop/native/verification/bin/book.py finish \
    --id "$BOOKING_ID" --lane M1 --run-id "$RUN_ID" --epoch "$EPOCH" --cleaned
else
  # Do not finish: the booking stays started (the Mac stays held) until the coordinator verifies
  # closure or the documented expiry recovery applies.
  echo "closure unconfirmed: launch=$LAUNCH_STATUS guardian=$GUARDIAN_STATUS; report to the coordinator" >&2
fi
```

If the booking is abandoned **before start**, use this instead of start/release/launch:

```sh
python3 desktop/native/verification/bin/book.py withdraw \
  --id "$BOOKING_ID" --lane M1 --reason "unit no longer ready"
```

Keep `LEASE_PATH`, `STOP_PATH` and `SUBJECT_PID_PATH` on the test Mac's local disk (run scratch), never on DevShared: lease writers coordinate with `flock` on `<lease>.lock`, which is only reliable locally. Every lease writer (the guardian, Drive's own guardian, any revocation) goes through `guardian.update_lease`.

Start issues one lease snapshot with the booked interval and initial heartbeat;
`bin/guardian.py` keeps that heartbeat within admission's 2-second tolerance, writes the stop file at the deadline minus a 15-second cleanup reserve, and stops on SIGTERM; a dead guardian makes admission fail closed. The release writer refuses a lease that differs
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

M2 owns `bin/cleanup-run.py` and its tests. It quits owned processes, verifies closure, releases only this run's lease/resources and deletes only approved scratch. Retain evidence until its cleanup policy permits deletion. M2 posts start and end+cleaned receipts for the granted run; M1 checks closure independently. No automatic renewal or retry after interruption. A granted test run may request foreground activation once when needed; record the actual call, then stop on subsequent loss of activation rather than continuously reclaiming focus.

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

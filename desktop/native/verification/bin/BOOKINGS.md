<!-- SPDX-License-Identifier: MIT -->
# Single-Mac GUI booking queue

M2 owns the verification skill and reviews its admission integration. `book.py`
provides cooperative FIFO scheduling on DevShared. It does **not** grant a GUI
lease, coordinator GO, foreground permission or permission to use owner data.
Launch's existing release, guardian, deadline and synthetic-profile checks still
apply. Non-GUI builds/tests and Launch's contract-only validation need no booking.

The shared ledger is
`/mnt/shared/modelplan/handoffs/gui-bookings/ledger.jsonl`. All lanes using the
same test Mac must use that ledger. `--ledger` and the config's `booking.ledger`
override are for isolated qualification fixtures, not independent real-run queues.
The ledger is a coordination record, not a security boundary; its writers are
trusted lanes on the approved share.

## One session, one unit, several scenarios

From the checkout root (invoke all commands with `python3`):

```sh
python3 desktop/native/verification/bin/book.py request \
  --lane M2 --unit U11a --scenario cold --scenario repeated-open-close --minutes 20
python3 desktop/native/verification/bin/book.py status
python3 desktop/native/verification/bin/book.py start \
  --id BOOKING_ID --lane M2 --run-id RUN_ID --epoch EPOCH
```

`request` prints the booking ID and serialized sequence. Arrival means append
order under the lock, not the timestamp at which a process was spawned. The
head is the oldest request not finished or expired. `start` succeeds exactly
once, only for that head and lane. Non-head callers stop and await the
coordinator's handoff; do not poll/start in a busy-retry loop. A queued request
does not hold the Mac. Make requests for ready work; an abandoned, unstarted
head requires coordinator resolution and is never silently skipped by expiry.

`--minutes` is an integer from 1 through 20, default 20. The absolute booking
deadline is start time plus this duration. Every scenario in the group must be
from the single declared unit and fit within that same session, including
preflight, waits and cleanup. There is no extension or automatic renewal.
Do not start a fresh booking for every scenario or finish between scenarios.

After `start`, obtain the matching coordinator-directed release/guardian lease
and use this additional field in the Launch or Drive run JSON:

```json
{
  "booking": {
    "id": "BOOKING_ID",
    "lane": "M2",
    "unit": "U11a",
    "scenario": "cold"
  }
}
```

The lease's `runID` and `epoch` must match `start`; its `notBefore` must be at or
after the booking start and its `expiresAt` must not exceed the booking deadline.
Synchronize participating hosts' clocks. The required phase-plus-cleanup time
must fit the remaining booking time. All scenarios in the session share this
run identity and deadline; set `booking.scenario` to the booked scenario being
executed. A booking is not evidence that any scenario actually ran or passed.

`launch.py --execute` checks the live ledger before creating the synthetic home
and again immediately before process launch. `drive-scenario.py` checks before
setup and before each preflight/measurement launch. Missing, non-head, unstarted,
expired or mismatched bookings refuse execution. Drive's heavy-resource admission
is one attempt: if another reservation exists or races it, stop, release only
this attempt's resources and report to the coordinator. No GUI busy-retry loop.

After all grouped scenarios and the shared Cleanup procedure, confirm closure
and finish explicitly:

```sh
python3 desktop/native/verification/bin/book.py finish \
  --id BOOKING_ID --lane M2 --run-id RUN_ID --epoch EPOCH --cleaned
```

This records **`end + cleaned`** and advances the queue. `--cleaned` is the
operator's cleanup attestation, not an automated process-closure probe. Existing
Cleanup and independent closure evidence are still required. A different lane,
run, epoch or booking cannot finish the holder.

## Expiry and recovery

```sh
python3 desktop/native/verification/bin/book.py expire
```

Only a started head at or beyond its deadline **plus 120 seconds of grace** is
released. The grace period permits cleanup, never additional GUI execution.
Launch stops admitting at the actual deadline. Status shows `expiryEligible`
but never changes state; `expire` appends the release event explicitly. An
early call prints `no-expiry` without appending. Expiry records `cleaned: null`
and **cleanup unconfirmed**, never a fabricated cleaned receipt. The next lane
still needs the ordinary release/guardian/GO and verified resource admission;
expiry does not kill a process, certify closure or override an owner stop.
The existing independent watchdog remains responsible for stopping the old run
by its absolute lease deadline. Do not admit a new GUI run while closure is
unconfirmed; report that state to the coordinator.

Every read and append holds an atomic `ledger.jsonl.lock/` directory on the
same share, then an exclusive `flock` on the ledger where supported. The
directory is mandatory even if `flock` reports success: some SMB configurations
implement it only locally. Unsupported-flock errors use the directory alone;
other lock/I/O errors fail closed. All readers cooperate, so a reader cannot
observe a writer's partial line. Appends flush and `fsync` before unlocking.
The transaction lock waits at most five seconds; this short I/O wait is separate
from GUI queue admission. JSON output goes to stdout; refusals are JSON on
stderr with exit status 2.

A process crash can leave a transaction lock or incomplete final line. Neither
is automatically stolen, truncated or repaired. Stop and report the lock's
`owner.json` (host/PID) and error. The coordinator must confirm the writer has
stopped on its host, preserve the ledger and resolve the lock/partial append
before resuming. Do not use lock age or a remote PID lookup to infer ownership
is dead. On a refused/ambiguous write, stop and report instead of retrying a
request that may already have committed. A single locked `status` after recovery
can establish the recorded state.

## Qualification without GUI

```sh
python3 -m unittest discover -s desktop/native/verification/tests -p 'test_book.py'
```

Tests use temporary ledgers, independent requester processes, simulated
unsupported `flock`, controlled expiry clocks and mocked process launches.
They do not create live bookings or launch a GUI. Filesystem tests on a Linux
share cannot establish cross-client SMB locking on the Mac; M2 should confirm
atomic directory exclusion from both clients before relying on that transport.

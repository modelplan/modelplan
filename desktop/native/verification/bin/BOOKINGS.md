<!-- SPDX-License-Identifier: MIT -->
# Single-Mac GUI booking queue

M2 owns the verification skill and reviews its admission integration. `book.py`
provides cooperative FIFO scheduling on the approved shared filesystem. It does **not** grant a GUI
lease, coordinator GO, foreground permission or permission to use owner data.
Launch's existing release, guardian, deadline and synthetic-profile checks still
apply. Non-GUI builds/tests and Launch's contract-only validation need no booking.

Use the shared ledger path configured by the coordinator. All lanes using the
same test Mac must use that ledger. There is no built-in path: pass `--ledger`
before the subcommand or set `MODELPLAN_BOOKING_LEDGER`. Launch/Drive use the
run config's `booking.ledger` or that same environment variable. An explicit
CLI/config path takes precedence over the environment. Missing or blank
configuration refuses with a clear error before opening a ledger. Isolated
qualification fixtures use their own temporary ledger, never an independent
real-run queue.
The ledger is a coordination record, not a security boundary; its writers are
trusted lanes on the approved share.

## One session, one unit, several scenarios

From the checkout root (invoke all commands with `python3`), set
`MODELPLAN_BOOKING_LEDGER` to the shared ledger path configured by the coordinator
before using these commands:

```sh
python3 desktop/native/verification/bin/book.py request \
  --lane M2 --unit U11a --scenario cold --scenario repeated-open-close --minutes 20
python3 desktop/native/verification/bin/book.py status
python3 desktop/native/verification/bin/book.py start \
  --id BOOKING_ID --lane M2 --run-id RUN_ID --epoch EPOCH
```

`request` prints the booking ID and serialized sequence. Arrival means append
order under the lock, not the timestamp at which a process was spawned. The
head is the oldest request not finished, expired or withdrawn. `start` succeeds exactly
once, only for that head and lane. Non-head callers stop and await the
coordinator's handoff; do not poll/start in a busy-retry loop. A queued request
does not hold the Mac. Make requests for ready work; an abandoned, unstarted
head requires explicit `withdraw` and is never silently skipped by expiry.

## Withdraw queued work

The requesting lane may withdraw its queued booking, including a non-head
booking. The coordinator resolution path for an abandoned queued head is:

```sh
python3 desktop/native/verification/bin/book.py withdraw \
  --id BOOKING_ID --coordinator --reason "requesting lane unavailable"
```

For an owner-initiated withdrawal, use `--lane M2` instead of `--coordinator`.
Both forms require a nonempty printable reason (at most 128 characters). The
event records the actor and reason, retains the booking in history as
`withdrawn`, and advances the head when necessary. It does not attest cleanup
or authorize a GUI session. A started or terminal booking cannot be withdrawn;
started work still uses finish or expiry and the existing closure checks.
The explicit coordinator flag is an attestation by trusted share writers,
not an authentication mechanism. Never impersonate another requesting lane.

## Run the booked session

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

Both tools require `releasePath` in the run config, pointing to the existing
M1 release file, plus `leasePath` and `stopPath`. The shared `admission.py` loader
reads both files, validates release approval, live heartbeat, timing, exclusivity
and stop state, then calls the live booking gate. Launch uses it before setup
and again after hashing; Drive uses it before any child (including its guardian)
and before each subject launch. Inline run-config approvals cannot replace the
external files. Missing, false, revoked or mismatched records refuse execution.

## Exact M1 command sequence

Set `MODELPLAN_BOOKING_LEDGER` to the shared ledger path configured by the
coordinator. Set `LEASE_PATH`, `RELEASE_PATH`, `RUN_CONFIG`, `RUN_ID`, `EPOCH`
and `APPROVAL_URL` to the agreed synthetic run files/identifiers and the https URL
of the coordinator's OK comment. The run config must reference these same lease
and release files, the stop path, the returned booking ID and booked unit/scenario.

```sh
python3 desktop/native/verification/bin/book.py request \
  --lane M1 --unit U11a --scenario cold --minutes 20
# Set BOOKING_ID to the returned id; start only after the queued head is handed off.
python3 desktop/native/verification/bin/book.py start \
  --id "$BOOKING_ID" --lane M1 --run-id "$RUN_ID" --epoch "$EPOCH" > "$LEASE_PATH"
```

From here on, follow the exact guarded sequence in [`../SKILL.md`](../SKILL.md): start
`guardian.py` (heartbeat, stop/deadline, subject supervision), then `release.py`, then the
supervised launch or Drive run, and record `finish --cleaned` only when the guardian has
confirmed closure. It is not repeated here, so the two cannot drift apart.


If work is abandoned **while still queued**, replace start/release/launch with:

```sh
python3 desktop/native/verification/bin/book.py withdraw \
  --id "$BOOKING_ID" --lane M1 --reason "unit no longer ready"
```

`start` emits a lease snapshot with the exact booked start/deadline and initial
heartbeat; this is not an independent watchdog or release approval. The heartbeat
must stay at most two seconds old. Only M1 runs `release.py`, with explicit
`--lane M1` and `--approval`; the writer checks the started head and exact issued
lease identity/interval under the ledger lock, refuses expired leases and never
overwrites a receipt. The receipt contains only that identity and M1's approval
reference. The lane flag and approval reference attest the operator's authority;
trusted writers must verify the linked comment is the coordinator's OK.
M1 may release a booked session owned by another requesting lane, but must use
that lane for its booking start/finish operations. Withdrawal cannot cancel an
already started session. A release never extends a lease or certifies cleanup.

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
`owner.json` and error. The record contains only the caller's lane/unit labels
where supplied and a random per-process `processToken`, never a hostname, PID
or user/home path. Status and expiry have no caller lane/unit, so record only
the token. The token correlates transactions from one process; it does not prove
that a writer has stopped. The coordinator must confirm closure with the owning
lane, preserve the ledger and resolve the lock/partial append before resuming.
Do not use lock age or a remote PID lookup to infer ownership
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

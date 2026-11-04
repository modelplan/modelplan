<!-- SPDX-License-Identifier: MIT -->
# M1 sequence end-to-end coverage and gaps

`tests/test_m1_sequence_e2e.py` runs the whole M1 sequence from [SKILL.md](SKILL.md) section 1
(`bin/BOOKINGS.md` "Exact M1 command sequence") against a fake subject app (a tiny python
script that stays up until signalled) in a temporary ledger/run directory. Every step goes
through the real CLIs via subprocess — `book.py` (request/start/finish/status), `guardian.py`,
`release.py`, `launch.py --execute`, `drive-scenario.py --config`, `check_drive_cleanup.py` —
never through script internals. Runtime is about 8 seconds on Linux.

## Covered

- **Launch-mode happy path**: request → start → guardian takes the lease heartbeat →
  `release.py` (plus "an existing receipt is never overwritten") → `launch.py --execute`
  spawns the exec-gated subject → stop file → both supervisors exit (controller 0/3,
  guardian 0 with `subjectClosed`) → no leftover subject process → `finish --cleaned` →
  `status` shows the booking finished with `cleaned: true` and an empty queue (lease released).
- **Second controller refused**: while the first controller's subject is registered and
  alive, a second `launch.py --execute` on the same booking/lease/pid-file is refused by the
  registration lock ("one controller per booking"), the registration is not replaced, and the
  original booking still closes and finishes afterwards.
- **Drive without a released lease refused**: with no `release.py` receipt, `drive-scenario.py`
  fails before creating any batch/scratch/lock resource or registering a subject, and the
  booking stays started.
- **Crashed subject**: the subject registers and then exits by itself; `launch.py` ends
  normally (exit 0, `stoppedBy: null`), but `check_drive_cleanup.py` fails (no verified
  cleanup batch), so the sequence does not finish and the booking keeps holding the lease.
  With the launcher gone, the guardian ends as `launcher-lost` with `subjectClosed: true`
  (exit 3); the test waits for that exit instead of racing the guardian's next poll.
- **Drive-mode leg (expected-fail, see gap 1)**: booking, guardian heartbeat and release all
  admit; the attempt is recorded `not-run` with reason `OSError-errno-*`; the gated child is
  killed before running and never registered; drive removes its scratch and locks and writes
  the stop file; `check_drive_cleanup.py` passes on the cleanup evidence, but the guardian
  cannot confirm closure (exit 3, `subjectClosed: false`), so the sequence correctly does not
  finish and the booking stays started.

Per SKILL.md, `check_drive_cleanup.py` is a drive-mode-only step (launch-mode closure is the
guardian's confirmed exit); the test asserts both accordingly.

## Gaps (macOS-only steps with no existing test seam)

1. **Drive subject launch needs macOS process identity** — `drive-scenario.py:116`
   (`ident=cleanup.identity(self.app.pid)`) resolves the subject's start identity through
   `cleanup-run.py:9` (`ctypes.CDLL('/usr/lib/libproc.dylib')`), which does not exist on
   Linux. There is no test seam (no env/flag to substitute the identity lookup), and none was
   added. On Linux the drive controller always fails there: outcome `not-run`,
   reason `OSError-errno-None`, subject registration stuck at `launching`, guardian exit 3.
   The drive-mode leg asserts exactly this documented behavior and is marked expected-fail.
   A full drive happy path (subject protocol, cycles, `finish --cleaned` after drive closure)
   is therefore **not** achievable on Linux without changing `drive-scenario.py`.
2. **Full drive measurement duration** — `drive-scenario.py:19` (`plan()`) hardcodes three
   cycles of three 60-second phases (540 s) and `drive-scenario.py:21` (`valid()`) requires
   ≥690 s of remaining lease. No seam shortens the phases, so even on macOS the E2E would
   take ~9.5 minutes; it is not exercised here.
3. **Drive owned-process stop and top observer** — `drive-scenario.py:206`
   (`cleanup.stop_owned`) and `drive-scenario.py:141`/`153` also resolve identity via
   libproc, and `drive-scenario.py:143` shells out to macOS `/usr/bin/top -l`. All are
   macOS-only and unreachable on Linux because gap 1 stops the attempt first.
4. **`cleanup-run.py` CLI on Linux** — its PID verification (`cleanup-run.py:7-11`) uses
   libproc, so the CLI cannot confirm real processes on Linux. The M1 sequence in SKILL.md
   does not invoke it directly (Drive calls the module internally; `guardian.py:82-93` has
   the `/proc` fallback for subject supervision), so the E2E relies on the guardian for
   closure and does not drive `cleanup-run.py` as a CLI step.
5. **Drive resource admission needs a large disk** — `drive-scenario.py:175` requires
   ~14.6 GiB free on `resourceRoot` (and `drive-scenario.py:173` runs `/usr/bin/du` per
   `buildRoots`). The E2E passes an empty `buildRoots` and a temporary `resourceRoot`; on a
   runner with less free space the drive leg would fail earlier with `resource-disk-floor`.

## Workflow wiring

The test lives in `desktop/native/verification/tests/`, which `desktop.yml` ("Verification Drive and Evidence pure checks") already discovers on macOS. The drive-mode leg is Linux-only by design (it documents gap 1), so it is skipped there; the four other cases run.

## Output

```
$ python3 -m unittest discover -s desktop/native/verification/tests -p 'test_*.py'
Ran 82 tests in 11.526s
OK
```

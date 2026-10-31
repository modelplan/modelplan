# SPDX-License-Identifier: MIT
"""Lease guardian for one started booking: heartbeat, stop/deadline, and supervision of the subject.

Run it in the background right after `book.py start`, before `release.py` and `launch.py`.
- Every interval it updates `guardianHeartbeatAt` (and marks `guardian: true`) under an exclusive
  lock on `<lease>.lock`, re-reading the lease inside the lock. It never changes identity fields and
  stops if anything revoked the lease (identity changed, `ownerPreempted` true, `exclusive` false).
  Any other lease writer must take the same lock (use `update_lease`).
- It stops on the stop file, the deadline minus the cleanup reserve, SIGTERM/SIGINT, or any error.
  On every exit path it writes the stop file and, if `--subject-pid-file` names a live subject,
  terminates it (TERM, then KILL) and waits for it to be gone. When the stop file ended the run, the
  subject first gets up to `--quit-grace` seconds (run config `quitGraceSeconds`, default 5, capped at
  10) to quit by itself; it is signalled only if it is still running after that. Exit status 0 means the subject is
  confirmed gone (or never started); anything else means closure is NOT verified.
- `launch.py --execute` independently stops its child when the heartbeat goes stale, so a killed
  guardian still fails closed; admission refuses a launch until the guardian has taken over.
"""
import argparse
import contextlib
import fcntl
import importlib.util
import json
import math
import os
from pathlib import Path
import signal
import sys
import time

_spec = importlib.util.spec_from_file_location('cleanup', Path(__file__).with_name('cleanup-run.py'))
cleanup = importlib.util.module_from_spec(_spec); _spec.loader.exec_module(cleanup)

IDENTITY = ('runID', 'epoch', 'notBefore', 'expiresAt')
MIN_RESERVE = 25.0  # TERM grace 10 s + KILL wait 5 s + closure checks and a late wakeup
QUIT_GRACE_DEFAULT = 5.0  # after the stop file: time for the subject's own normal quit before any signal
QUIT_GRACE_MAX = 10.0


def quit_grace(value):
    """The run config's `quitGraceSeconds`: default 5, capped at 10; anything but a finite number >= 0 refuses."""
    if value is None:
        return QUIT_GRACE_DEFAULT
    if type(value) not in (int, float) or not math.isfinite(value) or value < 0:
        raise ValueError('quitGraceSeconds must be a finite number of seconds >= 0')
    return float(min(value, QUIT_GRACE_MAX))


class Revoked(Exception):
    pass


def write_atomic(path, record):
    tmp = path.with_name(path.name + '.tmp')
    with tmp.open('w') as file:
        json.dump(record, file, allow_nan=False)
        file.write('\n'); file.flush(); os.fsync(file.fileno())
    os.replace(tmp, path)


@contextlib.contextmanager
def locked(lease_path):
    with lease_path.with_name(lease_path.name + '.lock').open('a') as handle:
        fcntl.flock(handle, fcntl.LOCK_EX)
        try:
            yield
        finally:
            fcntl.flock(handle, fcntl.LOCK_UN)


def update_lease(lease_path, change):
    """Read-modify-write of the lease under the shared lock. `change(record)` returns the new record."""
    with locked(lease_path):
        record = json.loads(lease_path.read_text())
        new = change(dict(record))
        write_atomic(lease_path, new)
        return new


def beat(lease_path, identity, now):
    def change(record):
        if {k: record.get(k) for k in IDENTITY} != identity:
            raise Revoked('lease identity changed')
        if record.get('ownerPreempted') is not False or record.get('exclusive') is not True:
            raise Revoked('lease revoked or preempted')
        record.update(guardianHeartbeatAt=now, guardian=True)
        return record
    update_lease(lease_path, change)


def stop(stop_path, reason, now):
    if not stop_path.exists():
        write_atomic(stop_path, dict(stop=True, reason=reason, at=now))


def identity(pid):
    """Owned process identity: positive PID plus start time (macOS libproc; /proc elsewhere)."""
    if type(pid) is not int or pid <= 0:
        return None
    if sys.platform == 'darwin':
        return cleanup.identity(pid)
    try:
        fields = Path(f'/proc/{pid}/stat').read_text().rsplit(')', 1)[1].split()
    except OSError:
        return None
    if fields[0] in ('Z', 'X'):
        return None  # exited, awaiting reaping by its parent
    return dict(pid=pid, startSeconds=int(fields[19]), startMicroseconds=0)


@contextlib.contextmanager
def registration(pid_file):
    """Serialises every read-check-write of the subject registration across controllers."""
    with pid_file.with_name(pid_file.name + '.lock').open('a') as handle:
        fcntl.flock(handle, fcntl.LOCK_EX)
        try:
            yield
        finally:
            fcntl.flock(handle, fcntl.LOCK_UN)


def mark_launching(pid_file, lookup=None, run=None):
    """A controller (launch.py or Drive), before spawning: reserve the registration (exec gate).

    One controller per booking: under the registration lock, refuse while a registered subject is
    still alive or another live controller holds the reservation. `run` (runID/epoch) binds the
    registration to one run, so a closure check can tell this run's subject from a stale record.
    """
    lookup = lookup or identity
    with registration(pid_file):
        me = lookup(os.getpid())
        if me is None:
            raise ValueError('launcher identity unavailable')
        if pid_file.exists():
            try:
                prior = json.loads(pid_file.read_text())
            except (OSError, ValueError):
                raise ValueError('subject registration unreadable; resolve before launching')
            if prior.get('state') == 'running' and cleanup.matches(lookup(prior.get('pid')), prior):
                raise ValueError('another owned subject is still running; one controller per booking')
            launcher = prior.get('launcher')
            if (prior.get('state') == 'launching' and isinstance(launcher, dict)
                    and not cleanup.matches(me, launcher) and cleanup.matches(lookup(launcher.get('pid')), launcher)):
                raise ValueError('another controller is launching; one controller per booking')
        write_atomic(pid_file, dict(state='launching', launcher=me, **run_fields(run)))
        return me


def run_fields(run):
    """runID/epoch of the run a registration belongs to (empty when the controller supplies none)."""
    if run is None:
        return {}
    if not isinstance(run, dict) or not all(isinstance(run.get(k), str) and run[k] for k in ('runID', 'epoch')):
        raise ValueError('registration run identity invalid')
    return dict(runID=run['runID'], epoch=run['epoch'])


def register(pid_file, pid, launcher=None, lookup=None, run=None):
    """The reserving controller records its subject before releasing the exec gate."""
    lookup = lookup or identity
    with registration(pid_file):
        try:
            current = json.loads(pid_file.read_text())
        except (OSError, ValueError):
            raise ValueError('reservation missing')
        if current.get('state') != 'launching' or not cleanup.matches(launcher, current.get('launcher') or {}):
            raise ValueError('reservation not held by this controller')
        bound = run_fields(run)
        if any(current.get(k) != v for k, v in bound.items()):
            raise ValueError('reservation belongs to another run')
        ident = lookup(pid)
        if ident is None:
            raise ValueError('subject identity unavailable')
        write_atomic(pid_file, dict(state='running', launcher=launcher, **bound, **ident))
        return ident


def launcher_lost(pid_file, lookup=identity):
    """True when a registered subject's launcher (its supervisor) has disappeared."""
    try:
        record = json.loads(pid_file.read_text())
    except (OSError, ValueError, AttributeError, TypeError):
        return False
    launcher = record.get('launcher')
    return (record.get('state') == 'running' and isinstance(launcher, dict)
            and not cleanup.matches(lookup(launcher.get('pid')), launcher))


def terminate(pid_file, grace=10.0, lookup=identity, send=os.kill, clock=time.monotonic, sleep=time.sleep,
              quit_grace=0.0, report=None, urgent=lambda: False):
    """Stop the owned subject and confirm it is gone. Returns True only when closure is verified.

    No file means nothing was ever launched. A 'launching' marker or an unreadable file is
    unconfirmed. A PID whose start identity no longer matches is never signalled; the original
    subject is gone only if nothing matching it is alive.
    """
    if pid_file is None or not pid_file.exists():
        return True
    try:
        record = json.loads(pid_file.read_text())
    except (OSError, ValueError):
        return False
    if record.get('state') != 'running' or type(record.get('pid')) is not int or record['pid'] <= 0:
        return False
    if quit_grace > 0:  # the subject's own normal quit first; no signal while it still has time
        end = clock() + quit_grace
        while clock() < end and cleanup.matches(lookup(record['pid']), record) and not urgent():
            sleep(0.1)  # revocation, a signal or the cleanup deadline ends the grace at once (macrev-332-7)
        exited = not cleanup.matches(lookup(record['pid']), record)
        if report is not None:
            report.update(quitGraceUsed=quit_grace, exitedDuringGrace=exited)
        if exited:
            return True
    for sig, wait in ((signal.SIGTERM, grace), (signal.SIGKILL, 5.0)):
        if not cleanup.matches(lookup(record['pid']), record):
            return True  # the owned subject no longer exists (a reused PID is not ours)
        with contextlib.suppress(ProcessLookupError):
            send(record['pid'], sig)
        end = clock() + wait
        while clock() < end and cleanup.matches(lookup(record['pid']), record):
            sleep(0.1)
    return not cleanup.matches(lookup(record['pid']), record)


def run(lease_path, stop_path, interval=1.0, reserve=30.0, pid_file=None,
        clock=time.time, sleep=time.sleep, running=lambda: True, kill=terminate, quit_grace=0.0, report=None):
    outcome = 'error'
    try:
        lease = json.loads(lease_path.read_text())
        identity = {k: lease.get(k) for k in IDENTITY}
        if any(v in (None, '') for v in identity.values()):
            raise ValueError('lease is missing identity fields')
        if not 0 < interval <= 1:
            raise ValueError('interval must keep the heartbeat within admission tolerance')
        if not (isinstance(reserve, (int, float)) and MIN_RESERVE <= reserve < lease['expiresAt'] - lease['notBefore']):
            raise ValueError('cleanup reserve must cover TERM grace, KILL wait and closure checks')
        while True:
            now = clock()
            if not running():
                outcome = 'signalled'; break
            if now >= lease['expiresAt'] - reserve:
                outcome = 'deadline'; break
            if pid_file is not None and launcher_lost(pid_file):
                outcome = 'launcher-lost'; break  # its supervisor died: stop the subject now
            beat(lease_path, identity, now)  # raises Revoked first: revocation outranks the stop file
            if stop_path.exists():
                outcome = 'stopped'; break
            sleep(interval)
    except Revoked:
        outcome = 'revoked'
    finally:
        try:
            stop(stop_path, 'guardian-' + outcome, clock())
        except OSError:
            pass  # still stop the subject; launch.py also stops on a stale heartbeat
        if outcome == 'stopped' and quit_grace > 0:  # only a stop-file ending gives the subject its own quit first
            def urgent():
                if not running() or clock() >= lease['expiresAt'] - (reserve - quit_grace):
                    return True  # keep the TERM/KILL budget inside the reserve
                try:
                    cur = json.loads(lease_path.read_text())
                except (OSError, ValueError):
                    return True
                return cur.get('ownerPreempted') is not False or cur.get('exclusive') is not True
            closed = kill(pid_file, quit_grace=quit_grace, report=report, urgent=urgent)
        else:
            closed = kill(pid_file)
    return outcome, closed


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--lease', type=Path, required=True)
    parser.add_argument('--stop', type=Path, required=True)
    parser.add_argument('--subject-pid-file', type=Path, required=True, help='written by launch.py; the subject is stopped on exit')
    parser.add_argument('--interval', type=float, default=1.0)
    parser.add_argument('--reserve', type=float, default=30.0, help='seconds kept for cleanup before expiresAt (at least 25)')
    parser.add_argument('--quit-grace', type=float, default=QUIT_GRACE_DEFAULT,
                        help='seconds the subject may take to quit by itself after the stop file (run config quitGraceSeconds; capped at 10)')
    args = parser.parse_args(argv)
    flag = {'run': True}
    for sig in (signal.SIGTERM, signal.SIGINT):
        signal.signal(sig, lambda *_: flag.update(run=False))
    report = dict(quitGraceUsed=None, exitedDuringGrace=False)
    try:
        outcome, closed = run(args.lease, args.stop, args.interval, args.reserve, args.subject_pid_file,
                              running=lambda: flag['run'], quit_grace=quit_grace(args.quit_grace), report=report)
    except (OSError, ValueError, KeyError, TypeError) as error:
        print(json.dumps(dict(error=type(error).__name__ if isinstance(error, OSError) else str(error))), file=sys.stderr)
        return 2
    print(json.dumps(dict(guardian=outcome, subjectClosed=closed, **report)))
    return 0 if closed and outcome in ('stopped', 'signalled', 'deadline') else 3


if __name__ == '__main__':
    sys.exit(main())

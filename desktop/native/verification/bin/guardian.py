# SPDX-License-Identifier: MIT
"""Lease guardian for one started booking: heartbeat, stop/deadline, and supervision of the subject.

Run it in the background right after `book.py start`, before `release.py` and `launch.py`.
- Every interval it updates `guardianHeartbeatAt` (and marks `guardian: true`) under an exclusive
  lock on `<lease>.lock`, re-reading the lease inside the lock. It never changes identity fields and
  stops if anything revoked the lease (identity changed, `ownerPreempted` true, `exclusive` false).
  Any other lease writer must take the same lock (use `update_lease`).
- It stops on the stop file, the deadline minus the cleanup reserve, SIGTERM/SIGINT, or any error.
  On every exit path it writes the stop file and, if `--subject-pid-file` names a live subject,
  terminates it (TERM, then KILL) and waits for it to be gone. Exit status 0 means the subject is
  confirmed gone (or never started); anything else means closure is NOT verified.
- `launch.py --execute` independently stops its child when the heartbeat goes stale, so a killed
  guardian still fails closed; admission refuses a launch until the guardian has taken over.
"""
import argparse
import contextlib
import fcntl
import importlib.util
import json
import os
from pathlib import Path
import signal
import sys
import time

_spec = importlib.util.spec_from_file_location('cleanup', Path(__file__).with_name('cleanup-run.py'))
cleanup = importlib.util.module_from_spec(_spec); _spec.loader.exec_module(cleanup)

IDENTITY = ('runID', 'epoch', 'notBefore', 'expiresAt')


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


def register(pid_file, pid):
    """launch.py: record the owned subject. Raises if the identity cannot be established."""
    ident = identity(pid)
    if ident is None:
        raise ValueError('subject identity unavailable')
    write_atomic(pid_file, dict(state='running', **ident))
    return ident


def terminate(pid_file, grace=10.0, lookup=identity, send=os.kill, clock=time.monotonic, sleep=time.sleep):
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
    for sig, wait in ((signal.SIGTERM, grace), (signal.SIGKILL, 5.0)):
        if not cleanup.matches(lookup(record['pid']), record):
            return True  # the owned subject no longer exists (a reused PID is not ours)
        with contextlib.suppress(ProcessLookupError):
            send(record['pid'], sig)
        end = clock() + wait
        while clock() < end and cleanup.matches(lookup(record['pid']), record):
            sleep(0.1)
    return not cleanup.matches(lookup(record['pid']), record)


def run(lease_path, stop_path, interval=1.0, reserve=15.0, pid_file=None,
        clock=time.time, sleep=time.sleep, running=lambda: True, kill=terminate):
    outcome = 'error'
    try:
        lease = json.loads(lease_path.read_text())
        identity = {k: lease.get(k) for k in IDENTITY}
        if any(v in (None, '') for v in identity.values()):
            raise ValueError('lease is missing identity fields')
        if not 0 < interval <= 1:
            raise ValueError('interval must keep the heartbeat within admission tolerance')
        while True:
            now = clock()
            if not running():
                outcome = 'signalled'; break
            if stop_path.exists():
                outcome = 'stopped'; break
            if now >= lease['expiresAt'] - reserve:
                outcome = 'deadline'; break
            beat(lease_path, identity, now)
            sleep(interval)
    except Revoked:
        outcome = 'revoked'
    finally:
        try:
            stop(stop_path, 'guardian-' + outcome, clock())
        except OSError:
            pass  # still stop the subject; launch.py also stops on a stale heartbeat
        closed = kill(pid_file)
    return outcome, closed


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--lease', type=Path, required=True)
    parser.add_argument('--stop', type=Path, required=True)
    parser.add_argument('--subject-pid-file', type=Path, required=True, help='written by launch.py; the subject is stopped on exit')
    parser.add_argument('--interval', type=float, default=1.0)
    parser.add_argument('--reserve', type=float, default=15.0, help='seconds kept for cleanup before expiresAt')
    args = parser.parse_args(argv)
    flag = {'run': True}
    for sig in (signal.SIGTERM, signal.SIGINT):
        signal.signal(sig, lambda *_: flag.update(run=False))
    try:
        outcome, closed = run(args.lease, args.stop, args.interval, args.reserve, args.subject_pid_file,
                              running=lambda: flag['run'])
    except (OSError, ValueError, KeyError, TypeError) as error:
        print(json.dumps(dict(error=type(error).__name__ if isinstance(error, OSError) else str(error))), file=sys.stderr)
        return 2
    print(json.dumps(dict(guardian=outcome, subjectClosed=closed)))
    return 0 if closed and outcome in ('stopped', 'signalled', 'deadline') else 3


if __name__ == '__main__':
    sys.exit(main())

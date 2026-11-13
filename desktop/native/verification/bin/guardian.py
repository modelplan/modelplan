# SPDX-License-Identifier: MIT
"""Lease guardian for one started booking: heartbeat, stop/deadline, and supervision of the subject.

Run it in the background right after `book.py start`, before `release.py` and `launch.py`.
- Every interval it updates `guardianHeartbeatAt` (and marks `guardian: true`) under an exclusive
  lock on `<lease>.lock`, re-reading the lease inside the lock. It never changes identity fields and
  stops if anything revoked the lease (identity changed, `ownerPreempted` true, `exclusive` false).
  Any other lease writer must take the same lock (use `update_lease`).
- It stops on the stop file, the deadline minus the cleanup reserve, SIGTERM/SIGINT, or any error.
  On every exit path it writes the stop file and, if `--subject-pid-file` names a live subject,
  terminates it (TERM, then KILL) and waits for it to be gone.
- A subject that never registered (the reservation is still `launching`) is closed by a
  project-scoped scan instead: the launcher records the run's exact executable path, its scratch
  prefix and the PID plus start time of each helper it spawns in the reservation, and the guardian
  (once that launcher is gone) stops any owned process inside that scope and rescans. An empty scan
  reports `subject: never-started`. A reservation without a scope stays unconfirmed. A launcher that
  exited non-zero before reserving anything (for example an admission refusal) leaves a run-bound
  `<subject-pid-file>.no-subject.json`; once that launcher is gone and no reservation exists, it is
  also closed as `never-started`. Without that proof a missing reservation is `none`. Process names
  and other processes' environments are never read.
- Exit status 0 means closure is verified and the booking may be finished as cleaned: either the
  run ended normally with the subject confirmed gone, or the scan proved the subject never started.
  Anything else means closure is NOT verified.
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

import process_scan

_spec = importlib.util.spec_from_file_location('cleanup', Path(__file__).with_name('cleanup-run.py'))
cleanup = importlib.util.module_from_spec(_spec); _spec.loader.exec_module(cleanup)

IDENTITY = ('runID', 'epoch', 'notBefore', 'expiresAt')
MIN_RESERVE = 25.0  # TERM grace 10 s + KILL wait 5 s + closure checks and a late wakeup


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


def mark_launching(pid_file, lookup=None, scope=None, mode=None):
    """A controller (launch.py or Drive), before spawning: reserve the registration (exec gate).

    One controller per booking: under the registration lock, refuse while a registered subject is
    still alive or another live controller holds the reservation. `scope` (process_scan.scope_for)
    lets the guardian prove closure if the subject never registers; `mode` is the launch mode.
    """
    lookup = lookup or identity
    if scope is not None and not process_scan.valid_scope(scope):
        raise ValueError('invalid scan scope')
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
        record = dict(state='launching', launcher=me)
        if scope is not None:
            record['scan'] = scope
        if mode is not None:
            record['launchMode'] = mode
        write_atomic(pid_file, record)
        return me


def add_helper(pid_file, launcher, helper):
    """The reserving controller records a helper it just spawned (PID plus start time) in the scope."""
    with registration(pid_file):
        try:
            current = json.loads(pid_file.read_text())
        except (OSError, ValueError):
            raise ValueError('reservation missing')
        if (current.get('state') != 'launching' or not cleanup.matches(launcher, current.get('launcher') or {})
                or not process_scan.valid_scope(current.get('scan'))):
            raise ValueError('scoped reservation not held by this controller')
        current['scan'] = process_scan.with_helper(current['scan'], helper)
        write_atomic(pid_file, current)
        return current['scan']


def register(pid_file, pid, launcher=None, lookup=None):
    """The reserving controller records its subject before releasing the exec gate."""
    lookup = lookup or identity
    with registration(pid_file):
        try:
            current = json.loads(pid_file.read_text())
        except (OSError, ValueError):
            raise ValueError('reservation missing')
        if current.get('state') != 'launching' or not cleanup.matches(launcher, current.get('launcher') or {}):
            raise ValueError('reservation not held by this controller')
        ident = lookup(pid)
        if ident is None:
            raise ValueError('subject identity unavailable')
        kept = {k: current[k] for k in ('scan', 'launchMode') if k in current}
        write_atomic(pid_file, dict(state='running', launcher=launcher, **kept, **ident))
        return ident


def launcher_lost(pid_file, lookup=identity):
    """True when a registered subject's launcher (its supervisor) has disappeared, or when the
    launcher of a scoped reservation died before registering (a LaunchServices subject may already
    be running unsupervised)."""
    try:
        record = json.loads(pid_file.read_text())
    except (OSError, ValueError, AttributeError, TypeError):
        return False
    launcher = record.get('launcher')
    pending = record.get('state') == 'launching' and process_scan.valid_scope(record.get('scan'))
    return ((record.get('state') == 'running' or pending) and isinstance(launcher, dict)
            and not cleanup.matches(lookup(launcher.get('pid')), launcher))


def stop_identities(records, grace, lookup, send, clock, sleep):
    """TERM, then KILL, owned identities together; True when nothing matching any of them is alive."""
    alive = lambda: [r for r in records if cleanup.matches(lookup(r['pid']), r)]
    for sig, wait in ((signal.SIGTERM, grace), (signal.SIGKILL, 5.0)):
        targets = alive()  # a reused PID no longer matches its start identity and is never signalled
        if not targets:
            return True
        for record in targets:
            with contextlib.suppress(ProcessLookupError):
                send(record['pid'], sig)
        end = clock() + wait
        while clock() < end and alive():
            sleep(0.1)
    return not alive()


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
    return stop_identities([record], grace, lookup, send, clock, sleep)


def no_subject_proof(pid_file, lease, lookup=identity, clock=time.monotonic, sleep=time.sleep, launcher_wait=5.0):
    """True when launch.py proved it exited before reserving: its run-bound proof matches this lease,
    records a non-zero exit, its launcher identity is gone, and still no reservation exists."""
    proof_path = pid_file.with_name(pid_file.name + '.no-subject.json')
    if lease is None or proof_path.is_symlink() or not proof_path.is_file():
        return False
    try:
        proof = json.loads(proof_path.read_text())
    except (OSError, ValueError):
        return False
    launcher = proof.get('launcher')
    if (proof.get('runID') != lease.get('runID') or proof.get('epoch') != lease.get('epoch')
            or proof.get('subjectPidPath') != str(pid_file) or type(proof.get('launcherExit')) is not int
            or proof['launcherExit'] == 0 or not isinstance(launcher, dict)):
        return False
    end = clock() + launcher_wait
    while cleanup.matches(lookup(launcher.get('pid')), launcher):
        if clock() >= end:
            return False
        sleep(0.1)
    with registration(pid_file):
        return not pid_file.exists()


def close(pid_file, lookup=identity, send=os.kill, scan=None, clock=time.monotonic, sleep=time.sleep,
          launcher_wait=5.0, grace=5.0, settle=1.0, lease=None):
    """Closure of this booking's subject: returns (closed, subject).

    subject: `none` (no reservation), `never-started` (no reservation, plus the launcher's run-bound
    pre-reservation exit proof for `lease`), `registered` (the owned PID was stopped/confirmed), or, for a
    subject that never registered, `never-started` / `unregistered-stopped` when the scope scan is
    empty, otherwise an unconfirmed `unregistered-*` / `unreadable` state.
    Only after the reserving launcher is gone (it alone can still register or spawn) does the scan
    count. Owned processes inside the scope are stopped by identity; after a settle delay (a
    LaunchServices request may still be in flight) the scope must scan empty.
    """
    def read():
        try:
            return json.loads(pid_file.read_text())
        except (OSError, ValueError):
            return None
    if pid_file is None:
        return True, 'none'
    if not pid_file.exists():
        if no_subject_proof(pid_file, lease, lookup, clock, sleep, launcher_wait):
            return True, 'never-started'
        if not pid_file.exists():
            return True, 'none'
    record = read()
    if record is None:
        return False, 'unreadable'
    if record.get('state') == 'launching':
        if not process_scan.valid_scope(record.get('scan')):
            return False, 'unregistered-unscoped'
        launcher = record.get('launcher') if isinstance(record.get('launcher'), dict) else {}
        end = clock() + launcher_wait
        while cleanup.matches(lookup(launcher.get('pid')), launcher):
            if clock() >= end:
                return False, 'unregistered-launcher-alive'
            sleep(0.1)
        record = read()  # the launcher may have registered before it went away
        if record is None:
            return False, 'unreadable'
    if record.get('state') == 'running':
        return terminate(pid_file, lookup=lookup, send=send, clock=clock, sleep=sleep), 'registered'
    if record.get('state') != 'launching':
        return False, 'unconfirmed'
    scope = record.get('scan')
    if not process_scan.valid_scope(scope):
        return False, 'unregistered-unscoped'
    scan = scan or (lambda s: process_scan.scan(s, lookup))
    try:
        found = scan(scope)
        stopped = stop_identities(found, grace, lookup, send, clock, sleep)
        sleep(settle)
        left = scan(scope)
    except (OSError, ValueError):
        return False, 'unregistered-scan-failed'
    if not stopped or left:
        return False, 'unregistered-still-running'
    return True, 'unregistered-stopped' if found else 'never-started'


def run(lease_path, stop_path, interval=1.0, reserve=30.0, pid_file=None,
        clock=time.time, sleep=time.sleep, running=lambda: True, kill=close):
    """Returns (outcome, closed, subject); `kill(pid_file)` returns (closed, subject)."""
    outcome = 'error'; bound = None
    try:
        lease = json.loads(lease_path.read_text())
        identity = bound = {k: lease.get(k) for k in IDENTITY}
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
            if stop_path.exists():
                outcome = 'stopped'; break
            if now >= lease['expiresAt'] - reserve:
                outcome = 'deadline'; break
            if pid_file is not None and launcher_lost(pid_file):
                outcome = 'launcher-lost'; break  # its supervisor died: stop the subject now
            beat(lease_path, identity, now)
            sleep(interval)
    except Revoked:
        outcome = 'revoked'
    finally:
        try:
            stop(stop_path, 'guardian-' + outcome, clock())
        except OSError:
            pass  # still stop the subject; launch.py also stops on a stale heartbeat
        if kill is close:
            closed, subject = close(pid_file, lease=bound)  # bound: None when the lease never parsed
        else:
            closed, subject = kill(pid_file)
    return outcome, closed, subject


def finishable(outcome, closed, subject):
    """Booking may be finished as cleaned: a normal end with verified closure, or a scan-proven
    subject that never started (whatever ended the run)."""
    return closed is True and (outcome in ('stopped', 'signalled', 'deadline') or subject == 'never-started')


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--lease', type=Path, required=True)
    parser.add_argument('--stop', type=Path, required=True)
    parser.add_argument('--subject-pid-file', type=Path, required=True, help='written by launch.py; the subject is stopped on exit')
    parser.add_argument('--interval', type=float, default=1.0)
    parser.add_argument('--reserve', type=float, default=30.0, help='seconds kept for cleanup before expiresAt (at least 25)')
    parser.add_argument('--candidate-registry', type=Path, help='optional run-bound direct-mode scratch registry')
    parser.add_argument('--candidate-parent', type=Path, help='approved parent for candidate scratch')
    parser.add_argument('--candidate-cleanup-receipt', type=Path, help='new local cleanup receipt path')
    args = parser.parse_args(argv)
    candidate_args = (args.candidate_registry, args.candidate_parent, args.candidate_cleanup_receipt)
    if any(candidate_args) and not all(candidate_args):
        parser.error('candidate registry, parent and cleanup receipt must be supplied together')
    flag = {'run': True}
    for sig in (signal.SIGTERM, signal.SIGINT):
        signal.signal(sig, lambda *_: flag.update(run=False))
    try:
        outcome, closed, subject = run(args.lease, args.stop, args.interval, args.reserve, args.subject_pid_file,
                              running=lambda: flag['run'])
    except (OSError, ValueError, KeyError, TypeError) as error:
        print(json.dumps(dict(error=type(error).__name__ if isinstance(error, OSError) else str(error))), file=sys.stderr)
        return 2
    result = dict(guardian=outcome, subjectClosed=closed, subject=subject)
    if all(candidate_args) and finishable(outcome, closed, subject):
        try:
            import candidate_scratch
            lease = json.loads(args.lease.read_text())
            candidate = json.loads(args.candidate_registry.read_text())
            registry = candidate.get('registry', candidate)
            if not args.subject_pid_file.exists():  # 'none' or a launcher-proven 'never-started'
                # A missing PID file alone is not proof: the launcher could
                # still be preparing. Require the run-bound receipt it writes
                # only after launch.py exited before registering a subject.
                proof_path = Path(candidate.get('noSubjectReceipt', ''))
                if (not proof_path.is_absolute() or proof_path.is_symlink() or not proof_path.is_file()
                        or candidate.get('subjectPidPath') != str(args.subject_pid_file)):
                    raise ValueError('pre-registration exit unconfirmed')
                with registration(args.subject_pid_file):
                    proof = json.loads(proof_path.read_text())
                    if (args.subject_pid_file.exists() or proof.get('runID') != lease['runID']
                            or proof.get('epoch') != lease['epoch'] or proof.get('subjectPidPath') != str(args.subject_pid_file)
                            or type(proof.get('launcherExit')) is not int or proof['launcherExit'] == 0):
                        raise ValueError('pre-registration exit unconfirmed')
                    root = candidate_scratch.validate_registry(registry, parent=args.candidate_parent,
                                                               run_id=lease['runID'], epoch=lease['epoch'])
                    if process_scan.scan(process_scan.scope_for(prefix=root), identity):
                        raise ValueError('candidate process scope not empty')
                    receipt = candidate_scratch.cleanup(registry, parent=args.candidate_parent,
                                                        run_id=lease['runID'], epoch=lease['epoch'], subject_closed=True)
            else:
                reservation = json.loads(args.subject_pid_file.read_text())
                receipt = candidate_scratch.cleanup_registered(
                    registry, reservation, parent=args.candidate_parent,
                    run_id=lease['runID'], epoch=lease['epoch'], subject_closed=closed,
                    lookup=identity, scan=lambda scope: process_scan.scan(scope, identity))
            with args.candidate_cleanup_receipt.open('x', encoding='utf-8') as stream:
                json.dump(receipt, stream, sort_keys=True)
                stream.flush(); os.fsync(stream.fileno())
            result['candidateCleaned'] = True
        except (OSError, ValueError, KeyError, TypeError, RuntimeError):
            result['candidateCleaned'] = False
            print(json.dumps(result), flush=True)
            return 3
    print(json.dumps(result))
    return 0 if finishable(outcome, closed, subject) else 3


if __name__ == '__main__':
    sys.exit(main())

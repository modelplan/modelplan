# SPDX-License-Identifier: MIT
"""Independent launch-mode closure check (CONTROLLER_MODE=launch), run after the sequence has waited for the
controller (launch.py), the guardian and the scenario. It signals and removes nothing; its only write is its
own receipt.

Usage: check_launch_cleanup.py --config <run.json> --controller-status N --guardian-status N --scenario-status N

Prints one JSON receipt (schema launch-cleanup/1) and writes the same receipt atomically to
`<directory of stopPath>/launch-cleanup.json` (the batch). Exit 0 only when every check holds:
- subjectGone:          the registration in subjectPidPath belongs to this run/epoch and its identity is gone
- helpersGone:          the registered launcher identity (launch.py) is gone
- controllerStatus:     launch.py exited 0, or 3 with a stop reason recorded in the stop file
- guardianStatus:       bin/guardian.py exited 0 (it confirmed the subject closed)
- scenarioStatus:       the scenario's drive step exited 0
- leaseClosable:        the lease matches the run config and the ledger's head booking is still started for
                        this run/epoch, so `book.py finish` can close it (replayed read-only, never locked)
- locksReleased:        no lock listed in the prepared receipt, and no lock under `locks`, carries this
                        attempt's token
- syntheticHomeRemoved: syntheticHome and any configured syntheticHomeSeed are gone
- syntheticTmpRemoved:  syntheticTmp is gone
- stopPathPresent:      the stop file exists at the run config's stopPath
The three status checks carry the exit status (null when not supplied, which fails); the others are booleans.
`stopReasonRecorded` says whether the stop file names a reason, so a controller status of 3 can be judged from the
receipt alone. `ok` is true iff every check passes and `failures` names exactly the failing checks; `ok` is resource
closure only.

Lease-window qualification inputs (C2.2 section 4), separate from `ok`: `leaseNotBefore`/`leaseExpiresAt` (from the
lease, when it matches the run), `subjectStartedAt` (the run-bound registration's `startedAt`, taken by launch.py
before the spawn), `closedAt` (UNIX seconds when this check observed the subject gone; null otherwise) and
`closedWithinLease` (closure observed inside [leaseNotBefore, leaseExpiresAt)). A late closure is a timing FAIL for
the evidence layer; it never changes `ok` or suppresses cleanup. `validate_receipt` rejects a malformed or
self-contradictory receipt; evidence code imports it. A missing or unreadable input fails its check. stderr carries one line of
fixed reason codes per failing check; no path, PID or file content is printed. Exit 1: not closed or the
receipt could not be written; 2: usage error."""
import argparse
import datetime
import json
import math
import os
from pathlib import Path
import re
import sys
import time

import book
import guardian
import scenario

IDENTITY = ('runID', 'epoch', 'notBefore', 'expiresAt')


def read_json(path):
    return json.loads(Path(path).read_text())


def gone(record, lookup):
    """True when no live process carries this exact start identity (a reused PID is not ours)."""
    return not guardian.cleanup.matches(lookup(record.get('pid')), record)


def well_formed(record):
    return (isinstance(record, dict) and type(record.get('pid')) is int and record['pid'] > 0
            and type(record.get('startSeconds')) is int and type(record.get('startMicroseconds')) is int)


def run_identity(c):
    """(runID, epoch) from the lease the attempt started, which must match the config's expected lease."""
    lease = read_json(c['leasePath'])
    expected = c.get('expectedLease')
    if expected is not None and any(lease.get(k) != expected.get(k) for k in IDENTITY):
        raise ValueError('lease-identity-mismatch')
    if not all(isinstance(lease.get(k), str) and lease[k] for k in ('runID', 'epoch')):
        raise ValueError('lease-identity-missing')
    return lease['runID'], lease['epoch']


def check_lease(c, run):
    try:
        booking = c['booking']
        ledger = book.Ledger(booking.get('ledger'))  # same path resolution as admission; opens nothing
        raw = ledger.path.read_bytes()
        if not raw or not raw.endswith(b'\n'):
            return 'ledger-incomplete'
        bookings = book.Ledger.replay([json.loads(line) for line in raw.splitlines()])
    except (OSError, ValueError, KeyError, TypeError, AttributeError):
        return 'ledger-unreadable'
    try:
        book.Ledger.owner(book.Ledger.head(bookings), booking.get('id'), booking.get('lane'), *run)
    except (ValueError, KeyError, TypeError):
        return 'not-closable'  # finished, expired, another head, or another run/epoch: finish would refuse
    return None


def check_registration(c, run, lookup):
    """(subject failure, helpers failure) for the registration launch.py wrote."""
    try:
        record = read_json(c['subjectPidPath'])
    except FileNotFoundError:
        return 'registration-missing', 'registration-missing'
    except (OSError, ValueError, KeyError, TypeError):
        return 'registration-unreadable', 'registration-unreadable'
    if not isinstance(record, dict) or record.get('state') != 'running':
        return 'registration-unconfirmed', 'registration-unconfirmed'  # 'launching': nothing proves what ran
    if run is None or (record.get('runID'), record.get('epoch')) != run:
        return 'registration-other-run', 'registration-other-run'
    subject = 'identity-malformed' if not well_formed(record) else (None if gone(record, lookup) else 'alive')
    launcher = record.get('launcher')
    helper = 'identity-malformed' if not well_formed(launcher) else (None if gone(launcher, lookup) else 'launcher-alive')
    return subject, helper


def stop_reason(path):
    try:
        record = read_json(path)
    except (OSError, ValueError):
        return None
    reason = record.get('reason') if isinstance(record, dict) else None
    return reason if isinstance(reason, str) and reason else None


def check_statuses(c, controller, guardian_status, scenario_status):
    out = {}
    if controller is None:
        out['controller'] = 'status-missing'
    elif controller == 3:
        try:
            out['controller'] = None if stop_reason(c['stopPath']) else 'stopped-without-reason'
        except (KeyError, TypeError):
            out['controller'] = 'stop-path-missing'
    else:
        out['controller'] = None if controller == 0 else 'exit-%d' % controller
    for name, status in (('guardian', guardian_status), ('scenario', scenario_status)):
        out[name] = 'status-missing' if status is None else (None if status == 0 else 'exit-%d' % status)
    return out


def check_locks(c, run):
    try:
        found = scenario.resolve(c)
    except ValueError:
        return 'scenario-registry-unreadable'
    path = c.get('preparedReceiptPath')
    required = bool(found and found[1]['receipt'])
    if not path:
        return 'prepared-receipt-required' if required else None
    try:
        receipt = read_json(path)
    except FileNotFoundError:
        return 'prepared-receipt-missing' if required else None  # an optional receipt that was never written
    except (OSError, ValueError):
        return 'prepared-receipt-unreadable'
    if (not isinstance(receipt, dict) or (receipt.get('runID'), receipt.get('epoch')) != run
            or not isinstance(receipt.get('attempt'), str) or not receipt['attempt']
            or not isinstance(receipt.get('locks'), list)):
        return 'prepared-receipt-mismatch'
    candidates = [Path(x) for x in receipt['locks'] if isinstance(x, str)]
    if len(candidates) != len(receipt['locks']):
        return 'prepared-receipt-mismatch'
    if c.get('locks'):
        try:
            candidates += [p for p in Path(c['locks']).iterdir()]
        except FileNotFoundError:
            pass
        except OSError:
            return 'locks-unreadable'
    for lock in candidates:
        try:
            owner = read_json(lock / 'owner.json')
        except FileNotFoundError:
            continue
        except (OSError, ValueError):
            return 'lock-owner-unreadable'
        if isinstance(owner, dict) and owner.get('attempt') == receipt['attempt']:
            return 'held'
    return None


SCHEMA = 'launch-cleanup/1'
CHECKS = ('subjectGone', 'helpersGone', 'controllerStatus', 'guardianStatus', 'scenarioStatus', 'leaseClosable',
          'locksReleased', 'syntheticHomeRemoved', 'syntheticTmpRemoved', 'stopPathPresent')


def check_scratch(c):
    """(home failure, tmp failure); the configured HOME seed counts with the synthetic HOME."""
    def left(*names):
        return [n for n in names if isinstance(c.get(n), str) and c[n] and os.path.lexists(c[n])]
    if not all(isinstance(c.get(k), str) and c[k] for k in ('syntheticHome', 'syntheticTmp')):
        return 'synthetic-roots-missing', 'synthetic-roots-missing'
    home, tmp = left('syntheticHome', 'syntheticHomeSeed'), left('syntheticTmp')
    return ('remains:' + ','.join(home) if home else None), ('remains:' + ','.join(tmp) if tmp else None)


def evaluate(c, controller=None, guardian_status=None, scenario_status=None, lookup=None):
    """Pure: ((runID, epoch) or None, {check: failure reason or None})."""
    lookup = lookup or guardian.identity
    failures = dict.fromkeys(CHECKS)
    try:
        run = run_identity(c)
    except (OSError, ValueError, KeyError, TypeError) as error:
        run = None
        failures['leaseClosable'] = str(error) if str(error).startswith('lease-') else 'lease-unreadable'
    if run is not None:
        failures['leaseClosable'] = check_lease(c, run)
    try:
        failures['subjectGone'], failures['helpersGone'] = check_registration(c, run, lookup)
    except KeyError:
        failures['subjectGone'] = failures['helpersGone'] = 'registration-path-missing'
    statuses = check_statuses(c, controller, guardian_status, scenario_status)
    try:
        failures['stopPathPresent'] = None if Path(c['stopPath']).is_file() else 'missing'
    except (KeyError, TypeError):
        failures['stopPathPresent'] = 'stop-path-missing'
    failures.update(controllerStatus=statuses['controller'], guardianStatus=statuses['guardian'],
                    scenarioStatus=statuses['scenario'])
    failures['locksReleased'] = 'run-unknown' if run is None else check_locks(c, run)
    failures['syntheticHomeRemoved'], failures['syntheticTmpRemoved'] = check_scratch(c)
    return run, failures


STATUSES = ('controllerStatus', 'guardianStatus', 'scenarioStatus')
TIMING = ('leaseNotBefore', 'leaseExpiresAt', 'subjectStartedAt', 'closedAt')
KEYS = frozenset(('schema', 'runID', 'epoch', 'ok', 'checks', 'failures', 'at', 'stopReasonRecorded',
                  'closedWithinLease') + TIMING)
# Every reason this check reports (C2.2 section 5: fixed structured codes; anything else becomes 'unknown').
REASONS = frozenset((
    'lease-identity-mismatch', 'lease-identity-missing', 'lease-unreadable', 'ledger-incomplete', 'ledger-unreadable',
    'not-closable', 'registration-missing', 'registration-unreadable', 'registration-unconfirmed',
    'registration-other-run', 'registration-path-missing', 'identity-malformed', 'alive', 'launcher-alive',
    'status-missing', 'stopped-without-reason', 'stop-path-missing', 'missing', 'scenario-registry-unreadable',
    'prepared-receipt-required', 'prepared-receipt-missing', 'prepared-receipt-unreadable',
    'prepared-receipt-mismatch', 'locks-unreadable', 'lock-owner-unreadable', 'held', 'synthetic-roots-missing',
    'run-unknown'))
STRUCTURED = re.compile(r'exit--?[0-9]{1,6}|remains:(syntheticHome|syntheticHomeSeed|syntheticTmp)'
                        r'(,(syntheticHome|syntheticHomeSeed|syntheticTmp)){0,2}')
AT = re.compile(r'[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z')


def bounded(reason):
    """A reason as reported: one of this check's fixed codes, an `exit-N` / `remains:<root names>` code, or 'unknown'."""
    if isinstance(reason, str) and STRUCTURED.fullmatch(reason):
        return reason
    return guardian.reason_code(reason, REASONS)


def number(value):
    return type(value) in (int, float) and math.isfinite(value)


def lease_window(c):
    """(notBefore, expiresAt) of the lease the run started, or (None, None) when it cannot be attributed."""
    try:
        run_identity(c)
        lease = read_json(c['leasePath'])
    except (OSError, ValueError, KeyError, TypeError):
        return None, None
    window = lease.get('notBefore'), lease.get('expiresAt')
    return window if all(number(x) for x in window) else (None, None)


def subject_started_at(c, run):
    """`startedAt` from this run's registration (written by launch.py), or None."""
    try:
        record = read_json(c['subjectPidPath'])
    except (OSError, ValueError, KeyError, TypeError):
        return None
    if not isinstance(record, dict) or run is None or (record.get('runID'), record.get('epoch')) != run:
        return None
    return record['startedAt'] if number(record.get('startedAt')) else None


def within(value, not_before, expires_at):
    return number(value) and number(not_before) and number(expires_at) and not_before <= value < expires_at


def status_passes(name, value, stop_reason_recorded):
    """The defined pass rule of a status check, from the receipt alone."""
    if type(value) is not int:
        return False
    if name == 'controllerStatus':
        return value == 0 or (value == 3 and stop_reason_recorded)
    return value == 0


def validate_receipt(receipt, run_id=None, epoch=None):
    """Return `receipt` when it is a well-formed, self-consistent launch-cleanup/1 receipt (and names run_id/epoch
    when given); raise ValueError with a fixed code otherwise. Consistency: `ok` iff every check passes, `failures`
    = exactly the failing checks (no duplicates, no unknown names), closedAt only with subjectGone, and
    closedWithinLease equal to closedAt inside [leaseNotBefore, leaseExpiresAt)."""
    if not isinstance(receipt, dict) or receipt.get('schema') != SCHEMA:
        raise ValueError('closure-schema')
    if set(receipt) != KEYS:
        raise ValueError('closure-keys')
    if not all(isinstance(receipt[k], str) for k in ('runID', 'epoch')):
        raise ValueError('closure-run-type')
    if run_id is not None or epoch is not None:
        if not receipt['runID'] or (receipt['runID'], receipt['epoch']) != (run_id, epoch):
            raise ValueError('closure-other-run')
    checks, failures = receipt['checks'], receipt['failures']
    if (type(receipt['ok']) is not bool or type(receipt['stopReasonRecorded']) is not bool
            or type(receipt['closedWithinLease']) is not bool or not isinstance(receipt['at'], str)
            or not AT.fullmatch(receipt['at'])):
        raise ValueError('closure-field-type')
    if not isinstance(checks, dict) or set(checks) != set(CHECKS):
        raise ValueError('closure-checks')
    for name in CHECKS:
        value = checks[name]
        if name in STATUSES:
            if value is not None and type(value) is not int:
                raise ValueError('closure-check-type')
        elif type(value) is not bool:
            raise ValueError('closure-check-type')
    if not isinstance(failures, list) or not all(isinstance(x, str) for x in failures) or len(set(failures)) != len(failures):
        raise ValueError('closure-failures')
    if any(receipt[k] is not None and not number(receipt[k]) for k in TIMING):
        raise ValueError('closure-timing-type')
    failing = {k for k in CHECKS if not (status_passes(k, checks[k], receipt['stopReasonRecorded'])
                                         if k in STATUSES else checks[k])}
    if set(failures) != failing:
        raise ValueError('closure-failures-inconsistent')
    if receipt['ok'] is not (not failing):
        raise ValueError('closure-ok-inconsistent')
    if (receipt['closedAt'] is None) is checks['subjectGone']:
        raise ValueError('closure-time-inconsistent')
    if receipt['closedWithinLease'] is not within(receipt['closedAt'], receipt['leaseNotBefore'], receipt['leaseExpiresAt']):
        raise ValueError('closure-window-inconsistent')
    return receipt


def lease_window_ok(receipt):
    """C2.2 section 4 timing for a validated receipt: the subject started and closure was observed inside the lease."""
    return (receipt['closedWithinLease'] is True
            and within(receipt['subjectStartedAt'], receipt['leaseNotBefore'], receipt['leaseExpiresAt']))


def check(c, controller=None, guardian_status=None, scenario_status=None, lookup=None, now=None):
    """The launch-cleanup/1 receipt (pinned fields plus the timing inputs, consumed by the U6 evidence builder)."""
    now = time.time() if now is None else now
    run, failures = evaluate(c, controller, guardian_status, scenario_status, lookup)
    not_before, expires_at = lease_window(c)
    started_at = subject_started_at(c, run)
    try:
        reason_recorded = stop_reason(c['stopPath']) is not None
    except (KeyError, TypeError):
        reason_recorded = False
    if run is None:  # still name the run the config expected, so the receipt is attributable
        expected = c.get('expectedLease') if isinstance(c.get('expectedLease'), dict) else {}
        run = tuple(expected.get(k) if isinstance(expected.get(k), str) else '' for k in ('runID', 'epoch'))
    statuses = dict(controllerStatus=controller, guardianStatus=guardian_status, scenarioStatus=scenario_status)
    checks = {k: statuses[k] if k in statuses else failures[k] is None for k in CHECKS}
    failing = [k for k in CHECKS if failures[k] is not None]
    at = datetime.datetime.fromtimestamp(now, datetime.timezone.utc)
    closed_at = float(now) if failures['subjectGone'] is None else None
    receipt = dict(schema=SCHEMA, runID=run[0], epoch=run[1], ok=not failing, checks=checks, failures=failing,
                   at=at.strftime('%Y-%m-%dT%H:%M:%SZ'), stopReasonRecorded=reason_recorded,
                   leaseNotBefore=not_before, leaseExpiresAt=expires_at, subjectStartedAt=started_at,
                   closedAt=closed_at, closedWithinLease=within(closed_at, not_before, expires_at))
    return receipt, {k: bounded(failures[k]) for k in failing}


def receipt_path(c):
    return Path(c['stopPath']).parent / 'launch-cleanup.json'


def write_receipt(path, receipt):
    temp = path.with_name(path.name + '.tmp')
    with temp.open('w') as file:
        json.dump(receipt, file, sort_keys=True)
        file.write('\n'); file.flush(); os.fsync(file.fileno())
    os.replace(temp, path)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--config', type=Path, required=True)
    for name in ('controller', 'guardian', 'scenario'):
        parser.add_argument(f'--{name}-status', type=int)
    args = parser.parse_args(argv)
    try:
        c = read_json(args.config)
        if not isinstance(c, dict) or not isinstance(c.get('stopPath'), str) or not c['stopPath']:
            raise ValueError
    except (OSError, ValueError):
        print(json.dumps(dict(error='run config unreadable or without stopPath')), file=sys.stderr)
        return 1
    receipt, reasons = check(c, args.controller_status, args.guardian_status, args.scenario_status)
    try:
        validate_receipt(receipt)  # never write a receipt the evidence layer would reject as contradictory
    except ValueError as error:
        print(json.dumps(dict(error='receipt inconsistent: ' + str(error))), file=sys.stderr)  # a fixed closure-* code
        return 1
    print(json.dumps(receipt, sort_keys=True), flush=True)
    if reasons:
        print(json.dumps(dict(reasons=reasons), sort_keys=True), file=sys.stderr)
    try:
        write_receipt(receipt_path(c), receipt)
    except OSError as error:
        print(json.dumps(dict(error='receipt not written: ' + type(error).__name__)), file=sys.stderr)
        return 1
    return 0 if receipt['ok'] else 1


if __name__ == '__main__':
    sys.exit(main())

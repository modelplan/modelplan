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
`failures` names the failing checks. A missing or unreadable input fails its check. stderr carries one line of
fixed reason codes per failing check; no path, PID or file content is printed. Exit 1: not closed or the
receipt could not be written; 2: usage error."""
import argparse
import datetime
import json
import os
from pathlib import Path
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
        out['controller'] = None if stop_reason(c['stopPath']) else 'stopped-without-reason'
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
    try:
        statuses = check_statuses(c, controller, guardian_status, scenario_status)
        failures['stopPathPresent'] = None if Path(c['stopPath']).is_file() else 'missing'
    except (KeyError, TypeError):
        statuses = dict(controller='stop-path-missing', guardian=None, scenario=None)
        failures['stopPathPresent'] = 'stop-path-missing'
    failures.update(controllerStatus=statuses['controller'], guardianStatus=statuses['guardian'],
                    scenarioStatus=statuses['scenario'])
    failures['locksReleased'] = 'run-unknown' if run is None else check_locks(c, run)
    failures['syntheticHomeRemoved'], failures['syntheticTmpRemoved'] = check_scratch(c)
    return run, failures


def check(c, controller=None, guardian_status=None, scenario_status=None, lookup=None, now=None):
    """The launch-cleanup/1 receipt (pinned shape, consumed by the U6 evidence builder)."""
    run, failures = evaluate(c, controller, guardian_status, scenario_status, lookup)
    if run is None:  # still name the run the config expected, so the receipt is attributable
        expected = c.get('expectedLease') if isinstance(c.get('expectedLease'), dict) else {}
        run = tuple(expected.get(k) if isinstance(expected.get(k), str) else '' for k in ('runID', 'epoch'))
    statuses = dict(controllerStatus=controller, guardianStatus=guardian_status, scenarioStatus=scenario_status)
    checks = {k: statuses[k] if k in statuses else failures[k] is None for k in CHECKS}
    failing = [k for k in CHECKS if failures[k] is not None]
    at = datetime.datetime.fromtimestamp(time.time() if now is None else now, datetime.timezone.utc)
    receipt = dict(schema=SCHEMA, runID=run[0], epoch=run[1], ok=not failing, checks=checks, failures=failing,
                   at=at.strftime('%Y-%m-%dT%H:%M:%SZ'))
    return receipt, {k: failures[k] for k in failing}


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

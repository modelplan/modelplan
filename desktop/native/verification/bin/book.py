# SPDX-License-Identifier: MIT
"""FIFO GUI bookings. This ledger complements, and never grants, a GUI lease."""

import argparse
from contextlib import contextmanager
import errno
import fcntl
import json
import math
import os
from pathlib import Path
import socket
import stat
import sys
import time
import uuid

DEFAULT_LEDGER = Path('/mnt/shared/modelplan/handoffs/gui-bookings/ledger.jsonl')
MAX_SECONDS = 20 * 60
GRACE_SECONDS = 120


def label(value, name):
    if (not isinstance(value, str) or not value.strip() or len(value) > 128
            or not value.isprintable()):
        raise ValueError(f'{name} must be a nonempty printable string (at most 128 characters)')
    return value


def finite(value):
    return type(value) in (int, float) and math.isfinite(value)


class Ledger:
    def __init__(self, path=DEFAULT_LEDGER, *, clock=time.time, lock_timeout=5):
        self.path = Path(path)
        self.clock = clock
        self.lock_timeout = lock_timeout

    @contextmanager
    def locked(self):
        """mkdir is the cross-host lock; flock is additional where supported.

        Never steal a lock based on its age: an SMB-disconnected writer could
        still be alive. A crashed transaction fails closed for manual recovery.
        The bounded wait is for milliseconds-long I/O, never GUI admission.
        """
        self.path.parent.mkdir(parents=True, exist_ok=True)
        lock = self.path.with_name(self.path.name + '.lock')
        deadline = time.monotonic() + self.lock_timeout
        while True:
            try:
                lock.mkdir(mode=0o700)
                break
            except FileExistsError:
                if time.monotonic() >= deadline:
                    raise ValueError(f'ledger transaction locked: {lock}; stop and report, do not busy-retry')
                time.sleep(0.02)
        try:
            (lock / 'owner.json').write_text(json.dumps(dict(host=socket.gethostname(), pid=os.getpid())))
            fd = os.open(self.path, os.O_RDWR | os.O_CREAT | os.O_APPEND | os.O_NOFOLLOW, 0o600)
            with os.fdopen(fd, 'a+b') as file:
                if not stat.S_ISREG(os.fstat(file.fileno()).st_mode):
                    raise ValueError('ledger must be a regular file')
                try:
                    fcntl.flock(file, fcntl.LOCK_EX | fcntl.LOCK_NB)
                except OSError as error:
                    if error.errno not in (errno.ENOSYS, errno.ENOTSUP, errno.EOPNOTSUPP, errno.EINVAL):
                        raise
                    # Some SMB mounts do not implement flock. mkdir above is
                    # mandatory even when flock succeeds on this client.
                file.seek(0)
                raw = file.read()
                if raw and not raw.endswith(b'\n'):
                    raise ValueError('incomplete ledger append; stop for recovery')
                try:
                    events = [json.loads(line) for line in raw.splitlines()]
                    bookings = self.replay(events)
                except (KeyError, TypeError, ValueError) as error:
                    raise ValueError('invalid ledger; stop for recovery') from error
                now = self.clock()
                if not finite(now):
                    raise ValueError('invalid clock')
                yield file, events, bookings, now
        finally:
            (lock / 'owner.json').unlink(missing_ok=True)
            lock.rmdir()

    @staticmethod
    def replay(events):
        bookings = {}
        for seq, event in enumerate(events, 1):
            if event['version'] != 1 or event['seq'] != seq or not finite(event['at']):
                raise ValueError('invalid event header')
            ident = label(event['id'], 'id')
            kind = event['event']
            if kind == 'request':
                if ident in bookings:
                    raise ValueError('duplicate booking')
                label(event['lane'], 'lane'); label(event['unit'], 'unit')
                Ledger.check_request(event['scenarios'], event['maxSeconds'])
                bookings[ident] = dict(event, state='queued')
                continue
            booking = bookings[ident]
            head = next((b for b in bookings.values() if b['state'] in ('queued', 'started')), None)
            if booking is not head:
                raise ValueError('transition outside queue head')
            if kind == 'start' and booking['state'] == 'queued':
                label(event['runID'], 'runID'); label(event['epoch'], 'epoch')
                booking.update(state='started', startedAt=event['at'], runID=event['runID'], epoch=event['epoch'])
                booking['deadline'] = event['at'] + booking['maxSeconds']
            elif kind == 'finish' and booking['state'] == 'started' and event['receipt'] == 'end + cleaned' and event['cleaned'] is True:
                booking.update(state='finished', endedAt=event['at'], cleaned=True)
            elif kind == 'expire' and booking['state'] == 'started' and event['at'] >= booking['deadline'] + GRACE_SECONDS and event['cleaned'] is None:
                booking.update(state='expired', endedAt=event['at'], cleaned=None)
            else:
                raise ValueError('invalid booking transition')
        return bookings

    @staticmethod
    def check_request(scenarios, seconds):
        if type(seconds) is not int or not 1 <= seconds <= MAX_SECONDS:
            raise ValueError('duration must be between 1 and 1200 seconds')
        if (not isinstance(scenarios, list) or not 1 <= len(scenarios) <= 64
                or any(not isinstance(s, str) for s in scenarios)):
            raise ValueError('provide 1 to 64 scenario IDs for one unit')
        for scenario in scenarios:
            label(scenario, 'scenario')
        if len(set(scenarios)) != len(scenarios):
            raise ValueError('duplicate scenario')

    @staticmethod
    def append(file, events, now, kind, ident, **fields):
        event = dict(version=1, seq=len(events) + 1, at=now, event=kind, id=ident, **fields)
        file.write((json.dumps(event, separators=(',', ':'), allow_nan=False) + '\n').encode())
        file.flush()
        os.fsync(file.fileno())
        return event

    @staticmethod
    def head(bookings):
        return next((b for b in bookings.values() if b['state'] in ('queued', 'started')), None)

    @staticmethod
    def owner(booking, ident, lane, run_id, epoch):
        if (booking is None or booking['id'] != ident or booking['lane'] != lane
                or booking['state'] != 'started' or booking['runID'] != run_id or booking['epoch'] != epoch):
            raise ValueError('caller does not hold the started head booking')

    def request(self, lane, unit, scenarios, seconds=MAX_SECONDS):
        label(lane, 'lane'); label(unit, 'unit'); self.check_request(scenarios, seconds)
        with self.locked() as (file, events, bookings, now):
            return self.append(file, events, now, 'request', uuid.uuid4().hex,
                               lane=lane, unit=unit, scenarios=scenarios, maxSeconds=seconds)

    def status(self):
        with self.locked() as (_, events, bookings, now):
            head = self.head(bookings)
            return dict(at=now, events=len(events), head=head,
                        queue=[b for b in bookings.values() if b['state'] in ('queued', 'started')],
                        history=[b for b in bookings.values() if b['state'] in ('finished', 'expired')],
                        expiryEligible=bool(head and head['state'] == 'started' and now >= head['deadline'] + GRACE_SECONDS))

    def start(self, ident, lane, run_id, epoch):
        label(run_id, 'runID'); label(epoch, 'epoch')
        with self.locked() as (file, events, bookings, now):
            head = self.head(bookings)
            if not head or head['id'] != ident or head['lane'] != lane or head['state'] != 'queued':
                raise ValueError('only the queued head may start; stop and wait for handoff, do not busy-retry')
            return self.append(file, events, now, 'start', ident, runID=run_id, epoch=epoch)

    def finish(self, ident, lane, run_id, epoch, *, cleaned=False):
        if cleaned is not True:
            raise ValueError('finish requires an explicit cleanup confirmation')
        with self.locked() as (file, events, bookings, now):
            self.owner(self.head(bookings), ident, lane, run_id, epoch)
            return self.append(file, events, now, 'finish', ident, receipt='end + cleaned', cleaned=True)

    def expire(self):
        with self.locked() as (file, events, bookings, now):
            head = self.head(bookings)
            if not head or head['state'] != 'started' or now < head['deadline'] + GRACE_SECONDS:
                return dict(event='no-expiry', at=now)
            return self.append(file, events, now, 'expire', head['id'], cleaned=None,
                               reason='max duration plus grace elapsed; cleanup unconfirmed')

    def admit(self, booking, lease, required_seconds):
        with self.locked() as (_, events, bookings, now):
            head = self.head(bookings)
            self.owner(head, booking['id'], booking['lane'], lease['runID'], lease['epoch'])
            if booking['unit'] != head['unit'] or booking['scenario'] not in head['scenarios']:
                raise ValueError('unit/scenario is outside the head booking')
            if (not finite(required_seconds) or required_seconds <= 0
                    or not head['startedAt'] <= now < head['deadline']
                    or now + required_seconds > head['deadline']
                    or not finite(lease['expiresAt']) or lease['expiresAt'] > head['deadline']
                    or lease['notBefore'] < head['startedAt']):
                raise ValueError('booking cannot cover the absolute lease and phase/cleanup budget')
            return head


def admit(config):
    """Live booking check for Launch; contract-only validation grants no launch."""
    booking = config.get('booking')
    if not isinstance(booking, dict):
        raise ValueError('GUI execution requires a started head booking')
    try:
        return Ledger(booking.get('ledger', DEFAULT_LEDGER)).admit(booking, config['lease'], config['requiredSeconds'])
    except (KeyError, TypeError) as error:
        raise ValueError('incomplete GUI booking identity') from error


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--ledger', type=Path, default=DEFAULT_LEDGER)
    commands = parser.add_subparsers(dest='command', required=True)
    request = commands.add_parser('request')
    request.add_argument('--lane', required=True); request.add_argument('--unit', required=True)
    request.add_argument('--scenario', action='append', required=True, dest='scenarios')
    request.add_argument('--minutes', type=int, choices=range(1, 21), default=20)
    for command in ('start', 'finish'):
        action = commands.add_parser(command)
        for flag in ('id', 'lane', 'run-id', 'epoch'):
            action.add_argument('--' + flag, required=True)
        if command == 'finish':
            action.add_argument('--cleaned', action='store_true', required=True)
    commands.add_parser('status'); commands.add_parser('expire')
    args = parser.parse_args(argv)
    ledger = Ledger(args.ledger)
    try:
        if args.command == 'request':
            result = ledger.request(args.lane, args.unit, args.scenarios, args.minutes * 60)
        elif args.command in ('start', 'finish'):
            fields = dict(cleaned=args.cleaned) if args.command == 'finish' else {}
            result = getattr(ledger, args.command)(args.id, args.lane, args.run_id, args.epoch, **fields)
        else:
            result = getattr(ledger, args.command)()
        print(json.dumps(result, allow_nan=False))
        return 0
    except (OSError, ValueError) as error:
        print(json.dumps(dict(error=str(error))), file=sys.stderr)
        return 2


if __name__ == '__main__':
    sys.exit(main())

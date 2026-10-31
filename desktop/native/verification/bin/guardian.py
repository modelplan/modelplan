# SPDX-License-Identifier: MIT
"""Lease guardian for one started booking: keeps the heartbeat fresh and enforces stop and deadline.

Run it in the background right after `book.py start`, before `release.py` and `launch.py`.
Every interval it rewrites only `guardianHeartbeatAt` in the lease (atomically; the identity fields
that the release is bound to never change). It stops heartbeating, and writes the stop file, when the
stop file appears, when the lease deadline minus the cleanup reserve is reached, or on SIGTERM/SIGINT.
A stale heartbeat makes admission refuse any further launch, so a dead guardian fails closed.
"""
import argparse
import json
import os
from pathlib import Path
import signal
import sys
import time

IDENTITY = ('runID', 'epoch', 'notBefore', 'expiresAt')


def write_atomic(path, record):
    tmp = path.with_name(path.name + '.tmp')
    with tmp.open('w') as file:
        json.dump(record, file, allow_nan=False)
        file.write('\n'); file.flush(); os.fsync(file.fileno())
    os.replace(tmp, path)


def beat(lease_path, identity, now):
    record = json.loads(lease_path.read_text())
    if {k: record.get(k) for k in IDENTITY} != identity:
        raise ValueError('lease identity changed under the guardian')
    record['guardianHeartbeatAt'] = now
    write_atomic(lease_path, record)


def stop(stop_path, reason, now):
    if not stop_path.exists():
        write_atomic(stop_path, dict(stop=True, reason=reason, at=now))


def run(lease_path, stop_path, interval=1.0, reserve=15.0, clock=time.time, sleep=time.sleep, running=lambda: True):
    lease = json.loads(lease_path.read_text())
    identity = {k: lease.get(k) for k in IDENTITY}
    if any(v in (None, '') for v in identity.values()):
        raise ValueError('lease is missing identity fields')
    if not 0 < interval <= 1:
        raise ValueError('interval must keep the heartbeat within admission tolerance')
    while True:
        now = clock()
        if not running():
            stop(stop_path, 'guardian-signalled', now); return 'signalled'
        if stop_path.exists():
            return 'stopped'
        if now >= lease['expiresAt'] - reserve:
            stop(stop_path, 'deadline', now); return 'deadline'
        beat(lease_path, identity, now)
        sleep(interval)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--lease', type=Path, required=True)
    parser.add_argument('--stop', type=Path, required=True)
    parser.add_argument('--interval', type=float, default=1.0)
    parser.add_argument('--reserve', type=float, default=15.0, help='seconds kept for cleanup before expiresAt')
    args = parser.parse_args(argv)
    flag = {'run': True}
    for sig in (signal.SIGTERM, signal.SIGINT):
        signal.signal(sig, lambda *_: flag.update(run=False))
    try:
        outcome = run(args.lease, args.stop, args.interval, args.reserve, running=lambda: flag['run'])
        print(json.dumps(dict(guardian=outcome)))
        return 0
    except (OSError, ValueError, KeyError, TypeError) as error:
        print(json.dumps(dict(error=type(error).__name__ if isinstance(error, OSError) else str(error))), file=sys.stderr)
        return 2


if __name__ == '__main__':
    sys.exit(main())

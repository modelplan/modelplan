# SPDX-License-Identifier: MIT
"""Run one supervisor outside the calling shell, so it outlives a short-lived tool call.

An agent's tool call can end its whole process group, which takes `guardian.py` and `launch.py`
with it and stops the run with `guardian-heartbeat-stale` or `launcher-lost`. A detached command
runs in its own session under a small runner that records the exit status, because a later tool
call cannot `wait` for it:

  detach.py start --record R.json --stdout OUT --stderr ERR -- python3 .../launch.py ...
  detach.py wait --record R.json --timeout 60

`start` returns once the command is running and prints its PID. `wait` exits 0 when the command
has ended (printing its `exit`), 2 when it is still running, and 3 when its runner disappeared
without recording an exit. The record holds the PID, the start identity and the exit status.
"""
import argparse
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import time

from guardian import cleanup, identity


def write_record(path, record):
    temporary = Path(str(path) + '.tmp')
    temporary.write_text(json.dumps(record, sort_keys=True))
    os.replace(temporary, path)


def serve(record_path, stdout, stderr, argv, report):
    """The detached runner: start the command, report its PID, record its exit."""
    signal.signal(signal.SIGHUP, signal.SIG_IGN)
    os.chdir('/')
    with open(stdout, 'ab') as out, open(stderr, 'ab') as err, open(os.devnull, 'rb') as nothing:
        child = subprocess.Popen(argv, stdin=nothing, stdout=out, stderr=err)
    record = dict(pid=child.pid, runner=identity(os.getpid()), startedAt=time.time(), exit=None)
    write_record(record_path, record)
    os.write(report, str(child.pid).encode())
    os.close(report)
    record.update(exit=child.wait(), endedAt=time.time())
    write_record(record_path, record)


def start(record_path, stdout, stderr, argv):
    if os.path.lexists(record_path):
        raise ValueError(f'record already exists: {record_path}')
    # Absolute paths: the runner leaves the caller's working directory.
    record_path, stdout, stderr = (os.path.abspath(x) for x in (record_path, stdout, stderr))
    readable, writable = os.pipe()
    first = os.fork()
    if first:
        os.close(writable)
        os.waitpid(first, 0)
        with os.fdopen(readable, 'rb') as stream:
            pid = stream.read().decode()
        if not pid:
            raise RuntimeError('detached command did not start')
        return int(pid)
    # New session, then a second fork: no controlling terminal, process group or parent in common
    # with the caller.
    code = 1
    try:
        os.close(readable)
        os.setsid()
        if os.fork():
            os._exit(0)
        for stream in (0, 1, 2):
            os.dup2(os.open(os.devnull, os.O_RDWR), stream)
        serve(record_path, stdout, stderr, argv, writable)
        code = 0
    finally:
        os._exit(code)


def wait(record_path, timeout, clock=time.monotonic, sleep=time.sleep, lookup=identity):
    """(status, record): 0 ended, 2 still running at the timeout, 3 runner gone without an exit."""
    end = clock() + timeout
    while True:
        record = json.loads(Path(record_path).read_text())
        if record.get('exit') is not None:
            return 0, record
        if not cleanup.matches(lookup(record['runner']['pid']), record['runner']):
            record = json.loads(Path(record_path).read_text())  # it may have just finished
            return (0 if record.get('exit') is not None else 3), record
        if clock() >= end:
            return 2, record
        sleep(0.2)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest='action', required=True)
    begin = sub.add_parser('start')
    begin.add_argument('--record', required=True)
    begin.add_argument('--stdout', required=True)
    begin.add_argument('--stderr', required=True)
    begin.add_argument('command', nargs='+', help='after --')
    finish = sub.add_parser('wait')
    finish.add_argument('--record', required=True)
    finish.add_argument('--timeout', type=float, default=0.0)
    args = parser.parse_args(argv)
    if args.action == 'start':
        print(json.dumps(dict(pid=start(args.record, args.stdout, args.stderr, args.command))))
        return 0
    status, record = wait(args.record, args.timeout)
    print(json.dumps(dict(state={0: 'ended', 2: 'running', 3: 'lost'}[status], exit=record.get('exit'))))
    return status


if __name__ == '__main__':
    sys.exit(main())

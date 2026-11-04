#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Exercise the packaged normal engine entry using an isolated synthetic home."""
import argparse
import os
from pathlib import Path
import selectors
import signal
import subprocess
import tempfile
import time


def synthetic_environment(home, scratch):
    return {'HOME': str(home), 'CFFIXED_USER_HOME': str(home), 'TMPDIR': str(scratch) + '/',
            'CODEX_HOME': str(home / 'codex'), 'CLAUDE_CONFIG_DIR': str(home / 'claude'),
            'MODELPLAN_CACHE': str(home / 'cache'), 'XDG_CONFIG_HOME': str(home / 'config'),
            'PATH': '/usr/bin:/bin', 'NO_COLOR': '1', 'MODELPLAN_NORMAL_ENTRY_SMOKE': '1'}


def run_process(command, environment, *, timeout=60):
    process = subprocess.Popen(command, env=environment, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                               stderr=subprocess.DEVNULL, start_new_session=True)
    deadline = time.monotonic() + timeout
    markers = [b'MODELPLAN_SMOKE_READY', b'MODELPLAN_SMOKE_ROWS']
    buffer = b''
    try:
        with selectors.DefaultSelector() as selector:
            selector.register(process.stdout, selectors.EVENT_READ)
            while markers:
                remaining = deadline - time.monotonic()
                if remaining <= 0 or not selector.select(remaining):
                    raise RuntimeError('normal entry timed out waiting for engine observations')
                chunk = os.read(process.stdout.fileno(), 4096)
                if not chunk:
                    raise RuntimeError('normal entry exited before engine observations')
                buffer += chunk
                if len(buffer) > 65536:
                    raise RuntimeError('normal entry produced too much output')
                while b'\n' in buffer:
                    line, buffer = buffer.split(b'\n', 1)
                    if line in (b'MODELPLAN_SMOKE_READY', b'MODELPLAN_SMOKE_ROWS'):
                        if line != markers[0]:
                            raise RuntimeError('normal entry observations out of order')
                        markers.pop(0)
                        if not markers:
                            break
        process.stdin.write(b'q'); process.stdin.flush()
        try:
            result = process.wait(timeout=max(0.01, deadline - time.monotonic()))
        except subprocess.TimeoutExpired:
            raise RuntimeError('normal entry did not terminate cleanly') from None
        if result:
            raise RuntimeError(f'normal entry exited with status {result}')
    except (BrokenPipeError, OSError) as error:
        raise RuntimeError('normal entry could not receive quit request') from error
    finally:
        if process.poll() is None:
            os.killpg(process.pid, signal.SIGKILL)
            process.wait()
        process.stdin.close(); process.stdout.close()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('app', type=Path)
    args = parser.parse_args()
    executable = args.app.resolve() / 'Contents/MacOS/ModelPlanCommunity'
    with tempfile.TemporaryDirectory(prefix='modelplan-normal-smoke-') as directory:
        root = Path(directory); home = root / 'home'; scratch = root / 'tmp'
        home.mkdir(); scratch.mkdir()
        profile = root / 'smoke.sb'
        profile.write_text('(version 1)\n(allow default)\n(deny network*)\n')
        run_process(['/usr/bin/sandbox-exec', '-f', str(profile), str(executable)],
                    synthetic_environment(home, scratch))
    print('packaged normal entry: ready, rows, clean exit')


if __name__ == '__main__':
    main()

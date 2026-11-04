# SPDX-License-Identifier: MIT
"""Usage: check_drive_cleanup.py <run-config.json>. Exit 0 only if the result in that exact config's batch
proves complete cleanup for that config's run and epoch (no separately supplied batch path)."""
import json
from pathlib import Path
import sys

REQUIRED_TRUE = ('ownedExited', 'guardianExited', 'topObserverJoined', 'leaseReleased')


def complete(path, run_id, epoch):
    try:
        result = json.loads(Path(path).read_text())
        cleanup = result['cleanup']
    except (OSError, ValueError, KeyError, TypeError):
        return False
    if not isinstance(result, dict) or result.get('runID') != run_id or result.get('epoch') != epoch:
        return False  # a stale or unrelated batch never certifies this run
    if not isinstance(cleanup, dict):
        return False
    if any(cleanup.get(k) is not True for k in REQUIRED_TRUE):
        return False
    removed = cleanup.get('scratchRemoved')
    return isinstance(removed, list) and {'home', 'tmp'} <= set(removed)  # both requested removals happened


def from_config(config_path):
    try:
        c = json.loads(Path(config_path).read_text())
        return complete(Path(c['batch']) / 'result.json', c['runID'], c['epoch'])
    except (OSError, ValueError, KeyError, TypeError):
        return False


if __name__ == '__main__':
    sys.exit(0 if len(sys.argv) == 2 and from_config(sys.argv[1]) else 1)

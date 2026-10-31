# SPDX-License-Identifier: MIT
"""Usage: check_drive_cleanup.py <result.json> <run-id> <epoch>. Exit 0 only if that run's result proves complete cleanup."""
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


if __name__ == '__main__':
    sys.exit(0 if len(sys.argv) == 4 and complete(sys.argv[1], sys.argv[2], sys.argv[3]) else 1)

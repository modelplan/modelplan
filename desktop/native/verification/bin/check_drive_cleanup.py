# SPDX-License-Identifier: MIT
"""Exit 0 only if a Drive run's result.json proves complete cleanup (used by the finish gate)."""
import json
from pathlib import Path
import sys

REQUIRED_TRUE = ('ownedExited', 'guardianExited', 'topObserverJoined', 'leaseReleased')


def complete(path):
    try:
        cleanup = json.loads(Path(path).read_text())['cleanup']
    except (OSError, ValueError, KeyError, TypeError):
        return False
    if not isinstance(cleanup, dict):
        return False
    if any(cleanup.get(k) is not True for k in REQUIRED_TRUE):
        return False
    return isinstance(cleanup.get('scratchRemoved'), list)  # remove_scratch evidence, not merely absent


if __name__ == '__main__':
    sys.exit(0 if len(sys.argv) == 2 and complete(sys.argv[1]) else 1)

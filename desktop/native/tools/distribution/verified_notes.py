#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Render only an explicitly dated, reviewed snapshot of verified ledger IDs."""
import argparse
from datetime import date
import json
from pathlib import Path
import re


def render(path, today):
    value = json.loads(path.read_text())
    if set(value) != {'date', 'verified'} or value['date'] != today.isoformat():
        raise ValueError('verified ledger handoff is absent or stale')
    ids = value['verified']
    if not isinstance(ids, list) or len(ids) != len(set(ids)) or any(not isinstance(x, str) or not re.fullmatch(r'G3-[0-9]+', x) for x in ids):
        raise ValueError('invalid verified ledger IDs')
    return 'Verified fixes\n\n' + ''.join('- ' + x + '\n' for x in ids)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('snapshot', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    args.output.write_text(render(args.snapshot, date.today()))

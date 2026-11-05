#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Export reviewed status IDs only; run on the host that can read the ledger."""
import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import re


def snapshot(ledger, today):
    ids = []
    seen = set()
    for line in ledger.splitlines():
        if not line.startswith('| G3-'):
            continue
        columns = [item.strip() for item in line.strip().strip('|').split('|')]
        if len(columns) != 7 or not re.fullmatch(r'G3-[0-9]+', columns[0]) or columns[0] in seen:
            raise ValueError('invalid ledger row')
        seen.add(columns[0])
        if re.match(r'^VERIFIED(?:\b|$)', columns[-1]):
            ids.append(columns[0])
    if not seen:
        raise ValueError('no ledger rows')
    return {'date': today.isoformat(), 'verified': ids}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('ledger', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    value = snapshot(args.ledger.read_text(), datetime.now(timezone.utc).date())
    args.output.write_text(json.dumps(value, indent=2) + '\n')

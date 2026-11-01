# SPDX-License-Identifier: MIT
"""M1 release receipt for one started booking, with coordinator approval."""
import argparse
import json
import os
from pathlib import Path
import sys
from urllib.parse import urlsplit

from book import Ledger, finite

IDENTITY_FIELDS = ('runID', 'epoch', 'notBefore', 'expiresAt')
RELEASED_FIELD = 'm1Released'


def approval_url(value):
    if not isinstance(value, str) or any(c.isspace() for c in value):
        raise ValueError('approval must be an https coordinator OK comment URL')
    url = urlsplit(value)
    if url.scheme != 'https' or not url.hostname or url.username or url.password:
        raise ValueError('approval must be an https coordinator OK comment URL')
    return value


def validate_release(lease, record):
    if not isinstance(record, dict) or record.get(RELEASED_FIELD) is not True:
        raise ValueError('M1 release missing')
    approval_url(record.get('approval'))
    if any(not lease.get(k) or lease[k] != record.get(k) for k in IDENTITY_FIELDS):
        raise ValueError('lease/release identity mismatch')


def issue(ledger, ident, lease, output, *, lane, approval):
    if lane != 'M1':
        raise ValueError('only lane M1 issues release receipts')
    approval_url(approval)
    with ledger.locked(lane=lane) as (_, _, bookings, now):
        head = ledger.head(bookings)
        if not isinstance(lease, dict) or head is None:
            raise ValueError('release requires the started head booking')
        ledger.owner(head, ident, head['lane'], lease.get('runID'), lease.get('epoch'))
        if (not finite(lease.get('notBefore')) or not finite(lease.get('expiresAt'))
                or lease['notBefore'] != head['startedAt'] or lease['expiresAt'] != head['deadline']
                or not lease['notBefore'] <= now < lease['expiresAt']):
            raise ValueError('lease must match the live interval issued by booking start')
        record = {k: lease[k] for k in IDENTITY_FIELDS}
        record.update({RELEASED_FIELD: True, 'approval': approval})
        # Never overwrite a receipt for another lease or repair an ambiguous write.
        with Path(output).open('x') as file:
            json.dump(record, file, allow_nan=False)
            file.write('\n'); file.flush(); os.fsync(file.fileno())
        return record


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--ledger')
    parser.add_argument('--id', required=True)
    parser.add_argument('--lane', required=True, choices=['M1'])
    parser.add_argument('--lease', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--approval', required=True)
    args = parser.parse_args(argv)
    try:
        issue(Ledger(args.ledger), args.id, json.loads(args.lease.read_text()), args.output,
              lane=args.lane, approval=args.approval)
        print('M1 release written')
        return 0
    except (OSError, ValueError, KeyError, TypeError) as error:
        print(json.dumps(dict(error=type(error).__name__ if isinstance(error, OSError) else str(error))), file=sys.stderr)
        return 2


if __name__ == '__main__':
    sys.exit(main())

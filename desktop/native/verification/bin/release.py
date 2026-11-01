# SPDX-License-Identifier: MIT
"""Release receipt for one started booking, with coordinator approval.

Host roles (`--host`, which must equal this machine's `MODELPLAN_VERIFICATION_HOST`; unset means
`dev-mac`):
- dev-mac: only lane M1 writes the receipt, with `--approval` (https URL of the coordinator's OK).
- macci:   only lane V1 writes the receipt, with `--coordinator-go` (the coordinator's GO comment
           on the handoff issue, as a GitHub issue-comment URL). M1 does not run on MacCI.
"""
import argparse
import json
import os
from pathlib import Path
import re
import sys
from urllib.parse import urlsplit

from book import Ledger, finite

IDENTITY_FIELDS = ('runID', 'epoch', 'notBefore', 'expiresAt')
RELEASED_FIELD = 'm1Released'
HOSTS = ('dev-mac', 'macci')
HOST_ENV = 'MODELPLAN_VERIFICATION_HOST'
RELEASE_LANE = {'dev-mac': 'M1', 'macci': 'V1'}
GO_URL = re.compile(r'https://github\.com/[A-Za-z0-9-]{1,39}/[A-Za-z0-9._-]{1,100}/issues/[1-9][0-9]{0,9}'
                    r'#issuecomment-[1-9][0-9]{0,19}')


def approval_url(value):
    if not isinstance(value, str) or any(c.isspace() for c in value):
        raise ValueError('approval must be an https coordinator OK comment URL')
    url = urlsplit(value)
    if url.scheme != 'https' or not url.hostname or url.username or url.password:
        raise ValueError('approval must be an https coordinator OK comment URL')
    return value


def coordinator_go(value):
    if not isinstance(value, str) or not GO_URL.fullmatch(value):
        raise ValueError('coordinatorGo must be the GitHub issue-comment URL of the coordinator GO '
                         '(https://github.com/OWNER/REPO/issues/N#issuecomment-ID)')
    return value


def host_role(declared=None, environ=None):
    """The declared host role must match this machine's configured role (unset: dev-mac)."""
    environ = os.environ if environ is None else environ
    actual = (environ.get(HOST_ENV) or '').strip() or 'dev-mac'
    declared = declared or 'dev-mac'
    if actual not in HOSTS or declared not in HOSTS:
        raise ValueError(f'host role must be one of {", ".join(HOSTS)}')
    if declared != actual:
        raise ValueError(f'host role mismatch: declared {declared}, this host is {actual} ({HOST_ENV})')
    return actual


def validate_release(lease, record, host='dev-mac'):
    if not isinstance(record, dict):
        raise ValueError('release missing')
    if host == 'dev-mac':
        if record.get(RELEASED_FIELD) is not True or 'host' in record:
            raise ValueError('M1 release missing')
        approval_url(record.get('approval'))
    elif host == 'macci':
        if (record.get('host') != 'macci' or record.get('releasedBy') != 'V1'
                or RELEASED_FIELD in record or 'approval' in record):
            raise ValueError('MacCI V1 release missing')
        coordinator_go(record.get('coordinatorGo'))
    else:
        raise ValueError(f'host role must be one of {", ".join(HOSTS)}')
    if any(not lease.get(k) or lease[k] != record.get(k) for k in IDENTITY_FIELDS):
        raise ValueError('lease/release identity mismatch')


def issue(ledger, ident, lease, output, *, lane, approval=None, host='dev-mac', go=None):
    if host not in HOSTS:
        raise ValueError(f'host role must be one of {", ".join(HOSTS)}')
    if lane != RELEASE_LANE[host]:
        raise ValueError('only lane M1 issues release receipts on the dev Mac; only V1 on MacCI')
    if host == 'dev-mac':
        if go is not None:
            raise ValueError('a coordinator GO does not replace the M1 release on the dev Mac')
        approval_url(approval)
    else:
        if approval is not None:
            raise ValueError('MacCI releases carry the coordinator GO, not an approval URL')
        coordinator_go(go)
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
        if host == 'dev-mac':
            record.update({RELEASED_FIELD: True, 'approval': approval})
        else:
            record.update(host='macci', releasedBy='V1', coordinatorGo=go)
        # Never overwrite a receipt for another lease or repair an ambiguous write.
        with Path(output).open('x') as file:
            json.dump(record, file, allow_nan=False)
            file.write('\n'); file.flush(); os.fsync(file.fileno())
        return record


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--ledger')
    parser.add_argument('--id', required=True)
    parser.add_argument('--lane', required=True, choices=['M1', 'V1'])
    parser.add_argument('--host', choices=HOSTS, default='dev-mac')
    parser.add_argument('--lease', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--approval', help='dev-mac: https URL of the coordinator OK comment')
    parser.add_argument('--coordinator-go', help='macci: GitHub issue-comment URL of the coordinator GO')
    args = parser.parse_args(argv)
    try:
        host = host_role(args.host)
        issue(Ledger(args.ledger), args.id, json.loads(args.lease.read_text()), args.output,
              lane=args.lane, approval=args.approval, host=host, go=args.coordinator_go)
        print(f'{args.lane} release written ({host})')
        return 0
    except (OSError, ValueError, KeyError, TypeError) as error:
        print(json.dumps(dict(error=type(error).__name__ if isinstance(error, OSError) else str(error))), file=sys.stderr)
        return 2


if __name__ == '__main__':
    sys.exit(main())

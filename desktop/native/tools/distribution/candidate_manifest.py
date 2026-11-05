#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Create and verify a candidate archive receipt without trusting its filename."""
import argparse
import hashlib
import json
from pathlib import Path
import plistlib
import re


def create(archive, info, source):
    if not re.fullmatch(r'[0-9a-f]{40}', source):
        raise ValueError('invalid source SHA')
    enabled = plistlib.loads(info.read_bytes()).get('ModelPlanCockpitEntryEnabled')
    if enabled is not True:
        raise ValueError('candidate cockpit entry must be enabled')
    return {'sourceSHA': source, 'packageSHA256': hashlib.sha256(archive.read_bytes()).hexdigest(),
            'cockpitEntryEnabled': enabled}


def verify(archive, manifest, expected):
    value = json.loads(manifest.read_text())
    if set(value) != {'sourceSHA', 'packageSHA256', 'cockpitEntryEnabled'}:
        raise ValueError('unexpected manifest')
    if not re.fullmatch(r'[0-9a-f]{40}', expected) or value['sourceSHA'] != expected:
        raise ValueError('source SHA mismatch')
    if value['cockpitEntryEnabled'] is not True or value['packageSHA256'] != hashlib.sha256(archive.read_bytes()).hexdigest():
        raise ValueError('package or cockpit mismatch')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=('create', 'verify'))
    parser.add_argument('--archive', type=Path, required=True)
    parser.add_argument('--manifest', type=Path, required=True)
    parser.add_argument('--source', required=True)
    parser.add_argument('--info', type=Path)
    args = parser.parse_args()
    if args.action == 'create':
        if args.info is None:
            parser.error('--info is required for create')
        args.manifest.write_text(json.dumps(create(args.archive, args.info, args.source), indent=2) + '\n')
    else:
        verify(args.archive, args.manifest, args.source)

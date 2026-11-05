#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Create and verify a candidate archive receipt without trusting its filename."""
import argparse
import hashlib
import json
from pathlib import Path
import plistlib
import re


def create(archive, info, source, control, run_id, attempt):
    if not re.fullmatch(r'[0-9a-f]{40}', source):
        raise ValueError('invalid source SHA')
    if not re.fullmatch(r'[0-9a-f]{40}', control) or not re.fullmatch(r'[1-9][0-9]*', run_id) or not re.fullmatch(r'[1-9][0-9]*', attempt):
        raise ValueError('invalid validation provenance')
    metadata = plistlib.loads(info.read_bytes())
    if (metadata.get('CFBundleExecutable') != 'ModelPlanCommunity' or
        metadata.get('CFBundleIdentifier') != 'org.modelplan.community.swift.scaffold' or
        metadata.get('LSMinimumSystemVersion') != '15.0'):
        raise ValueError('unexpected candidate identity or minimum OS')
    enabled = metadata.get('ModelPlanCockpitEntryEnabled')
    if enabled is not True:
        raise ValueError('candidate cockpit entry must be enabled')
    return {'sourceSHA': source, 'packageSHA256': hashlib.sha256(archive.read_bytes()).hexdigest(),
            'cockpitEntryEnabled': enabled, 'controlSHA': control, 'workflowRunID': run_id, 'workflowAttempt': attempt}


def verify(archive, manifest, expected):
    value = json.loads(manifest.read_text())
    if set(value) != {'sourceSHA', 'packageSHA256', 'cockpitEntryEnabled', 'controlSHA', 'workflowRunID', 'workflowAttempt'}:
        raise ValueError('unexpected manifest')
    if not re.fullmatch(r'[0-9a-f]{40}', expected) or value['sourceSHA'] != expected:
        raise ValueError('source SHA mismatch')
    if (not re.fullmatch(r'[0-9a-f]{40}', value['controlSHA']) or
        not re.fullmatch(r'[1-9][0-9]*', value['workflowRunID']) or
        not re.fullmatch(r'[1-9][0-9]*', value['workflowAttempt'])):
        raise ValueError('invalid validation provenance')
    if value['cockpitEntryEnabled'] is not True or value['packageSHA256'] != hashlib.sha256(archive.read_bytes()).hexdigest():
        raise ValueError('package or cockpit mismatch')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=('create', 'verify'))
    parser.add_argument('--archive', type=Path, required=True)
    parser.add_argument('--manifest', type=Path, required=True)
    parser.add_argument('--source', required=True)
    parser.add_argument('--info', type=Path)
    parser.add_argument('--control')
    parser.add_argument('--run-id')
    parser.add_argument('--attempt')
    args = parser.parse_args()
    if args.action == 'create':
        if None in (args.info, args.control, args.run_id, args.attempt):
            parser.error('--info is required for create')
        args.manifest.write_text(json.dumps(create(args.archive, args.info, args.source, args.control, args.run_id, args.attempt), indent=2) + '\n')
    else:
        verify(args.archive, args.manifest, args.source)

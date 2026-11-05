#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Create and verify a candidate archive receipt without trusting its filename."""
import argparse
import hashlib
import json
from pathlib import Path
import plistlib
import re


def create(archive, info, source, control, run_id, attempt, cli_pin):
    if not re.fullmatch(r'[0-9a-f]{40}', source):
        raise ValueError('invalid source SHA')
    if not re.fullmatch(r'[0-9a-f]{40}', control) or not re.fullmatch(r'[1-9][0-9]*', run_id) or not re.fullmatch(r'[1-9][0-9]*', attempt):
        raise ValueError('invalid validation provenance')
    metadata = plistlib.loads(info.read_bytes())
    if (metadata.get('CFBundleExecutable') != 'ModelPlanCommunity' or
        metadata.get('CFBundleIdentifier') != 'org.modelplan.community.swift.scaffold' or
        metadata.get('LSMinimumSystemVersion') != '15.0'):
        raise ValueError('unexpected candidate identity or minimum OS')
    pin = json.loads(cli_pin.read_text())
    version = pin.get('version')
    source_hashes = pin.get('sourceSHA256ByArchitecture')
    helper = info.parent / 'Helpers/modelplan'
    resource = info.parent / 'Resources/modelplan.sha256'
    if (not isinstance(version, str) or not re.fullmatch(r'[0-9]+\.[0-9]+\.[0-9]+', version) or
        not isinstance(source_hashes, dict) or set(source_hashes) != {'arm64', 'x86_64'} or
        any(not isinstance(v, str) or not re.fullmatch(r'[0-9a-f]{64}', v) for v in source_hashes.values()) or
        metadata.get('ModelPlanHelperVersion') != version or
        metadata.get('ModelPlanSourceHelperSHA256ByArchitecture') != source_hashes or
        helper.is_symlink() or not helper.is_file() or helper.stat().st_size > 128 * 1024 * 1024 or
        resource.is_symlink() or not resource.is_file() or resource.stat().st_size > 256):
        raise ValueError('invalid reviewed CLI identity')
    cli_digest = hashlib.sha256(helper.read_bytes()).hexdigest()
    if metadata.get('ModelPlanBundledHelperSHA256') != cli_digest or resource.read_text().strip() != cli_digest:
        raise ValueError('bundled CLI digest mismatch')
    enabled = metadata.get('ModelPlanCockpitEntryEnabled')
    if enabled is not True:
        raise ValueError('candidate cockpit entry must be enabled')
    package_digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    return {'sourceSHA': source, 'packageSHA256': package_digest, 'sha256': package_digest,
            'cockpitEntryEnabled': enabled, 'controlSHA': control, 'workflowRunID': run_id, 'workflowAttempt': attempt,
            'cliSource': 'declared-reviewed-release', 'cliVersion': version, 'cliSHA256': cli_digest}


def verify(archive, manifest, expected):
    value = json.loads(manifest.read_text())
    if set(value) != {'sourceSHA', 'packageSHA256', 'sha256', 'cockpitEntryEnabled', 'controlSHA', 'workflowRunID', 'workflowAttempt', 'cliSource', 'cliVersion', 'cliSHA256'}:
        raise ValueError('unexpected manifest')
    if not re.fullmatch(r'[0-9a-f]{40}', expected) or value['sourceSHA'] != expected:
        raise ValueError('source SHA mismatch')
    if (not re.fullmatch(r'[0-9a-f]{40}', value['controlSHA']) or
        not re.fullmatch(r'[1-9][0-9]*', value['workflowRunID']) or
        not re.fullmatch(r'[1-9][0-9]*', value['workflowAttempt'])):
        raise ValueError('invalid validation provenance')
    if (value['cliSource'] != 'declared-reviewed-release' or
        not re.fullmatch(r'[0-9]+\.[0-9]+\.[0-9]+', value['cliVersion']) or
        not re.fullmatch(r'[0-9a-f]{64}', value['cliSHA256'])):
        raise ValueError('invalid CLI receipt')
    if (value['cockpitEntryEnabled'] is not True or value['sha256'] != value['packageSHA256'] or
        value['packageSHA256'] != hashlib.sha256(archive.read_bytes()).hexdigest()):
        raise ValueError('package or cockpit mismatch')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=('create', 'verify'))
    parser.add_argument('--archive', type=Path, required=True)
    parser.add_argument('--manifest', type=Path, required=True)
    parser.add_argument('--source', required=True)
    parser.add_argument('--info', type=Path)
    parser.add_argument('--cli-pin', type=Path)
    parser.add_argument('--control')
    parser.add_argument('--run-id')
    parser.add_argument('--attempt')
    args = parser.parse_args()
    if args.action == 'create':
        if None in (args.info, args.control, args.run_id, args.attempt, args.cli_pin):
            parser.error('--info is required for create')
        args.manifest.write_text(json.dumps(create(args.archive, args.info, args.source, args.control, args.run_id, args.attempt, args.cli_pin), indent=2) + '\n')
    else:
        verify(args.archive, args.manifest, args.source)

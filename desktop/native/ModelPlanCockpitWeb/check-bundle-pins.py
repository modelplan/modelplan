#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Check native admission pins against locally built canonical web outputs."""
import argparse
import hashlib
import json
from pathlib import Path
import re


def is_appledouble(path):
    """Skip macOS transport metadata, never ordinary invalid bundle content."""
    return any(part.startswith('._') for part in Path(path).parts)


def validate(repo, editions=('community', 'official')):
    if not editions or len(set(editions)) != len(editions) or not set(editions) <= {'community', 'official'}:
        raise ValueError('Invalid edition selection')
    source = (repo / 'desktop/native/ModelPlanAppIntegration/Sources/ModelPlanAppIntegration/CommunityCockpitApplicationFactory.swift').read_text()
    pins = dict(re.findall(r'"(community|official)"\s*:\s*"([a-f0-9]{64})"', source))
    if set(pins) != {'community', 'official'}:
        raise ValueError('Both explicit native edition pins are required')
    results = []
    for edition in editions:
        root = repo / 'desktop/cockpit/.tmp' / edition
        if root.is_symlink() or not root.is_dir():
            raise ValueError('Missing or linked canonical bundle')
        manifest = root / 'bundle-manifest.json'
        data = manifest.read_bytes()
        if hashlib.sha256(data).hexdigest() != pins[edition]:
            raise ValueError(edition + ' native pin differs from canonical build')
        value = json.loads(data)
        if value['schemaVersion'] != 1 or value['edition'] != edition or value['interfaceOnly'] is not True:
            raise ValueError('Unexpected canonical edition metadata')
        seen = set()
        for path in root.rglob('*'):
            if is_appledouble(path):
                continue
            if path.is_symlink():
                raise ValueError('Linked build output')
            if not path.is_file() or path == manifest:
                continue
            relative = path.relative_to(root).as_posix()
            if hashlib.sha256(path.read_bytes()).hexdigest() != value['files'].get(relative):
                raise ValueError('Undeclared or changed canonical output')
            seen.add(relative)
        if seen != set(value['files']):
            raise ValueError('Missing canonical output')
        results.append({'edition': edition, 'manifestSHA256': pins[edition], 'files': len(seen)})
    return results


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repo', type=Path, default=Path(__file__).resolve().parents[3])
    parser.add_argument('--edition', choices=('community', 'official'), help='Check one edition (default: both)')
    args = parser.parse_args()
    print(json.dumps(validate(args.repo, editions=(args.edition,) if args.edition else ('community', 'official'))))

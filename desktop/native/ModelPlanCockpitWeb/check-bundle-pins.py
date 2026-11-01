#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Check native admission pins against locally built canonical web outputs."""
import argparse
import hashlib
import json
from pathlib import Path
import re


def validate(repo):
    source = (repo / 'desktop/native/ModelPlanAppIntegration/Sources/ModelPlanAppIntegration/CommunityCockpitApplicationFactory.swift').read_text()
    pins = dict(re.findall(r'"(community|official)"\s*:\s*"([a-f0-9]{64})"', source))
    if set(pins) != {'community', 'official'}:
        raise ValueError('Both explicit native edition pins are required')
    results = []
    for edition in ('community', 'official'):
        root = repo / 'desktop/cockpit/.tmp' / edition
        manifest = root / 'bundle-manifest.json'
        data = manifest.read_bytes()
        if hashlib.sha256(data).hexdigest() != pins[edition]:
            raise ValueError(edition + ' native pin differs from canonical build')
        value = json.loads(data)
        if value['schemaVersion'] != 1 or value['edition'] != edition or value['interfaceOnly'] is not True:
            raise ValueError('Unexpected canonical edition metadata')
        seen = set()
        for path in root.rglob('*'):
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
    print(json.dumps(validate(parser.parse_args().repo)))

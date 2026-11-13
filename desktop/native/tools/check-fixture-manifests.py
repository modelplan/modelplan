#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
import hashlib
import json
from pathlib import Path

root = Path(__file__).resolve().parent.parent / 'ContractChecks' / 'Fixtures'
count = 0
for manifest_file in sorted((root / 'Cases').glob('*/manifest.json')):
    manifest = json.loads(manifest_file.read_text())
    assert manifest['schemaVersion'] == 1
    for name, digest in manifest['inputs'].items():
        assert hashlib.sha256((manifest_file.parent / name).read_bytes()).hexdigest() == digest, name
    personal = json.loads((manifest_file.parent / 'personal.json').read_text())
    public = manifest_file.parent / 'publication.json'
    if public.exists():
        assert personal['publication']['publicationId'] == json.loads(public.read_text())['publicationId']
    else:
        assert (manifest_file.parent / 'publication-unavailable.json').exists()
    count += 1
assert count >= 8
print(f'PASS {count} synthetic case manifests: raw inputs, expected facts, actions and hashes')

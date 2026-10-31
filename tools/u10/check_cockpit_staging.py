#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Bind U10's staged and archived cockpit to the reviewed official manifest."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import zipfile


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def check(dist, expected, candidate=None):
    if not isinstance(expected, str) or not re.fullmatch(r'[a-f0-9]{64}', expected):
        raise ValueError('Missing or invalid reviewed cockpit manifest hash')
    manifest_path = dist / 'bundle-manifest.json'
    if manifest_path.is_symlink() or not manifest_path.is_file():
        raise ValueError('Staged cockpit manifest is missing or linked')
    manifest_bytes = manifest_path.read_bytes()
    if sha256(manifest_bytes) != expected:
        raise ValueError('Staged cockpit manifest does not match the reviewed hash')
    manifest = json.loads(manifest_bytes)
    if manifest.get('schemaVersion') != 1 or manifest.get('edition') != 'official' or manifest.get('interfaceOnly') is not True:
        raise ValueError('Expected the canonical official cockpit manifest')
    index = dist / 'index.html'
    index_hash = manifest.get('files', {}).get('index.html')
    if index.is_symlink() or not index.is_file() or sha256(index.read_bytes()) != index_hash:
        raise ValueError('Staged cockpit entry does not match its manifest')
    result = {'stagedManifestSHA256': expected, 'edition': 'official'}
    if candidate is not None:
        receipt = json.loads((candidate / 'packaging-receipt.json').read_bytes())
        if receipt.get('resources', {}).get('cockpit') != 'bundled-interface-only':
            raise ValueError('Candidate packaged the cockpit placeholder')
        prefix = 'ModelPlan.app/Contents/Resources/Cockpit/'
        with zipfile.ZipFile(candidate / 'ModelPlan-candidate-adhoc.zip') as archive:
            for name in ['bundle-manifest.json', 'index.html']:
                if archive.namelist().count(prefix + name) != 1:
                    raise ValueError('Archived cockpit manifest or entry is missing or duplicated')
            archived_manifest = archive.read(prefix + 'bundle-manifest.json')
            archived_index = archive.read(prefix + 'index.html')
        if sha256(archived_manifest) != expected:
            raise ValueError('Archived cockpit manifest differs from the staged official bundle')
        if b'U10 interface placeholder' in archived_index or sha256(archived_index) != index_hash:
            raise ValueError('Archived cockpit entry is a placeholder or differs from its manifest')
        result.update(archivedManifestSHA256=expected, packagedPlaceholder=False)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--dist', required=True, type=Path)
    parser.add_argument('--expected-manifest-sha256', required=True)
    parser.add_argument('--candidate', type=Path)
    args = parser.parse_args()
    try:
        print(json.dumps(check(args.dist, args.expected_manifest_sha256, args.candidate), sort_keys=True))
    except (OSError, ValueError, KeyError, zipfile.BadZipFile) as error:
        parser.exit(1, f'Cockpit staging check failed: {error}\n')


if __name__ == '__main__':
    main()

#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Write release identity, or explicit unverified CI metadata, after helper sealing. Never executes helpers."""
import argparse
import hashlib
import plistlib
import re
from pathlib import Path

SOURCE = {
    'arm64': '06e0be93fd4529673b0328d1066c09e8bde766dd6010bceec05668f42a56eef3',
    'x86_64': 'af389d7d015ca2d392fcee5973327d7b5c277861d7dbc4aed7f291e46ebcd282',
}

def digest_file(path):
    if path.is_symlink() or not path.is_file() or not 0 < path.stat().st_size <= 128 * 1024 * 1024:
        raise ValueError('missing, linked or oversized helper')
    return hashlib.sha256(path.read_bytes()).hexdigest()

def metadata(source, raw, bundled):
    if not re.fullmatch('[0-9a-f]{40}', source) or raw != SOURCE or not re.fullmatch('[0-9a-f]{64}', bundled):
        raise ValueError('unverified release/source identity')
    return {'ModelPlanPublicSource': source, 'ModelPlanHelperVersion': '0.5.45',
            'ModelPlanSourceHelperSHA256ByArchitecture': dict(raw),
            'ModelPlanBundledHelperSHA256': bundled}

def unverified_metadata(source, bundled):
    if not re.fullmatch('[0-9a-f]{40}', source) or not re.fullmatch('[0-9a-f]{64}', bundled):
        raise ValueError('invalid non-release source/helper digest')
    # Missing release version/source-helper fields deliberately fail runtime consent admission.
    return {'ModelPlanPublicSource': source, 'ModelPlanBundledHelperSHA256': bundled}

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--app', type=Path)
    p.add_argument('--public-source')
    p.add_argument('--arm64-input', type=Path)
    p.add_argument('--x86-64-input', type=Path)
    p.add_argument('--mode', choices=('release', 'unverified'), default='release',
                   help='release requires the reviewed helper identity; unverified omits consent admission fields')
    p.add_argument('--self-test', action='store_true')
    a = p.parse_args()
    if a.self_test:
        value = metadata('a' * 40, SOURCE, 'b' * 64)
        assert value['ModelPlanSourceHelperSHA256ByArchitecture'] == SOURCE
        assert value['ModelPlanHelperVersion'] == '0.5.45'
        for source, raw in [('bad', SOURCE), ('a' * 40, {**SOURCE, 'arm64': '0' * 64})]:
            try: metadata(source, raw, 'b' * 64)
            except ValueError: pass
            else: raise AssertionError('invalid input admitted')
        print('PASS metadata shape, invalid source and wrong raw helper refusal')
        return
    if not all([a.app, a.public_source, a.arm64_input, a.x86_64_input]):
        p.error('app, public-source and both raw helper inputs are required')
    raw = {'arm64': digest_file(a.arm64_input), 'x86_64': digest_file(a.x86_64_input)}
    bundled = digest_file(a.app / 'Contents/Helpers/modelplan')
    fields = unverified_metadata(a.public_source, bundled) if a.mode == 'unverified' else metadata(a.public_source, raw, bundled)
    info_path = a.app / 'Contents/Info.plist'
    if info_path.is_symlink() or info_path.stat().st_size > 65536:
        raise ValueError('invalid bundle metadata')
    info = plistlib.loads(info_path.read_bytes())
    for field in ('ModelPlanHelperVersion', 'ModelPlanSourceHelperSHA256', 'ModelPlanSourceHelperSHA256ByArchitecture'):
        info.pop(field, None)
    info.update(fields)
    info_path.write_bytes(plistlib.dumps(info))
    (a.app / 'Contents/Resources/modelplan.sha256').write_text(bundled + '\n')
    print(f'consent bundle metadata written ({a.mode}); source provenance/reader consent are separate gates')

if __name__ == '__main__': main()

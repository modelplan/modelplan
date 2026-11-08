#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Native cockpit admission pins, produced from the canonical web build at build time.

The pins are never committed. The default mode (or `--write`) validates both locally built
editions and writes the gitignored Swift file the app compiles in; `--check` only verifies that
file still equals the build; `--app` proves a packaged app ships exactly the built edition whose
pin is compiled into its executable.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re

EDITIONS = ('community', 'official')
FACTORY = 'desktop/native/ModelPlanAppIntegration/Sources/ModelPlanAppIntegration/CommunityCockpitApplicationFactory.swift'
GENERATED = 'desktop/native/ModelPlanAppIntegration/Sources/ModelPlanAppIntegration/CockpitBundlePins.generated.swift'
COMMITTED_PIN = re.compile(r'"(community|official)"\s*:\s*"[a-f0-9]{64}"')
# Official bundle prefixes copied from the reserved visuals, and their source directories under the register's prefix.
RESERVED_SOURCES = (('runtime/', 'runtime/'), ('assets/bells/SOURCES.md', 'cockpit/bells/SOURCES.md'),
                    ('assets/hull/SOURCES.md', 'cockpit/hull/SOURCES.md'), ('assets/bells/', 'cockpit/bells/assets/'),
                    ('assets/hull/', 'cockpit/hull/assets/'), ('assets/logo.svg', 'logo.svg'),
                    ('assets/', 'cockpit/strip/assets/'))
THIRD_PARTY = ('assets/brands/', 'assets/SOURCES.md')


def is_appledouble(path):
    """Skip macOS transport metadata, never ordinary invalid bundle content."""
    return any(part.startswith('._') for part in Path(path).parts)


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def is_text(data):
    if b'\0' in data:
        return False
    try:
        data.decode('utf-8')
    except UnicodeDecodeError:
        return False
    return True


def inventory(root, edition):
    """Exact regular-file inventory of one built edition, checked against its own manifest."""
    manifest = root / 'bundle-manifest.json'
    data = manifest.read_bytes()
    value = json.loads(data)
    if value.get('schemaVersion') != 1 or value.get('edition') != edition or value.get('interfaceOnly') is not True:
        raise ValueError('Unexpected canonical edition metadata')
    files = {}
    for path in root.rglob('*'):
        if is_appledouble(path.relative_to(root)):
            continue
        if path.is_symlink():
            raise ValueError('Linked build output')
        if not path.is_file() or path == manifest:
            continue
        relative = path.relative_to(root).as_posix()
        content = path.read_bytes()
        if sha256(content) != value['files'].get(relative):
            raise ValueError('Undeclared or changed canonical output: ' + relative)
        files[relative] = content
    if set(files) != set(value['files']):
        raise ValueError('Missing canonical output')
    return sha256(data), files


def register(repo):
    reserved = json.loads((repo / 'source-policy.json').read_text())['reservedVisuals']
    return reserved['prefix'], {**reserved.get('historicalMit', {}), **reserved['binaries']}


def check_register(repo, edition, files, reserved_prefix, listed):
    """Official ships reserved bytes only as registered; community ships no registered binary."""
    if edition == 'community':
        values = set(listed.values())
        for relative, data in files.items():
            if not is_text(data) and sha256(data) in values:
                raise ValueError('Community edition ships a reserved visual: ' + relative)
        return
    for relative, data in files.items():
        if relative.startswith(THIRD_PARTY):
            continue
        for prefix, source in RESERVED_SOURCES:
            if not relative.startswith(prefix):
                continue
            origin = reserved_prefix + source + relative[len(prefix):]
            path = repo / origin
            if not path.is_file() or path.is_symlink() or path.read_bytes() != data:
                raise ValueError('Official output differs from its reserved source: ' + relative)
            if not is_text(data) and listed.get(origin) != sha256(data):
                raise ValueError('Reserved binary is not in the register: ' + origin)
            break


def validate(repo):
    """Validate both built editions; return their manifest pins and file counts."""
    reserved_prefix, listed = register(repo)
    results = []
    for edition in EDITIONS:
        pin, files = inventory(repo / 'desktop/cockpit/.tmp' / edition, edition)
        check_register(repo, edition, files, reserved_prefix, listed)
        results.append({'edition': edition, 'manifestSHA256': pin, 'files': len(files)})
    return results


def render(results):
    rows = ''.join('        "%s": "%s",\n' % (r['edition'], r['manifestSHA256']) for r in results)
    return ('// SPDX-License-Identifier: MIT\n'
            '// Generated at build time by desktop/native/ModelPlanCockpitWeb/check-bundle-pins.py\n'
            '// from desktop/cockpit/.tmp. Never committed (.gitignore); see CommunityCockpitApplicationFactory.\n'
            'extension CockpitBuildPins {\n'
            '    static var manifest: [String: String] {\n'
            '        [\n' + rows + '        ]\n'
            '    }\n'
            '}\n')


def no_committed_pins(repo):
    if COMMITTED_PIN.search((repo / FACTORY).read_text()):
        raise ValueError('Cockpit manifest pins are generated at build time; remove the literals from the factory')


def write(repo):
    no_committed_pins(repo)
    results = validate(repo)
    (repo / GENERATED).write_text(render(results))
    return results


def check(repo):
    no_committed_pins(repo)
    results = validate(repo)
    path = repo / GENERATED
    if not path.is_file() or path.read_text() != render(results):
        raise ValueError('Generated cockpit pins are missing or differ from the canonical build; run --write')
    return results


def check_app(repo, app):
    """The packaged page is exactly the built edition, and its pin is compiled into the executable."""
    pins = {r['edition']: r['manifestSHA256'] for r in check(repo)}
    edition = json.loads((app / 'Contents/Resources/build-edition.json').read_text())['edition']
    if edition not in pins:
        raise ValueError('Unknown packaged cockpit edition')
    pin, files = inventory(app / 'Contents/Resources/Cockpit', edition)
    _, built = inventory(repo / 'desktop/cockpit/.tmp' / edition, edition)
    if pin != pins[edition] or files != built:
        raise ValueError('Packaged cockpit differs from the canonical build')
    if pins[edition].encode() not in (app / 'Contents/MacOS/ModelPlanCommunity').read_bytes():
        raise ValueError('Packaged executable does not carry the build pin of its cockpit')
    return {'edition': edition, 'manifestSHA256': pin, 'files': len(files)}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repo', type=Path, default=Path(__file__).resolve().parents[3])
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--write', action='store_true', help='write the gitignored generated pins file (default)')
    mode.add_argument('--check', action='store_true', help='only verify the generated file equals the build')
    mode.add_argument('--app', type=Path, help='check a packaged .app against the build and its pins')
    args = parser.parse_args()
    if args.app:
        print(json.dumps(check_app(args.repo, args.app)))
    elif args.check:
        print(json.dumps(check(args.repo)))
    else:
        print(json.dumps(write(args.repo)))

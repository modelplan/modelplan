#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Check the canonical native App/CLI notice catalog and render distribution views."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
CATALOG = 'desktop/third-party/notices.json'
BASE = 'desktop/third-party'
def release_targets(root):
    recipe = (root / '.github/workflows/release.yml').read_text()
    loops = re.findall(r'^\s*for target in ([^;$\n]+); do\s*$', recipe, re.M)
    require(len(loops) == 1, 'release target recipe changed; update notice inventory parser')
    targets = loops[0].split()
    require(targets and len(set(targets)) == len(targets) and
            all(re.fullmatch(r'[a-z0-9]+/[a-z0-9]+', target) for target in targets), 'invalid release targets')
    return targets


def require(condition, message):
    if not condition:
        raise ValueError(message)


def git_files(root):
    result = subprocess.check_output(['git', 'ls-files', '--cached', '--others', '--exclude-standard', '-z'], cwd=root)
    return sorted(set(p for p in result.decode().split('\0') if p))


def go_inventory(root):
    """Use the module resolver and the release's six real non-test package graphs."""
    mod = json.loads(subprocess.check_output(['go', 'mod', 'edit', '-json'], cwd=root / 'cli'))
    versions = {m['Path']: m['Version'] for m in mod['Require']}
    require(not mod.get('Replace'), 'Go replace directives require an explicit notice provenance review')
    inventory = {}
    for target in release_targets(root):
        goos, arch = target.split('/')
        output = subprocess.check_output(['go', 'list', '-mod=readonly', '-deps', '-f',
            '{{if and .Module (not .Module.Main)}}{{.Module.Path}} {{.Module.Version}} {{.Module.Dir}}{{end}}',
            './cmd/modelplan'], cwd=root / 'cli', text=True,
            env={**os.environ, 'GOOS': goos, 'GOARCH': arch, 'CGO_ENABLED': '0'})
        for line in output.splitlines():
            if not line:
                continue
            name, version, directory = line.split(' ', 2)
            require(versions.get(name) == version, 'linked Go module must be pinned in go.mod: ' + name)
            if name not in inventory:
                inventory[name] = dict(version=version, directory=directory, targets=[])
            inventory[name]['targets'].append(target)
    return inventory


def swift_inventory(root, files):
    """SPM v1/v2/v3 pins; local first-party packages have no remote notice entry."""
    inventory = {}
    locks = [p for p in files if Path(p).name == 'Package.resolved']
    for path in locks:
        data = json.loads((root / path).read_text())
        require(data.get('version') in (1, 2, 3), 'unsupported Swift lock format: ' + path)
        pins = data['object']['pins'] if data['version'] == 1 else data['pins']
        for pin in pins:
            name = pin.get('identity', pin.get('package'))
            location = pin.get('location', pin.get('repositoryURL'))
            state = pin['state']
            version = state.get('version') or state.get('revision')
            require(name and location and version and state.get('revision'), 'incomplete Swift pin: ' + path)
            key = 'swift:' + location.rstrip('/').removesuffix('.git').lower()
            item = dict(name=name, version=version, revision=state['revision'], source=location)
            if key in inventory:
                require(inventory[key] == item, 'conflicting Swift pins: ' + key)
            inventory[key] = item
    # Do not let a first remote dependency escape simply by omitting its lock.
    # Remote URL declarations (even before resolve) demand a committed matching pin.
    locations = {v['source'].rstrip('/').removesuffix('.git').lower() for v in inventory.values()}
    for path in [p for p in files if Path(p).name == 'Package.swift']:
        source = (root / path).read_text()
        for url in re.findall(r'\.package\s*\(\s*(?:name\s*:\s*"[^"]+"\s*,\s*)?url\s*:\s*"([^"]+)"', source):
            require(url.rstrip('/').removesuffix('.git').lower() in locations,
                    'Swift remote dependency needs a committed Package.resolved: ' + url)
    return inventory


def check_swift_manifests(root, files, pins):
    """Host Swift evaluates manifests so computed/conditional URLs cannot evade CI."""
    sources = {v['source'].rstrip('/').removesuffix('.git').lower() for v in pins.values()}
    for path in [p for p in files if Path(p).name == 'Package.swift']:
        scratch = root / '.tmp/notices/swift-manifests' / hashlib.sha256(path.encode()).hexdigest()[:12]
        package = json.loads(subprocess.check_output(['swift', 'package', '--package-path', str((root / path).parent),
            '--scratch-path', str(scratch), '--cache-path', str(root / '.tmp/notices/swift-cache'),
            'dump-package'], text=True))
        for dependency in package.get('dependencies', []):
            if 'fileSystem' in dependency:
                continue
            require('sourceControl' in dependency, 'unreviewed Swift dependency kind: ' + path)
            for source in dependency['sourceControl']:
                location = source['location']['remote'][0]['urlString']
                require(location.rstrip('/').removesuffix('.git').lower() in sources,
                        'Swift manifest dependency missing lock: ' + location)
        for target in package.get('targets', []):
            require(target.get('type') != 'binary', 'Swift binary target needs an explicit shipped-artifact notice review: ' + path)


def coverage(entries, inventory, kind):
    actual = {e['id']: e for e in entries if e['kind'] == kind}
    require(set(actual) == set(inventory), kind + ' notice coverage mismatch; missing=' +
            ', '.join(sorted(set(inventory) - set(actual))) + '; stale=' + ', '.join(sorted(set(actual) - set(inventory))))
    for key, expected in inventory.items():
        require(actual[key]['version'] == expected['version'], 'notice version drift: ' + key)
        if 'revision' in expected:
            require(actual[key].get('revision') == expected['revision'], 'notice revision drift: ' + key)


def vendored_coverage(root, files, entries):
    covered = {p: e for e in entries for p in e['paths']}
    for path in files:
        if any(part.lower() in ('tests', 'testdata', 'fixtures', 'appclitests', 'appclicontracttests') for part in Path(path).parts) or path.endswith('_test.go'):
            continue
        if path.startswith(BASE + '/licenses/') or Path(path).suffix not in ('.go', '.swift', '.js', '.mjs', '.cjs', '.ts', '.tsx', '.h', '.c', '.cpp'):
            continue
        if not path.startswith(('desktop/', 'cli/', 'clients/')):
            continue
        source = (root / path).read_text(errors='replace')
        is_three = (bool(re.search(r'(^|[/_.-])three([/_.-]|$)', path, re.I)) or
                    bool(re.search(r'three\.js|THREE\.REVISION|@license\s+three', source, re.I)))
        is_pulse = bool(re.search(r'(^|/)pulse/', path, re.I) or re.search(r'ported from Pulse', source, re.I))
        leading = []
        for line in source.splitlines():
            if line.strip() and not line.lstrip().startswith('//'):
                break
            leading.append(line)
        apache = bool(re.search(r'SPDX-License-Identifier:\s*Apache-2\.0|Licensed under the Apache License', source) or
                      'Apache-2.0' in '\n'.join(leading))
        if is_three or is_pulse or apache:
            require(path in covered, 'vendored source missing notice: ' + path)
            entry = covered[path]
            if is_three:
                require(entry['name'].lower() in ('three', 'three.js'), 'three.js attribution missing: ' + path)
            if is_pulse or apache:
                require('Apache-2.0' in entry['licenseSpdxId'], 'Apache source attribution missing: ' + path)
    # A dependency added through npm must also acquire a notice before vendoring.
    for path in files:
        if Path(path).name == 'package-lock.json' and path.startswith('desktop/'):
            data = json.loads((root / path).read_text())
            for name, item in data.get('packages', {}).items():
                if name.endswith('node_modules/three'):
                    require(any(e['name'].lower() in ('three', 'three.js') and e['version'] == item['version'] for e in entries),
                            'three.js npm pin missing notice: ' + path)


def license_files(root, entries):
    for entry in entries:
        require(entry['licenseTextPath'] == entry['licenseFiles'][0]['path'], 'primary licence path mismatch')
        texts = []
        for item in entry['licenseFiles']:
            relative = Path(item['path'])
            require(not relative.is_absolute() and '..' not in relative.parts and '\\' not in item['path'], 'licence path must stay inside notice resources')
            path = root / BASE / relative
            require(not path.is_symlink() and path.is_file() and path.resolve().is_relative_to((root / BASE).resolve()), 'invalid licence path')
            data = path.read_bytes()
            require(hashlib.sha256(data).hexdigest() == item['sha256'], 'licence bytes drift: ' + str(path.relative_to(root)))
            require(len(data) > 100, 'licence text incomplete')
            texts.append(data.decode())
        require(entry['name'] and entry['version'] and entry['usedBy'] and entry['copyright'], 'incomplete notice metadata')
        require(re.fullmatch(r'[A-Za-z0-9.+-]+(?: (?:AND|OR) [A-Za-z0-9.+-]+)*', entry['licenseSpdxId']), 'invalid SPDX expression')
        for path in entry['paths']:
            require((root / path).is_file(), 'notice usage path absent: ' + path)


def check(root, entries, files=None, go=None, evaluate_swift=False):
    files = git_files(root) if files is None else files
    require(len({e['id'] for e in entries}) == len(entries), 'duplicate notice identity')
    license_files(root, entries)
    go = go_inventory(root) if go is None else go
    coverage(entries, {'go:' + k: v for k, v in go.items()}, 'go-module')
    for e in entries:
        if e['kind'] != 'go-module':
            continue
        module = go[e['name']]
        upstream = Path(module['directory'])
        expected = sorted(f.name for f in upstream.iterdir() if f.is_file() and
                          (f.name.upper().startswith(('LICENSE', 'COPYING', 'NOTICE')) or f.name == 'PATENTS'))
        require(sorted(f['sourceFile'] for f in e['licenseFiles']) == expected, 'upstream licence/NOTICE omitted: ' + e['name'])
        for item in e['licenseFiles']:
            require((upstream / item['sourceFile']).read_bytes() == (root / BASE / item['path']).read_bytes(),
                    'upstream Go licence differs: ' + e['name'])
        require(e['targets'] == module['targets'], 'Go target coverage drift: ' + e['name'])
    pins = swift_inventory(root, files)
    coverage(entries, pins, 'swift-package')
    if evaluate_swift:
        check_swift_manifests(root, files, pins)
    fonts = json.loads((root / BASE / 'fonts/manifest.json').read_text())
    coverage(entries, {'font:' + f['id']: f for f in fonts['families']}, 'font')
    for family in fonts['families']:
        entry = next(e for e in entries if e['id'] == 'font:' + family['id'])
        require(entry['licenseSpdxId'] == 'OFL-1.1' and entry['licenseTextPath'] == 'fonts/' + family['licenseFile'] and
                entry['copyright'] == [family['copyright']], 'font attribution drift')
    pin = json.loads((root / 'cli/internal/quota/codexbar-pin.json').read_text())
    cb = next(e for e in entries if e['id'] == 'codexbar')
    require(cb['version'] == pin['version'] and cb['source'] == pin['release'], 'CodexBar pin drift')
    require((root / BASE / cb['licenseTextPath']).read_bytes() == (root / 'LICENSES/CodexBar-MIT.txt').read_bytes(), 'CodexBar licence drift')
    vendored_coverage(root, files, entries)
    return go, pins


def section(root, entry):
    title = entry['name'] + ' ' + entry['version']
    result = ['## ' + title, '', 'Licence: `' + entry['licenseSpdxId'] + '`.', '',
              *entry['copyright'], '', 'Used in: ' + '; '.join(entry['usedBy']) + '.', '', 'Source: ' + entry['source'], '']
    for item in entry['licenseFiles']:
        text = (root / BASE / item['path']).read_text().rstrip('\n')
        fence = '`' * max(3, max((len(m) + 1 for m in re.findall(r'`+', text)), default=0))
        result += ['### ' + item['sourceFile'], '', fence + 'text', text, fence, '']
    return '\n'.join(result)


def render(root, entries):
    intro = '''<!-- SPDX-License-Identifier: MIT -->
# Third-party notices

Generated from [notices.json](notices.json), the canonical editable catalog.
The full licence texts below are unmodified; the metadata and this index do not
replace them. Licence paths in JSON are relative to this directory, so a future
About renderer can load each text without a network request. About rendering
and App resource integration are separate work; this change provides their data.

Components are added with the PRs that ship them. three.js and the future native
Pulse shell port are not present in this catalog until those PRs land. The existing
Go Kiro ACP adaptation is covered by the Pulse entry below. Its upstream notices
are reproduced as provenance; Pulse's icons and other components are not bundled.
CodexBar covers the pinned optional helper and the already-ported native readers;
its separate upstream binary retains its own bundled dependency notices.

The Go list is the union of actual non-test CLI dependency graphs for all six
release targets (CGO disabled), resolved from cli/go.mod. Test/tool-only modules
are excluded. Native App Swift packages currently have only first-party local
dependencies and no Package.resolved pins; CI discovers every committed Swift
lockfile and checks evaluated manifests on macOS before accepting new dependencies.
OS-provided Apple frameworks are not redistributed Swift package dependencies.

The four unmodified font families retain OFL-1.1 and their Reserved Font Names.
The ModelPlan reserved visuals licence is separate and unchanged.

Update metadata only after reviewing upstream licences at the new pinned version.
Run `python3 scripts/third-party-notices.py --write` to regenerate both this file
and cli/THIRD-PARTY-NOTICES.md, then run without --write to check coverage and drift.
CI also rejects unlisted vendored three.js, Pulse paths and Apache-derived source.

'''
    docs = intro + '\n'.join(section(root, e) for e in entries)
    cli_entries = [e for e in entries if e['kind'] in ('go-module', 'source-port', 'helper')]
    cli = '# Third-party notices\n\nGenerated from desktop/third-party/notices.json. Includes the CLI dependency union across all release platforms and ported reader attributions.\n\n'
    cli += '\n'.join(section(root, e) for e in cli_entries)
    return {BASE + '/NOTICES.md': docs, 'cli/THIRD-PARTY-NOTICES.md': cli}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--write', action='store_true')
    parser.add_argument('--swift-manifests', action='store_true')
    args = parser.parse_args()
    try:
        data = json.loads((ROOT / CATALOG).read_text())
        require(data['schemaVersion'] == 1, 'unknown catalog schema')
        go, pins = check(ROOT, data['components'], evaluate_swift=args.swift_manifests)
        for path, expected in render(ROOT, data['components']).items():
            target = ROOT / path
            if args.write:
                target.write_text(expected)
            else:
                require(target.read_text() == expected, 'generated notices stale: ' + path + ' (run --write)')
        print(f'Notices cover {len(go)} shipped Go modules, {len(pins)} Swift pins, four OFL families, CodexBar and source ports.')
    except (ValueError, KeyError, OSError, subprocess.CalledProcessError) as exc:
        parser.exit(1, 'notice check failed: ' + str(exc) + '\n')


if __name__ == '__main__':
    main()

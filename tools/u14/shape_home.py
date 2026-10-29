# SPDX-License-Identifier: MIT
"""Build a new synthetic HOME from structural descriptors, never owner values."""
import argparse
from pathlib import Path, PurePosixPath
import re
import shutil

from contracts import digest, encoded, load_json, new_directory, validate, write_private

SUPPORT = 'Library/Application Support/ModelPlan/'
SETTINGS_PATHS = [SUPPORT + 'Beta07/settings-v1.json', SUPPORT + 'Native/settings-v1.json',
                  SUPPORT + 'Native/community-v1.json']
NEW_SETTINGS = SUPPORT + 'settings.json'
CONSENT = '.config/modelplan/consent.json'
CASES = ('coexistence', 'corrupt-beta07', 'missing-beta07', 'corrupt-native', 'corrupt-core',
         'all-corrupt', 'fresh', 'new-exists', 'corrupt-new', 'invalid-progress')
CORRUPT = b'{synthetic-corrupt\n'


def safe_relative(path):
    p = PurePosixPath(path)
    if (p.is_absolute() or str(p) != path or any(x in ('.', '..') for x in p.parts)
            or not p.parts or '\\' in path or any(ord(x) < 32 for x in path)):
        raise ValueError('invalid home-relative path')
    return p


def synthesize(node, depth=0):
    if depth > 24:
        raise ValueError('shape nesting limit')
    kind = node['kind']
    keys = {'kind'} | ({'fields'} if kind == 'object' else {'items'} if kind == 'array' else set())
    if set(node) != keys:
        raise ValueError('shape descriptors carry types only, never values')
    if kind == 'object':
        if any(not re.fullmatch(r'[A-Za-z_][A-Za-z0-9_.-]{0,79}', k) for k in node['fields']):
            raise ValueError('shape field names must be sanitized structural names')
        return {k: synthesize(v, depth + 1) for k, v in node['fields'].items()}
    if kind == 'array':
        return [synthesize(v, depth + 1) for v in node['items']]
    return {'string': 'synthetic', 'number': 0, 'boolean': False, 'null': None}[kind]


def settings(official):
    # Distinct synthetic sentinels expose field-group merging and edge regressions.
    return {'schemaVersion': 1, 'preferences': {
        'theme': 'night' if official else 'day', 'size': 'M', 'motion': 'system',
        'transparency': 'system', 'percentageMode': 'remaining' if official else 'used',
        'showPercentages': True, 'redBelow': 25, 'sliverAlert': True, 'showDock': True,
        'autoHide': True, 'revealMilliseconds': 150, 'magnification': 'subtle',
        'showOverFullscreen': False, 'followActiveDisplay': False,
        'dockEdge': 'left' if official else 'right', 'dockDisplayID': 'synthetic-unplugged-display',
        'dockAlongFraction': 0.25 if official else 0.75,
        'readerConsent': {'gemini': True, 'cursor': True},  # Never engine grants.
        'openAtLogin': False, 'automaticUpdates': False, 'menuDisplay': 'tightest',
        'openShortcut': {'modifiers': ['command', 'shift'], 'key': 'O'},
        'dockShortcut': {'modifiers': ['command', 'shift'], 'key': 'D'},
        'language': 'en', 'opening': 'hold', 'beatMilliseconds': 250, 'showProjectNames': False,
        'notifications': {'optedIn': False, 'kinds': ['stale']},
        'subscriptions': {'order': ['claude', 'codex', 'synthetic-unmatched-row'],
                          'hiddenIDs': ['synthetic-unmatched-row']},
        'subscriptionSettings': {'synthetic-unmatched-row': {'alias': 'Synthetic', 'percentagePin': 'auto'}},
        'helpHints': {'seen': ['ignition'], 'opens': 1, 'reveals': 1},
        'onboarding': {'step': 'setup65', 'completed': True, 'trialDemonstrated': False,
                       'definitionSignature': ['7:setup65:0']}}}


def preference_inputs(case):
    core = {'schemaVersion': 1, 'localeIdentifier': 'en_US',
            'favouriteModelIDs': ['synthetic-model'], 'fieldPickerValue': 'e30='}
    files = dict(zip(SETTINGS_PATHS, [encoded(settings(True)), encoded(settings(False)), encoded(core)]))
    source, core_source = 'beta07', 'core'
    community_source = 'native'
    if case == 'fresh':
        return {}, {'officialSettingsSource': 'defaults', 'communitySettingsSource': 'defaults', 'coreSource': 'defaults'}
    if case == 'invalid-progress':
        invalid = settings(True)
        invalid['preferences']['onboarding'] = {
            'step': 'synthetic-invalid-progress', 'completed': True,
            'trialDemonstrated': False, 'definitionSignature': []}
        files[SETTINGS_PATHS[0]] = encoded(invalid)
    if case == 'corrupt-beta07':
        files[SETTINGS_PATHS[0]] = CORRUPT
        source = 'native'
    if case == 'missing-beta07':
        del files[SETTINGS_PATHS[0]]
        source = 'native'
    if case == 'corrupt-native':
        files[SETTINGS_PATHS[1]] = CORRUPT
        community_source = 'beta07'
    if case == 'corrupt-core':
        files[SETTINGS_PATHS[2]] = CORRUPT
        core_source = 'defaults'
    if case == 'all-corrupt':
        files = {p: CORRUPT for p in SETTINGS_PATHS}
        source = core_source = community_source = 'defaults'
    if case == 'new-exists':
        new_preferences = settings(False)['preferences']
        del new_preferences['readerConsent']
        files[NEW_SETTINGS] = encoded({'schemaVersion': 1, 'settings': new_preferences, 'core': core})
        source = core_source = community_source = 'new'
    if case == 'corrupt-new':
        files[NEW_SETTINGS] = CORRUPT
        source = core_source = community_source = 'defaults'
    return files, {'officialSettingsSource': source, 'communitySettingsSource': community_source,
                   'coreSource': core_source}


def build_home(shape, destination, case='coexistence'):
    validate(shape, 'shape.schema.json')
    if (shape['fidelity'] == 'approved-shape-export') != (shape['approvalRef'] is not None):
        raise ValueError('approved shape needs an approval reference; hand-built shapes have none')
    if any(not re.fullmatch(r'[a-z][a-z0-9-]{0,47}', tool) for tool in shape['consent']['tools']):
        raise ValueError('invalid consent tool id')
    if case not in CASES:
        raise ValueError('unknown preference case')
    files, oracle = preference_inputs(case)
    reserved = set(SETTINGS_PATHS + [NEW_SETTINGS, CONSENT, '.u14-baseline.json'])
    for item in shape['files']:
        path = item['path']
        if ('shape' in item) != (item['state'] == 'json'):
            raise ValueError('only JSON files require a structural shape')
        safe_relative(path)
        if path in reserved or path.startswith('bin/') or path in files:
            raise ValueError('duplicate or reserved home path')
        files[path] = (encoded(synthesize(item['shape'])) if item['state'] == 'json'
                       else CORRUPT if item['state'] == 'corrupt' else b'')
    for tool in shape['tools']:
        files['bin/' + tool] = b'#!/bin/sh\n# Synthetic presence only; no runtime implementation.\nexit 69\n'
    consent = shape['consent']
    if consent['state'] == 'corrupt':
        files[CONSENT] = CORRUPT
    elif consent['state'] == 'v1':
        files[CONSENT] = encoded({'schemaVersion': 1, 'generation': 1, 'privacy': consent['privacy'],
                                 'tools': {tool: {'allowed': decision == 'allowed',
                                                  'consentTextVersion': 2, 'at': '2000-01-01T00:00:00Z',
                                                  'keychain': 'unset'}
                                           for tool, decision in consent['tools'].items() if decision != 'unset'}})
    # Detect ancestor/file conflicts before creating anything.
    for path in files:
        if any(str(parent) in files for parent in PurePosixPath(path).parents):
            raise ValueError('file/directory collision')
    available = ['synthetic-home', 'preference-inputs']
    if consent['state'] == 'v1':
        available.insert(1, 'consent-v1')
    gaps = list(shape['knownGaps']) + [
        'Tool executables represent presence only; runtime calls are unsupported.',
        'Generic JSON scalars are placeholders; vendor-specific parseable records need reader fixtures.',
        'Consent schema 2 awaits a pinned U2 store contract; this baseline emits schema 1 only.',
        'New settings envelope is provisional until the U5 migration contract is pinned.',
        'Keychain, GUI, displays and real account authentication are not reproduced.']
    report = {'schemaVersion': 1, 'baselineVersion': shape['baselineVersion'],
              'shapeSha256': digest(encoded(shape)), 'fidelity': shape['fidelity'],
              'approvalRef': shape['approvalRef'], 'preferenceCase': case,
              'covers': shape['covers'], 'knownGaps': gaps,
              'availableCapabilities': available, 'migrationOracle': oracle,
              'files': [{'path': p, 'sha256': digest(b)} for p, b in sorted(files.items())]}
    validate(report, 'baseline.schema.json')
    home = new_directory(destination)
    try:
        for path, data in files.items():
            target = home / path
            target.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
            write_private(target, data)
            if path.startswith('bin/'):
                target.chmod(0o700)
        write_private(home / '.u14-baseline.json', encoded(report))
    except BaseException:
        shutil.rmtree(home)
        raise
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--shape', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True, help='new HOME directory under an existing parent')
    parser.add_argument('--case', choices=CASES, default='coexistence')
    args = parser.parse_args()
    try:
        build_home(load_json(args.shape), args.output, args.case)
    except (ValueError, OSError, RecursionError) as exc:
        # Never echo paths, shape values, or raw input in error output.
        parser.exit(1, f'shape build failed ({type(exc).__name__})\n')
    print('Synthetic HOME and .u14-baseline.json created.')


if __name__ == '__main__':
    main()

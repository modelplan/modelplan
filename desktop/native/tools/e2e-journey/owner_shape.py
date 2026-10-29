#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Materialize H40 structural metadata into a NEW synthetic HOME; never inspect a user HOME."""
import argparse
import json
from pathlib import Path, PurePosixPath
import re

CACHE = 'Library/Caches/modelplan'
CONFIG = '.config/modelplan'
PREFERENCES = 'Library/Application Support/ModelPlan/Native'
TOOLS = {'codex', 'claude', 'gemini', 'cursor', 'qwen', 'copilot', 'kiro', 'zai', 'opencodego', 'antigravity', 'grok', 'kimi', 'minimax'}
ALIASES = {'claude-code': 'claude', 'zcode': 'zai', 'opencode': 'opencodego'}
PLACEMENTS = {'left', 'right', 'bottom', 'top', 'auto', 'on', 'off', 'used', 'remaining'}
KEYCHAIN_STATES = {'keychain-confirmation-needed', 'denied', 'canceled', 'not-found', 'unavailable', 'ok', 'consent-required'}
STATUSES = {'ok', 'missing', 'unreadable', 'too_large'}
MAX_FILE = 8 << 30
MAX_TOTAL = 32 << 30
MAX_ITEMS = 10000


def integer(value, maximum):
    if type(value) is not int or not 0 <= value <= maximum:
        raise ValueError('invalid bounded count')
    return value


def tool_id(value):
    result = ALIASES.get(value, value)
    if result not in TOOLS:
        raise ValueError('unknown public tool id')
    return result


def materialize(value, losses, context='', depth=0, budget=None):
    budget = [20000] if budget is None else budget
    budget[0] -= 1
    if budget[0] < 0 or depth > 12:
        raise ValueError('shape nesting limit')
    if isinstance(value, dict):
        if '<array>' in value:
            n = integer(value['<array>'], MAX_ITEMS)
            return [materialize(value.get('item'), losses, context, depth + 1, budget) for _ in range(n)]
        if '<object>' in value:
            losses.add('object contents were truncated by exporter')
            return {f'synthetic-{n}': None for n in range(integer(value['<object>'], MAX_ITEMS))}
        result = {}
        for key, item in value.items():
            if not isinstance(key, str) or not re.fullmatch(r'[A-Za-z0-9_.:< >-]{1,80}', key):
                raise ValueError('invalid structural key')
            if key == '<key>':
                losses.add('mixed-case or private keys were redacted by exporter')
            result[key] = materialize(item, losses, key, depth + 1, budget)
        return result
    if value == 'bool': return False
    if value == 'number': return 0
    if value == 'string': return 'synthetic'
    if value in ('null', None): return None
    if isinstance(value, str) and value in PLACEMENTS: return value
    raise ValueError('shape leaf must be a type or approved placement enum')


def encoded(value):
    return json.dumps(value, separators=(',', ':'), sort_keys=True).encode() + b'\n'


def generate(shape, destination):
    if not isinstance(shape, dict) or shape.get('schemaVersion') != 1:
        raise ValueError('unsupported shape schema')
    destination = Path(destination)
    # Never merge with or overwrite an existing HOME, symlink or file.
    if destination.exists() or destination.is_symlink():
        raise ValueError('destination must not exist')
    files, sizes, losses = {}, {}, set()
    directories = set()
    for field, root in [('cacheTree', CACHE), ('configTree', CONFIG)]:
        tree = shape.get(field, {'exists': False})
        if not isinstance(tree, dict) or type(tree.get('exists')) is not bool:
            raise ValueError('invalid tree')
        if not tree['exists']: continue
        directories.add(root)
        entries = tree.get('entries', [])
        if not isinstance(entries, list) or len(entries) > 400:
            raise ValueError('invalid tree entries')
        count = integer(tree.get('files', len(entries)), MAX_ITEMS)
        if count != len(entries):
            raise ValueError('export tree is truncated; cannot recreate missing file layout')
        for entry in entries:
            path = entry.get('path')
            if (not isinstance(path, str) or len(path) > 1024 or '\\' in path
                    or path.startswith('/') or any(part in ('', '.', '..') for part in path.split('/'))):
                raise ValueError('unsafe relative tree path')
            if any(not re.fullmatch(r'[a-z0-9_.:< >-]{1,80}', part) for part in path.split('/')):
                raise ValueError('invalid tree path component')
            if '<' in path:
                losses.add('file names were redacted by exporter')
            target = str(PurePosixPath(root) / path)
            if target in sizes: raise ValueError('duplicate redacted file path')
            sizes[target] = integer(entry.get('bytes'), MAX_FILE)
        if integer(tree.get('bytes', sum(sizes[p] for p in sizes if p.startswith(root + '/'))), MAX_TOTAL) != sum(sizes[p] for p in sizes if p.startswith(root + '/')):
            raise ValueError('tree total does not match entries')
    if sum(sizes.values()) > MAX_TOTAL: raise ValueError('tree total limit')

    def put(path, data):
        files[path] = data

    def section(field):
        value = shape.get(field, {'status': 'missing'})
        if not isinstance(value, dict) or value.get('status') not in STATUSES:
            raise ValueError('invalid section status')
        return value

    consent = section('consent')
    allowed = []
    generation, privacy = None, None
    consent_path = CONFIG + '/consent.json'
    if consent['status'] == 'ok':
        generation = integer(consent.get('generation'), (1 << 64) - 1)
        privacy = consent.get('privacy')
        if consent.get('schemaVersion') != 1 or privacy not in ('automatic', 'passive'):
            raise ValueError('invalid consent metadata')
        records = {}
        for raw_id, record in consent.get('tools', {}).items():
            tid = tool_id(raw_id)
            if tid in records or not isinstance(record, dict) or type(record.get('allowed')) is not bool:
                raise ValueError('invalid consent record')
            keychain = record.get('keychain', 'unset')
            if keychain not in ('unset', 'allowed', 'denied'): raise ValueError('invalid Keychain choice')
            # H40 removes readerId/consentTextVersion and timestamps. Fill with
            # public schema constants, not inferred owner values or credentials.
            result = dict(allowed=record['allowed'], consentTextVersion=2, at='2000-01-01T00:00:00Z',
                          backend=record.get('backend', 'native'), readerId='native:' + tid, keychain=keychain)
            if result['backend'] not in ('native', 'codexbar-compat', 'off'):
                raise ValueError('invalid reader backend')
            if result['backend'] != 'native': result['readerId'] = 'codexbar:' + tid
            records[tid] = result
            if result['allowed']: allowed.append(tid)
        put(consent_path, encoded(dict(schemaVersion=1, generation=generation, privacy=privacy, tools=records)))
        losses.add('consent timestamps and omitted route/version fields use synthetic public defaults')
    elif consent['status'] != 'missing': put(consent_path, b'!')
    elif consent_path in sizes: raise ValueError('missing consent conflicts with tree')

    connections = section('connections')
    connections_path = CONFIG + '/connections.json'
    legacy = []
    if connections['status'] == 'ok':
        structure = materialize(connections.get('shape'), losses)
        if not isinstance(structure, dict): raise ValueError('connections shape must be an object')
        # Exporter redacts quotaSources/schemaVersion and provider/backend values.
        arrays = [v for v in structure.values() if isinstance(v, list)]
        if len(arrays) != 1: raise ValueError('connections shape needs one quotaSources array')
        candidates = sorted({tool_id(c['id']) for c in shape.get('cliDesktopReadOnly', {}).get('connections', [])
                             if isinstance(c, dict) and ALIASES.get(c.get('id'), c.get('id')) in {'zai', 'kimi', 'minimax'}})
        if len(candidates) != len(arrays[0]):
            raise ValueError('connections provider identities are absent or ambiguous in export')
        structure['schemaVersion'] = 1
        structure.pop('<key>', None)
        structure['quotaSources'] = []
        for tid, item in zip(candidates, arrays[0]):
            if not isinstance(item, dict): raise ValueError('invalid quotaSource shape')
            structure['quotaSources'].append({**item, 'provider': tid, 'backend': 'native', 'enabled': True})
        legacy = candidates
        put(connections_path, encoded(structure))
        losses.add('connections provider ids come from reduced CLI metadata; backend/enabled use synthetic native/true values')
    elif connections['status'] != 'missing': put(connections_path, b'!')
    elif connections_path in sizes: raise ValueError('missing connections conflicts with tree')

    prefs = section('appPreferences')
    edge = None
    if prefs['status'] == 'ok':
        structure = materialize(prefs.get('shape'), losses)
        if not isinstance(structure, dict): raise ValueError('preferences shape must be an object')
        # Fixed decoder scaffolding does not claim to recover redacted fields.
        core = {**dict(favouriteModelIDs=[]), **structure, 'schemaVersion': 1}
        put(PREFERENCES + '/community-v1.json', encoded(core))
        def edges(value):
            if not isinstance(value, dict): return []
            return [v for k, v in value.items() if k in ('edge', 'dockEdge') and v in ('left', 'right', 'bottom')] + [e for v in value.values() if isinstance(v, dict) for e in edges(v)]
        found = set(edges(structure))
        if len(found) > 1: raise ValueError('conflicting Dock placement enums')
        edge = next(iter(found), None)
        if edge is not None:
            # H40 reads community-v1, while current Dock settings live in settings-v1.
            # An explicit synthetic edge also seeds that actual production store.
            put(PREFERENCES + '/settings-v1.json', encoded(dict(schemaVersion=1, preferences=dict(dockEdge=edge))))
            losses.add('explicit synthetic Dock enum is also seeded into production settings-v1; exporter does not capture that file')
        else:
            losses.add('export has no identifiable Dock edge; placement fidelity is unavailable')
    elif prefs['status'] != 'missing': put(PREFERENCES + '/community-v1.json', b'!')

    state = shape.get('claudeKeychainSavedState', 'missing')
    state_path = CACHE + '/observed/keychain/claude-code.json'
    if state in KEYCHAIN_STATES: put(state_path, encoded(dict(state=state)))
    elif state in ('unreadable', 'too_large'): put(state_path, b'!')
    elif state != 'missing': raise ValueError('invalid saved Keychain state')
    elif state_path in sizes: raise ValueError('missing Keychain state conflicts with tree')
    credentials = shape.get('claudeCredentialsFileExists')
    if type(credentials) is not bool: raise ValueError('invalid credentials existence flag')
    if credentials: put('.claude/.credentials.json', b'')
    # Validate before writing anything, including exact semantic-file sizes.
    for path, data in files.items():
        if path in sizes and data != b'!' and sizes[path] > 1 << 20:
            raise ValueError('ok semantic section exceeds export read bound')
        if path in sizes and len(data) > sizes[path]:
            raise ValueError('recorded file is too small for synthetic schema content')
    targets = set(files) | set(sizes)
    if any(str(PurePosixPath(p).parent) in targets or any(str(parent) in targets for parent in PurePosixPath(p).parents) for p in targets):
        raise ValueError('file/directory collision')
    destination.mkdir(mode=0o700)
    for root in directories: (destination / root).mkdir(parents=True, exist_ok=True, mode=0o700)
    for path in sorted(targets):
        target = destination / path
        target.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
        data = files.get(path, b'')
        size = sizes.get(path, len(data))
        with target.open('xb') as out:
            out.write(data)
            if path in files and data != b'!':
                # JSON trailing whitespace preserves validity and exact length.
                left = size - len(data)
                while left:
                    chunk = min(left, 65536); out.write(b' ' * chunk); left -= chunk
            else:
                # Sparse zero filler models large volumes without copying any data.
                out.truncate(size)
        target.chmod(0o600)
    (destination / '.claude').mkdir(exist_ok=True, mode=0o700)
    return dict(schemaVersion=1, synthetic=True, allowedTools=sorted(allowed), generation=generation, privacy=privacy,
                dockEdge=edge, legacyTools=legacy, keychainSavedState=state, credentialsFileExists=credentials,
                files=len(targets), recordedFiles=len(sizes), recordedBytes=sum(sizes.values()), limitations=sorted(losses))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('shape', type=Path); parser.add_argument('destination', type=Path)
    args = parser.parse_args()
    try:
        if args.shape.stat().st_size > 1 << 20: raise ValueError('shape input too large')
        result = generate(json.loads(args.shape.read_text()), args.destination)
        print(json.dumps(result, indent=2, sort_keys=True))
    except (OSError, ValueError, TypeError, KeyError):
        parser.exit(1, 'shape generation failed: invalid or incomplete structural metadata\n')

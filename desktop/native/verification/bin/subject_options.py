# SPDX-License-Identifier: MIT
"""Run-config options that shape the candidate's environment: `readers`, `subjectEnv`, `backup`.

Only restricting variables pass, each with a fixed set of values, so a run config can narrow what
the candidate's engine reads but never widen it:

  readers: "off"             MODELPLAN_READERS=off, MODELPLAN_CODEX_ACCOUNT=off
           "passive"         MODELPLAN_READERS=passive
           ["codex", "zai"]  MODELPLAN_VERIFY_READERS=codex,zai (the engine narrows saved and
                             default consent to these tool IDs; never widens it) and, unless codex
                             is listed, MODELPLAN_CODEX_ACCOUNT=off. `zcode` is accepted as the
                             brief name of the `zai` consent tool and recorded as such.
  subjectEnv: {KEY: value}   extra keys from ALLOWED only, e.g. {"MODELPLAN_HISTORY": "off"};
                             a reader list has this one spelling, `readers`
  backup: "product"          real profile only: product_backup.py around the subject

Every inherited MODELPLAN_* variable is removed from a real-profile environment (names recorded),
so only these reviewed values reach the candidate. Values here are switches and tool IDs, never
secrets, so the run manifest records them in full.

These variables reach the app process, and a packaged app hands its engine only the keys in its
launch-environment contract (schema/app-cli/child-environment.json). `engine_delivery` therefore
refuses, before spawn, any app-zip run whose app would drop one: a restriction that is recorded
must be a restriction the engine received.
"""
import re
from pathlib import Path

TOOL = re.compile(r'[a-z][a-z0-9-]{0,47}\Z')
ALIASES = {'zcode': 'zai'}  # brief names -> consent tool IDs (cli/internal/consent)
VERIFY_READERS = 'MODELPLAN_VERIFY_READERS'
# The marker the candidate's bundled engine must contain before a reader list is trusted: an engine
# without it would ignore the list and read every consented tool.
ENGINE_MARKER = VERIFY_READERS.encode()
ALLOWED = {
    'MODELPLAN_READERS': ('off', 'passive'),
    'MODELPLAN_CODEX_ACCOUNT': ('off',),
    'MODELPLAN_HISTORY': ('off',),
    'MODELPLAN_CODEXBAR': ('off',),
}
BACKUPS = ('product',)


def parse_readers(value):
    """'off' | 'passive' | list of tool IDs (or a comma string) -> (mode, ids, aliases used)."""
    if value is None:
        return None, [], {}
    if value in ('off', 'passive'):
        return value, [], {}
    if value == 'automatic':
        raise ValueError('readers automatic is the default, not a restriction; use off, passive or a tool list')
    if isinstance(value, str):
        value = [x.strip() for x in value.split(',')]
    if not isinstance(value, list) or not value or any(not isinstance(x, str) or not x for x in value):
        raise ValueError('readers must be off, passive or a non-empty list of tool IDs')
    ids, used = [], {}
    for raw in value:
        tool = ALIASES.get(raw, raw)
        if raw != tool:
            used[raw] = tool
        if not TOOL.fullmatch(tool):
            raise ValueError(f'invalid reader tool ID: {raw}')
        if tool not in ids:
            ids.append(tool)
    return 'list', ids, used


def reader_env(value):
    mode, ids, _ = parse_readers(value)
    if mode is None:
        return {}
    if mode == 'off':
        return {'MODELPLAN_READERS': 'off', 'MODELPLAN_CODEX_ACCOUNT': 'off'}
    if mode == 'passive':
        return {'MODELPLAN_READERS': 'passive'}
    env = {VERIFY_READERS: ','.join(ids)}
    if 'codex' not in ids:
        env['MODELPLAN_CODEX_ACCOUNT'] = 'off'
    return env


def check_env(extra):
    if extra is None:
        return {}
    if not isinstance(extra, dict):
        raise ValueError('subjectEnv must be an object')
    for key, value in extra.items():
        if key == VERIFY_READERS:
            raise ValueError(f'subjectEnv key not allowed: {key}; use readers, which also checks the engine')
        if key not in ALLOWED:
            raise ValueError(f'subjectEnv key not allowed: {key}')
        if value not in ALLOWED[key]:
            raise ValueError(f'subjectEnv {key} must be one of {", ".join(ALLOWED[key])}')
    return dict(extra)


def subject_overrides(config):
    """Validated environment additions for this run (readers first, then subjectEnv)."""
    env = reader_env(config.get('readers'))
    for key, value in check_env(config.get('subjectEnv')).items():
        if key in env and env[key] != value:
            raise ValueError(f'subjectEnv {key} conflicts with readers')
        env[key] = value
    return env


def validate(config):
    """Contract-time checks (admission.validate calls this)."""
    subject_overrides(config)
    backup = config.get('backup')
    if backup is not None:
        if backup not in BACKUPS:
            raise ValueError('backup must be product')
        if config.get('profile', 'synthetic') != 'real':
            raise ValueError('backup product needs the real profile (a synthetic HOME is thrown away)')
        path = config.get('backupDir')
        if not isinstance(path, str) or not path.startswith('/'):
            raise ValueError('backup product needs an absolute backupDir')
    if VERIFY_READERS in subject_overrides(config) and config.get('subjectKind', 'binary') != 'app-zip':
        raise ValueError('a reader list needs an app-zip subject (its bundled engine is checked)')
    manifest = config.get('runManifestPath')
    if manifest is not None and (not isinstance(manifest, str) or not manifest.startswith('/')):
        raise ValueError('runManifestPath must be absolute')


def apply(env, config, real):
    """Final candidate environment and its manifest entry. Real: inherited MODELPLAN_* removed."""
    stripped = sorted(k for k in env if k.startswith('MODELPLAN_')) if real else []
    out = {k: v for k, v in env.items() if k not in stripped}
    overrides = subject_overrides(config)
    out.update(overrides)
    _, ids, used = parse_readers(config.get('readers'))
    return out, dict(readers=config.get('readers'), readerIDs=ids, readerAliases=used,
                     subjectEnv=dict(sorted(overrides.items())), strippedEnvKeys=stripped)


def merge_flags(config, **flags):
    """CLI flags (--profile/--readers/--backup) fill the config; a different value already there is refused."""
    out = dict(config)
    for key, value in flags.items():
        if value is None:
            continue
        if key == 'readers' and value not in ('off', 'passive'):
            value = [x.strip() for x in value.split(',')]
        if key in out and out[key] != value:
            raise ValueError(f'--{key} conflicts with the run config')
        out[key] = value
    return out


def contains(path, marker):
    """Streamed byte search of one regular file; a symlink or a missing file holds nothing."""
    path = Path(path)
    if path.is_symlink() or not path.is_file():
        return False
    tail = b''
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1 << 20), b''):
            if marker in tail + block:
                return True
            tail = block[-len(marker):]
    return False


def engine_honours_readers(app):
    """The candidate's bundled engine (Contents/Helpers/modelplan) knows MODELPLAN_VERIFY_READERS."""
    return contains(app / 'Contents' / 'Helpers' / 'modelplan', ENGINE_MARKER)


def engine_delivery(kind, bundle, overrides):
    """How `overrides` reach the engine, or ValueError when they would not (checked before spawn).

    A binary subject receives them itself. An app-zip subject filters its engine's environment
    through WireChildEnvironment.allowedKeys, a set compiled into the main executable as plain
    strings, so a key absent from that executable never reaches the engine.
    """
    if not overrides:
        return None
    if kind != 'app-zip':
        return 'subject-process'
    missing = [key for key in sorted(overrides) if not contains(bundle['exe'], key.encode())]
    if missing:
        raise ValueError(f'candidate app does not forward {", ".join(missing)} to its engine; '
                         'use a build whose launch contract lists them, or drop the restriction')
    if VERIFY_READERS in overrides and not engine_honours_readers(bundle['app']):
        raise ValueError('candidate engine does not honour MODELPLAN_VERIFY_READERS; use readers off|passive')
    return 'app-forwarded'

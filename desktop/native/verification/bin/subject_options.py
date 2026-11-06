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
  subjectEnv: {KEY: value}   extra keys from ALLOWED only, e.g. {"MODELPLAN_HISTORY": "off"}
  backup: "product"          real profile only: product_backup.py around the subject

Every inherited MODELPLAN_* variable is removed from a real-profile environment (names recorded),
so only these reviewed values reach the candidate. Values here are switches and tool IDs, never
secrets, so the run manifest records them in full.
"""
import re

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
    VERIFY_READERS: None,  # a validated comma list of tool IDs
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
        if key not in ALLOWED:
            raise ValueError(f'subjectEnv key not allowed: {key}')
        allowed = ALLOWED[key]
        if allowed is None:
            parse_readers(value)  # same validation as `readers`
            if not isinstance(value, str) or value != ','.join(parse_readers(value)[1]):
                raise ValueError(f'{key} must be a normalised comma list of tool IDs')
        elif value not in allowed:
            raise ValueError(f'subjectEnv {key} must be one of {", ".join(allowed)}')
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
    mode = parse_readers(config.get('readers'))[0]
    if mode == 'list' and config.get('subjectKind', 'binary') != 'app-zip':
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


def engine_honours_readers(app):
    """The candidate's bundled engine (Contents/Helpers/modelplan) knows MODELPLAN_VERIFY_READERS."""
    helper = app / 'Contents' / 'Helpers' / 'modelplan'
    if helper.is_symlink() or not helper.is_file():
        return False
    tail = b''
    with helper.open('rb') as stream:
        for block in iter(lambda: stream.read(1 << 20), b''):
            if ENGINE_MARKER in tail + block:
                return True
            tail = block[-len(ENGINE_MARKER):]
    return False

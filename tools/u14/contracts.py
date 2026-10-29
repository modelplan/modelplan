# SPDX-License-Identifier: MIT
"""Dependency-free validation of the JSON Schema subset used by U14 contracts."""
import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parent


def load_json(path):
    def unique(pairs):
        out = {}
        for key, value in pairs:
            if key in out:
                raise ValueError('duplicate JSON key')
            out[key] = value
        return out
    with Path(path).open(encoding='utf-8') as stream:
        return json.load(stream, object_pairs_hook=unique,
                         parse_constant=lambda _: (_ for _ in ()).throw(ValueError('non-finite JSON')))


def encoded(value):
    return (json.dumps(value, sort_keys=True, indent=2, allow_nan=False) + '\n').encode()


def digest(data):
    return hashlib.sha256(data).hexdigest()


def validate(value, name):
    schema = load_json(ROOT / 'schemas' / name)
    _validate(value, schema, schema, '$')


def _validate(value, schema, root, at):
    # Reject unsupported keywords rather than silently weakening a future contract.
    supported = {'$schema', '$id', '$defs', '$ref', 'title', 'description', 'type',
                 'const', 'enum', 'anyOf', 'properties', 'required', 'additionalProperties',
                 'items', 'minItems', 'maxItems', 'uniqueItems', 'minLength', 'maxLength',
                 'pattern', 'minimum', 'maximum', 'maxProperties', 'propertyNames'}
    if set(schema) - supported:
        raise ValueError('unsupported schema keyword')
    if '$ref' in schema:
        ref = root
        if not schema['$ref'].startswith('#/'):
            raise ValueError('only local schema references are supported')
        for part in schema['$ref'][2:].split('/'):
            ref = ref[part.replace('~1', '/').replace('~0', '~')]
        _validate(value, ref, root, at)
    if 'anyOf' in schema:
        for option in schema['anyOf']:
            try:
                _validate(value, option, root, at)
                break
            except ValueError:
                pass
        else:
            raise ValueError(f'{at}: no matching schema')
    types = {'object': dict, 'array': list, 'string': str, 'integer': int,
             'number': (int, float), 'boolean': bool, 'null': type(None)}
    if 'type' in schema:
        kind = schema['type']
        if not isinstance(value, types[kind]) or (kind in ('integer', 'number') and isinstance(value, bool)):
            raise ValueError(f'{at}: wrong type')
    if 'const' in schema and (type(value) is not type(schema['const']) or value != schema['const']):
        raise ValueError(f'{at}: wrong constant')
    if 'enum' in schema and value not in schema['enum']:
        raise ValueError(f'{at}: unknown enum')
    if isinstance(value, dict):
        if set(schema.get('required', [])) - set(value):
            raise ValueError(f'{at}: missing required field')
        if len(value) > schema.get('maxProperties', 10000):
            raise ValueError(f'{at}: too many fields')
        for key, item in value.items():
            if 'propertyNames' in schema:
                _validate(key, schema['propertyNames'], root, at + '.*')
            rule = schema.get('properties', {}).get(key, schema.get('additionalProperties', True))
            if rule is False:
                raise ValueError(f'{at}: unexpected field')
            if isinstance(rule, dict):
                _validate(item, rule, root, at + '.*')
    if isinstance(value, list):
        if not schema.get('minItems', 0) <= len(value) <= schema.get('maxItems', 10000):
            raise ValueError(f'{at}: wrong array length')
        if schema.get('uniqueItems') and len({json.dumps(x, sort_keys=True) for x in value}) != len(value):
            raise ValueError(f'{at}: duplicate item')
        for item in value:
            if 'items' in schema:
                _validate(item, schema['items'], root, at + '[]')
    if isinstance(value, str):
        if not schema.get('minLength', 0) <= len(value) <= schema.get('maxLength', 100000):
            raise ValueError(f'{at}: wrong string length')
        if 'pattern' in schema and not re.search(schema['pattern'], value):
            raise ValueError(f'{at}: invalid string')
    if isinstance(value, (int, float)) and not isinstance(value, bool):
        if not schema.get('minimum', float('-inf')) <= value <= schema.get('maximum', float('inf')):
            raise ValueError(f'{at}: number out of range')


def new_directory(path):
    """Only a new leaf under a real existing parent; never resolve a symlink for writing."""
    path = Path(path).absolute()
    if '..' in path.parts or path.parent.resolve() != path.parent:
        raise ValueError('output parent must exist and contain no symlinks or traversal')
    if path.exists() or path.is_symlink():
        raise ValueError('output must not already exist')
    path.mkdir(mode=0o700)  # Exclusive creation, including on a concurrent invocation.
    return path


def write_private(path, data):
    with Path(path).open('xb') as stream:
        stream.write(data)
    Path(path).chmod(0o600)

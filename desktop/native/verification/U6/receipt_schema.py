# SPDX-License-Identifier: MIT
"""Stdlib-only validator for the Draft 2020-12 subset used by `schema/verification/`.

The verification suites run on hosted runners without third-party packages, so this
module implements exactly the keywords those schemas use and refuses any other keyword
(a schema cannot silently rely on something this checker ignores). Booleans are never
integers or numbers, and numbers must be finite, matching the Python receipt readers."""
import json
import math
import re
import sys
from pathlib import Path
from urllib.parse import urldefrag, urljoin
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from artifact_paths import is_appledouble

ROOT = Path(__file__).resolve().parents[4] / 'schema' / 'verification'
ANNOTATIONS = frozenset(('$schema', '$id', '$comment', '$defs', 'title', 'description', 'examples', 'default'))
KEYWORDS = frozenset(('$ref', 'type', 'const', 'enum', 'properties', 'required', 'additionalProperties', 'items',
                      'prefixItems', 'minItems', 'maxItems', 'uniqueItems', 'minimum', 'maximum',
                      'exclusiveMinimum', 'exclusiveMaximum', 'minLength', 'maxLength', 'pattern', 'allOf',
                      'anyOf', 'oneOf', 'not', 'if', 'then', 'else'))


class UnsupportedSchema(ValueError):
    """The schema uses a keyword or reference this subset does not implement."""


def _is_type(value, name):
    if name == 'null':
        return value is None
    if name == 'boolean':
        return type(value) is bool
    if name == 'integer':
        return type(value) is int
    if name == 'number':
        return type(value) in (int, float) and math.isfinite(value)
    if name == 'string':
        return isinstance(value, str)
    if name == 'array':
        return isinstance(value, list)
    if name == 'object':
        return isinstance(value, dict)
    raise UnsupportedSchema('type ' + repr(name))


def _equal(a, b):
    """JSON equality: 1 == 1.0 but True != 1."""
    if type(a) is bool or type(b) is bool:
        return type(a) is type(b) and a == b
    if isinstance(a, (int, float)) and isinstance(b, (int, float)):
        return a == b
    if isinstance(a, list) and isinstance(b, list):
        return len(a) == len(b) and all(_equal(x, y) for x, y in zip(a, b))
    if isinstance(a, dict) and isinstance(b, dict):
        return a.keys() == b.keys() and all(_equal(a[k], b[k]) for k in a)
    return type(a) is type(b) and a == b


class Registry:
    """All schema documents under one root, addressed by `$id` (and relative `$ref`)."""

    def __init__(self, root=ROOT):
        self.root = Path(root)
        self.documents = {}
        self.paths = {}
        for path in sorted(self.root.rglob('*.json')):
            if is_appledouble(path):
                continue
            if 'fixtures' in path.relative_to(self.root).parts:
                continue
            document = json.loads(path.read_text())
            identifier = document.get('$id')
            if not isinstance(identifier, str) or identifier in self.documents:
                raise UnsupportedSchema('missing or duplicate $id: ' + str(path))
            self.documents[identifier] = document
            self.paths[path.relative_to(self.root).as_posix()] = identifier

    def id_for(self, relative):
        return self.paths[relative]

    def resolve(self, base, reference):
        target, fragment = urldefrag(urljoin(base, reference))
        if target not in self.documents:
            raise UnsupportedSchema('unknown $ref ' + reference)
        node = self.documents[target]
        if fragment:
            if not fragment.startswith('/'):
                raise UnsupportedSchema('anchor $ref ' + reference)
            for part in fragment[1:].split('/'):
                node = node[part.replace('~1', '/').replace('~0', '~')]
        return target, node

    def errors(self, instance, relative_or_id):
        identifier = self.paths.get(relative_or_id, relative_or_id)
        if identifier not in self.documents:
            raise UnsupportedSchema('unknown schema ' + relative_or_id)
        out = []
        self._check(instance, self.documents[identifier], identifier, '$', out)
        return out

    def valid(self, instance, relative_or_id):
        return not self.errors(instance, relative_or_id)

    def _check(self, value, schema, base, where, out):
        if schema is True:
            return
        if schema is False:
            out.append(where + ': no value allowed')
            return
        if not isinstance(schema, dict):
            raise UnsupportedSchema('schema node at ' + where)
        unknown = set(schema) - KEYWORDS - ANNOTATIONS
        unknown = {k for k in unknown if not k.startswith('x-')}
        if unknown:
            raise UnsupportedSchema('unsupported keywords ' + ', '.join(sorted(unknown)))
        if '$ref' in schema:
            target, node = self.resolve(base, schema['$ref'])
            self._check(value, node, target, where, out)
        if 'type' in schema:
            names = schema['type'] if isinstance(schema['type'], list) else [schema['type']]
            if not any(_is_type(value, n) for n in names):
                out.append('%s: expected %s' % (where, '|'.join(names)))
                return
        if 'const' in schema and not _equal(value, schema['const']):
            out.append('%s: expected const %r' % (where, schema['const']))
        if 'enum' in schema and not any(_equal(value, x) for x in schema['enum']):
            out.append('%s: not in enum' % where)
        if isinstance(value, str):
            if 'minLength' in schema and len(value) < schema['minLength']:
                out.append(where + ': too short')
            if 'maxLength' in schema and len(value) > schema['maxLength']:
                out.append(where + ': too long')
            if 'pattern' in schema and not re.search(schema['pattern'], value):
                out.append(where + ': pattern mismatch')
        if _is_type(value, 'number'):
            if 'minimum' in schema and value < schema['minimum']:
                out.append(where + ': below minimum')
            if 'maximum' in schema and value > schema['maximum']:
                out.append(where + ': above maximum')
            if 'exclusiveMinimum' in schema and value <= schema['exclusiveMinimum']:
                out.append(where + ': not above exclusiveMinimum')
            if 'exclusiveMaximum' in schema and value >= schema['exclusiveMaximum']:
                out.append(where + ': not below exclusiveMaximum')
        if isinstance(value, dict):
            for key in schema.get('required', []):
                if key not in value:
                    out.append('%s: missing %s' % (where, key))
            properties = schema.get('properties', {})
            for key, item in value.items():
                if key in properties:
                    self._check(item, properties[key], base, where + '.' + key, out)
                elif 'additionalProperties' in schema:
                    self._check(item, schema['additionalProperties'], base, where + '.' + key, out)
        if isinstance(value, list):
            if 'minItems' in schema and len(value) < schema['minItems']:
                out.append(where + ': too few items')
            if 'maxItems' in schema and len(value) > schema['maxItems']:
                out.append(where + ': too many items')
            if schema.get('uniqueItems') and any(_equal(value[i], value[j]) for i in range(len(value))
                                                 for j in range(i + 1, len(value))):
                out.append(where + ': duplicate items')
            prefix = schema.get('prefixItems', [])
            for index, item in enumerate(value):
                if index < len(prefix):
                    self._check(item, prefix[index], base, '%s[%d]' % (where, index), out)
                elif 'items' in schema:
                    self._check(item, schema['items'], base, '%s[%d]' % (where, index), out)
        for sub in schema.get('allOf', []):
            self._check(value, sub, base, where, out)
        if 'anyOf' in schema and not any(self._passes(value, s, base) for s in schema['anyOf']):
            out.append(where + ': no anyOf branch matches')
        if 'oneOf' in schema and sum(self._passes(value, s, base) for s in schema['oneOf']) != 1:
            out.append(where + ': not exactly one oneOf branch matches')
        if 'not' in schema and self._passes(value, schema['not'], base):
            out.append(where + ': matches a forbidden schema')
        if 'if' in schema:
            branch = schema.get('then') if self._passes(value, schema['if'], base) else schema.get('else')
            if branch is not None:
                self._check(value, branch, base, where, out)

    def _passes(self, value, schema, base):
        out = []
        self._check(value, schema, base, '$', out)
        return not out


_DEFAULT = []


def registry():
    """The shared registry over `schema/verification/` (loaded once)."""
    if not _DEFAULT:
        _DEFAULT.append(Registry())
    return _DEFAULT[0]


def native_kinds(reg=None):
    """{kind: relative schema path} declared by the native envelope (`x-kinds`)."""
    reg = reg or registry()
    return dict(reg.documents[reg.id_for('native-row.json')]['x-kinds'])


def native_kind(row):
    """The row's kind in the App envelope: `event`, or `kind` for the flat refresh rows (C2.6 F)."""
    return row.get('event', row.get('kind')) if isinstance(row, dict) else None


def native_errors(row, reg=None):
    """Envelope errors, then the kind schema's errors. A kind outside `x-kinds` is checked by the envelope only."""
    reg = reg or registry()
    out = reg.errors(row, 'native-row.json')
    if out:
        return out
    relative = native_kinds(reg).get(native_kind(row))
    return [] if relative is None else reg.errors(row, relative)


def flat_native(row):
    """A schema-valid envelope row as one flat mapping {envelope, kind, **checks} (refresh rows are already flat)."""
    if 'event' not in row:
        return dict(row)
    out = {k: v for k, v in row.items() if k not in ('event', 'timestamp', 'checks')}
    out.update(row['checks'], kind=row['event'])
    return out

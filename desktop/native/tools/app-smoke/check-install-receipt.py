#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Prepare a text-only synthetic G4-11 receipt; never inspect real login items."""
import argparse
import json
import os
from pathlib import Path, PurePosixPath
import re
import sys
import tempfile

PATH = re.compile(r'/(?:synthetic|private/var/folders/synthetic)(?:/[A-Za-z0-9._-]+)+\.app\Z')
FIELDS = {'profile', 'quarantine', 'before', 'after', 'loginItemPath', 'postReboot'}


def safe_path(value, *, optional=False):
    if value is None and optional: return None
    if not isinstance(value, str) or not PATH.fullmatch(value) or any(p in ('.', '..') for p in PurePosixPath(value).parts):
        raise ValueError('invalid synthetic bundle path')
    return value


def make_receipt(facts):
    if not isinstance(facts, dict) or set(facts) != FIELDS or facts['profile'] != 'synthetic':
        raise ValueError('invalid synthetic observations')
    quarantine = facts['quarantine']
    if quarantine is not None and type(quarantine) is not bool: raise ValueError('invalid quarantine')
    before = safe_path(facts['before']); after = safe_path(facts['after'])
    login = safe_path(facts['loginItemPath'], optional=True)
    if facts['postReboot'] not in ('started', 'not-started', 'unknown'): raise ValueError('invalid reboot observation')
    return {'schemaVersion': 1, **facts, 'before': before, 'after': after, 'loginItemPath': login,
            'translocatedBefore': 'AppTranslocation' in PurePosixPath(before).parts,
            'translocatedAfter': 'AppTranslocation' in PurePosixPath(after).parts,
            'outcome': 'NOT_RUN', 'scope': 'synthetic observations only; not installation or reboot evidence'}


def synthetic_fixture():
    with tempfile.TemporaryDirectory(prefix='modelplan-install-synthetic-') as directory:
        bundle = Path(directory) / 'ModelPlan.app'; bundle.mkdir()
        try: quarantine = 'com.apple.quarantine' in os.listxattr(bundle)
        except (OSError, AttributeError): quarantine = None
        return make_receipt({'profile': 'synthetic', 'quarantine': quarantine,
            'before': '/private/var/folders/synthetic/AppTranslocation/A/d/ModelPlan.app',
            'after': '/synthetic/Applications/ModelPlan.app', 'loginItemPath': None, 'postReboot': 'unknown'})


def unique(pairs):
    result = {}
    for key, value in pairs:
        if key in result: raise ValueError('duplicate JSON field')
        result[key] = value
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--fixture', action='store_true', help='produce a synthetic CI fixture')
    args = parser.parse_args()
    try:
        if args.fixture: result = synthetic_fixture()
        else:
            raw = sys.stdin.buffer.read(65537)
            if len(raw) > 65536: raise ValueError('oversized input')
            result = make_receipt(json.loads(raw, object_pairs_hook=unique))
    except (ValueError, TypeError, UnicodeError):
        print('install receipt: invalid synthetic input', file=sys.stderr); return 1
    print(json.dumps(result, sort_keys=True))
    return 0


if __name__ == '__main__': sys.exit(main())

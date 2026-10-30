#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Compare final App bundles against one trusted, immutable helper artifact pin.

This validates packaging bytes only, not signing, Keychain ACLs or A14.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re

HELPER = Path('Contents/Helpers/modelplan-credential-agent')
MANIFEST = Path('Contents/Resources/credential-agent.json')
FIELDS = {'schemaVersion', 'sha256', 'bytes', 'inputSHA256', 'bundleIdentifier'}

class CheckFailure(Exception):
    pass

def validate_pin(pin):
    if not isinstance(pin, dict) or set(pin) != FIELDS:
        raise CheckFailure('invalid-pin-fields')
    if type(pin['schemaVersion']) is not int or pin['schemaVersion'] != 1:
        raise CheckFailure('unsupported-pin-version')
    if type(pin['bytes']) is not int or not 0 < pin['bytes'] <= 32 * 1024 * 1024:
        raise CheckFailure('invalid-helper-size')
    if pin['bundleIdentifier'] != 'ai.modelplan.credential-agent':
        raise CheckFailure('wrong-helper-identifier')
    for key in ['sha256', 'inputSHA256']:
        if not isinstance(pin[key], str) or re.fullmatch('[0-9a-f]{64}', pin[key]) is None:
            raise CheckFailure('invalid-pin-digest')

def regular_member(app, relative):
    if app.suffix != '.app' or not app.is_dir() or app.is_symlink():
        raise CheckFailure('invalid-app-root')
    member = app
    for component in relative.parts:
        member = member / component
        if member.is_symlink():
            raise CheckFailure('symlink-member')
    if not member.is_file():
        raise CheckFailure('missing-member')
    return member

def check_pair(first, second, pin):
    validate_pin(pin)
    for app in [Path(first), Path(second)]:
        descriptor = regular_member(app, MANIFEST)
        if descriptor.stat().st_size > 4096:
            raise CheckFailure('oversized-bundle-manifest')
        actual_pin = json.loads(descriptor.read_text())
        validate_pin(actual_pin)
        if actual_pin != pin:
            raise CheckFailure('bundle-pin-mismatch')
        helper = regular_member(app, HELPER)
        if helper.stat().st_size != pin['bytes']:
            raise CheckFailure('helper-size-mismatch')
        digest = hashlib.sha256()
        with helper.open('rb') as stream:
            for block in iter(lambda: stream.read(1024 * 1024), b''):
                digest.update(block)
        if digest.hexdigest() != pin['sha256']:
            raise CheckFailure('helper-hash-mismatch')
    return {'outcome': 'pass', 'helperSHA256': pin['sha256'],
            'helperBytes': pin['bytes'], 'agentInputSHA256': pin['inputSHA256'],
            'scope': 'packaging byte identity only; not signing/Keychain/A14 proof'}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--pin', type=Path, required=True, help='Trusted helper artifact pin, independent of the two Apps')
    parser.add_argument('first', type=Path)
    parser.add_argument('second', type=Path)
    args = parser.parse_args()
    try:
        if args.pin.stat().st_size > 4096:
            raise CheckFailure('oversized-trusted-pin')
        result = check_pair(args.first, args.second, json.loads(args.pin.read_text()))
    except (CheckFailure, OSError, ValueError) as error:
        category = str(error) if isinstance(error, CheckFailure) else type(error).__name__
        print(json.dumps({'outcome': 'fail', 'category': category}))
        return 1
    print(json.dumps(result))
    return 0

if __name__ == '__main__':
    raise SystemExit(main())

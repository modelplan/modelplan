#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Validate a synthetic G4-14 receipt from stdin; never inspect display or user state."""
import argparse
import json
import math
import re
import sys

LABEL = re.compile(r'[a-z][a-z0-9-]{0,31}\Z')
SHA = re.compile(r'[a-f0-9]{64}\Z')
KINDS = ('sleep', 'wake', 'unplug', 'replug')


def validate(receipt, approved):
    if not approved or any(not isinstance(label, str) or not LABEL.fullmatch(label) for label in approved):
        raise ValueError('invalid approved display labels')
    if not isinstance(receipt, dict) or set(receipt) != {'schemaVersion', 'profile', 'events'} or type(receipt['schemaVersion']) is not int or receipt['schemaVersion'] != 1 or receipt['profile'] != 'synthetic':
        raise ValueError('invalid synthetic receipt')
    events = receipt['events']
    if not isinstance(events, list) or len(events) != len(KINDS):
        raise ValueError('incomplete event sequence')
    prior = -1.0; baseline = None
    for expected, event in zip(KINDS, events):
        if not isinstance(event, dict) or set(event) != {'kind', 'elapsedSeconds', 'display', 'preferenceSHA256'} or event['kind'] != expected:
            raise ValueError('invalid event')
        elapsed = event['elapsedSeconds']
        if type(elapsed) not in (int, float) or not math.isfinite(elapsed) or not 0 <= elapsed <= 86400 or elapsed <= prior:
            raise ValueError('invalid event time')
        prior = elapsed
        if not isinstance(event['display'], str) or event['display'] not in approved:
            raise ValueError('unapproved display')
        digest = event['preferenceSHA256']
        if not isinstance(digest, str) or not SHA.fullmatch(digest):
            raise ValueError('invalid preference digest')
        if baseline is None: baseline = digest
        elif digest != baseline: raise ValueError('preference changed')
    return True


def unique(pairs):
    result = {}
    for key, value in pairs:
        if key in result: raise ValueError('duplicate JSON field')
        result[key] = value
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--approved-display', action='append', required=True)
    args = parser.parse_args()
    try:
        raw = sys.stdin.buffer.read(65537)
        if len(raw) > 65536: raise ValueError('oversized receipt')
        validate(json.loads(raw, object_pairs_hook=unique), set(args.approved_display))
    except (ValueError, TypeError, UnicodeError):
        print('G4-14 receipt: FAIL', file=sys.stderr)
        return 1
    print('G4-14 synthetic receipt: valid; device outcome NOT RUN')
    return 0


if __name__ == '__main__': sys.exit(main())

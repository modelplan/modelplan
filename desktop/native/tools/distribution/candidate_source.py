#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Admit an exact same-repository PR revision before and after building."""
import json
import re
import sys


def resolve(pr, expected):
    if (not re.fullmatch(r'[0-9a-f]{40}', expected) or pr.get('state') != 'open' or
        (pr.get('base') or {}).get('ref') != 'main' or
        ((pr.get('head') or {}).get('repo') or {}).get('full_name') != 'modelplan/modelplan' or
        (pr.get('head') or {}).get('sha') != expected):
        raise ValueError('PR source does not match expected head')
    return expected


if __name__ == '__main__':
    print(resolve(json.load(sys.stdin), sys.argv[1]))

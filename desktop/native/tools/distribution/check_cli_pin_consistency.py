#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Fail closed if a candidate's CLI tree differs from its reviewed pin tag."""
import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

PIN = 'desktop/native/consent-cli-pin.json'


def git(repo, *args):
    return subprocess.run(['git', '-C', str(repo), *args], stdout=subprocess.PIPE,
                          stderr=subprocess.PIPE, text=True, check=False)


def requires_check(repo, event):
    pr = event.get('pull_request')
    if not isinstance(pr, dict):
        raise ValueError('missing pull request context')
    base = pr.get('base', {}).get('sha', '')
    if not re.fullmatch(r'[0-9a-f]{40}', base):
        raise ValueError('missing pull request base commit')
    labels = {x.get('name') for x in pr.get('labels', []) if isinstance(x, dict)}
    branch = pr.get('head', {}).get('ref', '')
    title = pr.get('title', '').strip().lower()
    candidate = ('release-candidate' in labels or branch.startswith(('candidate/', 'release-candidate/'))
                 or title.startswith(('release candidate:', 'release-candidate:')))
    diff = git(repo, 'diff', '--quiet', base + '...HEAD', '--', PIN)
    if diff.returncode not in (0, 1):
        raise ValueError('cannot compare pull request pin against base')
    return candidate or diff.returncode == 1


def assert_pin_matches(repo):
    try:
        version = json.loads((Path(repo) / PIN).read_text())['version']
    except (OSError, ValueError, KeyError, TypeError) as error:
        raise ValueError('invalid native CLI pin') from error
    if not isinstance(version, str) or not re.fullmatch(r'(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)', version):
        raise ValueError('invalid native CLI pin version')
    tag = 'refs/tags/v' + version
    if git(repo, 'rev-parse', '--verify', tag + '^{commit}').returncode:
        raise ValueError('pinned CLI release tag is unavailable')
    diff = git(repo, 'diff', '--quiet', tag, 'HEAD', '--', 'cli/')
    if diff.returncode == 1:
        raise ValueError('candidate cli/ differs from pinned CLI tag v' + version)
    if diff.returncode:
        raise ValueError('cannot compare candidate CLI with pinned tag')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--repo', type=Path, default=Path(__file__).resolve().parents[4])
    parser.add_argument('--event', type=Path)
    parser.add_argument('--force', action='store_true')
    args = parser.parse_args()
    try:
        if not args.force and args.event is None:
            raise ValueError('missing pull request event')
        if not args.force and not requires_check(args.repo, json.loads(args.event.read_text())):
            print('not a release candidate or native CLI pin change')
            return 0
        assert_pin_matches(args.repo)
        print('candidate CLI tree matches pinned tag')
        return 0
    except (ValueError, OSError, json.JSONDecodeError) as error:
        print('CLI pin consistency: ' + str(error), file=sys.stderr)
        return 1


if __name__ == '__main__':
    raise SystemExit(main())

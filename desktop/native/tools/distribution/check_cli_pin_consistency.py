#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Fail closed if a candidate's CLI tree or bundled helper differs from its reviewed pin."""
import argparse
import hashlib
import json
import os
import plistlib
import re
import subprocess
import sys
import tempfile
from pathlib import Path

PIN = 'desktop/native/consent-cli-pin.json'
MINIMUM = 'desktop/native/ModelPlanAppIntegration/Sources/ModelPlanAppIntegration/EngineRowsEntry.swift'
VERSION = r'(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)'


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


def assert_pin_matches(repo, pin=None):
    try:
        version = json.loads(Path(pin or Path(repo) / PIN).read_text())['version']
    except (OSError, ValueError, KeyError, TypeError) as error:
        raise ValueError('invalid native CLI pin') from error
    if not isinstance(version, str) or not re.fullmatch(VERSION, version):
        raise ValueError('invalid native CLI pin version')
    try:
        source = (Path(repo) / MINIMUM).read_text()
    except OSError as error:
        raise ValueError('missing app minimum CLI version') from error
    matches = re.findall(r'\bminimumAppServerVersion\s*=\s*"(' + VERSION + r')"', source)
    if len(matches) != 1:
        raise ValueError('invalid app minimum CLI version')
    minimum = matches[0][0]
    if tuple(map(int, version.split('.'))) < tuple(map(int, minimum.split('.'))):
        raise ValueError('pinned CLI version is older than the app minimum ' + minimum)
    tag = 'refs/tags/v' + version
    if git(repo, 'rev-parse', '--verify', tag + '^{commit}').returncode:
        raise ValueError('pinned CLI release tag is unavailable')
    diff = git(repo, 'diff', '--quiet', tag, 'HEAD', '--', 'cli/')
    if diff.returncode == 1:
        raise ValueError('candidate cli/ differs from pinned CLI tag v' + version)
    if diff.returncode:
        raise ValueError('cannot compare candidate CLI with pinned tag')


HELPER = Path('Contents/Helpers/modelplan')
HELPER_HASH = Path('Contents/Resources/modelplan.sha256')
MAX_HELPER = 128 * 1024 * 1024


def load_pin(path):
    try:
        pin = json.loads(Path(path).read_text())
        version = pin['version']
    except (OSError, ValueError, KeyError, TypeError) as error:
        raise ValueError('invalid helper pin') from error
    if not isinstance(version, str) or not re.fullmatch(VERSION, version):
        raise ValueError('invalid helper pin version')
    return pin


def run_helper_version(helper):
    """Ask the bundled helper itself; plist and resource records alone can be stale."""
    with tempfile.TemporaryDirectory(prefix='cli-pin-helper-') as home:
        environment = {'HOME': home, 'CFFIXED_USER_HOME': home, 'MODELPLAN_CACHE': home + '/cache',
                       'XDG_CONFIG_HOME': home + '/config', 'PATH': '/usr/bin:/bin', 'NO_COLOR': '1',
                       'TMPDIR': home + '/'}
        try:
            result = subprocess.run([str(helper), 'version'], stdin=subprocess.DEVNULL,
                                    stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                                    env=environment, timeout=20, check=False)
        except (OSError, subprocess.TimeoutExpired) as error:
            raise ValueError('bundled helper could not report its version') from error
    if result.returncode:
        raise ValueError('bundled helper could not report its version')
    return result.stdout.decode('utf-8', 'replace')


def assert_helper_matches(app, pin_path, *, require_release_identity=False, version_of=run_helper_version):
    """Refuse an App whose Contents/Helpers/modelplan is not the declared pinned release."""
    pin = load_pin(pin_path)
    version = pin['version']
    app = Path(app)
    helper = app / HELPER
    if helper.is_symlink() or not helper.is_file() or not 0 < helper.stat().st_size <= MAX_HELPER:
        raise ValueError('bundled helper is missing, linked or oversized')
    digest = hashlib.sha256(helper.read_bytes()).hexdigest()
    record = app / HELPER_HASH
    if record.is_symlink() or not record.is_file() or record.read_text().strip() != digest:
        raise ValueError('bundled helper does not match its recorded hash')
    info_path = app / 'Contents/Info.plist'
    try:
        if info_path.is_symlink() or info_path.stat().st_size > 65536:
            raise ValueError('invalid bundle metadata')
        info = plistlib.loads(info_path.read_bytes())
    except (OSError, plistlib.InvalidFileException) as error:
        raise ValueError('invalid bundle metadata') from error
    if not isinstance(info, dict) or info.get('ModelPlanBundledHelperSHA256') != digest:
        raise ValueError('bundled helper does not match the App metadata hash')
    declared = info.get('ModelPlanHelperVersion')
    sources = info.get('ModelPlanSourceHelperSHA256ByArchitecture')
    if require_release_identity and (declared is None or sources is None):
        raise ValueError('candidate App lacks a release helper identity')
    if declared is not None and declared != version:
        raise ValueError(f'App declares helper {declared!r}, pin is {version}')
    if sources is not None and sources != pin.get('sourceSHA256ByArchitecture'):
        raise ValueError('App helper source hashes differ from the pin')
    reported = version_of(helper)
    if reported != f'modelplan {version}\n':
        shown = reported.strip()[:80] or 'nothing'
        raise ValueError(f'bundled helper reports {shown!r}, pin is modelplan {version}')
    return version


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--repo', type=Path, default=Path(__file__).resolve().parents[4])
    parser.add_argument('--event', type=Path)
    parser.add_argument('--force', action='store_true')
    parser.add_argument('--app', type=Path, help='packaged App whose Contents/Helpers/modelplan must be the pin')
    parser.add_argument('--pin', type=Path, help='helper pin for --app (default: the native consent pin)')
    parser.add_argument('--require-release-identity', action='store_true',
                        help='with --app: require the release helper version/source records in Info.plist')
    args = parser.parse_args()
    try:
        if args.app is not None:
            version = assert_helper_matches(args.app, args.pin or args.repo / PIN,
                                            require_release_identity=args.require_release_identity)
            print(f'bundled helper is the pinned modelplan {version}')
            if not args.force:
                return 0
        elif args.require_release_identity:
            raise ValueError('--require-release-identity needs --app')
        if not args.force and args.event is None:
            raise ValueError('missing pull request event')
        if not args.force and not requires_check(args.repo, json.loads(args.event.read_text())):
            print('not a release candidate or native CLI pin change')
            return 0
        assert_pin_matches(args.repo, args.pin)
        print('candidate CLI tree matches pinned tag')
        return 0
    except (ValueError, OSError, json.JSONDecodeError) as error:
        print('CLI pin consistency: ' + str(error), file=sys.stderr)
        return 1


if __name__ == '__main__':
    raise SystemExit(main())

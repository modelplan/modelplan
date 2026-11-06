#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Verify all bundled Mach-O files, except the exact independently pinned helper."""
import argparse
import hashlib
from pathlib import Path
import plistlib
import re
import subprocess

MAGIC = {bytes.fromhex(value) for value in (
    'feedface', 'cefaedfe', 'feedfacf', 'cffaedfe',
    'cafebabe', 'bebafeca', 'cafebabf', 'bfbafeca')}
HELPER = Path('Contents/Helpers/modelplan-credential-agent')


def inspect(path):
    return subprocess.check_output(['xcrun', 'lipo', '-archs', str(path)], text=True, timeout=30).split()


def validate(app, main, cli, approved_sha, inspector=inspect):
    app, main, cli = Path(app), Path(main), Path(cli)
    if app.is_symlink() or not app.is_dir() or not re.fullmatch('[0-9a-f]{64}', approved_sha):
        raise ValueError('invalid app or independent helper pin')
    info = app / 'Contents/Info.plist'
    if info.is_symlink() or not info.is_file() or info.stat().st_size > 65536:
        raise ValueError('invalid bundle metadata')
    if 'SUFeedURL' in plistlib.loads(info.read_bytes()):
        raise ValueError('update feed is not allowed in v1')
    if any(part.lower() == 'sparkle.framework' for path in app.rglob('*') for part in path.relative_to(app).parts):
        raise ValueError('Sparkle framework is not allowed in v1')
    helper = app / HELPER
    if helper.is_symlink() or not helper.is_file() or not 0 < helper.stat().st_size <= 32 * 1024 * 1024:
        raise ValueError('invalid pinned helper')
    if hashlib.sha256(helper.read_bytes()).hexdigest() != approved_sha:
        raise ValueError('credential helper pin mismatch')
    if 'arm64' not in inspector(helper):
        raise ValueError('pinned helper has no arm64 slice')
    required = {main, cli}
    for path in required:
        if path.is_symlink() or not path.is_file() or not path.resolve().is_relative_to(app.resolve()):
            raise ValueError('missing or linked app executable')
        if inspector(path) != ['arm64']:
            raise ValueError('app executable must contain exactly arm64')
    for path in app.rglob('*'):
        if path.is_symlink():
            try:
                target = path.resolve(strict=True)
            except OSError:
                raise ValueError('invalid bundle link') from None
            if not target.is_relative_to(app.resolve()):
                raise ValueError('external bundle link')
            continue
        if not path.is_file() or path == helper or path in required:
            continue
        with path.open('rb') as stream:
            magic = stream.read(4)
        if magic in MAGIC and inspector(path) != ['arm64']:
            raise ValueError('bundled executable must contain exactly arm64')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--app', required=True, type=Path)
    parser.add_argument('--main', required=True, type=Path)
    parser.add_argument('--approved-helper-sha256', required=True)
    args = parser.parse_args()
    validate(args.app, args.main, args.app / 'Contents/Helpers/modelplan', args.approved_helper_sha256)

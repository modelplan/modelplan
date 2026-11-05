#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Embed an already reviewed helper artifact; never compile or re-sign it."""
import argparse
import json
import subprocess
from pathlib import Path
from build_fixed_helper import embed
from check_embedded_agent import require_expected_sha

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--artifact', type=Path, required=True)
    parser.add_argument('--expected-sha256', help='Approved helper hash, independent of artifact directory')
    parser.add_argument('--universal', action='store_true', help='Require exactly arm64+x86_64 and a valid existing signature')
    parser.add_argument('app', type=Path)
    args = parser.parse_args()
    manifest = args.artifact / 'credential-agent.json'
    if manifest.is_symlink() or manifest.stat().st_size > 4096:
        raise SystemExit('invalid-artifact-manifest')
    pin = json.loads(manifest.read_text()); require_expected_sha(pin, args.expected_sha256)
    binary = args.artifact / 'modelplan-credential-agent'
    if binary.is_symlink():
        raise SystemExit('symlink-artifact')
    if args.universal:
        architectures = subprocess.check_output(['xcrun', 'lipo', '-archs', str(binary)], text=True).split()
        if len(architectures) != 2 or set(architectures) != {'arm64', 'x86_64'}:
            raise SystemExit('not-a-universal-helper')
        subprocess.run(['/usr/bin/codesign', '--verify', '--strict', str(binary)], check=True, timeout=30)
    embed(args.app, binary, pin)
    print('helper embedded; run final pair checker after all app packaging steps')

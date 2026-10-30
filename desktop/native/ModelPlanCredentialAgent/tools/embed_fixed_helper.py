#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Embed an already reviewed helper artifact; never compile or re-sign it."""
import argparse
import json
from pathlib import Path
from build_fixed_helper import embed
from check_embedded_agent import validate_pin

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--artifact', type=Path, required=True)
    parser.add_argument('app', type=Path)
    args = parser.parse_args()
    manifest = args.artifact / 'credential-agent.json'
    if manifest.is_symlink() or manifest.stat().st_size > 4096:
        raise SystemExit('invalid-artifact-manifest')
    pin = json.loads(manifest.read_text()); validate_pin(pin)
    binary = args.artifact / 'modelplan-credential-agent'
    if binary.is_symlink():
        raise SystemExit('symlink-artifact')
    embed(args.app, binary, pin)
    print('helper embedded; run final pair checker after all app packaging steps')

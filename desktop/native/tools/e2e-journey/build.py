#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Build both real CLI slices from this checkout and package an explicitly debug-only CI app."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tarfile

ROOT = Path(__file__).resolve().parents[4]


def build(output):
    output.mkdir(parents=True, exist_ok=False)
    source = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    version = json.loads((ROOT / 'codex/cli-pin.json').read_text())['version'] + '+e2e.' + source[:12]
    archives = output / 'archives'; archives.mkdir()
    checksums, inputs = [], {}
    for architecture, archive_arch in [('arm64', 'arm64'), ('amd64', 'amd64')]:
        folder = output / ('modelplan_darwin_' + archive_arch); folder.mkdir()
        environment = {**os.environ, 'GOOS': 'darwin', 'GOARCH': architecture, 'CGO_ENABLED': '0'}
        subprocess.run(['go', 'build', '-trimpath', '-ldflags', '-X main.version=' + version,
                        '-o', str(folder / 'modelplan'), './cmd/modelplan'], cwd=ROOT / 'cli', env=environment, check=True)
        shutil.copyfile(ROOT / 'cli/THIRD-PARTY-NOTICES.md', folder / 'THIRD-PARTY-NOTICES.md')
        archive = archives / (folder.name + '.tar.gz')
        with tarfile.open(archive, 'w:gz') as writer:
            writer.add(folder, arcname=folder.name)
        checksums.append(hashlib.sha256(archive.read_bytes()).hexdigest() + '  ' + archive.name)
        inputs[architecture] = hashlib.sha256((folder / 'modelplan').read_bytes()).hexdigest()
    (archives / 'checksums.txt').write_text('\n'.join(checksums) + '\n')
    subprocess.run(['go', 'build', '-o', str(output / 'codex'), str(Path(__file__).with_name('fake-codex.go'))],
                   cwd=ROOT / 'cli', env={**os.environ, 'GOOS': 'darwin', 'GOARCH': 'arm64', 'CGO_ENABLED': '0'}, check=True)
    subprocess.run(['bash', str(ROOT / 'desktop/native/tools/package-neutral.sh'), str(archives),
                    str(output / 'neutral'), '--e2e-journey'], cwd=ROOT, check=True)
    (output / 'build-receipt.json').write_text(json.dumps({'sourceCommit': source, 'cliVersion': version,
        'inputHelperSHA256': inputs, 'configuration': 'debug', 'identity': 'unverified'}, indent=2) + '\n')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('output', type=Path)
    build(parser.parse_args().output.resolve())

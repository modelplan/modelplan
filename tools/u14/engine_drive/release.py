# SPDX-License-Identifier: MIT
"""Fetch/verify ordinary public release artifacts; never build or patch a subject."""
import argparse
import hashlib
import io
import json
from pathlib import Path
import platform
import re
import tarfile
import urllib.request

BASE = 'https://github.com/modelplan/modelplan/releases/download/'


def sha(data):
    return hashlib.sha256(data).hexdigest()


def regular(path, limit=100 << 20):
    path = Path(path)
    if path.is_symlink() or not path.is_file() or path.stat().st_size > limit:
        raise ValueError('invalid-artifact-file')
    return path.read_bytes()


def asset_name():
    system = {'Darwin': 'darwin', 'Linux': 'linux'}.get(platform.system())
    arch = {'arm64': 'arm64', 'aarch64': 'arm64', 'x86_64': 'amd64'}.get(platform.machine())
    if not system or not arch:
        raise ValueError('unsupported-release-platform')
    return f'modelplan_{system}_{arch}.tar.gz'


def binary_from_archive(data):
    with tarfile.open(fileobj=io.BytesIO(data), mode='r:gz') as archive:
        entries = archive.getmembers()
        matches = [m for m in entries if m.isfile() and Path(m.name).name == 'modelplan']
        if len(entries) > 100 or len(matches) != 1 or matches[0].size > 100 << 20:
            raise ValueError('invalid-release-archive')
        # Read one regular member, never extract paths, links, or executable helpers.
        return archive.extractfile(matches[0]).read()


def verify(record_path):
    path = Path(record_path).resolve()
    record = json.loads(regular(path, 16384))
    tag, commit, asset = record['tag'], record['commit'], record['asset']
    if (not re.fullmatch(r'v[0-9]+\.[0-9]+\.[0-9]+', tag)
            or not re.fullmatch(r'[a-f0-9]{40}', commit) or asset != asset_name()):
        raise ValueError('invalid-release-identity')
    archive = regular(path.parent / asset)
    checksums = regular(path.parent / 'checksums.txt', 65536)
    lines = [line.split() for line in checksums.decode('ascii').splitlines()]
    matches = [parts[0] for parts in lines if len(parts) == 2 and parts[1].lstrip('*') == asset]
    if matches != [sha(archive)] or record['archiveSHA256'] != sha(archive):
        raise ValueError('release-checksum-mismatch')
    binary = binary_from_archive(archive)
    if record['binarySHA256'] != sha(binary):
        raise ValueError('release-binary-mismatch')
    executable = path.parent / 'modelplan'
    if regular(executable) != binary:
        raise ValueError('release-executable-mismatch')
    return executable, dict(tag=tag, commit=commit, asset=asset,
                           archiveSHA256=sha(archive), binarySHA256=sha(binary),
                           checksumsSHA256=sha(checksums), url=BASE + tag + '/' + asset)


def resolve_commit(tag):
    url = 'https://api.github.com/repos/modelplan/modelplan/git/ref/tags/' + tag
    with urllib.request.urlopen(url, timeout=30) as response:
        obj = json.loads(response.read(65536))['object']
    for _ in range(4):
        if obj['type'] == 'commit' and re.fullmatch(r'[a-f0-9]{40}', obj['sha']):
            return obj['sha']
        if obj['type'] != 'tag' or not re.fullmatch(r'[a-f0-9]{40}', obj['sha']):
            break
        url = 'https://api.github.com/repos/modelplan/modelplan/git/tags/' + obj['sha']
        with urllib.request.urlopen(url, timeout=30) as response:
            obj = json.loads(response.read(65536))['object']
    raise ValueError('invalid-release-tag')


def fetch(tag, commit, output):
    if not re.fullmatch(r'v[0-9]+\.[0-9]+\.[0-9]+', tag) or not re.fullmatch(r'[a-f0-9]{40}', commit):
        raise ValueError('invalid-release-identity')
    if resolve_commit(tag) != commit:
        raise ValueError('release-tag-commit-mismatch')
    output = Path(output)
    output.mkdir(mode=0o700)  # exclusive: never overwrite another task's artifact
    asset = asset_name()
    for name, limit in [('checksums.txt', 65536), (asset, 100 << 20)]:
        with urllib.request.urlopen(BASE + tag + '/' + name, timeout=60) as response:
            data = response.read(limit + 1)
        if len(data) > limit:
            raise ValueError('release-download-bound')
        (output / name).write_bytes(data)
    archive = (output / asset).read_bytes()
    binary = binary_from_archive(archive)
    (output / 'modelplan').write_bytes(binary)
    (output / 'modelplan').chmod(0o700)
    record = dict(tag=tag, commit=commit, asset=asset, archiveSHA256=sha(archive), binarySHA256=sha(binary))
    (output / 'release.json').write_text(json.dumps(record, indent=2) + '\n')
    verify(output / 'release.json')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--tag', required=True)
    parser.add_argument('--commit', required=True, help='full commit resolved from the public release tag')
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    fetch(args.tag, args.commit, args.output)

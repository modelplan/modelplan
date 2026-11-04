#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Fetch one independently approved main-run credential artifact; never build it."""
import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import stat
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[4]
DEFAULT_PIN = ROOT / 'desktop/native/credential-agent-artifact-pin.json'
REPOSITORY = 'modelplan/modelplan'
MAX_ARCHIVE = 64 * 1024 * 1024
MEMBERS = {'modelplan-credential-agent': 32 * 1024 * 1024,
           'credential-agent.json': 4096, 'proof.json': 1024 * 1024,
           'SHA256SUMS': 4096, 'LICENSE.txt': 64 * 1024}


class FetchFailure(ValueError):
    pass


def unique_fields(pairs):
    value = {}
    for key, item in pairs:
        if key in value:
            raise FetchFailure('duplicate-approved-pin-field')
        value[key] = item
    return value


def approval(path):
    try:
        if path.is_symlink() or path.stat().st_size > 4096:
            raise FetchFailure('invalid-approved-pin-file')
        value = json.loads(path.read_bytes(), object_pairs_hook=unique_fields)
    except (OSError, ValueError) as error:
        if isinstance(error, FetchFailure):
            raise
        raise FetchFailure('approved-triple-missing-or-invalid') from None
    if not isinstance(value, dict) or set(value) != {'runID', 'artifactName', 'sha256'}:
        raise FetchFailure('invalid-approved-triple-fields')
    if not isinstance(value['runID'], str) or re.fullmatch(r'[1-9][0-9]{0,19}', value['runID']) is None:
        raise FetchFailure('invalid-approved-run-id')
    if not isinstance(value['artifactName'], str) or re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9._-]{0,127}', value['artifactName']) is None:
        raise FetchFailure('invalid-approved-artifact-name')
    if not isinstance(value['sha256'], str) or re.fullmatch(r'[0-9a-f]{64}', value['sha256']) is None:
        raise FetchFailure('invalid-approved-helper-digest')
    return value


class GitHub:
    def api(self, route):
        try:
            result = subprocess.run(['gh', 'api', '--hostname', 'github.com', route], check=True, capture_output=True, timeout=60)
            return json.loads(result.stdout)
        except (OSError, ValueError, subprocess.SubprocessError):
            raise FetchFailure('github-metadata-request-failed') from None

    def download(self, route, destination):
        try:
            with destination.open('xb') as file:
                subprocess.run(['gh', 'api', '--hostname', 'github.com', route], check=True, stdout=file, stderr=subprocess.PIPE, timeout=120)
        except (OSError, subprocess.SubprocessError):
            raise FetchFailure('github-artifact-download-failed') from None


def unpack(archive, destination):
    if archive.stat().st_size > MAX_ARCHIVE:
        raise FetchFailure('artifact-archive-too-large')
    with zipfile.ZipFile(archive) as file:
        entries = file.infolist()
        if len(entries) > 4096 or sum(x.file_size for x in entries) > MAX_ARCHIVE:
            raise FetchFailure('artifact-inventory-too-large')
        seen = set()
        for entry in entries:
            name = PurePosixPath(entry.filename)
            mode = entry.external_attr >> 16
            if (name.is_absolute() or '..' in name.parts or '\\' in entry.filename
                    or entry.filename in seen or stat.S_ISLNK(mode)
                    or (stat.S_IFMT(mode) not in (0, stat.S_IFREG, stat.S_IFDIR))):
                raise FetchFailure('unsafe-artifact-member')
            seen.add(entry.filename)
        destination.mkdir()
        for name, limit in MEMBERS.items():
            if name not in seen:
                raise FetchFailure('required-artifact-member-missing')
            entry = file.getinfo(name)
            if entry.is_dir() or not 0 < entry.file_size <= limit:
                raise FetchFailure('invalid-artifact-member-size')
            # Never extract unneeded archive paths, including synthetic proof Apps.
            with (destination / name).open('xb') as output:
                output.write(file.read(entry))


def acquire(output, *, pin_path=DEFAULT_PIN, github=None):
    pin = approval(Path(pin_path))  # No network or build is possible without reviewed inputs.
    github = github or GitHub()
    prefix = f'repos/{REPOSITORY}/actions/runs/{pin["runID"]}'
    run = github.api(prefix)
    if (not isinstance(run, dict) or str(run.get('id')) != pin['runID']
            or (run.get('repository') or {}).get('full_name') != REPOSITORY
            or (run.get('head_repository') or {}).get('full_name') != REPOSITORY
            or run.get('head_branch') != 'main' or run.get('event') not in ('push', 'workflow_dispatch')
            or run.get('status') != 'completed' or run.get('conclusion') != 'success'
            or not isinstance(run.get('head_sha'), str) or re.fullmatch('[0-9a-f]{40}', run['head_sha']) is None):
        raise FetchFailure('untrusted-or-unsuccessful-producer-run')
    listing = github.api(prefix + '/artifacts?per_page=100')
    if (not isinstance(listing, dict) or type(listing.get('total_count')) is not int
            or not 0 <= listing['total_count'] <= 100 or not isinstance(listing.get('artifacts'), list)):
        raise FetchFailure('ambiguous-artifact-inventory')
    matches = [a for a in listing['artifacts'] if a.get('name') == pin['artifactName']]
    if len(matches) != 1:
        raise FetchFailure('approved-artifact-not-unique')
    artifact = matches[0]
    if (artifact.get('expired') is not False or type(artifact.get('id')) is not int or artifact['id'] <= 0
            or type(artifact.get('size_in_bytes')) is not int or not 0 < artifact['size_in_bytes'] <= MAX_ARCHIVE
            or (artifact.get('workflow_run') or {}).get('id') != run['id']):
        raise FetchFailure('invalid-or-expired-approved-artifact')
    output = Path(output).absolute()
    if '\n' in str(output) or '\r' in str(output) or output.resolve() != output or output.exists():
        raise FetchFailure('use-new-unlinked-artifact-output')
    output.mkdir(parents=True)
    archive = output / 'download.zip'
    github.download(f'repos/{REPOSITORY}/actions/artifacts/{artifact["id"]}/zip', archive)
    directory = output / 'artifact'
    unpack(archive, directory)
    binary = directory / 'modelplan-credential-agent'
    actual = hashlib.sha256(binary.read_bytes()).hexdigest()
    descriptor = json.loads((directory / 'credential-agent.json').read_bytes())
    if (not isinstance(descriptor, dict) or actual != pin['sha256'] or descriptor.get('sha256') != pin['sha256']
            or type(descriptor.get('bytes')) is not int or descriptor['bytes'] != binary.stat().st_size):
        raise FetchFailure('independent-helper-pin-mismatch')
    provenance = {**pin, 'repository': REPOSITORY, 'sourceCommit': run['head_sha'], 'artifactID': artifact['id']}
    (output / 'download-receipt.json').write_text(json.dumps(provenance, sort_keys=True) + '\n')
    return {'environment': {'MODELPLAN_CREDENTIAL_AGENT_ARTIFACT': str(directory),
                            'MODELPLAN_CREDENTIAL_AGENT_SHA256': pin['sha256']}, 'approval': provenance}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--pin', type=Path, default=DEFAULT_PIN)
    parser.add_argument('--github-env', type=Path)
    args = parser.parse_args()
    try:
        result = acquire(args.output, pin_path=args.pin)
        if args.github_env is not None:
            with args.github_env.open('a') as output:
                for key, value in result['environment'].items():
                    output.write(key + '=' + value + '\n')
        print(json.dumps(result['approval'], sort_keys=True))
    except (OSError, ValueError, TypeError, KeyError, AttributeError, zipfile.BadZipFile) as error:
        category = str(error) if isinstance(error, FetchFailure) else 'invalid-artifact-data'
        parser.exit(1, 'Credential artifact fetch failed: ' + category + '\n')


if __name__ == '__main__':
    main()

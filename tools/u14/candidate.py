# SPDX-License-Identifier: MIT
"""Generate an immutable evidence directory and candidate identity manifest."""
import argparse
from datetime import datetime, timezone
import os
from pathlib import Path
import platform
import shutil
import subprocess

from contracts import ROOT, digest, encoded, load_json, new_directory, validate, write_private


def git(path, *args):
    # No hooks, credentials, fetch or shell commands. Only local repository metadata.
    env = {**os.environ, 'GIT_OPTIONAL_LOCKS': '0'}
    return subprocess.check_output(['git', '-C', str(path), *args], env=env,
                                   stderr=subprocess.DEVNULL, text=True).strip()


def regular_bytes(path):
    p = Path(path).absolute()
    if p.is_symlink() or p.resolve() != p or not p.is_file():
        raise ValueError('input must be a regular file without symlink components')
    return p.read_bytes()


def artifact(path, allow_tree=False):
    if path is None:
        return {'state': 'unsupported'}
    p = Path(path).absolute()
    if p.resolve() != p or p.is_symlink():
        raise ValueError('artifact root must not be a symlink')
    if p.is_file():
        return {'state': 'available', 'kind': 'file', 'sha256': digest(regular_bytes(p))}
    if not allow_tree or not p.is_dir():
        raise ValueError('artifact is missing or has the wrong type')
    # Tree digest v1: canonical JSON records, sorted by POSIX relative path.
    # Modes and internal symlink targets are bound, but mtime/owner/absolute paths are not.
    records = []
    for child in sorted(p.rglob('*')):
        rel = child.relative_to(p).as_posix()
        if child.is_symlink():
            target = os.readlink(child)
            if Path(target).is_absolute() or not child.resolve().is_relative_to(p) or not child.exists():
                raise ValueError('artifact symlink escapes or is broken')
            records.append({'path': rel, 'kind': 'symlink', 'target': target})
        elif child.is_file():
            records.append({'path': rel, 'kind': 'file', 'sha256': digest(regular_bytes(child)),
                            'mode': child.stat().st_mode & 0o777})
        elif child.is_dir():
            records.append({'path': rel, 'kind': 'directory', 'mode': child.stat().st_mode & 0o777})
        else:
            raise ValueError('unsupported artifact entry')
    if not records:
        raise ValueError('empty app directory')
    return {'state': 'available', 'kind': 'tree', 'sha256': digest(encoded(records))}


def generate_bundle(spec, baseline, destination):
    validate(spec, 'candidate-input.schema.json')
    validate(baseline, 'baseline.schema.json')
    sources = []
    seen = set()
    for source in spec['sources']:
        if source['repository'] in seen:
            raise ValueError('duplicate source repository')
        seen.add(source['repository'])
        if git(source['path'], 'status', '--porcelain', '--untracked-files=all'):
            raise ValueError('source repository is dirty')
        sources.append({'repository': source['repository'],
                        'sha': git(source['path'], 'rev-parse', '--verify', 'HEAD'), 'dirty': False})
    inputs = spec['artifacts']
    artifacts = {key: artifact(inputs[key], allow_tree=key == 'app')
                 for key in ('app', 'helper', 'officialVisualsManifest')}
    artifacts['helperVersion'] = inputs['helperVersion']
    if (inputs['helper'] is None) != (inputs['helperVersion'] is None):
        raise ValueError('helper hash and version must be supplied together')
    artifacts['visualBaselines'] = [artifact(p) for p in inputs['visualBaselines']]
    catalog_bytes = regular_bytes(ROOT / 'scenarios.json')
    catalog = load_json(ROOT / 'scenarios.json')['scenarios']
    results = {}
    blobs = {}
    for result in spec['results']:
        if result['id'] in results or result['id'] not in {s['id'] for s in catalog}:
            raise ValueError('duplicate or unknown scenario')
        if result['outcome'] in ('pass', 'fail', 'timeout') and not result['evidence']:
            raise ValueError('executed scenario must have evidence')
        refs = []
        for path in result['evidence']:
            data = regular_bytes(path)
            sha = digest(data)
            ref = 'blobs/' + sha
            blobs[ref] = data
            refs.append({'ref': ref, 'sha256': sha})
        results[result['id']] = {'outcome': result['outcome'], 'evidence': refs}
    # Artifact capabilities are derived, never accepted from caller claims.
    derived = {'app-package', 'helper', 'official-visuals', 'visual-baselines', 'publication-data',
               'synthetic-home', 'preference-inputs', 'consent-v1'}
    available = set(spec['availableCapabilities']) - derived
    available.update(baseline['availableCapabilities'])
    for key, capability in [('app', 'app-package'), ('helper', 'helper'),
                            ('officialVisualsManifest', 'official-visuals')]:
        if artifacts[key]['state'] == 'available':
            available.add(capability)
    if artifacts['visualBaselines']:
        available.add('visual-baselines')
    publication = {'state': 'unsupported'}
    if spec['publicationRevision'] is not None:
        publication = {'state': 'available', 'revision': spec['publicationRevision']}
        available.add('publication-data')
    scenarios = []
    for scenario in catalog:
        result = results.get(scenario['id'], {'outcome': 'not-run', 'evidence': []})
        missing = sorted(set(scenario['capabilities']) - available)
        structures = sorted(set(scenario['structures']) - set(baseline['covers']))
        scenarios.append({'id': scenario['id'], **result,
                          'outcome': 'unsupported' if missing or structures else result['outcome'],
                          'missingCapabilities': missing, 'missingStructures': structures})
    bundle_files = {'scenarios.json': catalog_bytes,
                    'candidate-manifest.schema.json': regular_bytes(ROOT / 'schemas/candidate-manifest.schema.json')}
    manifest = {'schemaVersion': 1, 'candidateId': spec['candidateId'], 'profile': spec['profile'],
                'intendedLevel': spec['intendedLevel'], 'generatedAt': datetime.now(timezone.utc).isoformat(),
                'build': spec['build'], 'sources': sources, 'artifacts': artifacts,
                'publicationData': publication,
                'environment': {'os': {'system': platform.system(), 'release': platform.release(),
                                       'version': platform.version(), 'machine': platform.machine()},
                                'display': spec['display']},
                'shapeBaseline': baseline, 'availableCapabilities': sorted(available),
                'scenarioCatalogSha256': digest(catalog_bytes), 'scenarios': scenarios,
                'bundleFiles': [{'ref': p, 'sha256': digest(b)} for p, b in sorted(bundle_files.items())]}
    validate(manifest, 'candidate-manifest.schema.json')
    bundle = new_directory(destination)
    try:
        for path, data in {**blobs, **bundle_files, 'manifest.json': encoded(manifest)}.items():
            target = bundle / path
            target.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
            write_private(target, data)
        write_private(bundle / 'manifest.sha256', (digest(encoded(manifest)) + '\n').encode())
    except BaseException:
        shutil.rmtree(bundle)
        raise
    return manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--input', required=True, type=Path)
    parser.add_argument('--baseline', required=True, type=Path, help='.u14-baseline.json from shape_home.py')
    parser.add_argument('--output', required=True, type=Path, help='new evidence directory')
    args = parser.parse_args()
    try:
        generate_bundle(load_json(args.input), load_json(args.baseline), args.output)
    except (ValueError, OSError, subprocess.CalledProcessError, RecursionError) as exc:
        parser.exit(1, f'candidate generation failed ({type(exc).__name__})\n')
    print('Candidate manifest, hashes and evidence bundle created.')


if __name__ == '__main__':
    main()

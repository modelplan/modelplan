# SPDX-License-Identifier: MIT
"""Run U14 engine scenarios by ID and emit a part-B evidence bundle."""
import argparse
from pathlib import Path
import subprocess

from candidate import generate_bundle, git, regular_bytes
from contracts import ROOT, digest, encoded, load_json, new_directory, write_private
from engine_build import build_tools
from engine_process import EngineFailure, EngineTimeout
from engine_runner import admission, backpressure, empty_states, plain_smoke, zero_rows, verify_baseline
from shape_home import build_home

REPO = ROOT.parent.parent
ENGINE_IDS = ('U14-protocol-smoke', 'U3-backpressure', 'U2a-admission',
              'U14-zero-rows-omitted', 'U14-zero-rows-null', 'U14-zero-rows-reported',
              'U14-zero-rows-corrupt', 'U14-empty-states')


def schema_check(validator, messages):
    raw = b''.join(encoded(message).replace(b'\n', b'') + b'\n' for message in messages)
    checked = subprocess.run([str(validator), str(REPO)], input=raw, capture_output=True, timeout=30)
    if checked.returncode:
        raise EngineFailure('real-wire-schema-rejected')


def run(destination, selected=None):
    catalog = load_json(ROOT / 'scenarios.json')['scenarios']
    known = {item['id'] for item in catalog}
    selected = set(ENGINE_IDS if selected is None else selected)
    if not selected <= known:
        raise EngineFailure('unknown-scenario-id')
    if Path(destination).resolve().is_relative_to(REPO.resolve()):
        raise EngineFailure('output-must-be-outside-checkout')
    # Reject before a run starts: part-B evidence never binds a dirty subject.
    if git(REPO, 'status', '--porcelain', '--untracked-files=all'):
        raise EngineFailure('source-must-be-clean-and-committed')
    output = new_directory(destination)
    builds = output / 'build'
    builds.mkdir(mode=0o700)
    baseline = build_home(load_json(ROOT / 'examples/synthetic-shape.json'), output / 'home')
    evidence = output / 'reports'
    evidence.mkdir(mode=0o700)
    results, checks = [], []
    tools, plain = None, None

    def record(id, result, check=False):
        path = evidence / (id + '.json')
        write_private(path, encoded(result))
        target = checks if check else results
        target.append({'id': id, 'outcome': result['outcome'], 'evidence': [str(path)]})

    try:
        tools = build_tools(REPO, builds)
        record('runner-build', {'outcome': 'pass', **tools['metadata']}, check=True)
        verify_baseline(output / 'home', baseline)
        plain = plain_smoke(tools['plain'], output / 'home')
        schema_check(tools['validator'], plain.pop('wireMessages'))
        record('unmodified-binary', plain, check=True)
    except (EngineFailure, OSError, subprocess.SubprocessError, ValueError) as exc:
        record('runner-setup', {'outcome': 'timeout' if isinstance(exc, (EngineTimeout, subprocess.TimeoutExpired)) else 'fail',
                                'errorCode': str(exc) if isinstance(exc, EngineFailure) else type(exc).__name__}, check=True)

    if tools is not None and plain is not None:
        for id in sorted(selected):
            if id not in ENGINE_IDS:
                continue  # The part-B generator records unavailable UI as unsupported.
            try:
                if id == 'U14-protocol-smoke':
                    result = dict(plain)
                else:
                    home = output / ('home-' + id)
                    scenario_baseline = build_home(load_json(ROOT / 'examples/synthetic-shape.json'), home)
                    verify_baseline(home, scenario_baseline)
                    if id == 'U3-backpressure':
                        result = backpressure(tools['fixture'], home)
                    elif id == 'U2a-admission':
                        result = admission(tools['plain'], home, load_json(ROOT / 'examples/admission-plan.json'))
                    elif id == 'U14-empty-states':
                        result = empty_states(tools['fixture'], home)
                    else:
                        result = zero_rows(tools['fixture'], home, id.removeprefix('U14-zero-rows-'))
                    schema_check(tools['validator'], result.pop('wireMessages'))
                    verify_baseline(home, scenario_baseline)
            except (EngineFailure, OSError, subprocess.SubprocessError, ValueError, KeyError) as exc:
                result = {'outcome': 'timeout' if isinstance(exc, (EngineTimeout, subprocess.TimeoutExpired)) else 'fail',
                          'errorCode': str(exc) if isinstance(exc, EngineFailure) else type(exc).__name__}
            record(id, result)
    available = []
    if tools is not None and plain is not None:
        available = ['app-server', 'engine', 'fake-providers', 'recording-transport',
                     'sensitive-queries', 'pipe-backpressure']
    helper = str(tools['fixture']) if tools and plain else None
    spec = {'schemaVersion': 1, 'candidateId': 'u14-engine-' + git(REPO, 'rev-parse', 'HEAD')[:12],
            'profile': 'transport-engine-fixture', 'intendedLevel': 'L1',
            'build': {'type': 'community', 'configuration': 'debug'},
            'sources': [{'repository': 'modelplan/modelplan', 'path': str(REPO)}],
            'artifacts': {'app': None, 'helper': helper, 'helperVersion': plain['serverVersion'] if helper else None,
                          'officialVisualsManifest': None, 'visualBaselines': []},
            'publicationRevision': None, 'display': {'state': 'unsupported'},
            'availableCapabilities': available, 'results': results, 'checks': checks}
    manifest = generate_bundle(spec, baseline, output / 'bundle')
    summary = {'sourceSha': manifest['sources'][0]['sha'],
               'proofScope': 'transport/engine fixture proof',
               'manifestSha256': digest(regular_bytes(output / 'bundle/manifest.json')),
               'scenarios': {item['id']: item['outcome'] for item in manifest['scenarios']},
               'checks': {item['id']: item['outcome'] for item in manifest['checks']}}
    write_private(output / 'summary.json', encoded(summary))
    return summary


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True, help='new temporary run directory outside checkout')
    parser.add_argument('--scenarios', nargs='+', help='registry scenario IDs; omitted runs all engine IDs')
    args = parser.parse_args()
    try:
        summary = run(args.output, args.scenarios)
    except (ValueError, OSError, EngineFailure, subprocess.SubprocessError) as exc:
        parser.exit(1, f'U14 run rejected ({type(exc).__name__})\n')
    bad = any(value in ('fail', 'timeout') for value in (*summary['scenarios'].values(), *summary['checks'].values()))
    print('U14 engine run: ' + ('fail' if bad else 'pass') + '; see bundle/manifest.json and summary.json')
    if bad:
        parser.exit(1)


if __name__ == '__main__':
    main()

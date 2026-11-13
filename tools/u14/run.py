# SPDX-License-Identifier: MIT
"""Run U14 engine scenarios by ID and emit a part-B evidence bundle."""
import argparse
from pathlib import Path
import subprocess

from candidate import generate_bundle, git, regular_bytes
from contracts import ROOT, digest, encoded, load_json, new_directory, write_private
from engine_build import build_tools
from engine_process import EngineFailure, EngineTimeout
from engine_runner import admission, backpressure, empty_states, plain_smoke, zero_rows, verify_baseline, shared_state, null_selectors, ADMISSION_COMPONENTS
from shape_home import build_home

REPO = ROOT.parent.parent
ADMISSION_IDS = ('U2a-admission', *ADMISSION_COMPONENTS)
ENGINE_IDS = ('U3-null-selectors', *ADMISSION_COMPONENTS, 'U3-shared-state', 'U14-protocol-smoke', 'U3-backpressure', 'U2a-admission',
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
    output_path = Path(destination).absolute()
    if output_path.resolve().is_relative_to(REPO.resolve()):
        scratch = REPO / '.tmp'
        ignored = subprocess.run(['git', 'check-ignore', '-q', str(output_path)], cwd=REPO,
                                 capture_output=True, timeout=10).returncode == 0
        if not output_path.resolve().is_relative_to(scratch.resolve()) or scratch.resolve() != scratch or not ignored:
            raise EngineFailure('output-must-be-outside-checkout-or-in-ignored-scratch')
    if selected.intersection(ADMISSION_IDS):
        selected.update(ADMISSION_IDS)
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

    def bind(result, roles):
        identities = tools['metadata']['binaries']
        result['binaryBindings'] = {role: identities[role] for role in roles}
        if roles == ['providers']:
            require_provider = identities['providers']
            if require_provider['constructorChanged'] or require_provider['linksHistoryFixture']:
                raise EngineFailure('admission-constructor-was-replaced')
        return result

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
        verify_baseline(output / 'home', baseline, mutable=('.config/modelplan/consent.json',))
        schema_check(tools['validator'], plain.pop('wireMessages'))
        record('unmodified-binary', bind(plain, ['plain']), check=True)
    except (EngineFailure, OSError, subprocess.SubprocessError, ValueError) as exc:
        record('runner-setup', {'outcome': 'timeout' if isinstance(exc, (EngineTimeout, subprocess.TimeoutExpired)) else 'fail',
                                'errorCode': str(exc) if isinstance(exc, EngineFailure) else type(exc).__name__}, check=True)

    admission_results = None
    if tools is not None and plain is not None:
        for id in sorted(selected):
            if id not in ENGINE_IDS:
                continue
            try:
                if id in ADMISSION_IDS:
                    if admission_results is None:
                        home = output / 'home-U2a-admission'
                        scenario_baseline = build_home(load_json(ROOT / 'examples/synthetic-shape.json'), home)
                        report = admission(tools['providers'], home, load_json(ROOT / 'examples/admission-plan.json'))
                        schema_check(tools['validator'], report.pop('wireMessages'))
                        verify_baseline(home, scenario_baseline)
                        admission_results = {'U2a-admission': bind(report, ['providers'])}
                        for component, component_result in report['subscenarios'].items():
                            admission_results[component] = bind({**component_result,
                                'productionConstructorUnchanged': True, 'productionU2Executed': True,
                                'proofScope': report['proofScope'], 'testedLevel': 'L1 engine-only',
                                'L2DeviceOutcome': 'not-run', 'cleanup': 'exited'}, ['providers'])
                    result = admission_results[id]
                elif id == 'U14-protocol-smoke':
                    result = dict(plain)
                else:
                    home = output / ('home-' + id)
                    scenario_baseline = build_home(load_json(ROOT / 'examples/synthetic-shape.json'), home)
                    verify_baseline(home, scenario_baseline)
                    roles = ['fixture']
                    if id == 'U3-shared-state':
                        result = shared_state(tools['fixture'], home)
                    elif id == 'U3-null-selectors':
                        result = null_selectors(tools['fixture'], home)
                    elif id == 'U3-backpressure':
                        result = backpressure(tools['fixture'], home)
                    elif id == 'U14-empty-states':
                        result = empty_states(tools['plain'], home, tools['fixture'])
                        roles = ['plain', 'fixture']
                    else:
                        result = zero_rows(tools['fixture'], home, id.removeprefix('U14-zero-rows-'))
                    schema_check(tools['validator'], result.pop('wireMessages'))
                    bind(result, roles)
                    verify_baseline(home, scenario_baseline, mutable=('.config/modelplan/consent.json',))
            except (EngineFailure, OSError, subprocess.SubprocessError, ValueError, KeyError) as exc:
                result = {'outcome': 'timeout' if isinstance(exc, (EngineTimeout, subprocess.TimeoutExpired)) else 'fail',
                          'errorCode': str(exc) if isinstance(exc, EngineFailure) else type(exc).__name__}
                if id in ADMISSION_IDS and admission_results is None:
                    admission_results = {component: {'outcome': 'not-run', 'dependency': 'admission-group-failed'}
                                         for component in ADMISSION_IDS}
                    admission_results['U2a-admission'] = result
            record(id, result)
    available = []
    if tools is not None and plain is not None:
        available = ['app-server', 'engine', 'fake-providers', 'recording-transport',
                     'sensitive-queries', 'pipe-backpressure']
    executed_ids = selected.intersection(ENGINE_IDS)
    primary_role = 'providers' if executed_ids <= set(ADMISSION_IDS) | {'U14-protocol-smoke'} else 'fixture'
    if executed_ids <= {'U14-protocol-smoke'}:
        primary_role = 'plain'
    helper = str(tools[primary_role]) if tools and plain else None
    spec = {'schemaVersion': 1, 'candidateId': 'u14-engine-' + git(REPO, 'rev-parse', 'HEAD')[:12],
            'profile': 'production-engine-recording-providers', 'intendedLevel': 'L1',
            'build': {'type': 'community', 'configuration': 'debug'},
            'sources': [{'repository': 'modelplan/modelplan', 'path': str(REPO)}],
            'artifacts': {'app': None, 'helper': helper, 'helperVersion': plain['serverVersion'] if helper else None,
                          'officialVisualsManifest': None, 'visualBaselines': []},
            'publicationRevision': None, 'display': {'state': 'unsupported'},
            'availableCapabilities': available, 'results': results, 'checks': checks}
    manifest = generate_bundle(spec, baseline, output / 'bundle')
    summary = {'sourceSha': manifest['sources'][0]['sha'],
               'proofScope': 'production U2 state and guarded readers; scoped recording-provider and fault overlays',
               'primaryBinaryRole': primary_role,
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

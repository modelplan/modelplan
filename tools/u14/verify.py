# SPDX-License-Identifier: MIT
"""Run the U14 L1 profile and preserve a hash-bound evidence bundle (synthetic only)."""
import argparse
from pathlib import Path
import subprocess

from contracts import ROOT, encoded, load_json, new_directory, write_private
from shape_home import CASES

REPO = ROOT.parent.parent


def verify(destination):
    run = new_directory(destination)
    checks = []

    def check(id, args):
        result = subprocess.run(args, cwd=REPO, capture_output=True)
        log = run / (id + '.txt')
        write_private(log, result.stdout + result.stderr)
        checks.append({'id': id, 'outcome': 'pass' if result.returncode == 0 else 'fail',
                       'evidence': [str(log)]})
        return result.returncode == 0

    passed = check('u14-regressions', ['python3', '-m', 'unittest', 'discover', '-s', 'tools/u14/tests', '-v'])
    passed = check('source-policy', ['node', 'scripts/check-source-policy.mjs']) and passed
    for case in CASES:
        passed = check('shape-' + case, ['python3', str(ROOT / 'shape_home.py'), '--shape',
                       str(ROOT / 'examples/synthetic-shape.json'), '--case', case,
                       '--output', str(run / case)]) and passed
    baseline = run / 'coexistence/.u14-baseline.json'
    if not baseline.exists():
        return False
    spec = load_json(ROOT / 'examples/candidate-input.json')
    spec['sources'][0]['path'] = str(REPO)
    spec['candidateId'] = 'u14-l1'
    spec['profile'] = 'u14-linux-contracts'
    spec['checks'] = checks
    # The candidate CLI, rather than a parallel test-only implementation, emits the bundle.
    input_path = run / 'candidate-input.json'
    write_private(input_path, encoded(spec))
    result = subprocess.run(['python3', str(ROOT / 'candidate.py'), '--input', str(input_path),
                             '--baseline', str(baseline), '--output', str(run / 'bundle')], cwd=REPO)
    if result.returncode:
        return False
    manifest = load_json(run / 'bundle/manifest.json')
    if not all(s['outcome'] == 'unsupported' for s in manifest['scenarios']):
        raise ValueError('L1 builder checks must not claim real product scenarios')
    print('U14 L1 checks: ' + ('pass' if passed else 'fail') + '; product scenarios: unsupported')
    return passed


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True, help='new temporary directory outside the source checkout')
    args = parser.parse_args()
    try:
        if not verify(args.output):
            parser.exit(1, 'U14 verification failed; inspect the preserved evidence.\n')
    except (ValueError, OSError, subprocess.CalledProcessError) as exc:
        parser.exit(1, f'U14 verification failed ({type(exc).__name__})\n')


if __name__ == '__main__':
    main()

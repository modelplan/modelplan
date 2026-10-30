#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Build one immutable R2-denial artifact twice in independent clean roots.

No certificate, Keychain, trust, network or GUI action. Ad-hoc build sealing uses
no identity and enables hardened runtime, with no entitlement exceptions.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import tempfile
from check_embedded_agent import check_pair, HELPER, MANIFEST, validate_pin

PACKAGE = Path(__file__).resolve().parents[1]
REPO = PACKAGE.parents[2]
SOURCES = {'main.swift': PACKAGE / 'Helper/main.swift',
           'Generated.swift': REPO / 'clients/swift/ModelPlanWire/Sources/ModelPlanWire/Generated.swift'}
RECIPE = 'U7-fixed-helper-v2:Swift5,O,wmo,gnone,prefix-map,macos13,content-uuid,adhoc-runtime,no-entitlements'

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def run(args, **kwargs):
    return subprocess.run(args, check=True, timeout=180, **kwargs)

def inputs(universal=False):
    compiler = subprocess.check_output(['xcrun', 'swiftc', '--version'], text=True).strip()
    sdk = subprocess.check_output(['xcrun', '--show-sdk-version'], text=True).strip()
    arch = platform.machine()
    if arch not in ('arm64', 'x86_64'):
        raise ValueError('unsupported-architecture')
    metadata = {'recipe': RECIPE, 'compiler': compiler, 'sdk': sdk, 'architectures': ['arm64', 'x86_64'] if universal else [arch],
                'smokeArchitecture': arch,
                'sourceSHA256': {name: digest(path) for name, path in SOURCES.items()},
                'builderSHA256': digest(Path(__file__))}
    return metadata, hashlib.sha256(json.dumps(metadata, sort_keys=True).encode()).hexdigest()

def build(root, arch):
    for name, source in SOURCES.items():
        shutil.copyfile(source, root / name)
    sdk = subprocess.check_output(['xcrun', '--show-sdk-path'], text=True).strip()
    flags = ['-O', '-whole-module-optimization', '-gnone', '-swift-version', '5',
             '-target', arch + '-apple-macosx13.0', '-sdk', sdk,
             '-file-prefix-map', str(root) + '=.', '-debug-prefix-map', str(root) + '=.',
             '-module-cache-path', str(root / 'modules')]
    env = dict(os.environ, SWIFT_DETERMINISTIC_HASHING='1', SOURCE_DATE_EPOCH='0')
    run(['xcrun', 'swiftc', *flags, '-emit-library', '-static', '-emit-module',
         '-module-name', 'ModelPlanWire', 'Generated.swift', '-o', 'libModelPlanWire.a',
         '-emit-module-path', 'ModelPlanWire.swiftmodule'], cwd=root, env=env)
    run(['xcrun', 'swiftc', *flags, '-I', '.', '-L', '.', '-lModelPlanWire',
         '-module-name', 'ModelPlanCredentialAgentHelper', 'main.swift',
         '-o', 'modelplan-credential-agent'], cwd=root, env=env)
    artifact = root / 'modelplan-credential-agent'
    seal(artifact)
    if arch == platform.machine():
        smoke(artifact)
    return artifact

def seal(artifact):
    run(['/usr/bin/codesign', '--force', '--sign', '-', '--identifier',
         'ai.modelplan.credential-agent', '--options', 'runtime', '--timestamp=none', str(artifact)])
    run(['/usr/bin/codesign', '--verify', '--strict', str(artifact)])
    details = subprocess.run(['/usr/bin/codesign', '-dvv', str(artifact)], capture_output=True, text=True, check=True)
    if 'runtime' not in details.stderr:
        raise ValueError('missing-hardened-runtime')
    entitlements = subprocess.run(['/usr/bin/codesign', '-d', '--entitlements', ':-', str(artifact)], capture_output=True, check=True)
    if entitlements.stdout.strip():
        raise ValueError('unexpected-entitlements')

def smoke(artifact):
    request = {'operationId': 'u7-build-smoke', 'provider': 'claude',
               'scope': 'claude.account_usage.saved_login', 'interactive': False}
    smoke = subprocess.run([str(artifact)], input=json.dumps(request).encode(), capture_output=True,
                           timeout=8, env={'PATH': '/usr/bin:/bin', 'LANG': 'C'})
    if smoke.returncode != 0 or smoke.stderr or json.loads(smoke.stdout) != {'operationId': 'u7-build-smoke', 'outcome': 'denied'}:
        raise ValueError('helper-launch-smoke-failed')

def build_artifact(root, architectures):
    if len(architectures) == 1:
        return build(root, architectures[0])
    slices = []
    for arch in architectures:
        directory = root / arch
        directory.mkdir()
        slices.append(build(directory, arch))
    artifact = root / 'modelplan-credential-agent'
    run(['xcrun', 'lipo', '-create', *map(str, slices), '-output', str(artifact)])
    seal(artifact)
    # The OS executes its native slice only; do not invoke Rosetta or install it.
    smoke(artifact)
    return artifact

def embed(app, artifact, pin):
    # A packaging operation, never a helper rebuild or re-sign.
    if app.suffix != '.app' or not app.is_dir() or app.is_symlink():
        raise ValueError('invalid-app-root')
    for relative in (HELPER, MANIFEST):
        member = app
        for component in relative.parts:
            member = member / component
            if member.is_symlink():
                raise ValueError('symlink-member')
        member.parent.mkdir(parents=True, exist_ok=True)
    if artifact.stat().st_size != pin['bytes'] or digest(artifact) != pin['sha256']:
        raise ValueError('artifact-pin-mismatch')
    shutil.copyfile(artifact, app / HELPER)
    (app / HELPER).chmod(0o755)
    (app / MANIFEST).write_text(json.dumps(pin, sort_keys=True) + '\n')

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True, help='New artifact directory; never overwrites')
    parser.add_argument('--universal', action='store_true', help='Build arm64+x86_64; execute only the native slice')
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=False)
    metadata, input_sha = inputs(args.universal)
    with tempfile.TemporaryDirectory(prefix='clean-A-', dir=args.output) as a, tempfile.TemporaryDirectory(prefix='different-clean-B-', dir=args.output) as b:
        first = build_artifact(Path(a), metadata['architectures'])
        second = build_artifact(Path(b), metadata['architectures'])
        if first.read_bytes() != second.read_bytes():
            raise ValueError('non-reproducible-helper')
        artifact = args.output / 'modelplan-credential-agent'
        shutil.copyfile(first, artifact); artifact.chmod(0o755)
    pin = {'schemaVersion': 1, 'sha256': digest(artifact), 'bytes': artifact.stat().st_size,
           'inputSHA256': input_sha, 'bundleIdentifier': 'ai.modelplan.credential-agent'}
    validate_pin(pin)
    (args.output / 'credential-agent.json').write_text(json.dumps(pin, sort_keys=True) + '\n')
    # Two independently compiled synthetic app hosts; neither is executed.
    # This proves packaging of the real helper, not a production candidate/A14.
    apps = []
    for index in (1, 2):
        app = args.output / ('Synthetic' + str(index) + '.app')
        (app / 'Contents/MacOS').mkdir(parents=True)
        source = args.output / ('host' + str(index) + '.c')
        source.write_text('int main(void) { return ' + str(index) + '; }\n')
        run(['xcrun', 'clang', '-O2', str(source), '-o', str(app / 'Contents/MacOS/host')])
        source.unlink()
        (app / 'Contents/Info.plist').write_text('<?xml version="1.0"?><plist version="1.0"><dict><key>CFBundleIdentifier</key><string>ai.modelplan.u7.synthetic</string><key>CFBundleExecutable</key><string>host</string></dict></plist>')
        embed(app, artifact, pin); apps.append(app)
    proof = {'outcome': 'pass', 'cleanBuilds': 2, 'inputs': metadata, 'pin': pin,
             'twoSyntheticAppBuilds': check_pair(*apps, pin),
             'executedArchitectures': [metadata['smokeArchitecture']],
             'foreignSliceExecution': 'not-run', 'realCandidateA14': 'not-run',
             'security': 'R2 default-deny; ad-hoc runtime; no entitlements, trust or credential action'}
    (args.output / 'proof.json').write_text(json.dumps(proof, indent=2) + '\n')
    print(json.dumps({'outcome': 'pass', 'helperSHA256': pin['sha256'], 'inputSHA256': input_sha}))

if __name__ == '__main__':
    main()

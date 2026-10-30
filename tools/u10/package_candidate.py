#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""U10 interface: ad-hoc candidate assembly and U14 identity; run artifacts only."""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import platform
import plistlib
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools/u14'))
from candidate import artifact, generate_bundle, git
from contracts import digest, encoded, load_json


def module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


identity = module('u10_identity', ROOT / 'desktop/native/tools/write-consent-bundle-identity.py')
release = module('u10_release', ROOT / 'desktop/native/tools/distribution/release.py')
credential_artifact = module('u10_credential_artifact', ROOT / 'desktop/native/tools/distribution/fetch_credential_artifact.py')
BUNDLE_ID = 'ai.modelplan.candidate'
HELPER_VERSION = '0.5.49'


def run(*args, env=None):
    env = {k: v for k, v in (os.environ if env is None else env).items() if k not in ('GH_TOKEN', 'GITHUB_TOKEN')}
    try:
        return subprocess.check_output([str(a) for a in args], stderr=subprocess.STDOUT, env=env)
    except subprocess.CalledProcessError as error:
        sys.stderr.buffer.write(error.output)
        raise


def regular(path):
    path = Path(path).absolute()
    if path.resolve() != path or not path.is_file():
        raise ValueError('Expected a regular, unlinked file')
    return path


def copy_tree(source, destination):
    # These are public data/web resources, never nested executable containers.
    source = Path(source).absolute()
    if source.resolve() != source or not source.is_dir():
        raise ValueError('Resource root must be an unlinked directory')
    for item in source.rglob('*'):
        if item.is_symlink() or not (item.is_file() or item.is_dir()):
            raise ValueError('Linked or special resource entry')
    shutil.copytree(source, destination)


def raw_identity(raw_inputs):
    if set(raw_inputs) != set(identity.SOURCE):
        raise ValueError('Both reviewed Darwin inputs are required')
    raw = {arch: identity.digest_file(regular(path)) for arch, path in raw_inputs.items()}
    # The producer distinguishes released thin-binary hashes from archive and signed universal hashes.
    identity.metadata('a' * 40, raw, 'b' * 64)
    return raw


def verify_identity(app, source, raw):
    info = plistlib.loads(regular(app / 'Contents/Info.plist').read_bytes())
    bundled = identity.digest_file(regular(app / 'Contents/Helpers/modelplan'))
    expected = identity.metadata(source, raw, bundled)
    if any(info.get(key) != value for key, value in expected.items()):
        raise ValueError('Candidate consent identity mismatch')
    if regular(app / 'Contents/Resources/modelplan.sha256').read_text() != bundled + '\n':
        raise ValueError('Candidate helper resource hash mismatch')
    if 'ModelPlanSourceHelperSHA256' in info:
        raise ValueError('Legacy single-architecture source identity must be absent')
    if info.get('CFBundleIdentifier') != BUNDLE_ID:
        raise ValueError('Candidate bundle identifier mismatch')
    return expected


def seal(app, source, raw_inputs, command=run):
    raw = raw_identity(raw_inputs)  # Fail before invoking any signing command.
    helper = app / 'Contents/Helpers/modelplan'
    command('codesign', '--force', '--sign', '-', '--options', 'runtime', '--timestamp=none', helper)
    # Invoke the canonical release producer after helper signing and before app signing.
    command(sys.executable, '-B', ROOT / 'desktop/native/tools/write-consent-bundle-identity.py',
            '--mode', 'release', '--app', app, '--public-source', source,
            '--arm64-input', raw_inputs['arm64'], '--x86-64-input', raw_inputs['x86_64'])
    verify_identity(app, source, raw)
    command('codesign', '--force', '--sign', '-', '--options', 'runtime', '--timestamp=none', app)
    command('codesign', '--verify', '--strict', helper)
    command('codesign', '--verify', '--deep', '--strict', app)
    # No helper byte may change after the outer seal.
    return verify_identity(app, source, raw)


def stage_resources(app, root=ROOT):
    resources = app / 'Contents/Resources'
    visuals = root / 'desktop/official-visuals'
    fonts = root / 'desktop/third-party/fonts'
    copy_tree(visuals, resources / 'OfficialVisuals')
    copy_tree(fonts, resources / 'ThirdParty/fonts')
    copy_tree(root / 'desktop/third-party/licenses', resources / 'ThirdParty/licenses')
    shutil.copyfile(regular(root / 'desktop/third-party/NOTICES.md'), resources / 'ThirdParty/NOTICES.md')
    shutil.copyfile(regular(visuals / 'icons/icon.icns'), resources / 'ModelPlan.icns')
    shutil.copyfile(regular(visuals / 'LICENSE.md'), resources / 'VISUAL-LICENSE.md')
    cockpit = root / 'desktop/cockpit/dist'
    if cockpit.exists():
        regular(cockpit / 'index.html')
        copy_tree(cockpit, resources / 'Cockpit')
        cockpit_state = 'bundled-interface-only'
    else:
        (resources / 'Cockpit').mkdir()
        (resources / 'Cockpit/index.html').write_text(
            '<!doctype html><meta charset="utf-8"><title>ModelPlan candidate</title>'
            '<h1>Cockpit unavailable</h1><p>U10 interface placeholder. '
            'The U11 web bundle and private porthole art are not included. '
            'This page is not a cockpit acceptance result.</p>\n')
        cockpit_state = 'placeholder'
    # Static resources only; runtime lookup/bridge integration remains with the owning units.
    return {'cockpit': cockpit_state, 'privatePortholeArt': 'unsupported',
            'officialVisuals': artifact(resources / 'OfficialVisuals', allow_tree=True),
            'fonts': artifact(resources / 'ThirdParty/fonts', allow_tree=True),
            'cockpitResources': artifact(resources / 'Cockpit', allow_tree=True)}


def configure_product(app, source, build_number, root=ROOT):
    if not re.fullmatch(r'[1-9][0-9]{0,17}', build_number):
        raise ValueError('Build number must be a positive decimal integer')
    version = load_json(root / 'desktop/package.json')['version']
    if not re.fullmatch(r'\d+\.\d+\.\d+', version):
        raise ValueError('Product version must have three decimal components')
    info_path = regular(app / 'Contents/Info.plist')
    info = plistlib.loads(info_path.read_bytes())
    info.update(CFBundleName='ModelPlan', CFBundleDisplayName='ModelPlan Candidate',
                CFBundleIdentifier=BUNDLE_ID, CFBundleIconFile='ModelPlan.icns', CFBundleShortVersionString=version,
                CFBundleVersion=build_number, ModelPlanCandidateStage='interface-only')
    info_path.write_bytes(plistlib.dumps(info))
    resources = app / 'Contents/Resources'
    (resources / 'build-edition.json').write_bytes(encoded({'edition': 'official', 'stage': 'interface-only'}))
    (resources / 'release-provenance.json').write_bytes(encoded({
        'sourceRepository': 'modelplan/modelplan', 'sourceCommit': source,
        'signing': 'ad-hoc', 'notarized': False, 'published': False,
        'keychainTwoBuildAcceptance': 'not-run'}))


def verify_credential_helper(app, command=run, environment=None):
    environment = os.environ if environment is None else environment
    artifact = environment.get('MODELPLAN_CREDENTIAL_AGENT_ARTIFACT')
    expected = environment.get('MODELPLAN_CREDENTIAL_AGENT_SHA256')
    if not artifact or not expected:
        raise ValueError('Approved credential helper artifact and independent SHA256 are required')
    command(sys.executable, '-B', ROOT / 'desktop/native/ModelPlanCredentialAgent/tools/check_embedded_agent.py',
            '--pin', Path(artifact) / 'credential-agent.json', '--expected-sha256', expected, '--single', app)


def packaging_baseline():
    # No synthetic HOME or owner shape was exercised during packaging.
    return {'schemaVersion': 1, 'baselineVersion': 'u10-packaging-no-home-v1',
            'shapeSha256': digest(encoded({'kind': 'packaging-only', 'home': None})),
            'fidelity': 'hand-built', 'approvalRef': None, 'preferenceCase': 'fresh',
            'covers': [], 'knownGaps': ['Packaging only: no HOME, GUI, provider, Keychain or owner journey exercised.'],
            'availableCapabilities': [], 'migrationOracle': {
                'officialSettingsSource': 'defaults', 'communitySettingsSource': 'defaults', 'coreSource': 'defaults'},
            'files': []}


def evidence(app, output, source_root, candidate_id, receipt):
    resources = app / 'Contents/Resources'
    receipt_path = output / 'packaging-receipt.json'
    receipt_path.write_bytes(encoded(receipt))
    spec = {'schemaVersion': 1, 'candidateId': candidate_id, 'profile': 'macos-candidate-packaging',
            'intendedLevel': 'L1', 'build': {'type': 'official', 'configuration': 'release'},
            'sources': [{'repository': 'modelplan/modelplan', 'path': str(source_root)}],
            'artifacts': {'app': str(app), 'helper': str(app / 'Contents/Helpers/modelplan'),
                          'helperVersion': HELPER_VERSION,
                          'officialVisualsManifest': str(resources / 'OfficialVisuals/runtime/manifest.json'),
                          'visualBaselines': []},
            'publicationRevision': None, 'display': {'state': 'unsupported'},
            'availableCapabilities': [], 'results': [],
            'checks': [{'id': 'U10-packaging-identity', 'outcome': 'pass', 'evidence': [str(receipt_path)]}]}
    manifest = generate_bundle(spec, packaging_baseline(), output / 'evidence')
    if manifest['sources'][0]['sha'] != receipt['sourceCommit']:
        raise ValueError('Source changed during packaging')
    return manifest


def build(output, candidate_id, build_number):
    if platform.system() != 'Darwin':
        raise ValueError('Real candidate packaging requires macOS')
    if not re.fullmatch(r'[a-zA-Z0-9][a-zA-Z0-9._-]{0,99}', candidate_id):
        raise ValueError('Invalid candidate ID')
    if not re.fullmatch(r'[1-9][0-9]{0,17}', build_number):
        raise ValueError('Invalid build number')
    source = git(ROOT, 'rev-parse', 'HEAD')
    if git(ROOT, 'status', '--porcelain', '--untracked-files=all'):
        raise ValueError('Source must be clean')
    output = Path(output).absolute()
    if output.resolve() != output or output.exists():
        raise ValueError('Use a new, unlinked output directory')
    pin_path = ROOT / 'desktop/native/consent-cli-pin.json'
    if load_json(pin_path)['version'] != HELPER_VERSION:
        raise ValueError('Candidate helper pin needs a reviewed identity update')
    output.mkdir(parents=True)
    work = output / 'work'
    work.mkdir()
    binding = credential_artifact.acquire(work / 'credential-input')
    credential_env = {k: v for k, v in os.environ.items() if k not in ('GH_TOKEN', 'GITHUB_TOKEN')}
    credential_env.update(binding['environment'])
    archives = work / 'cli-archives'
    release.fetch_cli(pin_path, archives)
    # Preserve the release scaffold and its consumer; this path has no unverified identity switch.
    run('bash', ROOT / 'desktop/native/tools/package-neutral.sh', archives, work / 'native', env=credential_env)
    app = output / 'ModelPlan.app'
    shutil.move(work / 'native/ModelPlan Community.app', app)
    configure_product(app, source, build_number)
    resources = stage_resources(app)
    raw_inputs = {'arm64': work / 'native/cli-arm64/modelplan_darwin_arm64/modelplan',
                  'x86_64': work / 'native/cli-x86_64/modelplan_darwin_amd64/modelplan'}
    sealed = seal(app, source, raw_inputs)
    for executable in (app / 'Contents/Helpers/modelplan', app / 'Contents/MacOS/ModelPlanCommunity'):
        if set(run('xcrun', 'lipo', '-archs', executable).decode().split()) != {'arm64', 'x86_64'}:
            raise ValueError('App and helper must be universal')
    # The subprocess cwd is explicit; no global cwd mutation or helper execution.
    subprocess.run(['go', 'run', './internal/releaseguard/cmd', '--binary',
                    str(app / 'Contents/MacOS/ModelPlanCommunity')], cwd=ROOT / 'cli', env=credential_env, check=True)
    archive = output / 'ModelPlan-candidate-adhoc.zip'
    run('ditto', '-c', '-k', '--sequesterRsrc', '--keepParent', app, archive)
    release.check_archive(archive)
    unpacked = work / 'archive-roundtrip'
    run('ditto', '-x', '-k', archive, unpacked)
    if artifact(unpacked / 'ModelPlan.app', allow_tree=True) != artifact(app, allow_tree=True):
        raise ValueError('Archive does not contain the exact sealed app')
    receipt = {'schemaVersion': 1, 'stage': 'interface-only', 'sourceCommit': source,
               'bundleIdentifier': BUNDLE_ID, 'helperVersion': HELPER_VERSION,
               'appVersion': load_json(ROOT / 'desktop/package.json')['version'], 'buildNumber': build_number,
               'identity': sealed, 'resources': resources, 'credentialArtifact': binding['approval'], 'signing': 'ad-hoc',
               'notarized': False, 'published': False, 'intelExecution': 'not-run',
               'L2': 'not-run', 'L3': 'not-run', 'keychainTwoBuildAcceptance': 'not-run',
               'archive': {'file': archive.name, 'sha256': release.sha256(archive)}}
    manifest = evidence(app, output, ROOT, candidate_id, receipt)
    # Hash the final sealed app and helper, and the exact archived delivery bytes.
    if manifest['artifacts']['app'] != artifact(app, allow_tree=True):
        raise ValueError('Sealed app changed after manifest generation')
    verify_identity(app, source, raw_identity(raw_inputs))
    # U10 re-seals the App after the neutral scaffold; verify the pin after this final seal too.
    verify_credential_helper(app, environment=credential_env)
    (output / 'SHA256SUMS').write_text(''.join(
        f'{release.sha256(p)}  {p.relative_to(output).as_posix()}\n'
        for p in (archive, output / 'packaging-receipt.json', output / 'evidence/manifest.json')))
    shutil.rmtree(work)
    print('Ad-hoc candidate and U14 manifest created; interface only, no publication.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--candidate-id', required=True)
    parser.add_argument('--build-number', required=True)
    args = parser.parse_args()
    build(args.output, args.candidate_id, args.build_number)


if __name__ == '__main__':
    main()

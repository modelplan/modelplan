#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""R7 release plumbing. No credential discovery, publication, or updater runtime."""
import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import secrets
import stat
import tarfile
import zipfile
import posixpath
import subprocess
import tempfile
from urllib.parse import urlparse
from urllib.request import urlopen
import xml.etree.ElementTree as ET

SIGNING = ('MACOS_CERTIFICATE_P12_BASE64', 'MACOS_CERTIFICATE_PASSWORD',
           'MACOS_SIGNING_IDENTITY', 'MACOS_TEAM_ID', 'MACOS_BUNDLE_ID',
           'MACOS_OFFICIAL_WORKFLOW_ID', 'CANDIDATE_RUN_ID', 'MACOS_FEED_URL')
NOTARY = ('APPLE_NOTARY_KEY_P8_BASE64', 'APPLE_NOTARY_KEY_ID', 'APPLE_NOTARY_ISSUER_ID')
SPARKLE = ('SPARKLE_ED25519_PRIVATE_KEY', 'SPARKLE_TOOLS_URL',
           'SPARKLE_TOOLS_SHA256', 'MACOS_UPDATE_URL', 'MACOS_FEED_URL')
NS = 'http://www.andymatuschak.org/xml-namespaces/sparkle'
ET.register_namespace('sparkle', NS)


def release_plan(env):
    trusted = (env.get('RELEASE_REQUESTED') == 'true' and
               env.get('GITHUB_EVENT_NAME') == 'workflow_dispatch' and
               env.get('GITHUB_REF') == 'refs/heads/main')
    result = {}
    for stage, names in [('sign', SIGNING), ('notarize', SIGNING + NOTARY),
                         ('appcast', SIGNING + NOTARY + SPARKLE)]:
        missing = [name for name in names if not env.get(name, '').strip()]
        result[stage] = {'ready': trusted and not missing, 'missing': missing,
                         'requested_on_main': trusted}
    return result


def https_url(value):
    url = urlparse(value)
    if url.scheme != 'https' or not url.hostname or url.username or url.password or url.fragment:
        raise ValueError('A credential-free HTTPS URL is required')
    return value


def sha256(path):
    with Path(path).open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def run(*args, input=None):
    # Do not echo subprocess arguments/output: upstream key tools can echo bad input.
    env = {k: v for k, v in os.environ.items()
           if k not in SIGNING + NOTARY + SPARKLE and k not in ('GH_TOKEN', 'GITHUB_TOKEN')}
    result = subprocess.run(args, input=input, stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=env)
    if result.returncode:
        raise RuntimeError(f'{Path(args[0]).name} failed (output withheld; no credential diagnostics uploaded)')
    return result.stdout


def fetch_cli(pin_path, output):
    pin = json.loads(Path(pin_path).read_text())
    version = pin['version']
    if not re.fullmatch(r'\d+\.\d+\.\d+', version):
        raise ValueError('Invalid pinned CLI release')
    expected_base = f'https://github.com/modelplan/modelplan/releases/download/v{version}'
    if pin['release'] != expected_base:
        raise ValueError('Unexpected CLI release source')
    output = Path(output); output.mkdir(parents=True, exist_ok=False)
    lines = []
    for arch in ('arm64', 'amd64'):
        name = f'modelplan_darwin_{arch}.tar.gz'
        expected = pin['sha256'][f'darwin_{arch}']
        if not re.fullmatch('[0-9a-f]{64}', expected):
            raise ValueError('Invalid pinned CLI checksum')
        with urlopen(f'{expected_base}/{name}', timeout=60) as response:
            data = response.read(64 * 1024 * 1024 + 1)
        if len(data) > 64 * 1024 * 1024 or hashlib.sha256(data).hexdigest() != expected:
            raise ValueError('CLI download checksum/size mismatch')
        (output / name).write_bytes(data); lines.append(f'{expected}  {name}\n')
    (output / 'checksums.txt').write_text(''.join(lines))


def check_archive(archive):
    with zipfile.ZipFile(archive) as bundle:
        entries = bundle.infolist()
        if not entries or len(entries) > 10000 or sum(x.file_size for x in entries) > 1024 ** 3:
            raise ValueError('Candidate archive exceeds size/entry limits')
        seen = set()
        for item in entries:
            path = item.filename
            if path in seen or path.startswith('/') or '..' in path.split('/') or '\\' in path:
                raise ValueError('Unsafe or duplicate archive path')
            seen.add(path)
            if not (path.startswith('ModelPlan.app/') or path.startswith('__MACOSX/')):
                raise ValueError('Only ModelPlan.app and archive metadata are permitted')
            if stat.S_ISLNK(item.external_attr >> 16):
                target = bundle.read(item).decode('utf-8')
                resolved = posixpath.normpath(posixpath.join(posixpath.dirname(path), target))
                if target.startswith('/') or not resolved.startswith('ModelPlan.app/'):
                    raise ValueError('External archive symlink')
        if 'ModelPlan.app/Contents/Info.plist' not in seen:
            raise ValueError('Missing app Info.plist')


def fetch_sparkle(output):
    env = os.environ; url = https_url(env['SPARKLE_TOOLS_URL'])
    if not re.fullmatch(r'https://github.com/sparkle-project/Sparkle/releases/download/[0-9]+\.[0-9]+\.[0-9]+/[^/?]+\.tar\.xz', url):
        raise ValueError('Use a reviewed, immutable Sparkle release tar.xz URL')
    expected = env['SPARKLE_TOOLS_SHA256']
    if not re.fullmatch('[0-9a-f]{64}', expected): raise ValueError('Missing tool archive SHA256')
    output = Path(output); output.mkdir(parents=True, exist_ok=False)
    with tempfile.TemporaryDirectory(prefix='modelplan-sparkle-', dir=env['RUNNER_TEMP']) as directory:
        archive = Path(directory) / 'tools.tar.xz'
        with urlopen(url, timeout=60) as response:
            data = response.read(128 * 1024 * 1024 + 1)
        if len(data) > 128 * 1024 * 1024 or hashlib.sha256(data).hexdigest() != expected:
            raise ValueError('Sparkle tool archive checksum/size mismatch')
        archive.write_bytes(data)
        with tarfile.open(archive) as package:
            members = [m for m in package.getmembers() if m.name.removeprefix('./') == 'bin/sign_update' and m.isfile()]
            if len(members) != 1 or members[0].size > 32 * 1024 * 1024:
                raise ValueError('Expected one reviewed standalone sign_update tool')
            tool = output / 'sign_update'; tool.write_bytes(package.extractfile(members[0]).read()); tool.chmod(0o700)


def validate_candidate(app, source, bundle_id, team_id):
    app = Path(app).resolve(strict=True)
    # All symlinks must resolve inside the candidate; frameworks may use internal links.
    for item in app.rglob('*'):
        if item.is_symlink() and not item.resolve(strict=True).is_relative_to(app):
            raise ValueError('Candidate contains an external symlink')
    resource = app / 'Contents/Resources'
    edition = json.loads((resource / 'build-edition.json').read_text())
    provenance = json.loads((resource / 'release-provenance.json').read_text())
    info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
    if edition.get('edition') != 'official' or provenance.get('sourceCommit') != source:
        raise ValueError('Candidate edition or exact source commit mismatch')
    if not re.fullmatch('[0-9a-f]{40}', source) or not re.fullmatch('[A-Z0-9]{10}', team_id):
        raise ValueError('Invalid approved source/team')
    if info.get('CFBundleIdentifier') != bundle_id or not bundle_id:
        raise ValueError('Candidate bundle ID mismatch')
    if info.get('LSMinimumSystemVersion') not in ('14.0', '14.0.0'):
        raise ValueError('Candidate deployment floor mismatch')
    if not re.fullmatch(r'\d+(?:\.\d+){0,2}', info.get('CFBundleVersion', '')):
        raise ValueError('Invalid build version')
    for name in ('LICENSE.txt', 'CLI-THIRD-PARTY-NOTICES.md', 'VISUAL-LICENSE.md'):
        if not (resource / name).is_file():
            raise ValueError('Candidate license notice missing')
    helper = app / 'Contents/Helpers/modelplan'
    if sha256(helper) != (resource / 'modelplan.sha256').read_text().strip():
        raise ValueError('Candidate bundled CLI hash mismatch')
    for executable in (helper, app / 'Contents/MacOS' / info['CFBundleExecutable']):
        if set(run('xcrun', 'lipo', '-archs', str(executable)).decode().split()) != {'arm64', 'x86_64'}:
            raise ValueError('Candidate must contain universal app and CLI executables')
    if info.get('SUFeedURL') != https_url(os.environ['MACOS_FEED_URL']):
        raise ValueError('Candidate feed channel mismatch')
    public_key = base64.b64decode(info.get('SUPublicEDKey', ''), validate=True)
    if len(public_key) != 32:
        raise ValueError('Candidate Sparkle public key missing')
    return info


def sign(app):
    env = os.environ
    validate_candidate(app, env['GITHUB_SHA'], env['MACOS_BUNDLE_ID'], env['MACOS_TEAM_ID'])
    if not env['MACOS_SIGNING_IDENTITY'].startswith('Developer ID Application:'):
        raise ValueError('Only an approved Developer ID Application identity is supported')
    with tempfile.TemporaryDirectory(prefix='modelplan-sign-', dir=env['RUNNER_TEMP']) as directory:
        directory = Path(directory); directory.chmod(0o700)
        cert = directory / 'certificate.p12'
        cert.write_bytes(base64.b64decode(env['MACOS_CERTIFICATE_P12_BASE64'], validate=True)); cert.chmod(0o600)
        entitlements = directory / 'entitlements.plist'
        entitlements.write_bytes(plistlib.dumps({}))  # no sandbox/debug exceptions
        keychain = directory / 'signing.keychain-db'; password = secrets.token_urlsafe(32)
        try:
            run('security', 'create-keychain', '-p', password, str(keychain))
            run('security', 'unlock-keychain', '-p', password, str(keychain))
            run('security', 'import', str(cert), '-k', str(keychain), '-P', env['MACOS_CERTIFICATE_PASSWORD'], '-T', '/usr/bin/codesign')
            run('security', 'set-key-partition-list', '-S', 'apple-tool:,apple:,codesign:', '-s', '-k', password, str(keychain))
            app = Path(app)
            def codesign(path):
                run('codesign', '--force', '--sign', env['MACOS_SIGNING_IDENTITY'], '--keychain', str(keychain),
                    '--options', 'runtime', '--timestamp', '--entitlements', str(entitlements), str(path))
            # Sign Mach-O leaves then nested containers, deepest first. Never use --deep for signing.
            for path in sorted(app.rglob('*'), key=lambda p: len(p.parts), reverse=True):
                if path.is_file() and not path.is_symlink() and b'Mach-O' in run('file', '-b', str(path)):
                    codesign(path)
            for path in sorted(app.rglob('*'), key=lambda p: len(p.parts), reverse=True):
                if not path.is_symlink() and path.suffix in ('.framework', '.app', '.xpc', '.appex'):
                    codesign(path)
            resource = app / 'Contents/Resources/modelplan.sha256'
            resource.write_text(sha256(app / 'Contents/Helpers/modelplan') + '\n')
            codesign(app)
            run('codesign', '--verify', '--deep', '--strict', str(app))
            result = subprocess.run(['codesign', '-d', '--verbose=4', str(app)], capture_output=True, check=True)
            if f'TeamIdentifier={env["MACOS_TEAM_ID"]}' not in result.stderr.decode():
                raise ValueError('Signed team mismatch')
        finally:
            if keychain.exists():
                run('security', 'delete-keychain', str(keychain))


def notarize(app, output):
    env = os.environ; output = Path(output); output.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='modelplan-notary-', dir=env['RUNNER_TEMP']) as directory:
        directory = Path(directory); directory.chmod(0o700)
        key = directory / 'notary.p8'; key.write_bytes(base64.b64decode(env['APPLE_NOTARY_KEY_P8_BASE64'], validate=True)); key.chmod(0o600)
        upload = directory / 'upload.zip'
        run('ditto', '-c', '-k', '--sequesterRsrc', '--keepParent', str(app), str(upload))
        receipt = json.loads(run('xcrun', 'notarytool', 'submit', str(upload), '--key', str(key),
            '--key-id', env['APPLE_NOTARY_KEY_ID'], '--issuer', env['APPLE_NOTARY_ISSUER_ID'],
            '--wait', '--timeout', '15m', '--output-format', 'json'))
        if receipt.get('status') != 'Accepted':
            raise ValueError('Notarization was not accepted; no update candidate produced')
        run('xcrun', 'stapler', 'staple', str(app)); run('xcrun', 'stapler', 'validate', str(app))
        run('codesign', '--verify', '--deep', '--strict', str(app)); run('spctl', '--assess', '--type', 'execute', str(app))
        (output / 'notary-receipt.json').write_text(json.dumps({'id': receipt['id'], 'status': 'Accepted'}) + '\n')
        run('ditto', '-c', '-k', '--sequesterRsrc', '--keepParent', str(app), str(output / 'ModelPlan-universal.zip'))


def appcast_bytes(info, archive, signature, download, feed):
    https_url(download); https_url(feed)
    if len(base64.b64decode(signature, validate=True)) != 64 or Path(archive).stat().st_size <= 0:
        raise ValueError('A real signature and nonempty archive are required')
    rss = ET.Element('rss', version='2.0'); channel = ET.SubElement(rss, 'channel')
    ET.SubElement(channel, 'title').text = 'ModelPlan official macOS updates'
    ET.SubElement(channel, 'link').text = feed
    item = ET.SubElement(channel, 'item')
    ET.SubElement(item, 'title').text = 'ModelPlan ' + info['CFBundleShortVersionString']
    ET.SubElement(item, f'{{{NS}}}version').text = info['CFBundleVersion']
    ET.SubElement(item, f'{{{NS}}}shortVersionString').text = info['CFBundleShortVersionString']
    ET.SubElement(item, f'{{{NS}}}minimumSystemVersion').text = '14.0.0'
    ET.SubElement(item, 'description').text = 'Universal binary. Apple silicon tested; Intel untested; 3D may stutter.'
    ET.SubElement(item, 'enclosure', {'url': download, f'{{{NS}}}edSignature': signature,
        'length': str(Path(archive).stat().st_size), 'type': 'application/octet-stream'})
    return ET.tostring(rss, encoding='utf-8', xml_declaration=True)


def appcast(app, output, tool):
    env = os.environ; output = Path(output); archive = output / 'ModelPlan-universal.zip'
    info = plistlib.loads((Path(app) / 'Contents/Info.plist').read_bytes())
    key = env['SPARKLE_ED25519_PRIVATE_KEY'].strip().encode() + b'\n'
    signature = run(str(tool), '--ed-key-file', '-', '-p', str(archive), input=key).decode().strip()
    run(str(tool), '--ed-key-file', '-', '--verify', str(archive), signature, input=key)
    # Verify independently against the public key actually embedded in the candidate.
    verifier = '''import CryptoKit
import Foundation
let args = CommandLine.arguments
let key = try Curve25519.Signing.PublicKey(rawRepresentation: Data(base64Encoded: args[1])!)
let signature = Data(base64Encoded: args[2])!
let archive = try Data(contentsOf: URL(fileURLWithPath: args[3]), options: .mappedIfSafe)
if !key.isValidSignature(signature, for: archive) { exit(1) }
'''
    with tempfile.TemporaryDirectory(prefix='modelplan-verify-', dir=env['RUNNER_TEMP']) as directory:
        source = Path(directory) / 'verify.swift'; source.write_text(verifier)
        run('swift', '-module-cache-path', str(Path(directory) / 'module-cache'), str(source),
            info['SUPublicEDKey'], signature, str(archive))
    (output / 'appcast.xml').write_bytes(appcast_bytes(info, archive, signature, env['MACOS_UPDATE_URL'], env['MACOS_FEED_URL']))
    (output / 'SHA256SUMS').write_text(f'{sha256(archive)}  {archive.name}\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('stage', choices=('plan', 'fetch-cli', 'fetch-sparkle', 'check-archive', 'sign', 'notarize', 'appcast'))
    parser.add_argument('--archive'); parser.add_argument('--app'); parser.add_argument('--output'); parser.add_argument('--pin'); parser.add_argument('--tool')
    args = parser.parse_args()
    if args.stage == 'plan':
        plan = release_plan(os.environ); print(json.dumps(plan, indent=2))
        with open(os.environ['GITHUB_OUTPUT'], 'a') as output:
            for stage, decision in plan.items(): output.write(f'{stage}={str(decision["ready"]).lower()}\n')
    elif args.stage == 'fetch-cli': fetch_cli(args.pin, args.output)
    elif args.stage == 'fetch-sparkle': fetch_sparkle(args.output)
    elif args.stage == 'check-archive': check_archive(args.archive)
    else:
        if not release_plan(os.environ)[args.stage]['ready']:
            raise ValueError('Release stage is not authorized/configured')
        if args.stage == 'sign': sign(args.app)
        elif args.stage == 'notarize': notarize(args.app, args.output)
        else: appcast(args.app, args.output, args.tool)


if __name__ == '__main__':
    try: main()
    except Exception as error:
        # Never include key-tool stdout, environment values or command arguments in errors.
        raise SystemExit(f'Release stage failed: {type(error).__name__}; inspect the nonsecret stage configuration.') from None

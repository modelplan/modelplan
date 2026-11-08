# SPDX-License-Identifier: MIT
"""Shell-orchestration fixtures only; no real build, signature, helper or GUI proof.

Artifact names and pin fields follow M3's published contract. Universal/signature
validation is an inert boundary here; these tests prove shell orchestration,
early pin rejection and verifier failure propagation, not a real signed artifact.
"""
import hashlib
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[4]


class PackageNeutralFixture:
    def __init__(self, root):
        self.root = root
        self.repo = root / 'repo'
        self.bin = root / 'bin'
        self.bin.mkdir()
        self.home = root / 'home'
        self.home.mkdir()
        self.log = root / 'commands.jsonl'
        self.log.write_text('')
        self.script = self.repo / 'desktop/native/tools/package-neutral.sh'
        self.script.parent.mkdir(parents=True)
        shutil.copyfile(ROOT / 'desktop/native/tools/package-neutral.sh', self.script)
        (self.repo / 'LICENSE').write_text('Synthetic MIT fixture; no product or helper bytes.')
        visuals = self.repo / json.loads((ROOT / 'source-policy.json').read_text())['reservedVisuals']['prefix']
        visuals.mkdir(parents=True)
        (visuals / 'LICENSE.md').write_text('Synthetic visuals license')
        (visuals / 'icons').mkdir()
        (visuals / 'icons/AppIcon.icns').write_bytes(b'icns synthetic')
        (self.repo / 'THIRD-PARTY-TRADEMARKS.md').write_text('Synthetic trademark notice')
        self.archives = root / 'archives'
        self.archives.mkdir()
        sums = []
        for arch in ['arm64', 'amd64']:
            archive = self.archives / f'modelplan_darwin_{arch}.tar.gz'
            with tarfile.open(archive, 'w:gz') as file:
                for name, data in [('modelplan', b'synthetic CLI ' + arch.encode()),
                                   ('THIRD-PARTY-NOTICES.md', b'synthetic notices')]:
                    entry = tarfile.TarInfo(f'modelplan_darwin_{arch}/{name}')
                    entry.size = len(data)
                    file.addfile(entry, io.BytesIO(data))
            sums.append(f'{hashlib.sha256(archive.read_bytes()).hexdigest()}  {archive.name}\n')
        (self.archives / 'checksums.txt').write_text(''.join(sums))
        stub = '#!' + sys.executable + '\n' + r'''import json, os
from pathlib import Path
import sys
name = Path(sys.argv[0]).name
args = sys.argv[1:]
with open(os.environ['PACKAGING_COMMAND_LOG'], 'a') as output:
    output.write(json.dumps({'command': name, 'args': args}) + '\n')
if name == 'git':
    if args[-2:] == ['rev-parse', 'HEAD']:
        print('a' * 40)
    elif args[-2:] != ['status', '--porcelain']:
        raise SystemExit('unsupported fixture git command')
elif name == 'swift':
    scratch = Path(args[args.index('--scratch-path') + 1])
    triple = args[args.index('--triple') + 1]
    arch = triple.split('-')[0]
    configuration = args[args.index('--configuration') + 1]
    build = scratch / (arch + '-apple-macosx') / configuration
    build.mkdir(parents=True)
    (build / 'ModelPlanCommunityApp').write_bytes(b'synthetic App executable ' + arch.encode())
    resources = build / 'ModelPlanAppIntegration_ModelPlanAppIntegration.bundle'
    resources.mkdir()
    (resources / 'fixture.txt').write_text('synthetic resource')
    official = build / 'ModelPlanOfficialDock_ModelPlanOfficialDock.bundle'
    official.mkdir()
    (official / 'fixture.txt').write_text('synthetic official resource')
    dock = build / 'ModelPlanDockResources_ModelPlanDockResources.bundle'
    relative_mark = ('Resources/Marks/zai-white.svg' if os.environ.get('PACKAGING_FLAT_BUNDLE') == '1'
                     else 'Contents/Resources/Resources/Marks/zai-white.svg')
    mark = dock / relative_mark
    mark.parent.mkdir(parents=True)
    if os.environ.get('PACKAGING_NO_BETA_MARK') != '1':
        mark.write_text('synthetic beta-only mark')
    if os.environ.get('PACKAGING_DUPLICATE_BETA_MARK') == '1':
        duplicate = dock / 'other' / 'zai-white.svg'
        duplicate.parent.mkdir(parents=True)
        duplicate.write_text('synthetic duplicate')
elif name == 'xcrun':
    if args[:2] == ['lipo', '-archs']:
        print(os.environ.get('PACKAGING_ARCHS', 'arm64')); raise SystemExit(0)
    if args[:2] != ['lipo', '-create']:
        raise SystemExit('unsupported fixture xcrun command')
    split = args.index('-output')
    Path(args[split + 1]).write_bytes(b''.join(Path(p).read_bytes() for p in args[2:split]))
elif name == 'npm':
    # Synthetic canonical cockpit editions; the real build and pin check run in CI (u11-native).
    cockpit = Path(args[args.index('--prefix') + 1])
    for edition in ('community', 'official'):
        out = cockpit / '.tmp' / edition
        out.mkdir(parents=True, exist_ok=True)
        (out / 'index.html').write_text('synthetic ' + edition + ' cockpit')
elif name == 'python3':
    if args and args[0].endswith('/check-bundle-pins.py'):
        variable = 'PACKAGING_APP_PIN_EXIT' if '--app' in args else 'PACKAGING_PIN_EXIT'
        raise SystemExit(int(os.environ.get(variable, '0')))
    if args and args[0].endswith('/check_app_architectures.py'):
        raise SystemExit(0)
    if args and args[0].endswith('/embed_fixed_helper.py'):
        raise SystemExit(int(os.environ.get('PACKAGING_EMBED_EXIT', '0')))
    if args and args[0].endswith('/check_embedded_agent.py'):
        raise SystemExit(int(os.environ.get('PACKAGING_FINAL_CHECK_EXIT', '0')))
    if not args or not args[0].endswith('/write-consent-bundle-identity.py'):
        os.execv(os.environ['PACKAGING_REAL_PYTHON'], [os.environ['PACKAGING_REAL_PYTHON']] + args)
# Signing and verifier statuses are explicit inert boundaries here. Tests
# assert the actual shell forwards pins and propagates verifier failures;
# real universal/signature validation belongs to the canonical U7 tool tests.
'''
        for name in ['git', 'swift', 'xcrun', 'codesign', 'python3', 'npm']:
            command = self.bin / name
            command.write_text(stub)
            command.chmod(0o700)
        self.output = root / 'packaged'
        self.artifact = root / 'credential-artifact'
        self.artifact.mkdir()
        self.credential = self.artifact / 'modelplan-credential-agent'
        self.credential.write_bytes(b'synthetic credential artifact; not a Mach-O or signing proof')
        self.credential_sha = hashlib.sha256(self.credential.read_bytes()).hexdigest()
        (self.artifact / 'credential-agent.json').write_text(json.dumps({
            'schemaVersion': 1, 'sha256': self.credential_sha, 'bytes': self.credential.stat().st_size,
            'inputSHA256': 'b' * 64, 'bundleIdentifier': 'ai.modelplan.credential-agent'}))

    def run(self, *, arguments=(), environment=None):
        env = {'PATH': str(self.bin) + ':/usr/bin:/bin', 'HOME': str(self.home),
               'TMPDIR': str(self.root), 'LANG': 'en_US.UTF-8',
               'PACKAGING_COMMAND_LOG': str(self.log), 'PACKAGING_REAL_PYTHON': sys.executable,
               'MODELPLAN_CREDENTIAL_AGENT_ARTIFACT': str(self.artifact),
               'MODELPLAN_CREDENTIAL_AGENT_SHA256': self.credential_sha}
        for key, value in (environment or {}).items():
            if value is None:
                env.pop(key, None)
            else:
                env[key] = value
        return subprocess.run(['/bin/bash', str(self.script), str(self.archives), str(self.output), *arguments],
                              env=env, capture_output=True, text=True, timeout=15)

    def commands(self):
        return [json.loads(line) for line in self.log.read_text().splitlines()]

    @staticmethod
    def snapshot(paths):
        return {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}


class PackageNeutralHookTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.fixture = PackageNeutralFixture(Path(self.temp.name))

    def test_current_script_orchestration_orders_identity_before_outer_seal(self):
        inputs = list(self.fixture.archives.iterdir()) + list(self.fixture.artifact.iterdir())
        before = self.fixture.snapshot(inputs)
        result = self.fixture.run()
        self.assertEqual(result.returncode, 0, result.stderr)
        commands = self.fixture.commands()
        identity = next(i for i, c in enumerate(commands) if c['command'] == 'python3' and c['args'][0].endswith('/write-consent-bundle-identity.py'))
        seals = [(i, c['args'][-1]) for i, c in enumerate(commands)
                 if c['command'] == 'codesign' and '--force' in c['args']]
        self.assertEqual(len(seals), 2)
        self.assertTrue(seals[0][1].endswith('/Contents/Helpers/modelplan'))
        self.assertLess(seals[0][0], identity)
        self.assertLess(identity, seals[1][0])
        self.assertTrue(seals[1][1].endswith('/ModelPlan Community.app'))
        embed = next(i for i, c in enumerate(commands) if c['command'] == 'python3' and c['args'][0].endswith('/embed_fixed_helper.py'))
        final = commands[-1]
        self.assertLess(embed, seals[1][0])
        self.assertTrue(final['args'][0].endswith('/check_embedded_agent.py'))
        self.assertIn('--single', final['args'])
        self.assertEqual(final['args'][final['args'].index('--expected-sha256') + 1], self.fixture.credential_sha)
        embed_args = commands[embed]['args']
        self.assertIn('--universal', embed_args)
        self.assertEqual(embed_args[embed_args.index('--expected-sha256') + 1], self.fixture.credential_sha)
        self.assertTrue(all(not c['args'][0].endswith('/build_fixed_helper.py') for c in commands if c['command'] == 'python3'))
        self.assertTrue(all('credential-agent' not in target for _, target in seals))
        self.assertEqual(self.fixture.snapshot(inputs), before)
        resources = self.fixture.output / 'ModelPlan Community.app' / 'Contents' / 'Resources'
        self.assertTrue((resources / 'ModelPlanOfficialDock_ModelPlanOfficialDock.bundle' / 'fixture.txt').is_file())
        self.assertFalse(list((resources / 'ModelPlanDockResources_ModelPlanDockResources.bundle').rglob('zai-white.svg')))
        self.assertTrue((resources / 'VISUAL-LICENSE.md').is_file())
        self.assertEqual((resources / 'AppIcon.icns').read_bytes(), b'icns synthetic')
        self.assertIn('<key>CFBundleIconFile</key><string>AppIcon</string>', (resources.parent / 'Info.plist').read_text())
        self.assertTrue((resources / 'THIRD-PARTY-TRADEMARKS.md').is_file())

    def test_flat_resource_bundle_excludes_beta_only_mark(self):
        result = self.fixture.run(environment={'PACKAGING_FLAT_BUNDLE': '1'})
        self.assertEqual(result.returncode, 0, result.stderr)
        bundle = self.fixture.output / 'ModelPlan Community.app' / 'Contents' / 'Resources' / 'ModelPlanDockResources_ModelPlanDockResources.bundle'
        self.assertFalse(list(bundle.rglob('zai-white.svg')))

    def test_absent_or_duplicate_beta_mark_fails_closed(self):
        for env in ({'PACKAGING_NO_BETA_MARK': '1'}, {'PACKAGING_DUPLICATE_BETA_MARK': '1'}):
            with self.subTest(environment=env):
                with tempfile.TemporaryDirectory() as folder:
                    fixture = PackageNeutralFixture(Path(folder))
                    result = fixture.run(environment=env)
                    self.assertNotEqual(result.returncode, 0)
                    self.assertIn('Expected exactly one beta-only Z.ai mark', result.stderr)
                    self.assertFalse(any(c['command'] == 'codesign' for c in fixture.commands()))

    def test_existing_output_fails_without_building_or_signing(self):
        self.fixture.output.mkdir()
        result = self.fixture.run()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('refusing overwrite', result.stderr)
        self.assertEqual(self.fixture.commands(), [])

    def test_existing_cli_pin_mismatch_fails_before_any_seal(self):
        archive = self.fixture.archives / 'modelplan_darwin_arm64.tar.gz'
        archive.write_bytes(archive.read_bytes() + b'changed')
        result = self.fixture.run()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Official CLI checksum mismatch', result.stderr)
        self.assertFalse(any(c['command'] == 'codesign' for c in self.fixture.commands()))

    def test_missing_independent_credential_pin_fails_before_build(self):
        result = self.fixture.run(environment={'MODELPLAN_CREDENTIAL_AGENT_SHA256': None})
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.fixture.commands(), [])

    def test_missing_artifact_pin_file_fails_before_build(self):
        (self.fixture.artifact / 'credential-agent.json').unlink()
        result = self.fixture.run()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.fixture.commands(), [])

    def test_mismatched_credential_pin_fails_before_build(self):
        result = self.fixture.run(environment={'MODELPLAN_CREDENTIAL_AGENT_SHA256': '0' * 64})
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Credential helper pin mismatch', result.stderr)
        self.assertEqual(self.fixture.commands(), [])

    def test_embed_verifier_failure_prevents_outer_seal(self):
        result = self.fixture.run(environment={'PACKAGING_EMBED_EXIT': '47'})
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(any(c['command'] == 'codesign' for c in self.fixture.commands()))

    def test_final_pin_verifier_failure_fails_packaging(self):
        result = self.fixture.run(environment={'PACKAGING_FINAL_CHECK_EXIT': '48'})
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.fixture.commands()[-1]['command'], 'python3')


class AppleSiliconPackageTests(unittest.TestCase):
    def test_neutral_package_builds_and_embeds_only_arm64(self):
        with tempfile.TemporaryDirectory() as root:
            fixture = PackageNeutralFixture(Path(root))
            result = fixture.run()
            self.assertEqual(result.returncode, 0, result.stderr)
            commands = fixture.commands()
            builds = [c for c in commands if c['command'] == 'swift' and 'build' in c['args']]
            self.assertEqual(len(builds), 1)
            self.assertIn('arm64-apple-macosx14.0', builds[0]['args'])
            embed = next(c for c in commands if c['command'] == 'python3' and c['args'][0].endswith('/embed_fixed_helper.py'))
            self.assertIn('--universal', embed['args'])
            check = next(c for c in commands if c['command'] == 'python3' and c['args'][0].endswith('/check_app_architectures.py'))
            self.assertEqual(check['args'][check['args'].index('--approved-helper-sha256') + 1], fixture.credential_sha)
            self.assertFalse(any(c['command'] == 'xcrun' and c['args'][:2] == ['lipo', '-create'] for c in commands))

    def test_intel_or_universal_executable_stops_before_app_seal(self):
        for archs in ('x86_64', 'arm64 x86_64', ''):
            with self.subTest(archs=archs), tempfile.TemporaryDirectory() as root:
                fixture = PackageNeutralFixture(Path(root))
                result = fixture.run(environment={'PACKAGING_ARCHS': archs})
                self.assertNotEqual(result.returncode, 0)
                self.assertIn('exactly arm64', result.stderr)
                self.assertFalse(any(c['command'] == 'codesign' for c in fixture.commands()))


class OwnerTestCockpitEntryTests(unittest.TestCase):
    """Owner D39/D-E: only --owner-test opens the cockpit entry; preflight PF-08 checks the same flag."""
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.fixture = PackageNeutralFixture(Path(self.temp.name))

    def info(self):
        import plistlib
        return plistlib.loads((self.fixture.output / 'ModelPlan Community.app/Contents/Info.plist').read_bytes())

    def test_release_and_unverified_packages_keep_the_cockpit_entry_closed(self):
        for arguments in ((), ('--unverified',)):
            with self.subTest(arguments=arguments):
                with tempfile.TemporaryDirectory() as folder:
                    self.fixture = PackageNeutralFixture(Path(folder))
                    result = self.fixture.run(arguments=arguments)
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertIs(self.info()['ModelPlanCockpitEntryEnabled'], False)
                    self.assertNotIn('ModelPlanOwnerTestBuild', self.info())
                    resources = self.fixture.output / 'ModelPlan Community.app/Contents/Resources'
                    self.assertFalse((resources / 'Cockpit').exists())
                    self.assertFalse((resources / 'build-edition.json').exists())
                    self.assertFalse(any(c['command'] == 'npm' for c in self.fixture.commands()))
                    # No generated cockpit pins: a package without the page admits none.
                    swift = [c for c in self.fixture.commands() if c['command'] == 'swift']
                    self.assertTrue(swift)
                    self.assertFalse(any('-DMODELPLAN_COCKPIT_BUILD_PINS' in c['args'] for c in swift))
                    self.assertFalse(any(c['command'] == 'python3' and c['args'][0].endswith('/check-bundle-pins.py')
                                         for c in self.fixture.commands()))

    def test_owner_test_package_opens_the_entry_with_the_pinned_official_cockpit(self):
        result = self.fixture.run(arguments=('--owner-test',))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIs(self.info()['ModelPlanCockpitEntryEnabled'], True)
        self.assertIs(self.info()['ModelPlanOwnerTestBuild'], True)
        resources = self.fixture.output / 'ModelPlan Community.app/Contents/Resources'
        self.assertEqual((resources / 'Cockpit/index.html').read_text(), 'synthetic official cockpit')
        self.assertEqual(json.loads((resources / 'build-edition.json').read_text())['edition'], 'official')
        commands = self.fixture.commands()
        checks = [i for i, c in enumerate(commands) if c['command'] == 'python3' and c['args'][0].endswith('/check-bundle-pins.py')]
        self.assertEqual(len(checks), 2)
        pins, shipped = checks
        # Pins are generated from the fresh build (never read from the tree) before the App is compiled with them.
        self.assertIn('--write', commands[pins]['args'])
        builds = [i for i, c in enumerate(commands) if c['command'] == 'npm' and c['args'][0] == 'run']
        self.assertEqual([commands[i]['args'][1] for i in builds], ['build', 'build:official'])
        self.assertLess(max(builds), pins)
        swift = [i for i, c in enumerate(commands) if c['command'] == 'swift']
        self.assertLess(pins, swift[0])
        self.assertTrue(all('-DMODELPLAN_COCKPIT_BUILD_PINS' in commands[i]['args'] for i in swift))
        # Then the finished App is checked to ship exactly that page and pin, before anything is signed.
        app_args = commands[shipped]['args']
        self.assertEqual(app_args[app_args.index('--app') + 1], str(self.fixture.output / 'ModelPlan Community.app'))
        self.assertLess(max(swift), shipped)
        self.assertLess(shipped, next(i for i, c in enumerate(commands) if c['command'] == 'codesign'))
        identity = next(c for c in commands if c['command'] == 'python3' and c['args'][0].endswith('/write-consent-bundle-identity.py'))
        self.assertEqual(identity['args'][identity['args'].index('--mode') + 1], 'unverified')

    def test_owner_test_package_stops_on_a_cockpit_pin_mismatch(self):
        result = self.fixture.run(arguments=('--owner-test',), environment={'PACKAGING_PIN_EXIT': '1'})
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(any(c['command'] in ('swift', 'codesign') for c in self.fixture.commands()))

    def test_owner_test_package_stops_when_the_app_does_not_ship_its_pinned_page(self):
        result = self.fixture.run(arguments=('--owner-test',), environment={'PACKAGING_APP_PIN_EXIT': '1'})
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue(any(c['command'] == 'swift' for c in self.fixture.commands()))
        self.assertFalse(any(c['command'] == 'codesign' for c in self.fixture.commands()))


if __name__ == '__main__':
    unittest.main()

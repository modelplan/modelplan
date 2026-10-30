# SPDX-License-Identifier: MIT
"""Shell-orchestration fixtures only; no real build, signature, helper or GUI proof.

The credential-artifact cases are added when the artifact owner supplies its
exact contract. This scaffold deliberately defines no credential artifact shape.
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
elif name == 'xcrun':
    if args[:2] != ['lipo', '-create']:
        raise SystemExit('unsupported fixture xcrun command')
    split = args.index('-output')
    Path(args[split + 1]).write_bytes(b''.join(Path(p).read_bytes() for p in args[2:split]))
elif name == 'python3':
    if not args or not args[0].endswith('/write-consent-bundle-identity.py'):
        os.execv(os.environ['PACKAGING_REAL_PYTHON'], [os.environ['PACKAGING_REAL_PYTHON']] + args)
# codesign and only the existing CLI identity writer are inert. A future
# credential verifier is executed, never silently replaced with success.
'''
        for name in ['git', 'swift', 'xcrun', 'codesign', 'python3']:
            command = self.bin / name
            command.write_text(stub)
            command.chmod(0o700)
        self.output = root / 'packaged'

    def run(self, *, arguments=(), environment=None):
        env = {'PATH': str(self.bin) + ':/usr/bin:/bin', 'HOME': str(self.home),
               'TMPDIR': str(self.root), 'LANG': 'en_US.UTF-8',
               'PACKAGING_COMMAND_LOG': str(self.log), 'PACKAGING_REAL_PYTHON': sys.executable}
        env.update(environment or {})
        return subprocess.run(['/bin/bash', str(self.script), str(self.archives), str(self.output), *arguments],
                              env=env, capture_output=True, text=True, timeout=15)

    def commands(self):
        return [json.loads(line) for line in self.log.read_text().splitlines()]

    @staticmethod
    def snapshot(paths):
        return {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}


class PackageNeutralHookScaffoldTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.fixture = PackageNeutralFixture(Path(self.temp.name))

    def test_current_script_orchestration_orders_identity_before_outer_seal(self):
        before = self.fixture.snapshot(list(self.fixture.archives.iterdir()))
        result = self.fixture.run()
        self.assertEqual(result.returncode, 0, result.stderr)
        commands = self.fixture.commands()
        identity = next(i for i, c in enumerate(commands) if c['command'] == 'python3')
        seals = [(i, c['args'][-1]) for i, c in enumerate(commands)
                 if c['command'] == 'codesign' and '--force' in c['args']]
        self.assertEqual(len(seals), 2)
        self.assertTrue(seals[0][1].endswith('/Contents/Helpers/modelplan'))
        self.assertLess(seals[0][0], identity)
        self.assertLess(identity, seals[1][0])
        self.assertTrue(seals[1][1].endswith('/ModelPlan Community.app'))
        self.assertEqual(commands[-1]['args'][:3], ['--verify', '--deep', '--strict'])
        self.assertEqual(self.fixture.snapshot(list(self.fixture.archives.iterdir())), before)

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


if __name__ == '__main__':
    unittest.main()

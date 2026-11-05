# SPDX-License-Identifier: MIT
import hashlib
import plistlib
import importlib.util
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('app_architectures', Path(__file__).with_name('check_app_architectures.py'))
arch = importlib.util.module_from_spec(spec); spec.loader.exec_module(arch)


class BundleArchitectureTests(unittest.TestCase):
    def test_only_pinned_credential_helper_may_be_universal(self):
        with tempfile.TemporaryDirectory() as directory:
            app = Path(directory) / 'Synthetic.app'
            main = app / 'Contents/MacOS/app'; cli = app / 'Contents/Helpers/modelplan'
            credential = app / 'Contents/Helpers/modelplan-credential-agent'
            main.parent.mkdir(parents=True); cli.parent.mkdir(parents=True)
            (app / 'Contents/Info.plist').write_bytes(plistlib.dumps({'CFBundleIdentifier': 'synthetic.test'}))
            main.write_bytes(b'\xcf\xfa\xed\xfeapp'); cli.write_bytes(b'\xcf\xfa\xed\xfecli')
            credential.write_bytes(b'\xca\xfe\xba\xbeapproved')
            pin = hashlib.sha256(credential.read_bytes()).hexdigest()
            extra = app / 'Contents/Helpers/other'; extra.write_bytes(b'\xcf\xfa\xed\xfeother')
            def inspector(path):
                return ['arm64', 'x86_64'] if path == credential else ['arm64']
            arch.validate(app, main, cli, pin, inspector)
            with self.assertRaisesRegex(ValueError, 'pin'):
                arch.validate(app, main, cli, '0'*64, inspector)
            def other_universal(path):
                return ['arm64', 'x86_64'] if path in (credential, extra) else ['arm64']
            with self.assertRaisesRegex(ValueError, 'exactly arm64'):
                arch.validate(app, main, cli, pin, other_universal)
            with self.assertRaisesRegex(ValueError, 'arm64'):
                arch.validate(app, main, cli, pin, lambda path: ['x86_64'])
            extra.write_bytes(credential.read_bytes())
            with self.assertRaisesRegex(ValueError, 'exactly arm64'):
                arch.validate(app, main, cli, pin, lambda path: ['arm64', 'x86_64'] if path in (credential, extra) else ['arm64'])
            extra.unlink(); extra.symlink_to(Path(directory) / 'outside')
            with self.assertRaises(ValueError): arch.validate(app, main, cli, pin, inspector)

    def test_rejects_update_feed_and_sparkle_framework(self):
        with tempfile.TemporaryDirectory() as directory:
            app = Path(directory) / 'Synthetic.app'
            main = app / 'Contents/MacOS/app'; cli = app / 'Contents/Helpers/modelplan'
            helper = app / arch.HELPER
            main.parent.mkdir(parents=True); cli.parent.mkdir(parents=True)
            for item in (main, cli, helper): item.write_bytes(b'synthetic')
            pin = hashlib.sha256(helper.read_bytes()).hexdigest()
            info = app / 'Contents/Info.plist'
            info.write_bytes(plistlib.dumps({'SUFeedURL': 'https://example.invalid/feed'}))
            with self.assertRaisesRegex(ValueError, 'update feed'):
                arch.validate(app, main, cli, pin, lambda _: ['arm64'])
            info.write_bytes(plistlib.dumps({}))
            (app / 'Contents/Frameworks/Sparkle.framework').mkdir(parents=True)
            with self.assertRaisesRegex(ValueError, 'Sparkle'):
                arch.validate(app, main, cli, pin, lambda _: ['arm64'])

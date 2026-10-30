# SPDX-License-Identifier: MIT
import copy
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('notices', ROOT / 'scripts/third-party-notices.py')
notices = importlib.util.module_from_spec(spec)
spec.loader.exec_module(notices)


class NoticeCoverageTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.entries = json.loads((ROOT / notices.CATALOG).read_text())['components']
        cls.go = notices.go_inventory(ROOT)
        cls.files = notices.git_files(ROOT)

    def test_real_release_graph_coverage_rejects_removed_module(self):
        entries = [e for e in self.entries if e['id'] != 'go:github.com/mattn/go-isatty']
        # This dependency is not in Linux's CGO-disabled graph; the release union
        # must still require its notice for macOS/Windows binaries.
        with self.assertRaisesRegex(ValueError, 'go-module notice coverage mismatch.*go-isatty'):
            notices.check(ROOT, entries, self.files, self.go)

    def test_go_version_bump_cannot_reuse_old_notice(self):
        go = copy.deepcopy(self.go)
        go['github.com/google/uuid']['version'] = 'v99.0.0'
        with self.assertRaisesRegex(ValueError, 'notice version drift'):
            notices.check(ROOT, self.entries, self.files, go)

    def test_changed_licence_bytes_are_rejected(self):
        entries = copy.deepcopy(self.entries)
        entries[0]['licenseFiles'][0]['sha256'] = '0' * 64
        with self.assertRaisesRegex(ValueError, 'licence bytes drift'):
            notices.check(ROOT, entries, self.files, self.go)

    def test_font_copyright_and_helper_pin_cannot_drift(self):
        for id, field, replacement, message in [('font:manrope', 'copyright', ['missing author'], 'font attribution drift'),
                                               ('codexbar', 'version', '0.0.0', 'CodexBar pin drift')]:
            with self.subTest(id=id):
                entries = copy.deepcopy(self.entries)
                next(e for e in entries if e['id'] == id)[field] = replacement
                with self.assertRaisesRegex(ValueError, message):
                    notices.check(ROOT, entries, self.files, self.go)

    def test_swift_pin_formats_require_notices_and_full_revisions(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for version in (1, 2, 3):
                state = dict(version='1.2.3', revision='a' * 40)
                pin = dict(identity='example', location='https://github.com/example/library.git', state=state)
                data = dict(version=version, pins=[pin])
                if version == 1:
                    data = dict(version=1, object=dict(pins=[dict(package='Example', repositoryURL=pin['location'], state=state)]))
                (root / 'Package.resolved').write_text(json.dumps(data))
                inventory = notices.swift_inventory(root, ['Package.resolved'])
                with self.assertRaisesRegex(ValueError, 'swift-package notice coverage mismatch'):
                    notices.coverage([], inventory, 'swift-package')
                self.assertEqual(next(iter(inventory.values()))['revision'], 'a' * 40)

    def test_first_remote_swift_dependency_cannot_omit_its_lock(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'Package.swift').write_text('.package(url: "https://github.com/example/library", from: "1.0.0")')
            with self.assertRaisesRegex(ValueError, 'committed Package.resolved'):
                notices.swift_inventory(root, ['Package.swift'])

    def test_new_vendored_three_pulse_and_apache_files_require_explicit_coverage(self):
        samples = [('desktop/vendor/three.module.min.js', '/* three.js */'),
                   ('desktop/native/pulse/Panel.swift', '// adapted geometry'),
                   ('desktop/native/Panel.swift', '// SPDX-License-Identifier: Apache-2.0'),
                   ('desktop/native/PanelHeader.swift', '// Apache-2.0\nimport AppKit')]
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for path, content in samples:
                f = root / path
                f.parent.mkdir(parents=True, exist_ok=True)
                f.write_text(content)
                with self.subTest(path=path), self.assertRaisesRegex(ValueError, 'vendored source missing notice'):
                    notices.vendored_coverage(root, [path], self.entries)

    def test_existing_kiro_port_cannot_lose_its_pulse_entry(self):
        with self.assertRaisesRegex(ValueError, 'vendored source missing notice: cli/internal/quota/kiro.go'):
            notices.vendored_coverage(ROOT, ['cli/internal/quota/kiro.go'], [e for e in self.entries if e['id'] != 'pulse'])

    def test_generated_cli_view_preserves_existing_licences(self):
        output = notices.render(ROOT, self.entries)
        cli = output['cli/THIRD-PARTY-NOTICES.md']
        for e in self.entries:
            if e['kind'] in ('go-module', 'source-port', 'helper'):
                for item in e['licenseFiles']:
                    self.assertIn((ROOT / notices.BASE / item['path']).read_text().rstrip('\n'), cli)


if __name__ == '__main__':
    unittest.main()

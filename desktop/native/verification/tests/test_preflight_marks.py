# SPDX-License-Identifier: MIT
"""PF-07's Z.ai mark policy against apps built by the real producers (macrevb-567-6).

The neutral app comes from running the actual desktop/native/tools/package-neutral.sh through its
shell-orchestration fixture (synthetic toolchain, no real build); the beta app is that output after the
actual release.py configure_beta_zai, with the repository's real Dock resource manifest and mark.
"""
import hashlib
import io
import json
from pathlib import Path
import shutil
import sys
import tempfile
import unittest
import zipfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
sys.path.insert(0, str(HERE))
from verify_fixtures import SHA, FakeHost, manifest  # noqa: E402
import preflight  # noqa: E402
import importlib.util  # noqa: E402


def load(name, path):
    # By file path: the distribution folder is not put on sys.path, where its module names
    # (release, test_release) would shadow verification modules during test discovery.
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
    return module


DISTRIBUTION = ROOT / 'desktop/native/tools/distribution'
release = load('distribution_release', DISTRIBUTION / 'release.py')
PackageNeutralFixture = load('distribution_package_neutral_hook',
                             DISTRIBUTION / 'test_package_neutral_hook.py').PackageNeutralFixture

NAME = f'native-app-unverified-{SHA}'
DOCK = 'ModelPlanDockResources_ModelPlanDockResources.bundle'
REAL_RESOURCES = ROOT / 'desktop/third-party/dock-resources/Resources'


def zip_app(app):
    """Like the workflow's `ditto -c -k --keepParent`: files and directory entries."""
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, 'w') as archive:
        for path in sorted([app, *app.rglob('*')]):
            archive.write(path, str(path.relative_to(app.parent)) + ('/' if path.is_dir() else ''))
    return buffer.getvalue()


def artifact(directory, inner):
    build = f'sourceSHA={SHA}\nrunID=42\nrunAttempt=1\n{hashlib.sha256(inner).hexdigest()}  {preflight.INNER}\n'
    path = Path(directory) / (NAME + '.zip')
    with zipfile.ZipFile(path, 'w') as archive:
        archive.writestr('BUILD.txt', build)
        archive.writestr(preflight.INNER, inner)
    return 'sha256:' + hashlib.sha256(path.read_bytes()).hexdigest()


class ProducerShapedMarkTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / 'pack').mkdir()
        fixture = PackageNeutralFixture(self.root / 'pack')
        result = fixture.run()
        self.assertEqual(result.returncode, 0, result.stderr)  # the actual packager shell succeeded
        self.app = fixture.output / 'ModelPlan Community.app'
        self.bundle = self.app / 'Contents/Resources' / DOCK
        self.count = 0

    def pf07(self, inner):
        self.count += 1
        artifacts = self.root / f'artifacts{self.count}'; artifacts.mkdir()
        digest = artifact(artifacts, inner)
        receipt = preflight.run(manifest(digest), lane='V1', layout='single', ids=['D-01', 'V-01'],
                                artifacts_dir=artifacts, work=self.root / f'work{self.count}',
                                scratch_parent=self.root, host=FakeHost(digest))
        return [c for c in receipt['checks'] if c['id'] == 'PF-07']

    def beta(self, enabled=True):
        # The Dock bundle as SwiftPM ships it carries the resource manifest and vendor notes; the
        # neutral packager removed only the mark. The beta producer then restores it from the source.
        resources = self.bundle / 'Contents/Resources/Resources'
        shutil.copyfile(REAL_RESOURCES / 'manifest.json', resources / 'manifest.json')
        shutil.copyfile(REAL_RESOURCES / 'Marks/SOURCES.md', resources / 'Marks/SOURCES.md')
        release.configure_beta_zai(self.app, source_root=ROOT, zaiMarkEnabled=enabled)
        return resources / 'Marks/zai-white.svg'

    def test_neutral_packager_output_passes_pf07(self):
        self.assertEqual(list(self.bundle.rglob('zai-white.svg')), [])  # the packager removed the mark
        checks = self.pf07(zip_app(self.app))
        self.assertEqual([c['status'] for c in checks], ['PASS'], checks)

    def test_neutral_output_with_a_mark_put_back_is_refused(self):
        mark = self.bundle / 'Contents/Resources/Resources/Marks/zai-white.svg'
        mark.write_bytes((REAL_RESOURCES / 'Marks/zai-white.svg').read_bytes())
        checks = self.pf07(zip_app(self.app))
        self.assertEqual(checks[0]['status'], 'FAIL')
        self.assertIn('without zaiMarkEnabled', checks[0]['detail'])

    def test_beta_producer_output_passes_pf07(self):
        self.assertTrue(self.beta().is_file())
        checks = self.pf07(zip_app(self.app))
        self.assertEqual([c['status'] for c in checks], ['PASS'], checks)

    def test_beta_producer_with_the_mark_disabled_passes_without_a_mark(self):
        self.assertFalse(self.beta(enabled=False).exists())
        self.assertEqual([c['status'] for c in self.pf07(zip_app(self.app))], ['PASS'])

    def test_beta_mark_with_altered_bytes_or_a_duplicate_is_refused(self):
        mark = self.beta()
        mark.write_bytes(mark.read_bytes() + b' ')
        checks = self.pf07(zip_app(self.app))
        self.assertIn('do not match the manifest record', checks[0]['detail'])
        mark.write_bytes((REAL_RESOURCES / 'Marks/zai-white.svg').read_bytes())
        (self.bundle / 'other').mkdir()
        (self.bundle / 'other/zai-white.svg').write_bytes(mark.read_bytes())
        checks = self.pf07(zip_app(self.app))
        self.assertIn('2 zai-white.svg marks with zaiMarkEnabled', checks[0]['detail'])

    def test_missing_bundle_or_altered_helper_still_fails(self):
        helper = self.app / 'Contents/Helpers/modelplan'
        helper.write_bytes(helper.read_bytes() + b'x')
        self.assertIn('does not match', self.pf07(zip_app(self.app))[0]['detail'])
        shutil.rmtree(self.app / 'Contents/Resources/ModelPlanOfficialDock_ModelPlanOfficialDock.bundle')
        self.assertIn('missing ModelPlanOfficialDock', self.pf07(zip_app(self.app))[0]['detail'])


if __name__ == '__main__':
    unittest.main()

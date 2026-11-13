# SPDX-License-Identifier: MIT
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[2] / 'ModelPlanCockpitWeb/check-bundle-pins.py'
spec = importlib.util.spec_from_file_location('bundle_pin_guard', SCRIPT)
guard = importlib.util.module_from_spec(spec)
spec.loader.exec_module(guard)

PNG = b'\x89PNG\r\n\x1a\n\0synthetic reserved raster'


def build(root, edition, extra=None):
    """A synthetic canonical edition exactly as build.mjs lays it out."""
    directory = root / 'desktop/cockpit/.tmp' / edition
    shutil.rmtree(directory, ignore_errors=True)
    directory.mkdir(parents=True)
    files = {'index.html': b'public synthetic HTML'}
    files.update(extra or {})
    for name, body in files.items():
        (directory / name).parent.mkdir(parents=True, exist_ok=True)
        (directory / name).write_bytes(body)
    manifest = json.dumps(dict(schemaVersion=1, edition=edition, interfaceOnly=True,
                               files={k: hashlib.sha256(v).hexdigest() for k, v in files.items()})).encode()
    (directory / 'bundle-manifest.json').write_bytes(manifest)
    return hashlib.sha256(manifest).hexdigest()


class BundlePinGuardTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.register = {}
        self.write_policy()
        self.factory = self.root / guard.FACTORY
        self.factory.parent.mkdir(parents=True)
        self.factory.write_text('    public static let manifestPins = CockpitBuildPins.manifest\n')
        self.pins = {edition: build(self.root, edition) for edition in guard.EDITIONS}

    def write_policy(self):
        (self.root / 'source-policy.json').write_text(json.dumps({'reservedVisuals': {'prefix': 'desktop/reserved/', 'binaries': self.register}}))

    def test_write_generates_the_pins_of_the_build_and_check_accepts_them(self):
        self.assertEqual([x['manifestSHA256'] for x in guard.write(self.root)], [self.pins['community'], self.pins['official']])
        generated = (self.root / guard.GENERATED).read_text()
        self.assertIn('extension CockpitBuildPins {', generated)
        for edition, pin in self.pins.items():
            self.assertIn('"%s": "%s",' % (edition, pin), generated)
        self.assertEqual([x['files'] for x in guard.check(self.root)], [1, 1])

    def test_check_rejects_a_missing_or_stale_generated_file(self):
        with self.assertRaises(ValueError):
            guard.check(self.root)
        guard.write(self.root)
        build(self.root, 'official', {'src/view.js': b'changed after the pins were written'})
        with self.assertRaises(ValueError):
            guard.check(self.root)

    def test_committed_pin_literals_are_rejected(self):
        self.factory.write_text('static let manifestPins = [\n "official":"%s",\n]\n' % self.pins['official'])
        for step in (guard.write, guard.check):
            with self.assertRaises(ValueError):
                step(self.root)

    def test_rejects_orphan_and_linked_output(self):
        (self.root / 'desktop/cockpit/.tmp/official/orphan.js').write_text('orphan')
        with self.assertRaises(ValueError):
            guard.write(self.root)
        (self.root / 'desktop/cockpit/.tmp/official/orphan.js').unlink()
        (self.root / 'desktop/cockpit/.tmp/official/linked.js').symlink_to('index.html')
        with self.assertRaises(ValueError):
            guard.write(self.root)

    def test_official_reserved_binaries_must_be_registered_and_unchanged(self):
        source = self.root / 'desktop/reserved/runtime/scene/plate.png'
        source.parent.mkdir(parents=True)
        source.write_bytes(PNG)
        build(self.root, 'official', {'runtime/scene/plate.png': PNG})
        with self.assertRaisesRegex(ValueError, 'not in the register'):
            guard.write(self.root)
        self.register['desktop/reserved/runtime/scene/plate.png'] = hashlib.sha256(PNG).hexdigest()
        self.write_policy()
        guard.write(self.root)
        source.write_bytes(PNG + b'edited')
        with self.assertRaisesRegex(ValueError, 'reserved source'):
            guard.write(self.root)

    def reserve(self, origin, data, registered=True):
        source = self.root / 'desktop/reserved' / origin
        source.parent.mkdir(parents=True, exist_ok=True)
        source.write_bytes(data)
        if registered:
            self.register['desktop/reserved/' + origin] = hashlib.sha256(data).hexdigest()
            self.write_policy()

    def test_bell_hull_and_logo_outputs_map_to_their_reserved_sources(self):
        outputs = {
            'assets/bells/bell-night-2x.png': ('cockpit/bells/assets/bell-night-2x.png', PNG + b'bell'),
            'assets/hull/taper-890-1x.png': ('cockpit/hull/assets/taper-890-1x.png', PNG + b'hull'),
            'assets/hull/lower-stage-640-2x.png': ('cockpit/hull/assets/lower-stage-640-2x.png', PNG + b'stage'),
            'assets/bells/SOURCES.md': ('cockpit/bells/SOURCES.md', b'bell sources'),
            'assets/hull/SOURCES.md': ('cockpit/hull/SOURCES.md', b'hull sources'),
            'assets/logo.svg': ('logo.svg', b'<svg>logo</svg>'),
        }
        for origin, data in outputs.values():
            self.reserve(origin, data, registered=not guard.is_text(data))
        build(self.root, 'official', {name: data for name, (_, data) in outputs.items()})
        guard.write(self.root)
        for name, (origin, data) in outputs.items():
            self.reserve(origin, data + b'edited', registered=False)
            with self.assertRaisesRegex(ValueError, 'reserved source: ' + name):
                guard.write(self.root)
            self.reserve(origin, data, registered=False)

    def test_new_mappings_still_require_register_entries(self):
        self.reserve('cockpit/hull/assets/taper-890-1x.png', PNG, registered=False)
        build(self.root, 'official', {'assets/hull/taper-890-1x.png': PNG})
        with self.assertRaisesRegex(ValueError, 'not in the register: desktop/reserved/cockpit/hull/assets/taper-890-1x.png'):
            guard.write(self.root)

    def test_a_later_non_matching_source_does_not_override_an_earlier_match(self):
        # 'assets/' also matches the bell output, but its strip source holds other bytes: the first match must settle it.
        self.reserve('cockpit/bells/assets/bell-night-2x.png', PNG)
        self.reserve('cockpit/strip/assets/bells/bell-night-2x.png', PNG + b'other', registered=False)
        build(self.root, 'official', {'assets/bells/bell-night-2x.png': PNG})
        guard.write(self.root)

    def test_plain_assets_still_map_to_the_strip_sources(self):
        self.reserve('cockpit/strip/assets/rocket.png', PNG)
        build(self.root, 'official', {'assets/rocket.png': PNG})
        guard.write(self.root)

    def test_third_party_marks_are_outside_the_register(self):
        build(self.root, 'official', {'assets/brands/openai-white.svg': b'<svg/>', 'assets/SOURCES.md': b'sources'})
        guard.write(self.root)

    def test_community_must_not_ship_a_registered_reserved_binary(self):
        self.register['desktop/reserved/icons/x.png'] = hashlib.sha256(PNG).hexdigest()
        self.write_policy()
        build(self.root, 'community', {'leak.png': PNG})
        with self.assertRaisesRegex(ValueError, 'Community edition ships a reserved visual'):
            guard.write(self.root)

    def package(self, pin):
        app = self.root / 'ModelPlan Community.app'
        shutil.rmtree(app, ignore_errors=True)
        (app / 'Contents/MacOS').mkdir(parents=True)
        shutil.copytree(self.root / 'desktop/cockpit/.tmp/official', app / 'Contents/Resources/Cockpit')
        (app / 'Contents/Resources/build-edition.json').write_text('{"edition": "official", "stage": "owner-test"}')
        (app / 'Contents/MacOS/ModelPlanCommunity').write_bytes(b'\0synthetic executable\0' + pin.encode() + b'\0')
        return app

    def test_packaged_app_must_ship_the_built_edition_and_carry_its_pin(self):
        guard.write(self.root)
        app = self.package(self.pins['official'])
        self.assertEqual(guard.check_app(self.root, app)['manifestSHA256'], self.pins['official'])
        (app / 'Contents/Resources/Cockpit/index.html').write_bytes(b'tampered')
        with self.assertRaises(ValueError):
            guard.check_app(self.root, app)
        app = self.package(self.pins['community'])
        with self.assertRaisesRegex(ValueError, 'does not carry the build pin'):
            guard.check_app(self.root, app)


if __name__ == '__main__':
    unittest.main()

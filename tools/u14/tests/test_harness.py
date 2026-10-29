# SPDX-License-Identifier: MIT
import copy
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from shape_home import build_home, SETTINGS_PATHS
from candidate import generate_bundle
from contracts import load_json, validate


class ShapeTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.shape = load_json(ROOT / 'examples/synthetic-shape.json')

    def build(self, case='coexistence'):
        home = self.root / case
        return home, build_home(self.shape, home, case)

    def test_shape_builds_three_independent_preferences_and_no_owner_values(self):
        home, report = self.build()
        beta, native, core = [load_json(home / p) for p in SETTINGS_PATHS]
        self.assertEqual(beta['preferences']['dockEdge'], 'left')
        self.assertEqual(native['preferences']['dockEdge'], 'right')
        self.assertNotEqual(beta['preferences']['theme'], native['preferences']['theme'])
        self.assertEqual(core['localeIdentifier'], 'en_US')
        self.assertIn('readerConsent', beta['preferences'])
        self.assertFalse((home / 'Library/Application Support/ModelPlan/settings.json').exists())
        self.assertEqual(report['fidelity'], 'hand-built')
        self.assertTrue(report['knownGaps'])
        self.assertEqual(load_json(home / '.config/modelplan/consent.json')['tools']['claude']['keychain'], 'unset')
        self.assertEqual(load_json(home / '.claude/settings.json'), {'env': {'SYNTHETIC_SETTING': 'synthetic'}})
        self.assertEqual((home / '.claude/.credentials.json').stat().st_mode & 0o777, 0o600)
        self.assertEqual(subprocess.run([str(home / 'bin/codex')], capture_output=True).returncode, 69)
        self.assertEqual(report['availableCapabilities'], ['synthetic-home', 'consent-v1', 'preference-inputs'])

    def test_preference_cases_are_inputs_with_expected_groups_not_fake_migration(self):
        for case, settings_source, core_source in [
            ('coexistence', 'beta07', 'core'), ('corrupt-beta07', 'native', 'core'),
            ('missing-beta07', 'native', 'core'), ('corrupt-native', 'beta07', 'core'),
            ('corrupt-core', 'beta07', 'defaults'), ('all-corrupt', 'defaults', 'defaults'),
            ('fresh', 'defaults', 'defaults'), ('new-exists', 'new', 'new'),
            ('corrupt-new', 'defaults', 'defaults')]:
            with self.subTest(case=case):
                home, report = self.build(case)
                self.assertEqual(report['migrationOracle']['officialSettingsSource'], settings_source)
                self.assertEqual(report['migrationOracle']['coreSource'], core_source)
                if case == 'corrupt-beta07':
                    with self.assertRaises(json.JSONDecodeError):
                        load_json(home / SETTINGS_PATHS[0])
                if case == 'corrupt-new':
                    self.assertEqual((home / 'Library/Application Support/ModelPlan/settings.json').read_text(), '{synthetic-corrupt\n')

    def test_consent_states_and_shape_contract_rejections(self):
        for state in ('missing', 'corrupt'):
            shape = copy.deepcopy(self.shape)
            shape['consent']['state'] = state
            home = self.root / state
            report = build_home(shape, home)
            self.assertNotIn('consent-v1', report['availableCapabilities'])
            path = home / '.config/modelplan/consent.json'
            if state == 'missing':
                self.assertFalse(path.exists())
            else:
                with self.assertRaises(json.JSONDecodeError):
                    load_json(path)
        for mutate in [lambda s: s['files'][0].pop('shape'),
                       lambda s: s['files'][1].update(shape={'kind': 'string'}),
                       lambda s: s.update(fidelity='approved-shape-export'),
                       lambda s: s['consent']['tools'].update({'../escape': 'allowed'})]:
            shape = copy.deepcopy(self.shape)
            mutate(shape)
            with self.assertRaises(ValueError):
                build_home(shape, self.root / 'invalid')
            self.assertFalse((self.root / 'invalid').exists())

    def test_deterministic_and_refuses_existing_destination_or_symlink_parent(self):
        a, ar = self.build()
        b = self.root / 'second'
        br = build_home(self.shape, b, 'coexistence')
        self.assertEqual(ar, br)
        for p in a.rglob('*'):
            if p.is_file():
                self.assertEqual(p.read_bytes(), (b / p.relative_to(a)).read_bytes())
        with self.assertRaises((ValueError, FileExistsError)):
            build_home(self.shape, a, 'coexistence')
        (self.root / 'link').symlink_to(self.root, target_is_directory=True)
        with self.assertRaises(ValueError):
            build_home(self.shape, self.root / 'link/escape', 'coexistence')
        self.assertFalse((self.root / 'escape').exists())

    def test_rejects_value_bearing_shape_and_traversal_before_writing(self):
        for modify in [
            lambda s: s.update(token='TOKEN-CANARY'),
            lambda s: s['files'][0].update(path='../escape'),
            lambda s: s['files'][0].update(path='/tmp/escape'),
            lambda s: s['files'][0].update(path=SETTINGS_PATHS[0]),
            lambda s: s['files'][0].update(shape={'kind': 'string', 'value': 'TOKEN-CANARY'}),
            lambda s: s['tools'].append('../escape'),
        ]:
            s = copy.deepcopy(self.shape)
            modify(s)
            with self.subTest(shape=s), self.assertRaises(ValueError):
                build_home(s, self.root / 'invalid', 'coexistence')
            self.assertFalse((self.root / 'invalid').exists())


class CandidateTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        subprocess.run(['git', 'init', '-q', str(self.root / 'source')], check=True)
        self.source = self.root / 'source'
        (self.source / 'public.txt').write_text('synthetic source')
        for args in [['add', '.'], ['-c', 'user.name=Synthetic', '-c', 'user.email=synthetic@example.invalid', 'commit', '-qm', 'Synthetic']]:
            subprocess.run(['git', '-C', str(self.source), *args], check=True)
        self.artifact = self.root / 'App'
        self.artifact.mkdir()
        (self.artifact / 'binary').write_bytes(b'synthetic-app')
        self.helper = self.root / 'helper'
        self.helper.write_bytes(b'synthetic-helper')
        self.evidence = self.root / 'check.json'
        self.evidence.write_text('{"synthetic":true}\n')
        self.shape = build_home(load_json(ROOT / 'examples/synthetic-shape.json'), self.root / 'home', 'coexistence')
        self.spec = {
            'schemaVersion': 1, 'candidateId': 'synthetic-1', 'profile': 'engine-only',
            'intendedLevel': 'L1', 'build': {'type': 'community', 'configuration': 'release'},
            'sources': [{'repository': 'example/public', 'path': str(self.source)}],
            'artifacts': {'app': str(self.artifact), 'helper': str(self.helper),
                          'helperVersion': 'synthetic-v1', 'officialVisualsManifest': None, 'visualBaselines': []},
            'publicationRevision': None,
            'display': {'state': 'unsupported'},
            'availableCapabilities': ['engine'],
            'results': [{'id': 'A03', 'outcome': 'pass', 'evidence': [str(self.evidence)]}],
        }

    def generate(self):
        return generate_bundle(self.spec, self.shape, self.root / 'bundle')

    def test_missing_capability_becomes_unsupported_and_unrun_stays_not_run(self):
        m = self.generate()
        outcomes = {s['id']: s for s in m['scenarios']}
        self.assertEqual(outcomes['A03']['outcome'], 'unsupported')
        self.assertIn('native-ui', outcomes['A03']['missingCapabilities'])
        self.assertEqual(outcomes['U2a-admission']['outcome'], 'unsupported')
        self.assertEqual(m['artifacts']['officialVisualsManifest']['state'], 'unsupported')
        self.assertEqual(m['publicationData']['state'], 'unsupported')
        self.assertEqual(m['sources'][0]['sha'], subprocess.check_output(['git', '-C', str(self.source), 'rev-parse', 'HEAD'], text=True).strip())
        validate(m, 'candidate-manifest.schema.json')
        self.assertFalse(any(str(self.root) in json.dumps(v) for v in m.values()))

    def test_hashes_bind_app_helper_and_copied_evidence(self):
        self.spec['availableCapabilities'] += ['native-ui']
        m = self.generate()
        self.assertEqual(m['artifacts']['helper']['sha256'], hashlib.sha256(b'synthetic-helper').hexdigest())
        self.assertEqual(m['artifacts']['app']['kind'], 'tree')
        record = next(x for x in m['scenarios'] if x['id'] == 'A03')
        self.assertEqual(record['outcome'], 'pass')
        for e in record['evidence']:
            p = self.root / 'bundle' / e['ref']
            self.assertEqual(hashlib.sha256(p.read_bytes()).hexdigest(), e['sha256'])
        with self.assertRaises((ValueError, FileExistsError)):
            self.generate()

    def test_available_unexecuted_scenario_and_all_outcome_terms(self):
        self.spec['availableCapabilities'] += ['native-ui', 'recording-transport', 'fake-providers', 'app-server']
        self.spec['results'] = [
            {'id': id, 'outcome': outcome, 'evidence': [str(self.evidence)] if outcome in ('pass', 'fail', 'timeout') else []}
            for id, outcome in [('A03', 'pass'), ('A04', 'fail'), ('A05', 'not-run'), ('A07', 'unsupported'), ('A13', 'timeout')]]
        m = self.generate()
        outcomes = {s['id']: s['outcome'] for s in m['scenarios']}
        self.assertEqual([outcomes[x] for x in ('A03', 'A04', 'A05', 'A07', 'A13')], ['pass', 'fail', 'not-run', 'unsupported', 'timeout'])
        self.assertEqual(outcomes['A01'], 'not-run')

    def test_rejects_unbound_pass_unknown_scenario_dirty_repo_and_bad_schema(self):
        mutations = [lambda s: s['results'][0].update(evidence=[]),
                     lambda s: s['results'][0].update(id='invented'),
                     lambda s: s['results'].append(copy.deepcopy(s['results'][0])),
                     lambda s: s.update(unreviewed='TOKEN-CANARY')]
        for mutate in mutations:
            spec = copy.deepcopy(self.spec)
            mutate(spec)
            with self.assertRaises(ValueError):
                generate_bundle(spec, self.shape, self.root / 'bad')
            self.assertFalse((self.root / 'bad').exists())
        (self.source / 'untracked').write_text('dirty')
        with self.assertRaises(ValueError):
            self.generate()
        self.assertFalse((self.root / 'bundle').exists())

    def test_baseline_gaps_override_reported_pass(self):
        self.spec['availableCapabilities'] += ['native-ui']
        self.shape['covers'] = []
        m = self.generate()
        row = next(x for x in m['scenarios'] if x['id'] == 'A03')
        self.assertEqual(row['outcome'], 'unsupported')
        self.assertEqual(row['missingStructures'], ['tool-presence'])

    def test_app_hash_changes_on_bytes_mode_and_internal_link(self):
        from candidate import artifact
        initial = artifact(str(self.artifact), allow_tree=True)
        (self.artifact / 'binary').write_bytes(b'changed-app')
        changed = artifact(str(self.artifact), allow_tree=True)
        self.assertNotEqual(initial, changed)
        (self.artifact / 'binary').chmod(0o700)
        changed_mode = artifact(str(self.artifact), allow_tree=True)
        self.assertNotEqual(changed, changed_mode)
        (self.artifact / 'alias').symlink_to('binary')
        self.assertNotEqual(changed_mode, artifact(str(self.artifact), allow_tree=True))

    def test_complete_artifact_identity_and_second_repository(self):
        manifest_file = self.root / 'visual-manifest.json'
        manifest_file.write_text('{}')
        baseline_file = self.root / 'visual-baseline.png'
        baseline_file.write_bytes(b'synthetic-png')
        self.spec['artifacts']['officialVisualsManifest'] = str(manifest_file)
        self.spec['artifacts']['visualBaselines'] = [str(baseline_file)]
        self.spec['publicationRevision'] = 'synthetic-publication-1'
        self.spec['sources'].append({'repository': 'example/second', 'path': str(self.source)})
        self.spec['results'] = [{'id': 'A18', 'outcome': 'pass', 'evidence': [str(self.evidence)]}]
        m = self.generate()
        self.assertEqual(len(m['sources']), 2)
        self.assertEqual(m['artifacts']['officialVisualsManifest']['sha256'], hashlib.sha256(b'{}').hexdigest())
        self.assertEqual(m['publicationData']['revision'], 'synthetic-publication-1')
        self.assertEqual(next(s for s in m['scenarios'] if s['id'] == 'A18')['outcome'], 'pass')

    def test_artifact_symlink_escape_fails_closed(self):
        (self.artifact / 'escape').symlink_to(self.evidence)
        with self.assertRaises(ValueError):
            self.generate()
        self.assertFalse((self.root / 'bundle').exists())


if __name__ == '__main__':
    unittest.main()

# SPDX-License-Identifier: MIT
"""Synthetic-only H40 materializer and retained-startup oracle regressions."""
import copy
import json
from pathlib import Path
import tempfile
import unittest

import owner_shape
import test_journey as oracle_tests

journey = oracle_tests.journey

HERE = Path(__file__).parent


class OwnerShapeTests(unittest.TestCase):
    def setUp(self):
        self.shape = json.loads((HERE / 'shapes/sample.json').read_text())
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.home = Path(self.temporary.name) / 'home'

    def test_sample_recreates_exact_sizes_and_real_public_state_files(self):
        receipt = owner_shape.generate(self.shape, self.home)
        self.assertEqual(receipt['allowedTools'], ['claude', 'codex', 'grok'])
        for field, root in [('cacheTree', owner_shape.CACHE), ('configTree', owner_shape.CONFIG)]:
            for entry in self.shape[field]['entries']:
                self.assertEqual((self.home / root / entry['path']).stat().st_size, entry['bytes'])
        consent = json.loads((self.home / owner_shape.CONFIG / 'consent.json').read_text())
        self.assertEqual(consent['generation'], 37)
        self.assertEqual(consent['privacy'], 'automatic')
        self.assertEqual({k for k, v in consent['tools'].items() if v['allowed']}, {'codex', 'claude', 'grok'})
        self.assertEqual(consent['tools']['claude']['keychain'], 'allowed')
        connections = json.loads((self.home / owner_shape.CONFIG / 'connections.json').read_text())
        self.assertEqual(connections['quotaSources'], [dict(provider='zai', backend='native', enabled=True)])
        prefs = json.loads((self.home / owner_shape.PREFERENCES / 'community-v1.json').read_text())
        self.assertEqual(prefs['schemaVersion'], 1)
        self.assertEqual(prefs['edge'], 'left')
        self.assertIs(type(prefs['retained']), bool); self.assertIs(type(prefs['revision']), int)
        dock = json.loads((self.home / owner_shape.PREFERENCES / 'settings-v1.json').read_text())
        self.assertEqual(dock['preferences']['dockEdge'], 'left')
        saved = json.loads((self.home / owner_shape.CACHE / 'observed/keychain/claude-code.json').read_text())
        self.assertEqual(saved, {'state': 'keychain-confirmation-needed'})
        self.assertFalse((self.home / '.claude/.credentials.json').exists())
        self.assertEqual((self.home / owner_shape.CACHE / 'retained-volume.bin').read_bytes(), bytes(1048576))
        self.assertTrue(receipt['limitations'])
        for path in self.home.rglob('*'):
            if path.is_file(): self.assertEqual(path.stat().st_mode & 0o777, 0o600)

    def test_placeholder_exists_only_when_recorded_and_is_empty(self):
        self.shape['claudeCredentialsFileExists'] = True
        owner_shape.generate(self.shape, self.home)
        self.assertEqual((self.home / '.claude/.credentials.json').read_bytes(), b'')

    def test_never_reads_or_overwrites_an_existing_home_or_symlink(self):
        self.home.mkdir(); marker = self.home / 'canary'; marker.write_text('do not change')
        with self.assertRaises(ValueError): owner_shape.generate(self.shape, self.home)
        self.assertEqual(marker.read_text(), 'do not change')
        link = Path(self.temporary.name) / 'link'; link.symlink_to(self.home)
        with self.assertRaises(ValueError): owner_shape.generate(self.shape, link)

    def test_unsafe_and_incomplete_shapes_fail_before_creating_home(self):
        variants = []
        for path in ['../escape', '/absolute', 'a/../../escape', 'a\\b', 'a//b']:
            bad = copy.deepcopy(self.shape); bad['cacheTree']['entries'][0]['path'] = path; variants.append(bad)
        for update in [dict(files=4), dict(bytes=0)]:
            bad = copy.deepcopy(self.shape); bad['cacheTree'].update(update); variants.append(bad)
        bad = copy.deepcopy(self.shape); bad['configTree']['entries'][0]['bytes'] = 1; bad['configTree']['bytes'] = 1025; variants.append(bad)
        bad = copy.deepcopy(self.shape); bad['consent']['generation'] = True; variants.append(bad)
        bad = copy.deepcopy(self.shape); bad['claudeKeychainSavedState'] = 'canary-secret'; variants.append(bad)
        bad = copy.deepcopy(self.shape); bad['appPreferences']['shape']['retained'] = 'canary-secret'; variants.append(bad)
        bad = copy.deepcopy(self.shape); bad['cliDesktopReadOnly']['connections'] = []; variants.append(bad)
        for shape in variants:
            with self.subTest(shape=variants.index(shape)):
                with self.assertRaises((ValueError, TypeError)): owner_shape.generate(shape, self.home)
                self.assertFalse(self.home.exists())

    def test_nested_array_expansion_is_bounded(self):
        shape = 'string'
        for _ in range(4): shape = {'<array>': 100, 'item': shape}
        with self.assertRaises(ValueError): owner_shape.materialize(shape, set())

    def test_absent_and_unreadable_files_stay_absent_or_invalid(self):
        self.shape.update(consent=dict(status='missing'), connections=dict(status='unreadable'),
                          configTree=dict(exists=True, files=1, bytes=2048, entries=[dict(path='connections.json', bytes=2048)]),
                          appPreferences=dict(status='missing'))
        owner_shape.generate(self.shape, self.home)
        self.assertFalse((self.home / owner_shape.CONFIG / 'consent.json').exists())
        with self.assertRaises(ValueError): json.loads((self.home / owner_shape.CONFIG / 'connections.json').read_text())
        self.assertFalse((self.home / owner_shape.PREFERENCES / 'community-v1.json').exists())

    def test_export_redaction_is_reported_and_cannot_invent_saved_placement(self):
        self.shape['appPreferences']['shape'] = {'<key>': 'number'}
        result = owner_shape.generate(self.shape, self.home)
        self.assertIsNone(result['dockEdge'])
        self.assertTrue(any('placement fidelity' in text for text in result['limitations']))
        self.assertFalse((self.home / owner_shape.PREFERENCES / 'settings-v1.json').exists())

    def test_retained_startup_requires_actual_row_copy_placement_and_consent(self):
        receipt = owner_shape.generate(self.shape, self.home)
        oracle = oracle_tests.JourneyOracleTests(); oracle.setUp()
        facts = copy.deepcopy(oracle.facts[0])
        facts.update(claudeAccountCount=0, profile='owner-shape', consentGeneration=37, privacy='automatic', dockEdge='left',
                     renderedRows=[oracle.row('claude', next_step='Allow Keychain for Claude Code in Settings')])
        facts['rowInvariant'] = dict(canonicalKnown=True, allowedTools=receipt['allowedTools'],
                                     rowCounts={tool: 1 for tool in receipt['allowedTools']})
        self.assertTrue(journey.passes(0, facts, owner=receipt))
        for change in [dict(dockEdge='right'), dict(consentGeneration=0), dict(privacy='off'), dict(renderedRows=[]),
                       dict(unexpectedRowCount=1), dict(unexpectedRowCount=False), dict(claudeAccountCount=1), dict(profile='fresh')]:
            self.assertFalse(journey.passes(0, {**facts, **change}, owner=receipt), change)
        for row in [oracle.row('claude', next_step='Check tool settings'), {**oracle.row('claude'), 'readout': '37%'}]:
            self.assertFalse(journey.passes(0, {**facts, 'renderedRows': [row]}, owner=receipt))
        self.assertFalse(journey.passes(0, facts))
        self.assertFalse(journey.passes(0, {**facts, 'dockEdge': 'right'}, owner={**receipt, 'dockEdge': None}))

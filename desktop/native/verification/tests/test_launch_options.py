# SPDX-License-Identifier: MIT
"""Launcher options for owner test builds (11-06): allow-listed candidate environment (`readers`,
`subjectEnv`), product-path backup/restore with a SHA-256 manifest, the booking identity check and
the never-started close proof for a launcher that exits before reserving. Linux-safe: `defaults`
and the launcher identity are injected."""
import hashlib
import io
import json
import os
from pathlib import Path
import sys
import tarfile
import tempfile
import time
import unittest
from unittest import mock

BIN = Path(__file__).resolve().parents[1] / 'bin'
sys.path.insert(0, str(BIN))

import admission  # noqa: E402
import book  # noqa: E402
import guardian  # noqa: E402
import launch  # noqa: E402
import packaged_candidate  # noqa: E402
import product_backup  # noqa: E402
import subject_options  # noqa: E402

GONE = {'pid': 999_999_9, 'startSeconds': 1, 'startMicroseconds': 0}


def nobody(pid):
    return None


class ReaderOptionTests(unittest.TestCase):
    def test_off_passive_and_list_map_to_restricting_variables_only(self):
        self.assertEqual(subject_options.reader_env('off'),
                         {'MODELPLAN_READERS': 'off', 'MODELPLAN_CODEX_ACCOUNT': 'off'})
        self.assertEqual(subject_options.reader_env('passive'), {'MODELPLAN_READERS': 'passive'})
        self.assertEqual(subject_options.reader_env('codex,zcode'), {'MODELPLAN_VERIFY_READERS': 'codex,zai'})
        self.assertEqual(subject_options.reader_env(['zai']),
                         {'MODELPLAN_VERIFY_READERS': 'zai', 'MODELPLAN_CODEX_ACCOUNT': 'off'})
        self.assertEqual(subject_options.reader_env(None), {})
        self.assertEqual(subject_options.parse_readers('codex,zcode')[2], {'zcode': 'zai'})

    def test_bad_reader_values_are_refused(self):
        for bad in ('automatic', 'Codex', '', [], ['codex', ''], 'codex,../x', 5):
            with self.assertRaises(ValueError, msg=repr(bad)):
                subject_options.reader_env(bad)

    def test_subject_env_allows_only_listed_keys_and_values(self):
        self.assertEqual(subject_options.subject_overrides({'subjectEnv': {'MODELPLAN_HISTORY': 'off'}}),
                         {'MODELPLAN_HISTORY': 'off'})
        for bad in ({'MODELPLAN_READERS': 'automatic'}, {'MODELPLAN_CACHE': '/x'}, {'HOME': '/x'},
                    {'MODELPLAN_VERIFY_READERS': 'codex, zai'}, 'MODELPLAN_READERS=off'):
            with self.assertRaises(ValueError, msg=repr(bad)):
                subject_options.subject_overrides({'subjectEnv': bad})
        with self.assertRaisesRegex(ValueError, 'conflicts with readers'):
            subject_options.subject_overrides({'readers': 'passive', 'subjectEnv': {'MODELPLAN_READERS': 'off'}})

    def test_real_environment_drops_inherited_modelplan_keys_and_records_names(self):
        inherited = {'HOME': '/Users/t', 'PROVIDER_KEY': 'k', 'MODELPLAN_CACHE': '/elsewhere', 'MODELPLAN_READERS': 'automatic'}
        env, manifest = subject_options.apply(inherited, {'readers': 'off'}, real=True)
        self.assertEqual(env, {'HOME': '/Users/t', 'PROVIDER_KEY': 'k', 'MODELPLAN_READERS': 'off',
                               'MODELPLAN_CODEX_ACCOUNT': 'off'})
        self.assertEqual(manifest['strippedEnvKeys'], ['MODELPLAN_CACHE', 'MODELPLAN_READERS'])
        self.assertEqual(manifest['subjectEnv'], {'MODELPLAN_CODEX_ACCOUNT': 'off', 'MODELPLAN_READERS': 'off'})
        synthetic, _ = subject_options.apply(launch.subject_env(Path('/h'), Path('/t')), {'readers': 'passive'}, real=False)
        self.assertEqual(synthetic['MODELPLAN_READERS'], 'passive')
        self.assertEqual(synthetic['HOME'], '/h')

    def test_contract_rules(self):
        ok = {'profile': 'real', 'backup': 'product', 'backupDir': '/b', 'readers': ['codex'], 'subjectKind': 'app-zip'}
        subject_options.validate(ok)
        for bad, message in (({'backup': 'product', 'backupDir': '/b'}, 'needs the real profile'),
                             ({'profile': 'real', 'backup': 'product'}, 'absolute backupDir'),
                             ({'profile': 'real', 'backup': 'all', 'backupDir': '/b'}, 'backup must be product'),
                             ({'readers': ['codex']}, 'app-zip'),
                             ({'runManifestPath': 'rel'}, 'runManifestPath')):
            with self.assertRaisesRegex(ValueError, message):
                subject_options.validate(bad)

    def test_flags_fill_the_config_and_refuse_a_different_value(self):
        merged = subject_options.merge_flags({'profile': 'real'}, profile='real', readers='codex,zcode', backup='product')
        self.assertEqual((merged['readers'], merged['backup']), (['codex', 'zcode'], 'product'))
        self.assertEqual(subject_options.merge_flags({}, readers='off')['readers'], 'off')
        with self.assertRaisesRegex(ValueError, '--readers conflicts'):
            subject_options.merge_flags({'readers': 'passive'}, readers='off')

    def test_engine_marker_is_required_for_a_reader_list(self):
        with tempfile.TemporaryDirectory() as raw:
            app = Path(raw) / 'A.app'; helper = app / 'Contents' / 'Helpers' / 'modelplan'
            helper.parent.mkdir(parents=True)
            self.assertFalse(subject_options.engine_honours_readers(app))
            helper.write_bytes(b'\0' * (1 << 20) + b'MODELPLAN_VERIFY' + b'_READERS' + b'\0')  # across a block edge
            self.assertTrue(subject_options.engine_honours_readers(app))
            helper.write_bytes(b'MODELPLAN_READERS only')
            self.assertFalse(subject_options.engine_honours_readers(app))


def build_home(root):
    home = root / 'Users' / 'tester'
    native = home / 'Library' / 'Application Support' / 'ModelPlan' / 'Native'
    native.mkdir(parents=True)
    (native / 'settings-v1.json').write_text('{"a":1}')
    (native / 'community-v1.json').write_text('{"b":2}')
    prefs = home / 'Library' / 'Preferences'; prefs.mkdir(parents=True)
    (prefs / 'org.modelplan.community.swift.scaffold.plist').write_bytes(b'bplist00-original')
    (prefs / 'com.other.app.plist').write_bytes(b'other')
    cache = home / 'Library' / 'Caches' / 'modelplan' / 'objects'; cache.mkdir(parents=True)
    (cache / 'o1').write_bytes(b'object')
    config = home / '.config' / 'modelplan'; config.mkdir(parents=True)
    (config / 'consent.json').write_text('{"tools":{"codex":{}}}')
    bridge = home / 'Library' / 'Application Support' / 'M0Bridge'; bridge.mkdir(parents=True)
    (bridge / 'state.json').write_text('coordinator')
    (home / '.codex').mkdir(); (home / '.codex' / 'auth.json').write_text('secret')
    return home


class ProductBackupTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.home = build_home(self.root)
        self.calls = []

    def runner(self, argv, **kwargs):
        self.calls.append(argv[1:])

    def outside(self):
        return {p: p.read_bytes() for p in self.home.rglob('*') if p.is_file()
                and not product_backup.inside_list(p.relative_to(self.home).as_posix())}

    def test_backup_restores_byte_for_byte_and_touches_nothing_else(self):
        before_outside = self.outside()
        manifest = product_backup.backup(self.home, self.root / 'backup', clock=lambda: 1.0)
        self.assertEqual(manifest['roots'], {p: ('file' if p.endswith(('.plist', '.json')) else 'dir')
                                             for p in product_backup.PRODUCT_PATHS})
        names = {r['path'] for r in manifest['files']}
        self.assertFalse(any('M0Bridge' in n or '.codex' in n or 'com.other' in n for n in names))
        with tarfile.open(self.root / 'backup' / 'product.tar') as tar:
            self.assertEqual(sorted(m.name for m in tar.getmembers()), sorted(names))
        # the run changes product state ...
        native = self.home / 'Library' / 'Application Support' / 'ModelPlan' / 'Native'
        (native / 'settings-v1.json').write_text('{"a":2}')
        (native / 'new.json').write_text('{}')
        (self.home / '.config' / 'modelplan' / 'consent.json').unlink()
        (self.home / 'Library' / 'Preferences' / 'org.modelplan.community.swift.scaffold.plist').write_bytes(b'changed')
        # ... and something outside the list changes too (it must stay as the run left it)
        (self.home / 'Library' / 'Application Support' / 'M0Bridge' / 'state.json').write_text('coordinator-2')
        result = product_backup.restore(self.root / 'backup', runner=self.runner, sleep=lambda s: None)
        self.assertTrue(result['restored'], result)
        self.assertEqual(result['runChanges']['added'], ['Library/Application Support/ModelPlan/Native/new.json'])
        self.assertEqual(result['runChanges']['removed'], ['.config/modelplan/consent.json'])
        self.assertIn('Library/Application Support/ModelPlan/Native/settings-v1.json', result['runChanges']['changed'])
        self.assertEqual(self.calls, [['import', 'org.modelplan.community.swift.scaffold', str(self.root / 'backup' / 'preferences-import.plist')]])
        self.assertEqual((native / 'settings-v1.json').read_text(), '{"a":1}')
        self.assertFalse((native / 'new.json').exists())
        self.assertEqual((self.home / '.config' / 'modelplan' / 'consent.json').read_text(), '{"tools":{"codex":{}}}')
        after_outside = self.outside()
        before_outside[self.home / 'Library' / 'Application Support' / 'M0Bridge' / 'state.json'] = b'coordinator-2'
        self.assertEqual(after_outside, before_outside)
        self.assertTrue(json.loads((self.root / 'backup' / 'restore-manifest.json').read_text())['restored'])
        self.assertEqual(product_backup.main(['verify', '--backup-dir', str(self.root / 'backup')]), 0)

    def test_absent_paths_stay_absent_and_the_domain_is_deleted(self):
        import shutil
        shutil.rmtree(self.home / 'Library' / 'Caches' / 'modelplan')
        (self.home / 'Library' / 'Preferences' / 'org.modelplan.community.swift.scaffold.plist').unlink()
        manifest = product_backup.backup(self.home, self.root / 'backup')
        self.assertEqual(manifest['roots']['Library/Caches/modelplan'], 'absent')
        (self.home / 'Library' / 'Caches' / 'modelplan').mkdir()
        (self.home / 'Library' / 'Caches' / 'modelplan' / 'store').write_text('x')
        result = product_backup.restore(self.root / 'backup', runner=self.runner)
        self.assertTrue(result['restored'])
        self.assertFalse((self.home / 'Library' / 'Caches' / 'modelplan').exists())
        self.assertEqual(self.calls, [['delete', 'org.modelplan.community.swift.scaffold']])

    def test_refusals(self):
        cache = self.home / 'Library' / 'Caches' / 'modelplan'
        (cache / 'M0Bridge.sock').write_text('x')
        with self.assertRaisesRegex(product_backup.Refused, 'M0Bridge'):
            product_backup.backup(self.home, self.root / 'b1')
        (cache / 'M0Bridge.sock').unlink()
        (cache / 'auth.json').write_text('x')
        with self.assertRaisesRegex(product_backup.Refused, 'credential'):
            product_backup.backup(self.home, self.root / 'b2')
        (cache / 'auth.json').unlink()
        (cache / 'link').symlink_to(self.home / '.codex' / 'auth.json')
        with self.assertRaisesRegex(product_backup.Refused, 'symlink'):
            product_backup.backup(self.home, self.root / 'b3')
        (cache / 'link').unlink()
        with self.assertRaisesRegex(product_backup.Refused, 'outside the product paths'):
            product_backup.backup(self.home, cache / 'backup')
        self.assertFalse(any((self.root / n).exists() for n in ('b1', 'b2', 'b3')))

    def test_restore_refuses_tampered_or_foreign_archives(self):
        dest = self.root / 'backup'
        product_backup.backup(self.home, dest)
        manifest = json.loads((dest / 'backup-manifest.json').read_text())
        # a member outside the list, with the manifest hash updated to match
        with tarfile.open(dest / 'product.tar', 'a') as tar:
            info = tarfile.TarInfo('.codex/auth.json'); info.size = 1
            tar.addfile(info, io.BytesIO(b'x'))
        manifest['archiveSHA256'] = product_backup.sha256_file(dest / 'product.tar')
        (dest / 'backup-manifest.json').write_text(json.dumps(manifest))
        with self.assertRaisesRegex(product_backup.Refused, 'outside the product paths'):
            product_backup.restore(dest, runner=self.runner)
        manifest['archiveSHA256'] = '0' * 64
        (dest / 'backup-manifest.json').write_text(json.dumps(manifest))
        with self.assertRaisesRegex(product_backup.Refused, 'hash mismatch'):
            product_backup.restore(dest, runner=self.runner)
        self.assertEqual(self.calls, [])  # nothing was touched
        self.assertEqual((self.home / '.codex' / 'auth.json').read_text(), 'secret')


class LaunchBackupTests(unittest.TestCase):
    """launch.py: backup before the subject, restore after it, run manifest with the environment."""
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.home = build_home(self.root)
        launch.RUN.update(children=[], pidPath=None, leasePath=None, manifest=None)

    def test_real_run_restores_and_writes_the_manifest(self):
        binary = self.root / 'subject'; binary.write_bytes(b'x')
        manifest_path = self.root / 'run-manifest.json'
        cfg = self.root / 'run.json'
        cfg.write_text(json.dumps(dict(profile='real', syntheticTmp=str(self.root / 'tmp'), argv=[str(binary)],
                                       binarySHA256=hashlib.sha256(b'x').hexdigest(), subjectPidPath=str(self.root / 'pid'),
                                       backupDir=str(self.root / 'backup'), runManifestPath=str(manifest_path),
                                       lease=dict(runID='r1', epoch='e1'))))
        consent = self.home / '.config' / 'modelplan' / 'consent.json'

        def subject(*args, **kwargs):  # the "app" edits consent, then launch fails at the spawn
            consent.write_text('{"edited":true}')
            raise RuntimeError('stop here')
        with mock.patch.dict(os.environ, {'HOME': str(self.home), 'MODELPLAN_CACHE': '/elsewhere'}), \
                mock.patch.object(launch, 'load_and_admit', side_effect=lambda x: x), \
                mock.patch.object(launch, 'mark_launching', return_value={}), \
                mock.patch.object(launch.subprocess, 'Popen', side_effect=subject) as popen, \
                mock.patch.object(product_backup, 'sync_preferences', return_value='imported'), \
                self.assertRaises(RuntimeError):
            launch.main(['--config', str(cfg), '--execute', '--readers', 'off', '--backup', 'product'])
        env = popen.call_args.kwargs['env']
        self.assertEqual((env['MODELPLAN_READERS'], env['MODELPLAN_CODEX_ACCOUNT']), ('off', 'off'))
        self.assertNotIn('MODELPLAN_CACHE', env)
        self.assertEqual(consent.read_text(), '{"tools":{"codex":{}}}')
        manifest = json.loads(manifest_path.read_text())
        self.assertTrue(manifest['restore']['restored'])
        self.assertEqual(manifest['restore']['runChanges']['changed'], ['.config/modelplan/consent.json'])
        self.assertEqual(manifest['environment']['subjectEnv'], {'MODELPLAN_CODEX_ACCOUNT': 'off', 'MODELPLAN_READERS': 'off'})
        self.assertEqual(manifest['environment']['strippedEnvKeys'], ['MODELPLAN_CACHE'])
        self.assertEqual(manifest['backup']['roots']['.config/modelplan/consent.json'], 'file')

    def test_reader_list_needs_an_engine_that_knows_it(self):
        cfg = self.root / 'run.json'
        binary = self.root / 'subject'; binary.write_bytes(b'x')
        cfg.write_text(json.dumps(dict(profile='real', syntheticTmp=str(self.root / 'tmp'), argv=[str(binary)],
                                       binarySHA256=hashlib.sha256(b'x').hexdigest(), subjectPidPath=str(self.root / 'pid'),
                                       subjectKind='app-zip', readers=['codex', 'zcode'])))
        app = self.root / 'A.app'; (app / 'Contents' / 'Helpers').mkdir(parents=True)
        (app / 'Contents' / 'Helpers' / 'modelplan').write_bytes(b'old engine')
        with mock.patch.dict(os.environ, {'HOME': str(self.home)}), \
                mock.patch.object(launch, 'load_and_admit', side_effect=lambda x: x), \
                mock.patch.object(launch, 'extract_app', return_value=dict(app=app, exe=app / 'x', evidence={})), \
                mock.patch.object(launch.subprocess, 'Popen') as popen, \
                self.assertRaisesRegex(ValueError, 'does not honour MODELPLAN_VERIFY_READERS'):
            launch.main(['--config', str(cfg), '--execute'])
        popen.assert_not_called()


class BookingIdentityTests(unittest.TestCase):
    def test_missing_scenario_is_named_up_front(self):
        with self.assertRaisesRegex(ValueError, 'missing: scenario'):
            book.check_identity({'id': 'b1', 'lane': 'M1', 'unit': 'U11a'})
        self.assertTrue(book.check_identity({'id': 'b1', 'lane': 'M1', 'unit': 'U11a', 'scenario': 'cold'}))
        now = time.time()
        lease = dict(runID='r', epoch='e', notBefore=now - 1, expiresAt=now + 600, guardianHeartbeatAt=now - 1,
                     ownerPreempted=False, exclusive=True)
        config = dict(binarySHA256='a' * 64, argv=['x'], requiredSeconds=60, lease=lease, stop=False,
                      release=dict(lease, m1Released=True, approval='https://github.com/o/r/issues/1#issuecomment-1'),
                      booking={'id': 'b1', 'lane': 'M1', 'unit': 'U11a'})
        with self.assertRaisesRegex(ValueError, 'missing: scenario'):
            admission.validate(config, now)


class NeverStartedTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.dir = Path(self.temp.name)
        self.pid = self.dir / 'subject.pid'
        self.lease_path = self.dir / 'lease.json'
        self.lease = dict(runID='r1', epoch='e1', notBefore=1.0, expiresAt=1000.0)
        self.lease_path.write_text(json.dumps(self.lease))
        launch.RUN.update(children=[], pidPath=self.pid, leasePath=self.lease_path, manifest=None)

    def test_launcher_refused_before_reserving_closes_as_never_started(self):
        proof = launch.no_subject_proof(1, lookup=lambda pid: dict(GONE))
        self.assertEqual((proof['runID'], proof['launcherExit']), ('r1', 1))
        self.assertEqual(guardian.close(self.pid, lookup=nobody, lease=self.lease, settle=0), (True, 'never-started'))
        self.assertTrue(guardian.finishable('error', True, 'never-started'))
        # without the lease binding (or for another run) it stays the old, unproven `none`
        self.assertEqual(guardian.close(self.pid, lookup=nobody, settle=0), (True, 'none'))
        self.assertEqual(guardian.close(self.pid, lookup=nobody, lease=dict(self.lease, runID='r2'), settle=0), (True, 'none'))

    def test_live_launcher_or_zero_exit_or_reservation_is_not_proof(self):
        self.assertIsNone(launch.no_subject_proof(0, lookup=lambda pid: dict(GONE)))
        launch.no_subject_proof(3, lookup=lambda pid: dict(GONE))
        alive = lambda pid: dict(GONE) if pid == GONE['pid'] else None
        self.assertEqual(guardian.close(self.pid, lookup=alive, lease=self.lease, settle=0, launcher_wait=0.05,
                                        clock=time.monotonic), (True, 'none'))
        self.pid.with_name(self.pid.name + '.no-subject.json').unlink()
        self.pid.write_text(json.dumps({'state': 'running'}))
        self.assertIsNone(launch.no_subject_proof(1, lookup=lambda pid: dict(GONE)))
        self.assertFalse(self.pid.with_name(self.pid.name + '.no-subject.json').exists())

    def test_entry_writes_the_proof_when_admission_refuses(self):
        cfg = self.dir / 'run.json'
        cfg.write_text(json.dumps(dict(subjectPidPath=str(self.pid), leasePath=str(self.lease_path),
                                       booking={'id': 'b1', 'lane': 'M1', 'unit': 'U11a'})))
        with mock.patch.object(launch, 'load_and_admit', side_effect=ValueError('missing: scenario')), \
                mock.patch.object(launch, 'identity', side_effect=lambda pid: dict(GONE)), \
                self.assertRaisesRegex(ValueError, 'scenario'):
            launch.entry(['--config', str(cfg), '--execute'])
        self.assertEqual(guardian.run(self.lease_path, self.dir / 'STOP', clock=lambda: 1.5, sleep=lambda s: None,
                                      running=lambda: False, pid_file=self.pid,
                                      kill=lambda f: guardian.close(f, lookup=nobody, lease=self.lease, settle=0)),
                         ('signalled', True, 'never-started'))

    def test_guardian_run_binds_its_own_lease_when_closing(self):
        launch.no_subject_proof(2, lookup=lambda pid: dict(GONE))
        self.lease_path.write_text(json.dumps(dict(self.lease, ownerPreempted=False, exclusive=True, guardianHeartbeatAt=1.0)))
        with mock.patch.object(guardian, 'identity', side_effect=nobody):
            outcome = guardian.run(self.lease_path, self.dir / 'STOP', reserve=30.0, clock=lambda: 1.5,
                                   sleep=lambda s: None, running=lambda: False, pid_file=self.pid)
        self.assertEqual(outcome, ('signalled', True, 'never-started'))


class PackagedOptionsTests(unittest.TestCase):
    def test_prepare_fills_backup_and_manifest_paths_outside_scratch(self):
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw)
            template = root / 't.json'
            template.write_text(json.dumps({'profile': 'real', 'booking': {'id': 'b', 'lane': 'M1', 'unit': 'U'}}))
            with self.assertRaisesRegex(ValueError, 'missing: scenario'):
                with mock.patch.object(packaged_candidate.candidate_config, 'verify_archive'):
                    (root / 'm.json').write_text(json.dumps({'sourceSHA': 'a' * 40, 'sha256': 'b' * 64}))
                    packaged_candidate.prepare(root / 'a.zip', root / 'm.json', template, root / 'scratch',
                                               root / 'reg.json', readers='codex,zcode', backup='product')


if __name__ == '__main__':
    unittest.main()

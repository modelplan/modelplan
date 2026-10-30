# SPDX-License-Identifier: MIT
import argparse
import contextlib
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tarfile
import tempfile
import unittest
from unittest.mock import patch

import run as drive
import release


class DriveTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='engine-drive-test-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.binary = self.root / 'subject'
        self.binary.write_text('#!/usr/bin/env python3\nimport time\ntime.sleep(30)\n')
        self.binary.chmod(0o700)
        self.args = argparse.Namespace(output=self.root / 'evidence', binary=self.binary,
            source_sha='a' * 40, release=None, old_release=[],
            shape=Path(__file__).with_name('profile.json'), context=None, level='L1',
            run_id='test-run', attempt='1', epoch='test-epoch', timeout=20,
            scenario_timeout=1, deadline=None, stop_file=None)
        drive.STOP = False

    def execute(self):
        with contextlib.redirect_stdout(io.StringIO()):
            status = drive.execute(self.args)
        manifest = json.loads((self.args.output / 'manifest.json').read_text())
        return status, manifest

    def test_source_or_pending_profile_cannot_qualify_as_l2(self):
        self.args.level = 'L2'
        status, result = self.execute()
        self.assertEqual(status, 1)
        self.assertIsNone(result['earnedLevel'])
        self.assertIn('released-subject-required', result['qualification'])
        self.assertIn('coordinator-shape-approval-required', result['qualification'])
        self.assertTrue(all(s['outcome'] == 'unsupported' for s in result['scenarios']))
        self.assertEqual(result['cleanup']['outcome'], 'cleaned')
        self.assertFalse((self.args.output / '.work').exists())

    def test_hosted_mac_is_l1_even_with_approved_inputs(self):
        shape = dict(fidelity='approved-shape-export', approvalRef='shape-review')
        subject = dict(kind='released')
        context = dict(dedicatedTestMac=True, approvalRef='run-review')
        with patch.object(drive.platform, 'system', return_value='Darwin'), patch.dict(os.environ, GITHUB_ACTIONS='true'):
            self.assertEqual(drive.qualification('L2', shape, subject, {'v0.5.46': {}, 'v0.5.47': {}}, context),
                             ['dedicated-test-mac-required'])
        with patch.object(drive.platform, 'system', return_value='Darwin'), patch.dict(os.environ, GITHUB_ACTIONS='false'):
            self.assertEqual(drive.qualification('L2', shape, subject, {'v0.5.46': {}, 'v0.5.47': {}}, context), [])

    def test_stop_records_not_run_and_preserves_subject_profile(self):
        self.args.stop_file = self.root / 'stop'
        self.args.stop_file.touch()
        status, result = self.execute()
        self.assertEqual(status, 1)
        self.assertTrue(all(s['outcome'] == 'not-run' and s['reason'] == 'caller-stop' for s in result['scenarios']))
        self.assertEqual(result['subject']['binarySHA256'], release.sha(self.binary.read_bytes()))
        self.assertEqual(result['cleanup']['outcome'], 'cleaned')

    def test_timeout_reaps_owned_worker_and_keeps_outcome(self):
        # A real stalled subject exercises supervisor/worker process-group cleanup.
        # One scenario is enough; this is not a mock of the timeout implementation.
        with patch.object(drive, 'IDS', ['U2-migration']):
            status, result = self.execute()
        self.assertEqual(status, 1)
        self.assertEqual(result['scenarios'][0]['outcome'], 'timeout')
        self.assertEqual(result['cleanup']['outcome'], 'cleaned')
        self.assertFalse((self.args.output / '.work').exists())

    def test_cleanup_failure_keeps_original_results_and_durable_evidence(self):
        def finish(args, output, scratch, manifest, *rest):
            for s in manifest['scenarios']:
                s.update(outcome='pass', reason='observed')
            return []
        def fail_cleanup(path):
            before = json.loads((self.args.output / 'manifest.json').read_text())
            self.assertTrue(all(s['outcome'] == 'pass' for s in before['scenarios']))
            self.assertTrue((self.args.output / 'profile.json').exists())
            raise PermissionError('read-only cache')
        with patch.object(drive, 'run_scenarios', side_effect=finish), patch.object(drive.shutil, 'rmtree', side_effect=fail_cleanup):
            status, result = self.execute()
        self.assertEqual(status, 1)
        self.assertEqual(result['outcome'], 'pass')
        self.assertTrue(all(s['outcome'] == 'pass' for s in result['scenarios']))
        self.assertEqual(result['cleanup']['outcome'], 'failed')
        self.assertEqual(json.loads((self.args.output / 'cleanup.json').read_text())['reasons'], ['scratch-removal-failed'])

    def test_preflight_failure_also_has_all_scenario_outcomes(self):
        self.args.binary = self.root / 'missing'
        status, result = self.execute()
        self.assertEqual(status, 1)
        self.assertEqual(result['outcome'], 'not-run')
        self.assertTrue(all(s['reason'] == 'preflight-or-harness-failed' for s in result['scenarios']))
        self.assertEqual(result['cleanup']['outcome'], 'cleaned')

    def test_release_checksum_and_executable_bytes_are_both_checked(self):
        asset = release.asset_name()
        data = b'ordinary-release-test-bytes'
        stream = io.BytesIO()
        with tarfile.open(fileobj=stream, mode='w:gz') as archive:
            item = tarfile.TarInfo('modelplan')
            item.size = len(data)
            archive.addfile(item, io.BytesIO(data))
        packed = stream.getvalue()
        (self.root / asset).write_bytes(packed)
        (self.root / 'modelplan').write_bytes(data)
        (self.root / 'checksums.txt').write_text(release.sha(packed) + '  ' + asset + '\n')
        record = dict(tag='v0.5.47', commit='b' * 40, asset=asset,
                      archiveSHA256=release.sha(packed), binarySHA256=release.sha(data))
        path = self.root / 'release.json'
        path.write_text(json.dumps(record))
        _, identity = release.verify(path)
        self.assertEqual(identity['binarySHA256'], release.sha(data))
        (self.root / 'modelplan').write_bytes(b'source-build-substitution')
        with self.assertRaisesRegex(ValueError, 'release-executable-mismatch'):
            release.verify(path)
        (self.root / 'modelplan').write_bytes(data)
        (self.root / asset).write_bytes(packed + b'modified')
        with self.assertRaisesRegex(ValueError, 'release-checksum-mismatch'):
            release.verify(path)


if __name__ == '__main__':
    unittest.main()

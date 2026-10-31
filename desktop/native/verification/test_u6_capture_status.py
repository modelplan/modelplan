# SPDX-License-Identifier: MIT
"""Status capture is retired; retain cleanup/orphan and Python compatibility controls."""
import hashlib,importlib.util,json,subprocess,tempfile,unittest
from pathlib import Path
from unittest.mock import patch
spec=importlib.util.spec_from_file_location('u6_status_capture',Path(__file__).parent/'U6/capture_status.py')
capture=importlib.util.module_from_spec(spec);spec.loader.exec_module(capture)

class StatusCapturePolicyTests(unittest.TestCase):
    def test_retired_entry_never_invokes_capture_or_creates_pixels(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);config=dict(batch=directory,expectedLease=dict(runID='run',epoch='epoch'))
            with self.assertRaisesRegex(ValueError,'disabled-by-policy'):
                capture.capture(config,run_capture=lambda *_a,**_k:self.fail('capture invoked'))
            self.assertEqual(list(root.rglob('*.png')),[])
            self.assertEqual(json.loads((root/'status-capture-refusal.json').read_text())['reason'],'status-capture-disabled-by-policy')
    def test_owned_temporaries_cleanup_in_finally_for_errors_and_timeouts(self):
        for error in [ValueError('move'),subprocess.TimeoutExpired('unused',5),RuntimeError('unexpected')]:
            with tempfile.TemporaryDirectory() as directory:
                private=Path(directory)/'private';stage=Path(directory)/'.u6-status-publish-test'
                for path in (private,stage):path.mkdir();(path/'partial.png').write_bytes(b'partial')
                with self.assertRaises(type(error)):
                    try:raise error
                    finally:capture.cleanup_owned_temporaries(private,stage)
                self.assertFalse(private.exists());self.assertFalse(stage.exists())
    def test_stage_cleanup_is_attempted_even_if_private_cleanup_fails(self):
        with patch.object(capture.shutil,'rmtree',side_effect=[OSError('io'),None]) as remove:
            with self.assertRaises(OSError):capture.cleanup_owned_temporaries('private','stage')
            self.assertEqual(remove.call_count,2)
    def test_dock_capture_policy_does_not_require_new_hashlib_api(self):
        from capture_artifacts import approved_images
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);image=root/'dock-owned.png';image.write_bytes(b'owned-dock')
            (root/'subject.json').write_text(json.dumps(dict(pid=42)))
            (root/'native-observations.jsonl').write_text(json.dumps(dict(runID='run',epoch='epoch',pid=42,seq=1,event='dock-surface-frame'))+'\n')
            (root/'dock-capture.json').write_text(json.dumps(dict(schema='u6-capture/1',runID='run',epoch='epoch',pid=42,frameSeq=1,file=image.name,sha256=hashlib.sha256(image.read_bytes()).hexdigest())))
            config=dict(subjectPidPath=str(root/'subject.json'),expectedLease=dict(runID='run',epoch='epoch'))
            with patch.object(hashlib,'file_digest',None,create=True):allowed,problems=approved_images(config,root)
            self.assertEqual(allowed,{'dock-owned.png'});self.assertEqual(problems,[])

if __name__=='__main__':unittest.main()

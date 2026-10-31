# SPDX-License-Identifier: MIT
"""Single-owned-window capture receipt tests; screencapture itself is faked."""
import importlib.util,json,sys,tempfile,types,unittest
from pathlib import Path

BIN=Path(__file__).parent/'bin';sys.path.insert(0,str(BIN))
spec=importlib.util.spec_from_file_location('u6_capture',Path(__file__).parent/'U6/capture_owned.py')
capture=importlib.util.module_from_spec(spec);spec.loader.exec_module(capture)

class U6CaptureTests(unittest.TestCase):
    def test_capture_binds_registered_pid_window_and_frame_sequence(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);(root/'subject.json').write_text(json.dumps(dict(pid=42,state='running')))
            frame=dict(event='dock-surface-frame',runID='run',epoch='epoch',pid=42,seq=7,mono=100,
                       checks=dict(state='expanded',windowNumber=77))
            (root/'native-observations.jsonl').write_text(json.dumps(frame)+'\n')
            config=dict(batch=str(root),subjectPidPath=str(root/'subject.json'),expectedLease=dict(runID='run',epoch='epoch'))
            original=capture.cleanup.matches
            capture.still_admitted=lambda _:True
            capture.identity=lambda _:dict(pid=42)
            capture.cleanup.matches=lambda *_:True
            capture.launcher_lost=lambda _:False
            def fake(command,**_):
                self.assertEqual(command[:4],['screencapture','-x','-l','77'])
                Path(command[4]).write_bytes(b'synthetic-owned-window')
                return types.SimpleNamespace(returncode=0)
            try:
                capture.capture(config,run_capture=fake,now=lambda:101)
                receipt=json.loads((root/'dock-capture.json').read_text())
                self.assertEqual((receipt['pid'],receipt['windowNumber'],receipt['frameSeq']),(42,77,7))
                self.assertEqual(receipt['mono'],101)
                with self.assertRaisesRegex(ValueError,'capture-not-fresh'):
                    capture.capture(config,run_capture=fake,now=lambda:102)
            finally:capture.cleanup.matches=original

if __name__=='__main__':unittest.main()

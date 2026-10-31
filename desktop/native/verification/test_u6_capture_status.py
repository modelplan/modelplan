# SPDX-License-Identifier: MIT
"""Owned status-rectangle capture; all screen/process operations are fakes."""
import hashlib,importlib.util,json,tempfile,types,unittest
from pathlib import Path
from unittest.mock import patch
spec=importlib.util.spec_from_file_location('u6_status_capture',Path(__file__).parent/'U6/capture_status.py')
capture=importlib.util.module_from_spec(spec);spec.loader.exec_module(capture)

class StatusCaptureTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup);self.root=Path(self.temp.name)
        self.config=dict(batch=str(self.root),subjectPidPath=str(self.root/'subject.json'),expectedLease=dict(runID='run',epoch='epoch'))
        (self.root/'subject.json').write_text(json.dumps(dict(pid=42,state='running',runID='run',epoch='epoch')))
        self.frame=dict(event='status-item-frame',runID='run',epoch='epoch',pid=42,seq=7,mono=100,
            checks=dict(x=1800,y=1418,cgX=1800,cgY=0,width=44,height=22,coordinateSpace='appkit-screen',
                settled=True,visible=True,stableSinceMono=99,frameGeneration=2,windowNumber=1<<32,
                displayBounds=[0,0,2560,1440],menuBarBand=[0,0,2560,22]))
        self.write()
        (self.root/'status-pointer-plan.json').write_text(json.dumps(dict(runID='run',epoch='epoch',subjectPID=42,
            u6FrameSeq=7,u6StatusFrameGeneration=2,u6StatusWindowNumber=1<<32,statusWindowCheck='unavailable')))
    def write(self):
        (self.root/'native-observations.jsonl').write_text(json.dumps(self.frame)+'\n')
    def run_capture(self,fake):
        with patch.object(capture,'still_admitted'),patch.object(capture,'identity',return_value=dict(pid=42)), \
             patch.object(capture.cleanup,'matches',return_value=True),patch.object(capture,'launcher_lost',return_value=False):
            capture.capture(self.config,run_capture=fake,now=lambda:100.5)
    def test_exact_owned_rectangle_and_receipt_before_input(self):
        def fake(command,**_):
            self.assertEqual(command,['screencapture','-x','-R','1800,0,44,22',str(self.root/'status-preclick.png')])
            Path(command[-1]).write_bytes(b'synthetic-owned-rectangle');return types.SimpleNamespace(returncode=0)
        self.run_capture(fake);r=json.loads((self.root/'status-preclick-capture.json').read_text())
        self.assertEqual((r['pid'],r['frameSeq'],r['frameGeneration']),(42,7,2))
        self.assertEqual(r['sha256'],hashlib.sha256(b'synthetic-owned-rectangle').hexdigest())
        self.assertEqual(r['statusWindowCheck'],'unavailable')
    def test_unsettled_or_oversized_never_invokes_capture(self):
        for changes in [dict(settled=False),dict(height=44),dict(frameGeneration=3)]:
            with self.subTest(changes=changes):
                original=dict(self.frame['checks']);self.frame['checks'].update(changes);self.write()
                with self.assertRaises(ValueError):self.run_capture(lambda *_a,**_k:self.fail('unowned capture invoked'))
                self.frame['checks']=original
    def test_movement_during_capture_cannot_create_visibility_receipt(self):
        def fake(command,**_):
            Path(command[-1]).write_bytes(b'synthetic');self.frame['checks']['frameGeneration']=3;self.write()
            return types.SimpleNamespace(returncode=0)
        with self.assertRaisesRegex(ValueError,'owned-frame-changed'):self.run_capture(fake)
        self.assertFalse((self.root/'status-preclick-capture.json').exists())

if __name__=='__main__':unittest.main()

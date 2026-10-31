# SPDX-License-Identifier: MIT
"""Malformed U6 IDs refuse through the real pointer entry before any host query."""
import json,os,subprocess,tempfile,unittest
from pathlib import Path

class PointerWindowCLI(unittest.TestCase):
    def test_park_click_is_bounded_refusal_without_input(self):
        binary=Path(os.environ.get('U6_POINTER_BINARY',str(Path(__file__).resolve().parents[3]/'pointer_drive')))
        if not binary.is_file():self.skipTest('Pointer binary supplied by kit or U6_POINTER_BINARY')
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);output=root/'park.jsonl';plan=root/'park.json'
            plan.write_text(json.dumps(dict(profile='synthetic',runID='run',epoch='epoch',subjectPID=42,subjectBundle='/unused.app',
                lease='unused',stop='unused',output=str(output),allowedRectangles=[[499,499,2,2]],purpose='park',
                parkDisplayBounds=[0,0,1000,1000],parkExclusions=[[0,0,10,10]],
                steps=[dict(x=500,y=500,seconds=0,dwell=0,action='click')])))
            result=subprocess.run([str(binary),'--plan',str(plan)],capture_output=True,text=True,timeout=5)
            self.assertEqual(result.returncode,1,result.stderr)
            rows=[json.loads(line) for line in output.read_text().splitlines()]
            self.assertEqual(len(rows),1);self.assertEqual(rows[0]['purpose'],'park');self.assertEqual(rows[0]['outcome'],'not-run')
    def test_out_of_range_plan_returns_bounded_receipt_without_signal(self):
        binary=Path(os.environ.get('U6_POINTER_BINARY',str(Path(__file__).resolve().parents[3]/'pointer_drive')))
        if not binary.is_file():self.skipTest('Pointer binary supplied by kit or U6_POINTER_BINARY')
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory)
            for number in [0,-1,1<<32,(1<<63)-1]:
                with self.subTest(number=number):
                    output=root/(str(number)+'.jsonl');plan=root/'plan.json'
                    plan.write_text(json.dumps(dict(profile='synthetic',runID='run',epoch='epoch',subjectPID=42,
                        subjectBundle='/unused.app',lease='unused',stop='unused',output=str(output),
                        allowedRectangles=[[0,0,100,100]],steps=[dict(x=10,y=10,seconds=0,dwell=0,action='click')],
                        u6InputKind='status',u6Observations='unused',u6FrameSeq=1,u6StatusFrameGeneration=1,u6StatusWindowNumber=number)))
                    result=subprocess.run([str(binary),'--plan',str(plan)],capture_output=True,text=True,timeout=5)
                    self.assertEqual(result.returncode,1,result.stderr)
                    self.assertNotIn('Fatal error',result.stderr)
                    rows=[json.loads(line) for line in output.read_text().splitlines()]
                    self.assertEqual(len(rows),1);self.assertEqual(rows[0]['outcome'],'not-run')
                    self.assertEqual(rows[0]['event'],'pointer-result')
                    self.assertEqual(json.loads(result.stdout)['reason'],'invalid-or-ended-verification-contract')

if __name__=='__main__':unittest.main()

# SPDX-License-Identifier: MIT
import importlib.util,json,os,subprocess,sys,tempfile,unittest
from pathlib import Path
from unittest.mock import patch

ROOT=Path(__file__).resolve().parents[3]
sys.path[:0]=[str(Path(__file__).parent/'U6'),str(ROOT/'tools/u14/engine_drive')]
import stub_runtime
from scenarios import fixture

class U6StubRuntimeTests(unittest.TestCase):
    def test_higher_priority_home_candidate_refuses_without_execution(self):
        with tempfile.TemporaryDirectory() as directory:
            home=Path(directory);(home/'.local/bin').mkdir(parents=True)
            (home/'.local/bin/copilot').write_text('must never run')
            with self.assertRaisesRegex(ValueError,'stub-shadowed'):stub_runtime.verify_selection(home)
    def test_stub_serializer_emits_bound_jsonl(self):
        with tempfile.TemporaryDirectory() as directory:
            home=Path(directory);(home/'bin').mkdir()
            with patch.object(stub_runtime,'assert_unshadowed',lambda _:None):
                digest=stub_runtime.install(home,'run','epoch',fixture.FAKE_RUNTIME)
            message=json.dumps(dict(jsonrpc='2.0',id=1,method='connect')).encode()
            frame=('Content-Length: '+str(len(message))+'\r\n\r\n').encode()+message
            result=subprocess.run([str(home/'bin/copilot')],input=frame,capture_output=True,
                env=dict(HOME=str(home),PATH='/usr/bin:/bin'),timeout=5)
            self.assertEqual(result.returncode,0)
            row=json.loads((home/'.modelplan-stub/runtime-calls.jsonl').read_text())
            self.assertEqual((row['schema'],row['runID'],row['epoch'],row['method'],row['seq']),('runtime-calls/1','run','epoch','connect',1))
            self.assertEqual(row['ppid'],os.getpid());self.assertGreater(row['mono'],0)
            self.assertEqual(len(digest),64)

if __name__=='__main__':unittest.main()

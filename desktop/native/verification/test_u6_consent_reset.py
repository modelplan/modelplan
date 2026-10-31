# SPDX-License-Identifier: MIT
"""Offline consent-reset/1 correlation; the helper process is faked."""
import hashlib,importlib.util,json,sys,tempfile,types,unittest
from pathlib import Path

BIN=Path(__file__).parent/'bin';sys.path.insert(0,str(BIN))
spec=importlib.util.spec_from_file_location('u6_reset',Path(__file__).parent/'U6/consent_reset.py')
reset=importlib.util.module_from_spec(spec);spec.loader.exec_module(reset)

class U6ResetTests(unittest.TestCase):
    def test_success_is_bound_to_second_open_private_menu_and_synthetic_home(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);scratch=root/'scratch';scratch.mkdir();home=scratch/'home';home.mkdir();tmp=scratch/'tmp';tmp.mkdir()
            app=root/'Test.app/Contents';binary=app/'MacOS/App';binary.parent.mkdir(parents=True);binary.write_bytes(b'app')
            helper=app/'Helpers/modelplan';helper.parent.mkdir();helper.write_bytes(b'helper')
            (root/'subject.json').write_text(json.dumps(dict(pid=42,state='running')))
            native=[dict(event='menu-begin',runID='run',epoch='epoch',pid=42,checks=dict(surface='status',menuObjectID='object',sessionID='A')),
                dict(event='menu-end',runID='run',epoch='epoch',pid=42,checks=dict(sessionID='A')),
                dict(event='menu-begin',runID='run',epoch='epoch',pid=42,checks=dict(surface='status',menuObjectID='object',sessionID='B')),
                dict(event='menu-private-title-visible',runID='run',epoch='epoch',pid=42,checks=dict(sessionID='B'))]
            (root/'native-observations.jsonl').write_text(''.join(json.dumps(r)+'\n' for r in native))
            config=dict(batch=str(root),scratch=str(scratch),syntheticHome=str(home),syntheticTmp=str(tmp),
                subjectPidPath=str(root/'subject.json'),argv=[str(binary)],helperSHA256=hashlib.sha256(b'helper').hexdigest(),
                expectedLease=dict(runID='run',epoch='epoch'))
            original=reset.cleanup.matches
            reset.load_and_admit=lambda _:True
            reset.identity=lambda _:dict(pid=42)
            reset.cleanup.matches=lambda *_:True
            reset.launcher_lost=lambda _:False
            ticks=iter((100,102))
            def fake(command,**kwargs):
                self.assertEqual(command[1:],['consent','reset','confirmed','--json'])
                self.assertEqual((kwargs['env']['HOME'],kwargs['env']['TMPDIR']),(str(home.resolve()),str(tmp.resolve())))
                return types.SimpleNamespace(returncode=0,stdout=json.dumps(dict(storeEpoch='new-epoch',generation=1)))
            try:
                reset.reset(config,run_helper=fake,now=lambda:next(ticks))
                receipt=json.loads((root/'consent-reset.json').read_text())
                self.assertEqual((receipt['sessionID'],receipt['storeEpochAfter'],receipt['generationAfter']),('B','new-epoch',1))
                self.assertEqual((receipt['startMono'],receipt['endMono'],receipt['outcome']),(100,102,'success'))
                with self.assertRaisesRegex(ValueError,'reset-receipt-not-fresh'):
                    reset.reset(config,run_helper=fake,now=lambda:103)
            finally:reset.cleanup.matches=original

if __name__=='__main__':unittest.main()

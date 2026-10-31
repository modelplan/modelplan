# SPDX-License-Identifier: MIT
"""Offline U6 pointer geometry and receipt checks; no GUI or input is posted."""
import importlib.util, json, sys, tempfile, unittest
from pathlib import Path

BIN=Path(__file__).parent/'bin'
sys.path.insert(0,str(BIN))
spec=importlib.util.spec_from_file_location('u6_pointer_plan',BIN/'u6-pointer-plan.py')
tool=importlib.util.module_from_spec(spec);spec.loader.exec_module(tool)
menu_spec=importlib.util.spec_from_file_location('u6_prepare_menu',Path(__file__).parent/'U6/prepare_menu_plan.py')
menu=importlib.util.module_from_spec(menu_spec);menu_spec.loader.exec_module(menu)

class U6PointerPlanTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.root=Path(self.temp.name)
        self.original_matches=tool.cleanup.matches
        self.lease=dict(runID='run',epoch='epoch')
        self.config=dict(batch=str(self.root),expectedLease=self.lease,subjectPidPath=str(self.root/'subject.json'),
            leasePath=str(self.root/'lease.json'),stopPath=str(self.root/'stop.json'),argv=[str(self.root/'Test.app/Contents/MacOS/App')])
        (self.root/'subject.json').write_text(json.dumps(dict(pid=42,state='running')))
        tool.load_and_admit=lambda _:True
        tool.identity=lambda _:dict(pid=42)
        tool.cleanup.matches=lambda *_:True
        tool.launcher_lost=lambda _:False
    def tearDown(self):
        tool.cleanup.matches=self.original_matches
        self.temp.cleanup()
    def write_rows(self, rows):
        (self.root/'native-observations.jsonl').write_text(''.join(json.dumps(r)+'\n' for r in rows))
    def test_dock_move_requires_same_run_expansion_after_posted_input(self):
        self.write_rows([dict(event='dock-surface-frame',runID='run',epoch='epoch',timestamp=100,
            checks=dict(state='sliver',coordinateSpace='cg-screen',x=10,y=20,width=30,height=40,windowNumber=77))])
        tool.make(self.config,'dock')
        plan=json.loads((self.root/'dock-pointer-plan.json').read_text())
        self.assertEqual(plan['steps'],[dict(x=25,y=40,seconds=0,dwell=.25)])
        self.assertEqual(plan['u6OwnedWindowNumber'],77)
        (self.root/'dock-pointer.jsonl').write_text(''.join(json.dumps(r)+'\n' for r in [
            dict(event='mouse-moved-posted',runID='run',epoch='epoch',subjectPID=42,timestamp='1970-01-01T00:01:41Z'),
            dict(event='pointer-result',outcome='posted')]))
        with self.assertRaisesRegex(ValueError,'native-arrival-missing'):tool.check(self.config,'dock')
        with (self.root/'native-observations.jsonl').open('a') as stream:
            stream.write(json.dumps(dict(event='dock-surface-frame',runID='run',epoch='epoch',timestamp=102,
                checks=dict(state='expanded')))+'\n')
        tool.check(self.config,'dock')
    def test_status_click_requires_owned_menu_begin(self):
        self.write_rows([dict(event='status-item-frame',runID='run',epoch='epoch',timestamp=100,
            checks=dict(coordinateSpace='appkit-screen',cgX=100,cgY=20,width=20,height=20))])
        tool.make(self.config,'status')
        plan=json.loads((self.root/'status-pointer-plan.json').read_text())
        self.assertEqual(plan['steps'][0]['action'],'click')
        (self.root/'status-pointer.jsonl').write_text(''.join(json.dumps(r)+'\n' for r in [
            dict(event='mouse-moved-posted',runID='run',epoch='epoch',subjectPID=42,timestamp='1970-01-01T00:01:41Z'),
            dict(event='mouse-button-down-posted',runID='run',epoch='epoch',subjectPID=42,timestamp='1970-01-01T00:01:41Z'),
            dict(event='mouse-button-up-posted',runID='run',epoch='epoch',subjectPID=42,timestamp='1970-01-01T00:01:41Z'),
            dict(event='pointer-result',outcome='posted')]))
        with self.assertRaisesRegex(ValueError,'native-arrival-missing'):tool.check(self.config,'status')
        with (self.root/'native-observations.jsonl').open('a') as stream:
            stream.write(json.dumps(dict(event='menu-begin',runID='run',epoch='epoch',timestamp=102,checks=dict(instanceID='owned',surface='status')))+'\n')
        tool.check(self.config,'status')
        tool.make(self.config,'status','clear')
        clear=json.loads((self.root/'status-pointer-clear-plan.json').read_text())
        self.assertEqual(clear['steps'][0]['action'],'click')
        self.assertNotEqual(clear['output'],plan['output'])
    def test_refresh_plan_reuses_physically_opened_status_menu(self):
        self.write_rows([])
        menu.load_and_admit=lambda _:True
        menu.identity=lambda _:dict(pid=42)
        menu.cleanup.matches=lambda *_:True
        menu.launcher_lost=lambda _:False
        called=[];menu.pointer.check=lambda _,kind:called.append(kind)
        self.config['expectedLease'].update(notBefore=100,expiresAt=200)
        menu.prepare(self.config)
        self.assertEqual(called,['status'])
        plan=json.loads((self.root/'menu-plan.json').read_text())
        self.assertFalse(plan['statusMenu']['openMenu'])
        self.assertEqual(plan['statusMenu']['request']['action'],'refresh')

if __name__=='__main__':unittest.main()

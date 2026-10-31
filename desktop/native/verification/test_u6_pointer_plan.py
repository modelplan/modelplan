# SPDX-License-Identifier: MIT
"""Offline U6 pointer geometry and receipt checks; no GUI or input is posted."""
import importlib.util, json, sys, tempfile, unittest, subprocess
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
        tool.still_admitted=lambda _:True
        tool.identity=lambda _:dict(pid=42)
        tool.cleanup.matches=lambda *_:True
        tool.launcher_lost=lambda _:False
    def tearDown(self):
        tool.cleanup.matches=self.original_matches
        self.temp.cleanup()
    def write_rows(self, rows):
        (self.root/'native-observations.jsonl').write_text(''.join(json.dumps(r)+'\n' for r in rows))
    def status_checks(self):
        return dict(coordinateSpace='appkit-screen',x=1796,y=1403,cgX=1796,cgY=-7,width=60,height=44,
                    settled=True,visible=True,frameGeneration=1,windowNumber=7,
                    stableSinceMono=98,displayBounds=[0,0,2560,1440],menuBarBand=[0,0,2560,28])
    def test_dock_move_requires_same_run_expansion_after_posted_input(self):
        self.write_rows([dict(event='dock-surface-frame',runID='run',epoch='epoch',pid=42,seq=1,mono=100,
            checks=dict(state='sliver',coordinateSpace='cg-screen',x=10,y=20,width=30,height=40,windowNumber=77))])
        tool.make(self.config,'dock')
        plan=json.loads((self.root/'dock-pointer-plan.json').read_text())
        self.assertEqual(plan['steps'],[dict(x=25,y=40,seconds=0,dwell=.25)])
        self.assertEqual(plan['u6OwnedWindowNumber'],77)
        (self.root/'dock-pointer.jsonl').write_text(''.join(json.dumps(r)+'\n' for r in [
            dict(event='mouse-moved-posted',kind='move',runID='run',epoch='epoch',targetPID=42,mono=101),
            dict(event='pointer-result',outcome='posted',runID='run',epoch='epoch',targetPID=42)]))
        with self.assertRaisesRegex(ValueError,'native-arrival-missing'):tool.check(self.config,'dock')
        with (self.root/'native-observations.jsonl').open('a') as stream:
            stream.write(json.dumps(dict(event='dock-surface-frame',runID='run',epoch='epoch',pid=42,seq=2,mono=102,
                checks=dict(state='expanded')))+'\n')
        tool.check(self.config,'dock')
    def test_status_click_requires_owned_menu_begin(self):
        self.write_rows([dict(event='status-item-frame',runID='run',epoch='epoch',pid=42,seq=1,mono=100,
            checks=self.status_checks())])
        tool.make(self.config,'status',clock=lambda:100)
        plan=json.loads((self.root/'status-pointer-plan.json').read_text())
        self.assertEqual(plan['steps'][0]['action'],'click')
        (self.root/'status-pointer.jsonl').write_text(''.join(json.dumps(r)+'\n' for r in [
            dict(event='mouse-moved-posted',kind='move',runID='run',epoch='epoch',targetPID=42,mono=100.8),
            dict(event='mouse-button-down-posted',kind='click',runID='run',epoch='epoch',targetPID=42,mono=100.9),
            dict(event='mouse-button-up-posted',kind='click',runID='run',epoch='epoch',targetPID=42,mono=101),
            dict(event='pointer-result',outcome='posted',runID='run',epoch='epoch',targetPID=42)]))
        with self.assertRaisesRegex(ValueError,'native-arrival-missing'):tool.check(self.config,'status')
        with (self.root/'native-observations.jsonl').open('a') as stream:
            stream.write(json.dumps(dict(event='menu-begin',runID='run',epoch='epoch',pid=42,seq=2,mono=100.95,checks=dict(instanceID='owned',surface='status',subjectPID=42,menuObjectID='owned',sessionID='A')))+'\n')
        tool.check(self.config,'status')
        tool.make(self.config,'status','clear',clock=lambda:100)
        clear=json.loads((self.root/'status-pointer-clear-plan.json').read_text())
        self.assertEqual(clear['steps'][0]['action'],'click')
        self.assertNotEqual(clear['output'],plan['output'])
        (self.root/'status-pointer-clear.jsonl').write_text(''.join(json.dumps(r)+'\n' for r in [
            dict(event='mouse-moved-posted',kind='move',runID='run',epoch='epoch',targetPID=42,mono=103.8),
            dict(event='mouse-button-down-posted',kind='click',runID='run',epoch='epoch',targetPID=42,mono=104),
            dict(event='mouse-button-up-posted',kind='click',runID='run',epoch='epoch',targetPID=42,mono=104.1),
            dict(event='pointer-result',outcome='posted',runID='run',epoch='epoch',targetPID=42)]))
        with self.assertRaisesRegex(ValueError,'first-menu-not-ended'):tool.check(self.config,'status','clear')
        with (self.root/'native-observations.jsonl').open('a') as stream:
            stream.write(json.dumps(dict(event='menu-end',runID='run',epoch='epoch',pid=42,seq=3,mono=103,
                checks=dict(menuObjectID='owned',sessionID='A')))+'\n')
            stream.write(json.dumps(dict(event='menu-begin',runID='run',epoch='epoch',pid=42,seq=4,mono=105,
                checks=dict(instanceID='owned',surface='status',subjectPID=42,menuObjectID='owned',sessionID='B')))+'\n')
        tool.check(self.config,'status','clear')
    def test_refresh_plan_reuses_physically_opened_status_menu(self):
        self.write_rows([])
        menu.still_admitted=lambda _:True
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

    def test_newer_move_hidden_or_replacement_invalidates_settled_frame(self):
        settled=dict(event='status-item-frame',runID='run',epoch='epoch',pid=42,seq=1,mono=100,checks=self.status_checks())
        for change in [dict(visible=True,windowNumber=7),dict(visible=False,windowNumber=7),dict(visible=True,windowNumber=8)]:
            with self.subTest(change=change):
                invalid=dict(event='status-item-frame',runID='run',epoch='epoch',pid=42,seq=2,mono=100.1,
                    checks=dict(change,frameGeneration=2,settled=False))
                self.write_rows([settled,invalid]);now=[100.2]
                with self.assertRaisesRegex(ValueError,'owned-frame-missing'):
                    tool.make(self.config,'status',clock=lambda:now[0],sleep=lambda n:now.__setitem__(0,now[0]+n))
                self.assertFalse((self.root/'status-pointer-plan.json').exists())
        replacement=dict(event='status-item-frame',runID='run',epoch='epoch',pid=42,seq=3,mono=106,
            checks=dict(self.status_checks(),windowNumber=8,frameGeneration=2,stableSinceMono=105))
        self.write_rows([settled,invalid,replacement]);tool.make(self.config,'status',clock=lambda:106)
        plan=json.loads((self.root/'status-pointer-plan.json').read_text())
        self.assertEqual(plan['u6StatusWindowNumber'],8);self.assertEqual(plan['u6StatusFrameGeneration'],2)

    def test_old_settled_frame_is_not_current(self):
        self.write_rows([dict(event='status-item-frame',runID='run',epoch='epoch',pid=42,seq=1,mono=100,checks=self.status_checks())])
        now=[103.0]
        with self.assertRaisesRegex(ValueError,'owned-frame-missing'):
            tool.make(self.config,'status',clock=lambda:now[0],sleep=lambda n:now.__setitem__(0,now[0]+n))

    @unittest.skipUnless(sys.platform=='darwin','Production sampler needs AppKit; pure planner regressions run on every platform')
    def test_production_sampler_invalidations_through_real_planner(self):
        integration=Path(__file__).parent.parent/'ModelPlanAppIntegration/Sources/ModelPlanAppIntegration/U6StatusItemFrameSampler.swift'
        harness=Path(__file__).parent/'U6/StatusFrameTransitionCheck/main.swift'
        if not integration.exists():self.skipTest('Kit omits application source; producer replay runs from the checkout')
        executable=self.root/'sampler-check'
        subprocess.run(['swiftc','-parse-as-library','-module-cache-path',str(self.root/'swift-cache'),str(integration),str(harness),'-o',str(executable)],check=True,capture_output=True)
        traces=json.loads(subprocess.check_output([str(executable)]))
        for change in ['move','hidden','replacement']:
            with self.subTest(change=change):
                self.write_rows(traces[change]);now=[100.2]
                with self.assertRaisesRegex(ValueError,'owned-frame-missing'):
                    tool.make(self.config,'status',clock=lambda:now[0],sleep=lambda n:now.__setitem__(0,now[0]+n))
                self.write_rows(traces[change+'-settled']);tool.make(self.config,'status',clock=lambda:101.7)
                plan=json.loads((self.root/'status-pointer-plan.json').read_text())
                self.assertEqual(plan['steps'][0]['x'],1730 if change=='move' else 1826)
                self.assertEqual(plan['u6StatusWindowNumber'],8 if change=='replacement' else 7)
                (self.root/'status-pointer-plan.json').unlink()

    def status_input(self):
        self.write_rows([dict(event='status-item-frame',runID='run',epoch='epoch',pid=42,seq=1,mono=99,
            checks=self.status_checks())])
        tool.make(self.config,'status',clock=lambda:100)
        rows=[dict(event='mouse-moved-posted',kind='move',runID='run',epoch='epoch',targetPID=42,mono=100),
              dict(event='mouse-button-down-posted',kind='click',runID='run',epoch='epoch',targetPID=42,mono=100),
              dict(event='mouse-button-up-posted',kind='click',runID='run',epoch='epoch',targetPID=42,mono=100.1),
              dict(event='pointer-result',outcome='posted',runID='run',epoch='epoch',targetPID=42)]
        path=self.root/'status-pointer.jsonl';path.write_text(''.join(json.dumps(r)+'\n' for r in rows));return path

    def test_waits_for_owned_arrival_without_posting_another_input(self):
        path=self.status_input();before=path.read_bytes();now=[100.4];checks=[]
        tool.still_admitted=lambda _:checks.append(now[0])
        def sleep(seconds):
            now[0]+=seconds
            if now[0]>=101.1:
                with (self.root/'native-observations.jsonl').open('a') as out:
                    out.write(json.dumps(dict(event='menu-begin',runID='run',epoch='epoch',pid=42,seq=2,mono=101.1,
                        checks=dict(surface='status',subjectPID=42,menuObjectID='owned',sessionID='A')))+'\n')
        tool.check(self.config,'status',clock=lambda:now[0],sleep=sleep)
        self.assertGreater(now[0],100.4);self.assertGreater(len(checks),1);self.assertEqual(path.read_bytes(),before)

    def test_wait_never_extends_the_posted_input_deadline(self):
        path=self.status_input();before=path.read_bytes();now=[100.4]
        def sleep(seconds):now[0]+=seconds
        with self.assertRaisesRegex(ValueError,'native-arrival-missing'):
            tool.check(self.config,'status',clock=lambda:now[0],sleep=sleep)
        self.assertAlmostEqual(now[0],103.1);self.assertEqual(path.read_bytes(),before)

    def test_real_startup_fixture_refuses_and_settled_frame_targets_menu_bar(self):
        fixture=json.loads((Path(__file__).parent/'U6/fixtures/status-frame-startup.json').read_text())
        self.assertEqual(len(fixture),13)
        for row in fixture:row.update(runID='run',epoch='epoch')
        self.write_rows(fixture);now=[101.0]
        with self.assertRaisesRegex(ValueError,'owned-frame-missing'):
            tool.make(self.config,'status',clock=lambda:now[0],sleep=lambda seconds:now.__setitem__(0,now[0]+seconds))
        self.assertFalse((self.root/'status-pointer-plan.json').exists())
        settled=dict(event='status-item-frame',runID='run',epoch='epoch',pid=42,seq=14,mono=107,
                     checks=dict(self.status_checks(),stableSinceMono=106.4))
        self.write_rows(fixture+[settled]);tool.make(self.config,'status',clock=lambda:107.1)
        plan=json.loads((self.root/'status-pointer-plan.json').read_text())
        self.assertEqual((plan['steps'][0]['x'],plan['steps'][0]['y']),(1826,15))
        self.assertEqual(plan['u6FrameSeq'],14)

    def test_late_menu_begin_at_up_plus_3_1_is_not_arrival(self):
        self.status_input()
        with (self.root/'native-observations.jsonl').open('a') as out:
            out.write(json.dumps(dict(event='menu-begin',runID='run',epoch='epoch',pid=42,seq=2,mono=103.2,
                checks=dict(surface='status',subjectPID=42,menuObjectID='owned',sessionID='A')))+'\n')
        with self.assertRaisesRegex(ValueError,'native-arrival-missing'):
            tool.check(self.config,'status',clock=lambda:104)

    def test_status_clear_waits_for_its_distinct_session(self):
        self.status_input()
        with (self.root/'native-observations.jsonl').open('a') as out:
            for row in [dict(event='menu-begin',seq=2,mono=100.05,checks=dict(surface='status',subjectPID=42,menuObjectID='owned',sessionID='A')),
                        dict(event='menu-end',seq=3,mono=101,checks=dict(menuObjectID='owned',sessionID='A'))]:
                out.write(json.dumps(dict(runID='run',epoch='epoch',pid=42,**row))+'\n')
        tool.make(self.config,'status','clear',clock=lambda:100)
        rows=[dict(event='mouse-moved-posted',kind='move',mono=102),dict(event='mouse-button-down-posted',kind='click',mono=102),
              dict(event='mouse-button-up-posted',kind='click',mono=102.1),dict(event='pointer-result',outcome='posted')]
        (self.root/'status-pointer-clear.jsonl').write_text(''.join(json.dumps(dict(runID='run',epoch='epoch',targetPID=42,**r))+'\n' for r in rows))
        now=[102.4]
        def sleep(seconds):
            now[0]+=seconds
            if now[0]>=103.1:
                with (self.root/'native-observations.jsonl').open('a') as out:
                    out.write(json.dumps(dict(event='menu-begin',runID='run',epoch='epoch',pid=42,seq=4,mono=103.1,
                        checks=dict(surface='status',subjectPID=42,menuObjectID='owned',sessionID='B')))+'\n')
        tool.check(self.config,'status','clear',clock=lambda:now[0],sleep=sleep)
        self.assertGreaterEqual(now[0],103.1)

if __name__=='__main__':unittest.main()

# SPDX-License-Identifier: MIT
"""C2.7 replacements for the retired C2.3 final-entry fixture checks.

All ordered receipt corruptions are covered with exact outcomes by the independent
test_u6_receipt_schema matrix. These checks retain the final manifest and untrusted
caller-assertion coverage that is outside the pure oracle.
"""
import json,subprocess,sys,tempfile,unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).parent/'tests'))
import test_u6_receipt_schema as matrix

class U6FinalManifestTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.args=matrix.sb.kit_batch(matrix.sb.context(),matrix.sb.valid(closure_receipt=matrix.CLOSURE).files(),self.temp.name)
        self.batch=Path(self.args[3]);self.config=json.loads(Path(self.args[1]).read_text())
    def final(self):
        result=subprocess.run([sys.executable,'-B',str(Path(__file__).parent/'bin/evidence-u6.py'),*self.args],capture_output=True,text=True)
        self.assertEqual(result.returncode,0,result.stderr)
        return json.loads(result.stdout),json.loads((self.batch/'manifest.json').read_text())
    def test_valid_current_schema_trace_and_manifest_pins(self):
        outcome,manifest=self.final();self.assertEqual(outcome['outcome'],'pass')
        self.assertEqual(manifest['scenarios'][0]['outcome'],'pass')
        for field in ('head','binarySHA256','packageSHA256','helperSHA256','syntheticHomeSeedSHA256'):
            expected=self.config[field]
            self.assertEqual(manifest['subject'][field],expected)
    def test_caller_booleans_cannot_replace_missing_closure(self):
        (self.batch/'launch-cleanup.json').unlink()
        (self.batch/'evidence-receipt.json').write_text(json.dumps(dict(ownedCleanupVerified=True,appStarted=True)))
        outcome,_=self.final();self.assertEqual(outcome['outcome'],'not-run')
    def test_wrong_bundled_member_is_not_run(self):
        path=Path(self.args[7]);manifest=json.loads(path.read_text())
        manifest['bundleMembers']['engine']['sha256']='0'*64;path.write_text(json.dumps(manifest))
        outcome,_=self.final();self.assertEqual(outcome['outcome'],'not-run')
    def test_orphan_image_is_fail_and_never_exported_by_evidence_or_inventory(self):
        image=self.batch/'status-preclick.png';image.write_bytes(b'not-owned-pixels')
        outcome,manifest=self.final();self.assertEqual((outcome['outcome'],outcome['step']),('fail','capture-privacy'))
        self.assertNotIn('status-preclick.png',json.dumps(manifest))
        result=subprocess.run([sys.executable,'-B',str(Path(__file__).parent/'U6/inventory_evidence.py'),'--config',self.args[1]],capture_output=True,text=True)
        self.assertEqual(result.returncode,1,result.stderr)
        self.assertNotIn('status-preclick.png',(self.batch/'filelist.txt').read_text())
        self.assertEqual(json.loads(result.stdout)['outcome'],'fail')
    def test_missing_capture_proof_stays_not_run_but_pixels_are_excluded(self):
        (self.batch/'dock-capture.json').unlink()
        outcome,manifest=self.final();self.assertEqual(outcome['outcome'],'not-run')
        self.assertTrue(outcome['captureContradiction'])
        self.assertTrue(manifest['capturePrivacy']['contradiction'])
        self.assertNotIn('dock-owned.png',json.dumps(manifest))
    def unavailable_receipts(self):
        native_path=self.batch/'native-observations.jsonl'
        native=[json.loads(line) for line in native_path.read_text().splitlines()]
        frames=[r for r in native if r.get('event')=='status-item-frame']
        for name in ('status-pointer.jsonl','status-pointer-clear.jsonl'):
            path=self.batch/name;rows=[json.loads(line) for line in path.read_text().splitlines()]
            for row in rows:
                if row.get('event')!='pointer-host-permission':row['statusWindowCheck']='unavailable'
            path.write_text(''.join(json.dumps(row)+'\n' for row in rows))
            frame=frames[0 if name=='status-pointer.jsonl' else 1]
            moved=next(r for r in rows if r.get('event')=='mouse-moved-posted')
            frame.update(mono=moved['mono']-.1,at=moved['at']-.1,timestamp=moved['at']-.1)
            frame['checks'].update(settled=True,visible=True,frameGeneration=1,windowNumber=1<<32,
                stableSinceMono=frame['mono']-1,displayBounds=[0,0,1440,1080],menuBarBand=[0,0,1440,22])
        native.sort(key=lambda r:r['mono'])
        for seq,row in enumerate(native,1):row['seq']=seq
        native_path.write_text(''.join(json.dumps(row)+'\n' for row in native))
        for name,frame in zip(('status-pointer','status-pointer-clear'),frames):
            path=self.batch/(name+'-plan.json');plan=json.loads(path.read_text())
            plan.update(statusWindowCheck='unavailable',u6StatusWindowNumber=1<<32,u6StatusFrameGeneration=1,
                u6FrameSeq=frame['seq'],steps=[dict(x=1212,y=12.5)])
            path.write_text(json.dumps(plan))
        path=self.batch/'dock-capture.json';capture=json.loads(path.read_text())
        capture['frameSeq']=next(r['seq'] for r in native if r.get('event')=='dock-surface-frame' and r['checks'].get('state')=='expanded')
        path.write_text(json.dumps(capture))
    def test_unavailable_window_receipt_keeps_full_final_chain(self):
        self.unavailable_receipts()
        outcome,_=self.final();self.assertEqual(outcome['outcome'],'pass')
    def test_unavailable_posted_input_without_menu_arrival_never_passes(self):
        self.unavailable_receipts();path=self.batch/'native-observations.jsonl'
        rows=[json.loads(line) for line in path.read_text().splitlines()]
        path.write_text(''.join(json.dumps(row)+'\n' for row in rows if row.get('event')!='menu-begin'))
        outcome,_=self.final();self.assertEqual(outcome['outcome'],'not-run')
    def test_each_plan_receipt_mode_mismatch_is_fail(self):
        for mode in ('required','unavailable'):
            for stem in ('status-pointer','status-pointer-clear'):
                for event in ('mouse-moved-posted','mouse-button-down-posted','mouse-button-up-posted','pointer-result'):
                    with self.subTest(mode=mode,stem=stem,event=event):
                        self.setUp()
                        if mode=='unavailable':self.unavailable_receipts()
                        path=self.batch/(stem+'.jsonl');rows=[json.loads(line) for line in path.read_text().splitlines()]
                        next(r for r in rows if r['event']==event)['statusWindowCheck']='verified' if mode=='unavailable' else 'unavailable'
                        path.write_text(''.join(json.dumps(row)+'\n' for row in rows))
                        outcome,_=self.final();self.assertEqual(outcome['outcome'],'fail')
    def test_unavailable_geometry_contradictions_fail(self):
        for field,value,expected in [('settled',False,'fail'),('visible',False,'not-run'),('stableSinceMono',matrix.sb.MONO0+19.8,'fail'),('menuBarBand',[0,0,1440,5],'fail')]:
            with self.subTest(field=field):
                self.setUp();self.unavailable_receipts();path=self.batch/'native-observations.jsonl'
                rows=[json.loads(line) for line in path.read_text().splitlines()]
                frame=next(r for r in rows if r.get('event')=='status-item-frame');frame['checks'][field]=value
                path.write_text(''.join(json.dumps(row)+'\n' for row in rows))
                outcome,_=self.final();self.assertEqual(outcome['outcome'],expected) # schema-invalid remains NOT-RUN (C2.7 F)
    def test_unavailable_stale_generation_or_planned_point_is_fail(self):
        for change in ('stale','generation','point'):
            with self.subTest(change=change):
                self.setUp();self.unavailable_receipts()
                if change=='stale':
                    path=self.batch/'status-pointer.jsonl';rows=[json.loads(line) for line in path.read_text().splitlines()]
                    for row in rows:
                        if 'mono' in row:row['mono']+=3
                    path.write_text(''.join(json.dumps(row)+'\n' for row in rows))
                elif change=='generation':
                    path=self.batch/'status-pointer-plan.json';plan=json.loads(path.read_text());plan['u6StatusFrameGeneration']=2;path.write_text(json.dumps(plan))
                else:
                    path=self.batch/'status-pointer-plan.json';plan=json.loads(path.read_text());plan['steps'][0]['x']=0;path.write_text(json.dumps(plan))
                outcome,_=self.final();self.assertEqual((outcome['outcome'],outcome['step']),('fail','menu-a'))

if __name__=='__main__':unittest.main()

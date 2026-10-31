# SPDX-License-Identifier: MIT
"""Replay complete and contradictory traces through the actual final U6 command."""
import importlib.util,json,subprocess,sys,unittest
from pathlib import Path

ROOT=Path(__file__).parent;BIN=ROOT/'bin'
spec=importlib.util.spec_from_file_location('fixture',ROOT/'test_u6_evidence_chain.py')
fixture=importlib.util.module_from_spec(spec);spec.loader.exec_module(fixture)

class U6FinalEntryTests(unittest.TestCase):
    def setUp(self):
        self.case=fixture.U6ChainTests('test_complete_trace_passes');self.case.setUp()
        self.root=self.case.root
        (self.root/'run.json').write_text(json.dumps(self.case.config))
        (self.root/'kit-manifest.json').write_text(json.dumps(self.case.manifest))
    def tearDown(self):self.case.tearDown()
    def final(self):
        command=[sys.executable,'-B',str(BIN/'evidence-u6.py'),'--config',str(self.root/'run.json'),
                 '--batch',str(self.root),'--package',str(self.case.package),
                 '--kit-manifest',str(self.root/'kit-manifest.json')]
        result=subprocess.run(command,text=True,capture_output=True)
        self.assertEqual(result.returncode,0,result.stderr)
        return json.loads(result.stdout),json.loads((self.root/'manifest.json').read_text())
    def test_complete_trace_is_pass_and_manifest_pins_subject(self):
        outcome,manifest=self.final()
        self.assertEqual(outcome['outcome'],'pass')
        self.assertEqual(manifest['scenarios'][0]['outcome'],'pass')
        self.assertEqual(manifest['subject']['helperSHA256'],self.case.config['helperSHA256'])
    def test_missing_closure_cannot_be_overridden_by_caller_booleans(self):
        (self.root/'launch-cleanup.json').unlink()
        (self.root/'evidence-receipt.json').write_text(json.dumps(dict(ownedCleanupVerified=True,appStarted=True)))
        outcome,_=self.final();self.assertEqual(outcome['outcome'],'not-run')
    def test_contradictory_closure_is_fail(self):
        path=self.root/'launch-cleanup.json';value=json.loads(path.read_text())
        value['checks']['subjectGone']=False;path.write_text(json.dumps(value))
        outcome,_=self.final();self.assertEqual(outcome['outcome'],'fail')
    def test_review_negative_matrix_through_final_command(self):
        def change_file(name,modify):
            path=self.root/name;value=json.loads(path.read_text());modify(value);path.write_text(json.dumps(value))
        def preclose():
            for row in self.case.native[11:]:row['seq']+=1
            row=dict(self.case.native[12],seq=12,mono=112.8,at=112.8,checks=dict(sessionID='B',cause='other'))
            self.case.native.insert(11,row);self.case.write_native()
        changes=[
            ('wrong-native-pid',lambda:self.case.native[5].update(pid=99)),
            ('native-mono-regression',lambda:self.case.native[8].update(mono=90)),
            ('wrong-bundle-member',lambda:change_file('kit-manifest.json',lambda x:x['bundleMembers']['engine'].update(sha256='0'*64))),
            ('missing-dock-input',lambda:(self.root/'dock-pointer.jsonl').unlink()),
            ('capture-wrong-frame',lambda:change_file('dock-capture.json',lambda x:x.update(frameSeq=2))),
            ('menu-out-of-window',lambda:self.case.native[4].update(mono=110)),
            ('refresh-unchanged',lambda:self.case.native[8].update(rowsSequenceAfter=1)),
            ('duplicate-terminal',lambda:self.case.native.append(dict(self.case.native[8],seq=18,mono=117,at=117))),
            ('ordinary-b-preclose',preclose),
            ('missing-title',lambda:self.case.native.pop(10)),
            ('wrong-reset-operation',lambda:change_file('consent-reset.json',lambda x:x.update(operation='grant'))),
            ('wrong-store-epoch',lambda:change_file('consent-reset.json',lambda x:x.update(storeEpochAfter='other'))),
            ('failed-reset',lambda:change_file('consent-reset.json',lambda x:x.update(exitCode=1,outcome='failed'))),
            ('private-item-remains',lambda:self.case.native[14]['checks']['itemStates'][0].update(state='private')),
            ('stale-title-after-clear',lambda:self.case.native.append(dict(self.case.native[10],seq=18,mono=117,at=117))),
            ('missing-closure-checks',lambda:change_file('launch-cleanup.json',lambda x:x.pop('checks'))),
            ('late-closure',lambda:change_file('launch-cleanup.json',lambda x:x.update(closedAt=181,closedWithinLease=False))),
        ]
        self.tearDown()
        for label,mutation in changes:
            with self.subTest(label=label):
                self.setUp()
                try:
                    mutation();self.case.write_native()
                    outcome,_=self.final();self.assertNotEqual(outcome['outcome'],'pass')
                finally:self.tearDown()

if __name__=='__main__':unittest.main()

# SPDX-License-Identifier: MIT
import copy,importlib.util,json,sys,tempfile,unittest
from pathlib import Path
spec=importlib.util.spec_from_file_location('u5_evidence',Path(__file__).parent/'bin/evidence-u5.py');u5=importlib.util.module_from_spec(spec);spec.loader.exec_module(u5)
class U5EvidenceTests(unittest.TestCase):
    def receipt(self):
        observation=dict(running=True,disk=True,lease=True,visible=True,onScreen=True,nonActivating=True,key=False,postEvents=True,
                         timestamp='2026-01-01T00:00:00Z',activationCall='not-invoked')
        r=dict(profile='synthetic',headSHA='a'*40,binarySHA256='b'*64,packageSHA256='c'*64,profileSHA256='d'*64,helperSHA256='e'*64,cliVersion='0.5.48',durationSeconds=60)
        r.update({k:True for k in u5.COMMON})
        r['scenarios']={name:dict(attempted=True,inputMethod='computer-use',inputDelivered=True,resultObserved=True,nativeObservation=copy.deepcopy(observation),actionEvidenceFiles=['input.json','state.json'],assertions={k:True for k in s['assertions']}) for name,s in u5.CASES.items()}
        return r
    def test_complete_mock_contract_is_pass_but_not_actual_l2_evidence(self):
        self.assertEqual(set(u5.qualify(self.receipt()).values()),{'pass'})
    def test_each_runtime_assertion_can_fail_without_being_relabelled_not_run(self):
        for name,s in u5.CASES.items():
            for key in s['assertions']:
                r=self.receipt();r['scenarios'][name]['assertions'][key]=False
                self.assertEqual(u5.qualify(r)[name],'fail',(name,key))
    def test_missing_receipts_and_direct_handlers_never_establish_pass(self):
        for name in u5.CASES:
            for field,value in [('attempted',False),('inputDelivered',False),('resultObserved',False),('inputMethod','direct-handler'),('inputMethod','hit-test'),('actionEvidenceFiles',[]),('nativeObservation',{}),('assertions',{})]:
                r=self.receipt();r['scenarios'][name][field]=value
                self.assertEqual(u5.qualify(r)[name],'not-run',(name,field))
    def test_unmet_doctor_requirement_blocks_every_scope(self):
        for name in u5.CASES:
            for field in ('visible','onScreen','nonActivating','lease'):
                r=self.receipt();r['scenarios'][name]['nativeObservation'][field]=False
                self.assertEqual(u5.qualify(r)[name],'not-run')
    def test_global_pin_lease_cleanup_and_duration_are_required(self):
        for field,value in [('cliVersion','0.5.46'),('cliVersion',None),('helperSHA256',''),('headSHA',''),('ownedCleanupVerified',False),('watchdogObserved',False),('stopHookObserved',False),('helperIdentityVerified',False),('leaseMatched',False),('stopped',True),('durationSeconds',True),('durationSeconds',1201),('durationSeconds',float('nan'))]:
            r=self.receipt();r[field]=value
            self.assertEqual(set(u5.qualify(r).values()),{'not-run'},field)
    def test_timeout_and_unavailable_physical_display_are_explicit(self):
        r=self.receipt();r['scenarios']['U5-display-following']['inputCapability']='unsupported'
        self.assertEqual(u5.qualify(r)['U5-display-following'],'unsupported')
        r=self.receipt();r['scenarios']['U5-sampler']['timedOut']=True
        self.assertEqual(u5.qualify(r)['U5-sampler'],'timeout')
    def test_stub_login_cannot_claim_real_system_changes_as_success(self):
        r=self.receipt();r['scenarios']['U5-presence-login-stubs']['assertions']['realLoginItemsUntouched']=False
        self.assertEqual(u5.qualify(r)['U5-presence-login-stubs'],'fail')
    def test_existing_structural_builder_accepts_reader_free_legacy_profile_cases(self):
        root=Path(__file__).resolve().parents[3]
        sys.path.insert(0,str(root/'tools/u14'))
        from shape_home import build_home
        shape=json.loads((Path(__file__).parent/'fixtures/u5-synthetic-shape.json').read_text())
        self.assertEqual(shape['tools'],[]);self.assertEqual(shape['files'],[])
        for case in ('coexistence','corrupt-beta07'):
            with tempfile.TemporaryDirectory() as directory:
                home=Path(directory).resolve()/'home';build_home(shape,home,case)
                support=home/'Library/Application Support/ModelPlan'
                self.assertTrue((support/'Beta07/settings-v1.json').is_file())
                self.assertTrue((support/'Native/settings-v1.json').is_file())
                self.assertTrue((support/'Native/community-v1.json').is_file())
                self.assertFalse((support/'settings.json').exists())
                consent=json.loads((home/'.config/modelplan/consent.json').read_text())
                self.assertTrue(all(tool['allowed'] is False for tool in consent['tools'].values()))
    def test_candidate_test_commands_are_limited_to_stub_and_migration_cases(self):
        for name in u5.CASES:
            r=self.receipt();case=r['scenarios'][name]
            case.update(inputMethod='candidate-test-command',candidateBound=True,actionDelivered=True)
            expected='not-run' if u5.CASES[name]['nativeInputRequired'] else 'pass'
            self.assertEqual(u5.qualify(r)[name],expected)
            case['candidateBound']=False;self.assertEqual(u5.qualify(r)[name],'not-run')
    def test_post_events_gate_only_blocks_the_pointer_cases(self):
        r=self.receipt()
        for case in r['scenarios'].values():case['nativeObservation']['postEvents']=False
        result=u5.qualify(r)
        for name,spec in u5.CASES.items():self.assertEqual(result[name],'not-run' if spec['nativeInputRequired'] else 'pass')
    def test_owner_profile_is_rejected(self):
        r=self.receipt();r['profile']='owner'
        with self.assertRaises(ValueError):u5.qualify(r)
if __name__=='__main__':unittest.main()

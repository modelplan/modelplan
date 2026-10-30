# SPDX-License-Identifier: MIT
import sys,unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).parents[1]/'bin'))
from doctor import doctor,requirements_for

class DoctorScenarioTests(unittest.TestCase):
    def observation(self,scope):
        _,required=requirements_for(scope)
        return {k:True for k in required}|dict(timestamp='2026-01-01T00:00:00Z',activationCall='not-invoked')
    def test_native_dock_does_not_require_key_active_or_webkit(self):
        value=self.observation('native-dock')|dict(key=False,active=False,WebKit=False)
        result=doctor(value,'native-dock')
        self.assertEqual(result['outcome'],'pass')
        self.assertEqual(set(result['checks']),{'running','disk','lease','visible','onScreen','nonActivating'})
        self.assertFalse(result['observations']['key']['required'])
        self.assertIs(result['observations']['key']['value'],False)
    def test_each_dock_requirement_fails_individually_and_missing_is_not_run(self):
        value=self.observation('native-dock')
        for key in requirements_for('native-dock')[1]:
            for changed in (value|{key:False},{k:v for k,v in value.items() if k!=key}):
                r=doctor(changed,'native-dock');self.assertEqual(r['outcome'],'not-run',key)
                self.assertEqual(r['checks'][key]['status'],'fail')
                self.assertEqual(sum(x['status']=='fail' for x in r['checks'].values()),1)
    def test_dock_claiming_nonactivating_cannot_also_be_key(self):
        r=doctor(self.observation('U6')|{'keyWindow':True},'U6')
        self.assertEqual(r['outcome'],'not-run');self.assertEqual(r['checks']['nonActivating']['status'],'fail')
    def test_cockpit_requires_real_positive_pid_and_active_key_visible(self):
        value=self.observation('cockpit')|{'WebKitPID':314}
        self.assertEqual(doctor(value,'U11a')['outcome'],'pass')
        for pid in (None,0,-1,True,'314',3.14):
            self.assertEqual(doctor(value|{'WebKitPID':pid},'cockpit')['outcome'],'not-run')
        self.assertEqual(doctor(value|{'WebKit':False},'cockpit')['outcome'],'not-run')
        for key in ('active','key','visible'):
            self.assertEqual(doctor(value|{key:False},'cockpit')['outcome'],'not-run')
    def test_settings_requires_key_visible_but_not_webkit_or_active(self):
        value=self.observation('U8')|dict(active=False,WebKit=False,nonActivating=False)
        self.assertEqual(doctor(value,'U8')['outcome'],'pass')
        for key in ('key','visible'):self.assertEqual(doctor(value|{key:False},'settings')['outcome'],'not-run')
    def test_aliases_and_unknown_scope_fail_closed(self):
        value=dict(running=True,disk=True,lease=True,windowVisible=True,onScreenFrame=True,
                   nonActivatingPanel=True,keyWindow=False,timestamp='now',activationCall='not-invoked')
        self.assertEqual(doctor(value,'native-dock')['outcome'],'pass')
        with self.assertRaises(ValueError):doctor(value,'unbound')
        with self.assertRaises(ValueError):doctor(value,{})
        with self.assertRaises(ValueError):doctor(value|{'activationCall':''},'native-dock')
    def test_u5_pointer_requires_post_events_but_migration_remains_independent(self):
        value=self.observation('native-dock')
        self.assertEqual(doctor(value,'U5')['outcome'],'not-run')
        self.assertEqual(doctor(value|{'postEvents':False},'U5')['checks']['postEvents']['status'],'fail')
        self.assertEqual(doctor(value|{'postEvents':True},'U5')['outcome'],'pass')
        self.assertEqual(doctor(value|{'postEvents':False},'native-dock')['outcome'],'pass')
    def test_boolean_truth_is_not_replaced_by_strings_or_numbers(self):
        value=self.observation('native-dock')
        for invalid in (1,'true',None):self.assertEqual(doctor(value|{'onScreen':invalid},'native-dock')['outcome'],'not-run')

if __name__=='__main__':unittest.main()

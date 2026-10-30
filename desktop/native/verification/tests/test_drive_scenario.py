# SPDX-License-Identifier: MIT
import importlib.util,json,subprocess,sys,tempfile,unittest
from pathlib import Path
from unittest.mock import patch
B=Path(__file__).parents[1]/'bin'
sys.path.insert(0,str(B))
def load(name):
 s=importlib.util.spec_from_file_location(name,B/(name+'.py'));m=importlib.util.module_from_spec(s);s.loader.exec_module(m);return m
D=load('drive-scenario');E=load('export-native');I=load('check_inputs')
class Drive(unittest.TestCase):
 def test_rejected_booking_prevents_wired_helper_and_app_launch(self):
  with tempfile.TemporaryDirectory() as directory:
   root=Path(directory);out=root/'batch';out.mkdir()
   config=dict(runID='run',epoch='epoch',batch=str(out),scratch=str(root/'scratch'),binary='synthetic-app',binarySHA256='a'*64,scripts=[],resourceRoot=str(root),booking={'id':'fixture'},wired=dict(productEntry=True,helper='never-read-helper',helperSHA256='b'*64))
   attempt=D.Attempt(config);attempt.entry='http://127.0.0.1:1234/index.html'
   lease=dict(runID='run',epoch='epoch',exclusive=True,ownerPreempted=False,notBefore=1000,expiresAt=2200,guardianHeartbeatAt=1019.5)
   attempt.scratch.mkdir();D.write(attempt.lease,lease)
   with patch.object(D.time,'time',return_value=1020),patch.object(D,'admit',side_effect=ValueError('booking-rejected')) as admit,patch.object(D.subprocess,'run') as helper,patch.object(D.subprocess,'Popen') as app:
    with self.assertRaisesRegex(ValueError,'booking-rejected'):attempt.launch('preflight')
   admit.assert_called_once();helper.assert_not_called();app.assert_not_called()
   self.assertEqual(admit.call_args.args[0]['booking'],config['booking'])

 def test_shared_setup_failure_omits_user_home_paths_and_subprocess_arguments(self):
  errors=[FileNotFoundError(2,'missing','/Users/synthetic-owner/private/binary'),
          subprocess.TimeoutExpired(['/home/synthetic-owner/private/binary','private-argument'],5),
          subprocess.CalledProcessError(1,['/home/synthetic-owner/private/binary'],output='private-output')]
  for error in errors:
   with self.subTest(error=type(error).__name__),tempfile.TemporaryDirectory() as d:
    root=Path(d);out=root/'batch'
    config=root/'config.json';config.write_text(json.dumps(dict(runID='run',epoch='epoch',batch=str(out),scratch=str(root/'scratch'))))
    def fail(attempt):
     attempt.out.mkdir()
     raise error
    with patch.object(sys,'argv',['drive','--config',str(config)]),patch.object(D.Attempt,'run',fail):
     with self.assertRaises(type(error)):D.main()
    result=json.loads((out/'result.json').read_text())
    self.assertEqual(result['reason'],type(error).__name__+'-errno-'+str(getattr(error,'errno',None)))
    self.assertFalse(result['AppLaunched'])
    self.assertNotIn('synthetic-owner',json.dumps(result))
    self.assertNotIn('private-',json.dumps(result))

 def test_real_relative_import_failure_before_launch(self):
  with tempfile.TemporaryDirectory() as d:
   root=Path(d);(root/'index.html').write_text('<script type="module" src="app.js"></script>');(root/'app.js').write_text("import {face} from './support/face.js';")
   self.assertEqual(I.check(root,'index.html')[0]['target'],'support/face.js')
   (root/'support').mkdir();(root/'support/face.js').write_text('export const face=1;')
   self.assertEqual(I.check(root,'index.html'),[])

 def test_three_cycles_and_grant(self):
  self.assertEqual(len(D.plan()),9);self.assertEqual(sum(x[2] for x in D.plan()),540)
  c=dict(GO=True,announcementID='synthetic',start=1000,expiresAt=2200)
  self.assertTrue(D.valid(c,1020));self.assertFalse(D.valid(c,2200));self.assertFalse(D.valid(c|dict(GO=False),1020))
 def test_native_source_export_has_absent_initial_cpu_and_explicit_cycle_views(self):
  rows=[dict(event='app-sample',pid=1,cycle=1,phase='before-open',elapsedSeconds=0,timestampUnix=1000,cpuSeconds=1,rssBytes=100),dict(event='app-sample',pid=1,cycle=1,phase='open',elapsedSeconds=1,timestampUnix=1001,cpuSeconds=1.1,rssBytes=120)]
  exported=E.export(rows,'synthetic');self.assertIsNone(exported[0]['cpu_percent']);self.assertAlmostEqual(exported[2]['cpu_percent'],10)
  self.assertEqual(exported[1]['phase'],'repeated-open-close')

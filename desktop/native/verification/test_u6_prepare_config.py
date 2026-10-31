# SPDX-License-Identifier: MIT
"""Offline named synthetic seed and run-config pins; no helper or GUI is run."""
import hashlib,importlib.util,json,tempfile,types,unittest,zipfile
from pathlib import Path

spec=importlib.util.spec_from_file_location('u6_prepare',Path(__file__).parent/'U6/prepare_config.py')
prepare=importlib.util.module_from_spec(spec);spec.loader.exec_module(prepare)

class U6PrepareConfigTests(unittest.TestCase):
    def test_platform_cache_locations_match_normal_cli_home_resolution(self):
        self.assertEqual(prepare.default_cache_dir(Path('/synthetic'),'darwin'),Path('/synthetic/Library/Caches/modelplan'))
        self.assertEqual(prepare.default_cache_dir(Path('/synthetic'),'linux'),Path('/synthetic/.cache/modelplan'))
    def test_named_approved_title_and_bundle_pins_are_recorded(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);scratch=root/'scratch';scratch.mkdir();batch=root/'batch';batch.mkdir();locks=root/'locks';locks.mkdir()
            binary=root/'Test.app/Contents/MacOS/App';binary.parent.mkdir(parents=True);binary.write_bytes(b'app')
            helper=root/'Test.app/Contents/Helpers/modelplan';helper.parent.mkdir();helper.write_bytes(b'helper')
            package=root/'candidate.zip'
            with zipfile.ZipFile(package,'w') as archive:
                archive.writestr('Test.app/Contents/MacOS/App',b'app')
                archive.writestr('Test.app/Contents/Helpers/modelplan',b'helper')
            manifest=root/'kit-manifest.json';manifest.write_text(json.dumps(dict(sourceHead='a'*40,
                binarySHA256=hashlib.sha256(b'app').hexdigest(),helperSHA256=hashlib.sha256(b'helper').hexdigest(),
                packageSHA256=hashlib.sha256(package.read_bytes()).hexdigest(),bundleMembers={
                    'main':dict(path='Contents/MacOS/App',sha256=hashlib.sha256(b'app').hexdigest()),
                    'engine':dict(path='Contents/Helpers/modelplan',sha256=hashlib.sha256(b'helper').hexdigest()),
                    'consentHelper':dict(path='Contents/Helpers/modelplan',sha256=hashlib.sha256(b'helper').hexdigest())})))
            lease=root/'lease.json' # macrev-332-16: built before book.py start, so the lease does not exist yet
            args=types.SimpleNamespace(config=str(batch/'run.json'),scratch=str(scratch),batch=str(batch),ledger=str(root/'ledger.jsonl'),
                booking_id='booking',run_id='run',epoch='epoch',lease=str(lease),release=str(root/'release.json'),subject_pid=str(root/'subject.json'),
                locks=str(locks),resource_root=str(root),binary=str(binary),package=str(package),kit_manifest=str(manifest),
                head='a'*40,private_tool='copilot')
            class FakeHome:
                def __init__(self,seed,*_):
                    self.seed=seed;seed.mkdir();(seed/'bin').mkdir();(seed/'synthetic.txt').write_text('synthetic');(seed/'cache').mkdir()
                def allow(self):pass
                def refresh(self):
                    (self.seed/'cache/runtime.txt').write_text('synthetic-runtime')
                    (self.seed/'.modelplan-stub/runtime-calls.jsonl').write_text('{"method":"account.getQuota"}\n')
                    return types.SimpleNamespace(returncode=0)
                def calls(self):return 'account.getQuota'
            modes=[]
            def probe(helper,home,tmp,tool,mode='first',expected_title_hash=None,expected_stub_hash=None,details=False):
                self.assertEqual(tool,'copilot')
                self.assertEqual((prepare.default_cache_dir(home)/'runtime.txt').is_file(),mode=='refreshed')
                self.assertFalse((home/'cache').exists())
                modes.append(mode)
                self.assertEqual(hashlib.sha256((home/'bin/copilot').read_bytes()).hexdigest(),expected_stub_hash)
                if expected_title_hash:self.assertEqual(expected_title_hash,hashlib.sha256(b'GitHub Copilot').hexdigest())
                return dict(title='GitHub Copilot',readingSHA256='e'*64) if details else 'GitHub Copilot'
            prepare.prepare(args,make_home=FakeHome,probe=probe)
            config=json.loads((batch/'run.json').read_text());seed=json.loads((batch/'synthetic-seed.json').read_text())
            self.assertEqual(config['booking']['unit'],'U6')
            entry=json.loads((Path(__file__).parent/'bin/scenarios.json').read_text())['u6'] # macrev-332-27: book.py request uses these
            self.assertEqual((config['booking']['unit'],config['booking']['scenario']),(entry['unit'],entry['bookingScenario']))
            self.assertEqual(config['packageSHA256'],hashlib.sha256(package.read_bytes()).hexdigest())
            self.assertEqual(seed['titleSHA256'],hashlib.sha256(b'GitHub Copilot').hexdigest())
            self.assertEqual(seed['homeSeedSHA256'],config['syntheticHomeSeedSHA256'])
            self.assertEqual(modes,['refreshed','first'])
            self.assertFalse((scratch/'title-twin').exists())
            self.assertTrue(seed['firstAttempt'])
            self.assertEqual((seed['runID'],seed['epoch']),('run','epoch'))
            self.assertEqual(config['expectedLease'],dict(runID='run',epoch='epoch')) # completed from the lease after start
            self.assertEqual(config['leasePath'],str(lease));self.assertFalse(lease.exists())
            with self.assertRaisesRegex(ValueError,'run-path-not-fresh'):
                prepare.prepare(args,make_home=FakeHome,probe=probe)
            for name in ('run.json','synthetic-seed.json'):(batch/name).unlink()
            import shutil;shutil.rmtree(scratch/'home-seed')
            for key in ('lease','release','subject_pid'): # an attempt path that already exists refuses before seeding
                Path(getattr(args,key)).write_text('{}')
                with self.subTest(key=key),self.assertRaisesRegex(ValueError,'run-path-not-fresh'):
                    prepare.prepare(args,make_home=FakeHome,probe=probe)
                Path(getattr(args,key)).unlink();self.assertFalse((scratch/'home-seed').exists())
            for change,error in [(dict(config=str(root/'elsewhere.json')),'run-config-must-be-batch-run-json'),
                                 (dict(run_id=''),'run-identity-invalid'),(dict(epoch='e\n'),'run-identity-invalid')]:
                with self.subTest(change=change),self.assertRaisesRegex(ValueError,error):
                    prepare.prepare(types.SimpleNamespace(**vars(args)|change),make_home=FakeHome,probe=probe)

if __name__=='__main__':unittest.main()

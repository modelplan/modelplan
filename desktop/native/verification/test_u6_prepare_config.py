# SPDX-License-Identifier: MIT
"""Offline named synthetic seed and run-config pins; no helper or GUI is run."""
import hashlib,importlib.util,json,tempfile,types,unittest,zipfile
from pathlib import Path

spec=importlib.util.spec_from_file_location('u6_prepare',Path(__file__).parent/'U6/prepare_config.py')
prepare=importlib.util.module_from_spec(spec);spec.loader.exec_module(prepare)

class U6PrepareConfigTests(unittest.TestCase):
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
            lease=root/'lease.json';lease.write_text(json.dumps(dict(runID='run',epoch='epoch',notBefore=1,expiresAt=1201)))
            args=types.SimpleNamespace(scratch=str(scratch),batch=str(batch),ledger=str(root/'ledger.jsonl'),
                booking_id='booking',lease=str(lease),release=str(root/'release.json'),subject_pid=str(root/'subject.json'),
                locks=str(locks),resource_root=str(root),binary=str(binary),package=str(package),kit_manifest=str(manifest),
                head='a'*40,private_title='Copilot')
            class FakeHome:
                def __init__(self,seed,*_):self.seed=seed
                def allow(self):self.seed.mkdir();(self.seed/'synthetic.txt').write_text('synthetic')
                def refresh(self):
                    (self.seed/'runtime.txt').write_text('synthetic-runtime')
                    return types.SimpleNamespace(returncode=0)
                def calls(self):return 'account.getQuota'
            prepare.prepare(args,make_home=FakeHome)
            config=json.loads((batch/'run.json').read_text());seed=json.loads((batch/'synthetic-seed.json').read_text())
            self.assertEqual(config['booking']['unit'],'U6')
            self.assertEqual(config['packageSHA256'],hashlib.sha256(package.read_bytes()).hexdigest())
            self.assertEqual(seed['titleSHA256'],hashlib.sha256(b'Copilot').hexdigest())
            self.assertEqual(seed['homeSeedSHA256'],config['syntheticHomeSeedSHA256'])
            with self.assertRaisesRegex(ValueError,'run-path-not-fresh'):
                prepare.prepare(args,make_home=FakeHome)

if __name__=='__main__':unittest.main()

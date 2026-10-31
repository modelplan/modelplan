# SPDX-License-Identifier: MIT
import hashlib,importlib.util,json,tempfile,types,unittest
from pathlib import Path

spec=importlib.util.spec_from_file_location('u6_seed_probe',Path(__file__).parent/'U6/seed_probe.py')
probe=importlib.util.module_from_spec(spec);spec.loader.exec_module(probe)

class U6SeedProbeTests(unittest.TestCase):
    def test_probe_uses_only_launch_environment_and_actual_row_name(self):
        original=(probe.subprocess.run,probe.EngineProcess,probe.fresh_rows)
        case=self
        class Engine:
            def __init__(self,*_,arguments=()):case.assertEqual(arguments,('--offline','--read-only'))
            def __enter__(self):
                case.assertEqual(set(self.environment),{'PATH','HOME','TMPDIR','LANG'});return self
            def __exit__(self,*_):pass
            def initialize(self):pass
            def request(self,_):return {'result':{'data':{'scopes':[{'scope':'copilot.runtime_usage','state':'allowed'}]}}}
        def quota(command,**kwargs):
            self.assertEqual(set(kwargs['env']),{'PATH','HOME','TMPDIR','LANG'})
            self.assertEqual(command[1:],['quota','--json','--offline'])
            return types.SimpleNamespace(returncode=0,stdout=json.dumps(dict(accounts=[])))
        try:
            probe.subprocess.run=quota;probe.EngineProcess=Engine
            probe.fresh_rows=lambda _:dict(rows=[dict(id='copilot',accounts=[],name=dict(en='GitHub Copilot'))])
            with tempfile.TemporaryDirectory() as directory:
                home=Path(directory);(home/'bin').mkdir();stub=home/'bin/copilot';stub.write_text('synthetic');stub.chmod(0o700)
                title_hash=hashlib.sha256(b'GitHub Copilot').hexdigest()
                self.assertEqual(probe.probe_seed(Path('/synthetic/helper'),home,home/'tmp',expected_title_hash=title_hash),'GitHub Copilot')
                cache=home/('Library/Caches/modelplan' if probe.sys.platform=='darwin' else '.cache/modelplan')
                (cache/'observed').mkdir(parents=True);(cache/'observed/copilot-v1.json').write_text('{}')
                with self.assertRaisesRegex(ValueError,'reading-or-cooldown-present'):
                    probe.probe_seed(Path('/synthetic/helper'),home,home/'tmp')
        finally:probe.subprocess.run,probe.EngineProcess,probe.fresh_rows=original

if __name__=='__main__':unittest.main()

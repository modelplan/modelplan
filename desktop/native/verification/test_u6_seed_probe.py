# SPDX-License-Identifier: MIT
import importlib.util,json,types,unittest
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
        def quota(command,**kwargs):
            self.assertEqual(set(kwargs['env']),{'PATH','HOME','TMPDIR','LANG'})
            self.assertEqual(command[1:],['quota','--json','--offline'])
            return types.SimpleNamespace(returncode=0,stdout=json.dumps(dict(accounts=[{}])))
        try:
            probe.subprocess.run=quota;probe.EngineProcess=Engine
            probe.fresh_rows=lambda _:dict(rows=[dict(id='copilot',accounts=[{}],name=dict(en='GitHub Copilot'))])
            self.assertEqual(probe.probe_seed(Path('/synthetic/helper'),Path('/synthetic/home'),Path('/synthetic/tmp')),'GitHub Copilot')
            probe.subprocess.run=lambda *_args,**_kwargs:types.SimpleNamespace(returncode=0,stdout='{"accounts":[]}')
            with self.assertRaisesRegex(ValueError,'seeded-account-missing'):
                probe.probe_seed(Path('/synthetic/helper'),Path('/synthetic/home'),Path('/synthetic/tmp'))
        finally:probe.subprocess.run,probe.EngineProcess,probe.fresh_rows=original

if __name__=='__main__':unittest.main()

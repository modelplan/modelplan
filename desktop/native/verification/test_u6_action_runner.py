# SPDX-License-Identifier: MIT
"""Fail-closed U6 action handoff; no UI or pointer process is started."""
import importlib.util,json,tempfile,unittest
from pathlib import Path

spec=importlib.util.spec_from_file_location('u6_actions',Path(__file__).parent/'U6/action_runner.py')
actions=importlib.util.module_from_spec(spec);spec.loader.exec_module(actions)

class U6ActionRunnerTests(unittest.TestCase):
    def test_refused_admission_writes_failure_handoff_and_stop(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);config=dict(batch=str(root),stopPath=str(root/'stop.json'),
                subjectPidPath=str(root/'subject.json'),expectedLease=dict(runID='run',epoch='epoch'))
            path=root/'run.json';path.write_text(json.dumps(config))
            original=actions.load_and_admit
            actions.load_and_admit=lambda _: (_ for _ in ()).throw(ValueError('not-admitted'))
            try:
                with self.assertRaises(SystemExit) as error:actions.run(path,root/'unused-pointer')
                self.assertEqual(error.exception.code,3)
            finally:actions.load_and_admit=original
            self.assertTrue((root/'stop.json').is_file())
            finish=json.loads((root/'operator-finish.json').read_text())
            self.assertEqual((finish['schema'],finish['runID'],finish['outcome']),('u6-actions/1','run','not-run'))
            self.assertTrue(all(x=='not-run' for x in finish['steps'].values()))

if __name__=='__main__':unittest.main()

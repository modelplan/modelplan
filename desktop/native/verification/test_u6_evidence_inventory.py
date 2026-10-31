# SPDX-License-Identifier: MIT
import importlib.util, json, tempfile, unittest
from pathlib import Path

spec=importlib.util.spec_from_file_location('u6_inventory',Path(__file__).parent/'U6/inventory_evidence.py')
tool=importlib.util.module_from_spec(spec);spec.loader.exec_module(tool)

class U6EvidenceInventoryTests(unittest.TestCase):
    def test_pins_and_timing_bound_the_file_inventory(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory)
            config=dict(batch=str(root),head='a'*40,binarySHA256='b'*64,helperSHA256='h'*64,
                packageSHA256='c'*64,syntheticHomeSeedSHA256='d'*64,expectedLease=dict(runID='run',epoch='epoch'))
            subject={key:config[key] for key in ('head','binarySHA256','helperSHA256','packageSHA256','syntheticHomeSeedSHA256')}
            (root/'manifest.json').write_text(json.dumps(dict(profile='synthetic',headSHA=config['head'],subject=subject,
                timing=dict(durationSeconds=10),scenarios=[dict(outcome='not-run')])))
            for name in ('native-observations.jsonl','dock-pointer.jsonl','menu-drive.jsonl','run.json'):(root/name).write_text('{}\n')
            invalid=dict(config,syntheticHomeSeedSHA256='e'*64)
            with self.assertRaisesRegex(ValueError,'pins-mismatch'):tool.inventory(invalid)
            self.assertFalse((root/'filelist.txt').exists())
            tool.inventory(config)
            self.assertEqual(len((root/'filelist.txt').read_text().splitlines()),5)
            self.assertEqual(json.loads((root/'README.md').read_text().split('\n\n')[1])['durationSeconds'],10)

if __name__=='__main__':unittest.main()

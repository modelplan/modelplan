# SPDX-License-Identifier: MIT
"""C2.7 replacements for the retired C2.3 final-entry fixture checks.

All ordered receipt corruptions are covered with exact outcomes by the independent
test_u6_receipt_schema matrix. These checks retain the final manifest and untrusted
caller-assertion coverage that is outside the pure oracle.
"""
import json,subprocess,sys,tempfile,unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).parent/'tests'))
import test_u6_receipt_schema as matrix

class U6FinalManifestTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.args=matrix.sb.kit_batch(matrix.sb.context(),matrix.sb.valid(closure_receipt=matrix.CLOSURE).files(),self.temp.name)
        self.batch=Path(self.args[3]);self.config=json.loads(Path(self.args[1]).read_text())
    def final(self):
        result=subprocess.run([sys.executable,'-B',str(Path(__file__).parent/'bin/evidence-u6.py'),*self.args],capture_output=True,text=True)
        self.assertEqual(result.returncode,0,result.stderr)
        return json.loads(result.stdout),json.loads((self.batch/'manifest.json').read_text())
    def test_valid_current_schema_trace_and_manifest_pins(self):
        outcome,manifest=self.final();self.assertEqual(outcome['outcome'],'pass')
        self.assertEqual(manifest['scenarios'][0]['outcome'],'pass')
        for field in ('head','binarySHA256','packageSHA256','helperSHA256','syntheticHomeSeedSHA256'):
            expected=self.config[field]
            self.assertEqual(manifest['subject'][field],expected)
    def test_caller_booleans_cannot_replace_missing_closure(self):
        (self.batch/'launch-cleanup.json').unlink()
        (self.batch/'evidence-receipt.json').write_text(json.dumps(dict(ownedCleanupVerified=True,appStarted=True)))
        outcome,_=self.final();self.assertEqual(outcome['outcome'],'not-run')
    def test_wrong_bundled_member_is_not_run(self):
        path=Path(self.args[7]);manifest=json.loads(path.read_text())
        manifest['bundleMembers']['engine']['sha256']='0'*64;path.write_text(json.dumps(manifest))
        outcome,_=self.final();self.assertEqual(outcome['outcome'],'not-run')

if __name__=='__main__':unittest.main()

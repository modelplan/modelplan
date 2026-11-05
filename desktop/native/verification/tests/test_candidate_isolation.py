# SPDX-License-Identifier: MIT
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import unittest

MODULE = Path(__file__).resolve().parents[1] / "bin" / "candidate_isolation.py"
spec = importlib.util.spec_from_file_location("candidate_isolation", MODULE)
isolation = importlib.util.module_from_spec(spec)
spec.loader.exec_module(isolation)


class CandidateIsolationTests(unittest.TestCase):
    def test_unproven_guards_refuse_without_scratch_or_false_proof(self):
        receipt = isolation.isolation_receipt()
        self.assertEqual(receipt["verdict"], "refuse")
        self.assertTrue(all(value == "not-enforced" for value in receipt["guards"].values()))
        self.assertTrue(all(value == "not-run" for value in receipt["proofResults"].values()))
        self.assertEqual(receipt["scratchPaths"], {})
        self.assertTrue(receipt["reason"])

    def test_cli_emits_refusal_and_nonzero_exit(self):
        result = subprocess.run([sys.executable, str(MODULE)], capture_output=True, text=True, check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(json.loads(result.stdout)["verdict"], "refuse")
        self.assertEqual(result.stderr, "")


if __name__ == "__main__":
    unittest.main()

# SPDX-License-Identifier: MIT
import importlib.util
from pathlib import Path
import tempfile
import unittest

MODULE = Path(__file__).resolve().parents[1] / "bin" / "keychain_recovery.py"
SPEC = importlib.util.spec_from_file_location("keychain_recovery", MODULE)
recovery = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(recovery)


class Backend:
    def __init__(self): self.current = ["/synthetic/original.keychain-db"]
    def read_search_list(self): return list(self.current)
    def write_search_list(self, value): self.current = list(value)


class KeychainRecoveryTests(unittest.TestCase):
    def test_crash_recovery_is_idempotent_and_journal_precedes_change(self):
        with tempfile.TemporaryDirectory() as temporary:
            journal = Path(temporary) / "journal.json"; backend = Backend()
            recovery.begin(journal, "/synthetic/run.keychain-db", backend, run_id="r", epoch="e")
            self.assertEqual(backend.current, ["/synthetic/run.keychain-db"])
            self.assertEqual(recovery.recover(journal, backend, run_id="r", epoch="e"), "restored")
            self.assertEqual(backend.current, ["/synthetic/original.keychain-db"])
            self.assertEqual(recovery.recover(journal, backend, run_id="r", epoch="e"), "already-restored")

    def test_external_change_and_wrong_epoch_are_not_overwritten(self):
        with tempfile.TemporaryDirectory() as temporary:
            journal = Path(temporary) / "journal.json"; backend = Backend()
            recovery.begin(journal, "/synthetic/run.keychain-db", backend, run_id="r", epoch="e")
            backend.current = ["/synthetic/other.keychain-db"]
            with self.assertRaisesRegex(ValueError, "independently"):
                recovery.recover(journal, backend, run_id="r", epoch="e")
            with self.assertRaisesRegex(ValueError, "journal"):
                recovery.recover(journal, backend, run_id="r", epoch="other")
            self.assertEqual(backend.current, ["/synthetic/other.keychain-db"])

    def test_backend_failure_after_mutation_still_leaves_recovery_journal(self):
        class Interrupted(Backend):
            def write_search_list(self, value):
                super().write_search_list(value)
                raise RuntimeError("simulated interruption")
        with tempfile.TemporaryDirectory() as temporary:
            journal = Path(temporary) / "journal.json"; backend = Interrupted()
            with self.assertRaisesRegex(RuntimeError, "interruption"):
                recovery.begin(journal, "/synthetic/run.keychain-db", backend, run_id="r", epoch="e")
            self.assertTrue(journal.is_file())
            stable = Backend(); stable.current = backend.current
            self.assertEqual(recovery.recover(journal, stable, run_id="r", epoch="e"), "restored")
            self.assertEqual(stable.current, ["/synthetic/original.keychain-db"])


if __name__ == "__main__":
    unittest.main()

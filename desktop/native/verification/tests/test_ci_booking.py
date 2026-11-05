# SPDX-License-Identifier: MIT
import sys
import tempfile
import unittest
from pathlib import Path

BIN = Path(__file__).resolve().parents[1] / "bin"
sys.path.insert(0, str(BIN))
import book
import ci_booking


class SharedGUIBookingTests(unittest.TestCase):
    def test_fifo_prevents_v1_from_starting_while_m1_holds_screen(self):
        with tempfile.TemporaryDirectory() as temp:
            ledger = book.Ledger(Path(temp) / "ledger", clock=lambda: 1000)
            first = ledger.request("M1", "candidate", ["V-01"])["id"]
            ledger.start(first, "M1", "m1-run", "e1")
            second = ledger.request("V1", "candidate", ["V-03"])["id"]
            with self.assertRaisesRegex(ValueError, "queued head"):
                ledger.start(second, "V1", "v1-run", "e2")
            ledger.finish(first, "M1", "m1-run", "e1", cleaned=True)
            self.assertEqual(ledger.start(second, "V1", "v1-run", "e2")["id"], second)

    def test_finish_requires_matching_lease_guardian_and_cleanup(self):
        with tempfile.TemporaryDirectory() as temp:
            ledger = book.Ledger(Path(temp) / "ledger", clock=lambda: 1000)
            ident = ledger.request("V1", "candidate", ["V-03"])["id"]
            lease = ledger.start(ident, "V1", "run", "epoch")
            guardian = {"guardian": "stopped", "subjectClosed": True, "subject": "registered"}
            cleanup = {"runID": "run", "epoch": "epoch", "cleaned": True}
            for bad_lease, bad_guardian, bad_cleanup in (
                ({**lease, "runID": "other"}, guardian, cleanup),
                (lease, {**guardian, "subjectClosed": False}, cleanup),
                (lease, guardian, {**cleanup, "cleaned": False}),
                (lease, guardian, {**cleanup, "epoch": "other"}),
            ):
                with self.assertRaises(ValueError):
                    ci_booking.finish(ledger, ident, "run", "epoch", bad_lease, bad_guardian, bad_cleanup)
                self.assertEqual(ledger.status()["head"]["state"], "started")
            self.assertEqual(ci_booking.finish(ledger, ident, "run", "epoch", lease, guardian, cleanup)["event"], "finish")


if __name__ == "__main__":
    unittest.main()

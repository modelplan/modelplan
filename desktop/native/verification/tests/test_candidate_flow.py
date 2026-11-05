# SPDX-License-Identifier: MIT
import hashlib
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "bin"))
import candidate_flow


class SyntheticPorts:
    def __init__(self, failure=None):
        self.calls = []
        self.failure = failure

    def call(self, name, result):
        self.calls.append(name)
        if self.failure == name:
            raise RuntimeError(name + " failed")
        return result

    def isolation(self, config): return self.call("isolation", {"enforced": True})
    def start_monitor(self, config, isolation): return self.call("monitor-start", {"stopsOnHit": True})
    def check_monitor(self, monitor): return self.call("monitor-check", {"status": "clear"})
    def stop_monitor(self, monitor): return self.call("monitor-stop", {"status": "clear"})
    def admit(self, config, isolation): return self.call("booking", {"admitted": True})
    def start_guardian(self, config, admission): return self.call("guardian", object())
    def launch(self, config, isolation, admission, guardian): return self.call("launch", object())
    def capture(self, config, subject): return self.call("capture", {"scenario": "V-01", "complete": True})
    def close(self, config, subject, guardian): return self.call("close", {"closed": True, "scopeEmpty": True})
    def cleanup(self, config, closure): return self.call("cleanup", {"cleaned": True})
    def finish_booking(self, config, admission, cleanup): return self.call("finish", None)


class CandidateFlowTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(); self.addCleanup(self.tmp.cleanup)
        archive = Path(self.tmp.name) / "synthetic.zip"; archive.write_bytes(b"synthetic")
        self.config = {"sourceSHA": "a" * 40, "archive": str(archive),
                       "archiveSHA256": hashlib.sha256(archive.read_bytes()).hexdigest()}

    def test_synthetic_ports_cover_order_and_receipt(self):
        ports = SyntheticPorts()
        result = candidate_flow.run(self.config, ports)
        self.assertEqual(ports.calls, ["isolation", "monitor-start", "booking", "guardian", "monitor-check", "launch", "monitor-check", "capture", "monitor-check", "close", "cleanup", "finish", "monitor-stop"])
        self.assertEqual(result["outcome"], "pass")
        self.assertEqual(result["candidateSHA256"], self.config["archiveSHA256"])

    def test_guardian_or_capture_failure_always_attempts_independent_closure(self):
        for failure in ("guardian", "launch", "capture"):
            with self.subTest(failure=failure):
                ports = SyntheticPorts(failure)
                result = candidate_flow.run(self.config, ports)
                self.assertEqual(result["outcome"], "not-run")
                self.assertEqual(ports.calls[-4:], ["close", "cleanup", "finish", "monitor-stop"])

    def test_guardian_lost_after_launch_uses_independent_recovery(self):
        class GuardianLost(SyntheticPorts):
            def capture(self, config, subject):
                self.calls.append("guardian-lost")
                raise RuntimeError("guardian heartbeat lost during capture")
        ports = GuardianLost()
        result = candidate_flow.run(self.config, ports)
        self.assertEqual(result["outcome"], "not-run")
        self.assertEqual(ports.calls[-5:], ["guardian-lost", "close", "cleanup", "finish", "monitor-stop"])

    def test_rejected_admission_never_finishes_a_booking(self):
        class Refused(SyntheticPorts):
            def admit(self, config, isolation): return self.call("booking", {"admitted": False})
        ports = Refused()
        self.assertEqual(candidate_flow.run(self.config, ports)["outcome"], "not-run")
        self.assertEqual(ports.calls, ["isolation", "monitor-start", "booking", "monitor-stop"])

    def test_no_booking_finish_if_closure_or_cleanup_is_unconfirmed(self):
        for failure in ("close", "cleanup"):
            ports = SyntheticPorts(failure)
            result = candidate_flow.run(self.config, ports)
            self.assertEqual(result["outcome"], "not-run")
            self.assertNotIn("finish", ports.calls)

    def test_default_ports_fail_before_booking_or_launch(self):
        result = candidate_flow.run(self.config)
        self.assertEqual(result["outcome"], "not-run")
        self.assertEqual(result["errors"][0]["phase"], "isolation")

    def test_isolation_allow_requires_actual_named_enforced_guards(self):
        ports = candidate_flow.ExistingAdmissionPorts()
        for receipt in ({"verdict": "refuse"}, {"verdict": "allow", "guards": {}},
                        {"verdict": "allow", "guards": {"syntheticInputs": "enforced", "providerNetwork": "not-enforced"}}):
            with patch.object(candidate_flow.candidate_isolation, "isolation_receipt", return_value=receipt):
                with self.assertRaisesRegex(RuntimeError, "not enforced"):
                    ports.isolation(self.config)

    def test_monitor_hit_after_launch_stops_before_capture_and_is_recorded(self):
        class Hit(SyntheticPorts):
            def check_monitor(self, monitor):
                self.calls.append("monitor-check")
                return {"status": "hit" if "launch" in self.calls else "clear"}
            def stop_monitor(self, monitor): return self.call("monitor-stop", {"status": "hit"})
        ports = Hit(); result = candidate_flow.run(self.config, ports)
        self.assertNotIn("capture", ports.calls)
        self.assertEqual(ports.calls[-4:], ["close", "cleanup", "finish", "monitor-stop"])
        self.assertEqual(result["keychainMonitor"]["status"], "hit")
        self.assertEqual(result["outcome"], "not-run")

    def test_monitor_without_enforced_stop_cannot_start_booking(self):
        class Unsafe(SyntheticPorts):
            def start_monitor(self, config, isolation): return self.call("monitor-start", {"stopsOnHit": False})
        ports = Unsafe(); result = candidate_flow.run(self.config, ports)
        self.assertNotIn("booking", ports.calls)
        self.assertEqual(result["outcome"], "not-run")

    def test_bad_archive_or_source_never_reaches_ports(self):
        ports = SyntheticPorts()
        for bad in ({**self.config, "sourceSHA": "short"}, {**self.config, "archiveSHA256": "0" * 64}):
            with self.assertRaises(ValueError): candidate_flow.run(bad, ports)
        self.assertEqual(ports.calls, [])

    def test_existing_ports_require_matching_packaged_booking_and_live_guardian(self):
        config = {**self.config, "runConfig": {"subjectKind": "app-zip", "launchMode": "direct",
                   "binarySHA256": self.config["archiveSHA256"], "argv": [self.config["archive"]],
                   "booking": {"scenario": "V-01"}},
                  "guardianIdentity": {"pid": 55, "startSeconds": 7, "startMicroseconds": 1}}
        ports = candidate_flow.ExistingAdmissionPorts()
        with patch.object(candidate_flow.admission, "load_and_admit", side_effect=lambda item: item) as admit, \
             patch.object(candidate_flow.guardian_module, "identity", return_value=config["guardianIdentity"]):
            admitted = ports.admit(config, {"enforced": True})
            self.assertEqual(ports.start_guardian(config, admitted), config["guardianIdentity"])
            self.assertEqual(admit.call_count, 1)
            with self.assertRaisesRegex(ValueError, "match"):
                ports.admit({**config, "archiveSHA256": "0" * 64}, {"enforced": True})
            self.assertEqual(admit.call_count, 1)
        with patch.object(candidate_flow.guardian_module, "identity", return_value=None):
            with self.assertRaisesRegex(ValueError, "not live"):
                ports.start_guardian(config, admitted)


if __name__ == "__main__":
    unittest.main()

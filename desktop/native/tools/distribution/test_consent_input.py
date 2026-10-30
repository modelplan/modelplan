# SPDX-License-Identifier: MIT
"""The actual native workflow must fetch the release admitted by its consent contract."""
import importlib.util
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[4]


class NativeConsentInputTests(unittest.TestCase):
    def test_workflow_archive_input_matches_producer_and_runtime_identity(self):
        workflow = (ROOT / ".github/workflows/macos-distribution.yml").read_text()
        match = re.search(r"fetch-cli --pin ([^ ]+) --output", workflow)
        self.assertIsNotNone(match, "The real packaging workflow must declare its archive input")
        pin_path = (ROOT / match.group(1)).resolve()
        self.assertTrue(pin_path.is_relative_to(ROOT))
        pin = json.loads(pin_path.read_text())
        producer_path = ROOT / "desktop/native/tools/write-consent-bundle-identity.py"
        spec = importlib.util.spec_from_file_location("consent_identity_input_test", producer_path)
        producer = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(producer)
        version = producer.metadata("a" * 40, dict(producer.SOURCE), "b" * 64)["ModelPlanHelperVersion"]
        source = (ROOT / "desktop/native/ModelPlanAppIntegration/Sources/ModelPlanAppIntegration/CommunityConsentCLIIdentity.generated.swift").read_text()
        runtime = re.search(r'static let version = "([^"\n]+)"', source)
        self.assertIsNotNone(runtime)
        self.assertEqual(runtime.group(1), version, "Producer and runtime must admit the same consent release")
        self.assertEqual(pin["version"], version, "Plugin upgrades must not change the native consent input implicitly")
        self.assertEqual(pin["release"], "https://github.com/modelplan/modelplan/releases/download/v" + version)
        self.assertEqual(set(pin["sha256"]), {"darwin_arm64", "darwin_amd64", "linux_arm64", "linux_amd64"})
        for digest in pin["sha256"].values():
            self.assertRegex(digest, r"^[0-9a-f]{64}$")
        runtime_hashes = dict(re.findall(r'"(arm64|x86_64)": "([0-9a-f]{64})"', source))
        self.assertEqual(runtime_hashes, producer.SOURCE, "Inner Darwin hashes must match in producer and runtime")


    def test_every_current_identity_literal_matches_the_single_pin(self):
        pin = json.loads((ROOT / "desktop/native/consent-cli-pin.json").read_text())
        def module(name, path):
            spec = importlib.util.spec_from_file_location(name, path)
            result = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(result)
            return result

        producer = module("consent_identity_literals", ROOT / "desktop/native/tools/write-consent-bundle-identity.py")
        sys.path.insert(0, str(ROOT / "tools/u10"))
        try:
            packaging = module("consent_packaging_literals", ROOT / "tools/u10/package_candidate.py")
        finally:
            sys.path.pop(0)
        swift = (ROOT / "desktop/native/ModelPlanAppIntegration/Sources/ModelPlanAppIntegration/CommunityConsentCLIIdentity.generated.swift").read_text()
        scenario = json.loads((ROOT / "desktop/native/verification/u5-real-input-scenario.json").read_text())
        for consumer, version in {
            "Swift runtime": re.search(r'static let version = "([^"\n]+)"', swift).group(1),
            "Python producer": producer.VERSION,
            "Python metadata": producer.metadata("a" * 40, dict(producer.SOURCE), "b" * 64)["ModelPlanHelperVersion"],
            "U10 candidate": packaging.HELPER_VERSION,
            "U5 scenario": scenario["requiredNativeCLIVersion"],
        }.items():
            with self.subTest(consumer=consumer):
                self.assertEqual(version, pin["version"])
        for consumer, hashes in {
            "Swift thin binaries": dict(re.findall(r'"(arm64|x86_64)": "([0-9a-f]{64})"', swift)),
            "Python thin binaries": producer.SOURCE,
            "U10 thin binaries": packaging.identity.SOURCE,
        }.items():
            with self.subTest(consumer=consumer):
                self.assertEqual(hashes, pin["sourceSHA256ByArchitecture"])
        subprocess.run([sys.executable, "-B", str(ROOT / "desktop/native/tools/generate-consent-cli-identity.py"), "--check"], check=True)


    def test_current_release_capture_and_provenance_match_native_input(self):
        pin = json.loads((ROOT / "desktop/native/consent-cli-pin.json").read_text())
        fixtures = ROOT / "desktop/native/ModelPlanAppIntegration/Tests/ModelPlanAppIntegrationTests/Fixtures"
        name = "consent-v" + pin["version"]
        capture = (fixtures / (name + "-synthetic.json")).read_bytes()
        provenance = json.loads((fixtures / (name + "-provenance.json")).read_text())
        self.assertEqual(provenance["cliVersion"], pin["version"])
        self.assertEqual(provenance["sourceArchiveSHA256"], pin["sha256"][provenance["capturePlatform"]])
        self.assertEqual(provenance["outputSHA256"], hashlib.sha256(capture).hexdigest())
        self.assertEqual(provenance["bytes"], len(capture))
        self.assertEqual(provenance["command"], ["consent", "--json"])
        self.assertEqual(provenance["exit"], 0)
        for gate in ("syntheticHomeOnly", "ownerHomeDenied", "networkDenied", "allReadersOff"):
            self.assertIs(provenance[gate], True)
        self.assertTrue(provenance["isolation"]["outsideDirectoryReadDenied"])
        self.assertTrue(provenance["isolation"]["networkSocketDenied"])
        self.assertEqual(provenance["sourceCommit"], "4011d78d81803d82c7e86a35feebdb2d44cbf364")
        self.assertRegex(provenance["rawSourceHelperSHA256"], r"^[0-9a-f]{64}$")
        self.assertEqual(json.loads(capture)["mode"], "off")


if __name__ == "__main__":
    unittest.main()

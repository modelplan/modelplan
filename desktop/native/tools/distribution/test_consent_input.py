# SPDX-License-Identifier: MIT
"""The actual native workflow must fetch the release admitted by its consent contract."""
import importlib.util
import json
from pathlib import Path
import re
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
        source = (ROOT / "desktop/native/ModelPlanAppIntegration/Sources/ModelPlanAppIntegration/CommunityConsentBundleIdentity.swift").read_text()
        runtime = re.search(r'public static let version = "([^"\n]+)"', source)
        self.assertIsNotNone(runtime)
        self.assertEqual(runtime.group(1), version, "Producer and runtime must admit the same consent release")
        self.assertEqual(pin["version"], version, "Plugin upgrades must not change the native consent input implicitly")
        self.assertEqual(pin["release"], "https://github.com/modelplan/modelplan/releases/download/v" + version)
        for architecture in ("arm64", "amd64"):
            self.assertRegex(pin["sha256"]["darwin_" + architecture], r"^[0-9a-f]{64}$")


if __name__ == "__main__":
    unittest.main()

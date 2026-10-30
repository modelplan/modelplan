# SPDX-License-Identifier: MIT
from pathlib import Path
import re
import unittest

class HelperBoundaryTests(unittest.TestCase):
    def test_app_facing_package_cannot_call_keychain_apis(self):
        root = Path(__file__).parents[2] / 'Sources/ModelPlanCredentialAgent'
        forbidden = re.compile(r'\b(?:SecItemCopyMatching|SecItemAdd|SecItemUpdate|SecItemDelete|SecKeychain\w*)\s*\(')
        violations = [str(path.relative_to(root)) for path in root.rglob('*.swift') if forbidden.search(path.read_text())]
        self.assertEqual(violations, [], 'Keychain operations belong exclusively in the separate quota helper')

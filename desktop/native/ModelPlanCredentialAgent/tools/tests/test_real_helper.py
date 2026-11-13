# SPDX-License-Identifier: MIT
import json
import os
import subprocess
import unittest

class RealHelperTests(unittest.TestCase):
    def setUp(self):
        self.binary = os.environ.get('U7_TEST_HELPER_BINARY')
        if not self.binary:
            self.skipTest('real helper build is required by the macOS proof workflow')
    def run_helper(self, payload, *args):
        return subprocess.run([self.binary, *args], input=payload, capture_output=True, timeout=8,
                              env={'PATH': '/usr/bin:/bin', 'LANG': 'C', 'U7_ENABLE_TOKEN': '1'})
    def test_generated_requests_deny_without_any_secret_field(self):
        for interactive in (False, True):
            value = {'operationId': 'synthetic-operation', 'provider': 'claude',
                     'scope': 'claude.account_usage.saved_login', 'interactive': interactive}
            result = self.run_helper(json.dumps(value).encode())
            self.assertEqual(result.returncode, 0)
            self.assertEqual(json.loads(result.stdout), {'operationId': value['operationId'], 'outcome': 'denied'})
            self.assertEqual(result.stderr, b'')
    def test_invalid_and_oversized_frames_echo_nothing(self):
        for payload in (b'U7_PRIVATE_CANARY', b'x' * 65537, b'{}'):
            result = self.run_helper(payload)
            self.assertEqual(result.returncode, 64)
            self.assertEqual(result.stdout + result.stderr, b'')
    def test_arguments_cannot_enable_a_backend(self):
        result = self.run_helper(b'{}', '--enable-token')
        self.assertEqual(result.returncode, 64)
        self.assertEqual(result.stdout + result.stderr, b'')

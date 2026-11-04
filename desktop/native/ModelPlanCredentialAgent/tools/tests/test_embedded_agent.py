# SPDX-License-Identifier: MIT
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('checker', Path(__file__).parents[1] / 'check_embedded_agent.py')
checker = importlib.util.module_from_spec(spec)
spec.loader.exec_module(checker)

class EmbeddedAgentTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        # Hand-made bytes qualify the packaging checker only, not an executable helper.
        self.payload = b'U7 synthetic helper artifact bytes'
        self.pin = {'schemaVersion': 1, 'sha256': hashlib.sha256(self.payload).hexdigest(),
                    'bytes': len(self.payload), 'inputSHA256': 'a' * 64,
                    'bundleIdentifier': 'ai.modelplan.credential-agent'}
        self.apps = [self.root / 'Build1.app', self.root / 'Build2.app']
        for i, app in enumerate(self.apps):
            helper = app / checker.HELPER
            helper.parent.mkdir(parents=True)
            helper.write_bytes(self.payload)
            descriptor = app / checker.MANIFEST
            descriptor.parent.mkdir(parents=True)
            descriptor.write_text(json.dumps(self.pin))
            (app / 'Contents/Info.plist').write_text('different app build ' + str(i))
    def check(self):
        return checker.check_pair(*self.apps, self.pin)
    def test_app_changes_preserve_the_same_pinned_helper(self):
        self.assertEqual(self.check()['outcome'], 'pass')
    def test_second_helper_change_fails(self):
        (self.apps[1] / checker.HELPER).write_bytes(b'changed helper')
        with self.assertRaises(checker.CheckFailure): self.check()
    def test_equal_length_change_is_detected_by_digest(self):
        (self.apps[1] / checker.HELPER).write_bytes(b'X' * len(self.payload))
        with self.assertRaisesRegex(checker.CheckFailure, 'hash'): self.check()
    def test_self_consistent_replacement_cannot_override_trusted_pin(self):
        replacement = b'other artifact'
        other = dict(self.pin, sha256=hashlib.sha256(replacement).hexdigest(), bytes=len(replacement))
        for app in self.apps:
            (app / checker.HELPER).write_bytes(replacement)
            (app / checker.MANIFEST).write_text(json.dumps(other))
        with self.assertRaisesRegex(checker.CheckFailure, 'pin-mismatch'): self.check()
    def test_missing_helper_fails(self):
        (self.apps[1] / checker.HELPER).unlink()
        with self.assertRaisesRegex(checker.CheckFailure, 'missing'): self.check()
    def test_symlink_helper_fails_without_reading_its_target(self):
        (self.apps[1] / checker.HELPER).unlink()
        (self.apps[1] / checker.HELPER).symlink_to(self.root / 'unavailable-outside-target')
        with self.assertRaisesRegex(checker.CheckFailure, 'symlink'): self.check()
    def test_source_identity_mismatch_fails(self):
        (self.apps[1] / checker.MANIFEST).write_text(json.dumps(dict(self.pin, inputSHA256='b' * 64)))
        with self.assertRaisesRegex(checker.CheckFailure, 'pin-mismatch'): self.check()
    def test_boolean_or_unknown_manifest_fields_fail(self):
        for pin in [dict(self.pin, bytes=True), dict(self.pin, arbitraryPath='elsewhere')]:
            with self.assertRaises(checker.CheckFailure): checker.validate_pin(pin)

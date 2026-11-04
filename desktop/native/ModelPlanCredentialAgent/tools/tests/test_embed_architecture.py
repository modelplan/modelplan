# SPDX-License-Identifier: MIT
"""The embedded helper retains its signature and exact approved architecture."""
import importlib.util
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

TOOLS = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOLS))
spec = importlib.util.spec_from_file_location('embed_architecture', TOOLS / 'embed_fixed_helper.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class EmbedArchitectureTests(unittest.TestCase):
    def test_exact_arm64_requires_valid_signature(self):
        binary = Path('/synthetic/helper')
        with patch.object(module.subprocess, 'check_output', return_value='arm64\n'), patch.object(module.subprocess, 'run') as verify:
            module.verify_architecture(binary, arm64=True)
            verify.assert_called_once_with(['/usr/bin/codesign', '--verify', '--strict', str(binary)], check=True, timeout=30)
        for archs in ('arm64 x86_64', 'x86_64', '', 'arm64 arm64'):
            with self.subTest(archs=archs), patch.object(module.subprocess, 'check_output', return_value=archs), patch.object(module.subprocess, 'run') as verify:
                with self.assertRaises(SystemExit):
                    module.verify_architecture(binary, arm64=True)
                verify.assert_not_called()

    def test_universal_mode_remains_accepted_and_bad_signature_fails(self):
        with patch.object(module.subprocess, 'check_output', return_value='x86_64 arm64'), patch.object(module.subprocess, 'run', side_effect=RuntimeError('bad signature')):
            with self.assertRaises(RuntimeError):
                module.verify_architecture(Path('/synthetic/helper'), arm64=False)

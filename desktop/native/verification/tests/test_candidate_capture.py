# SPDX-License-Identifier: MIT
import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

PATH = Path(__file__).resolve().parents[1] / 'bin' / 'candidate_capture.py'
SPEC = importlib.util.spec_from_file_location('candidate_capture', PATH)
module = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(module)


def rect(x, y, width, height):
    return dict(x=x, y=y, width=width, height=height)


def observation():
    return dict(pid=42, processVerified=True, scale=2, appearance='dark',
                displayFrame=rect(0, 0, 1000, 800), menuBarFrame=rect(0, 0, 1000, 24),
                cropFrame=rect(870, 0, 60, 24), statusFrame=rect(890, 2, 20, 20),
                neighbourFrames=[rect(865, 2, 20, 20), rect(915, 2, 20, 20)],
                windows=[dict(id=7, ownerPID=42, frame=rect(100, 100, 200, 100))])


class Fake:
    def __init__(self):
        self.state = observation()
        self.moved = False
        self.fail = False
    def observe(self, _pid):
        if self.moved:
            return {**self.state, 'statusFrame': rect(891, 2, 20, 20)}
        return self.state
    def capture(self, _pid, kind, _ident, frame, path):
        path.write_bytes(b'synthetic image')
        if self.fail:
            raise RuntimeError('synthetic failure')
        return (frame['width'] * 2, frame['height'] * 2)


class CaptureTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.scratch = self.root / 'private'
        self.batch = self.root / 'batch'
        self.scratch.mkdir()
        self.batch.mkdir()
        self.fake = Fake()
    def tearDown(self):
        self.tmp.cleanup()
    def run_capture(self):
        return module.capture(self.fake, pid=42, source_sha='a' * 40, package_sha256='b' * 64,
                              scratch_parent=self.scratch, batch=self.batch, name='v01')
    def test_receipt_and_atomic_pair(self):
        receipt = self.run_capture()
        self.assertEqual(receipt['displayScale'], 2)
        self.assertEqual(len(receipt['neighbourStatusItemFrames']), 2)
        self.assertEqual(json.loads((self.batch / 'v01' / 'receipt.json').read_text()), receipt)
        self.assertEqual(len(receipt['capturePaths']), 2)
        self.assertFalse(list(self.scratch.iterdir()))
    def test_other_app_window_rejected(self):
        self.fake.state['windows'][0]['ownerPID'] = 43
        with self.assertRaisesRegex(ValueError, 'non-candidate'):
            self.run_capture()
        self.assertFalse(list(self.batch.iterdir()))
    def test_outside_bar_rejected(self):
        self.fake.state['cropFrame'] = rect(870, 0, 60, 25)
        with self.assertRaisesRegex(ValueError, 'outside'):
            self.run_capture()
        self.assertFalse(list(self.batch.iterdir()))
    def test_partial_failure_cleans_private_and_batch(self):
        self.fake.fail = True
        with self.assertRaises(RuntimeError):
            self.run_capture()
        self.assertFalse(list(self.scratch.iterdir()))
        self.assertFalse(list(self.batch.iterdir()))
    def test_move_after_capture_refuses(self):
        original = self.fake.capture
        def move(*args):
            result = original(*args)
            self.fake.moved = True
            return result
        self.fake.capture = move
        with self.assertRaisesRegex(ValueError, 'changed'):
            self.run_capture()
        self.assertFalse(list(self.scratch.iterdir()))
        self.assertFalse(list(self.batch.iterdir()))
    def test_missing_neighbours_refuses(self):
        self.fake.state['neighbourFrames'] = []
        with self.assertRaisesRegex(ValueError, 'neighbour'):
            self.run_capture()


if __name__ == '__main__':
    unittest.main()

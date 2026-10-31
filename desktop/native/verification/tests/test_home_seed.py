# SPDX-License-Identifier: MIT
import hashlib, json, os, sys, tempfile, unittest
from pathlib import Path
from unittest.mock import MagicMock, patch
BIN = Path(__file__).resolve().parents[1] / 'bin'
sys.path.insert(0, str(BIN))
import homeseed  # noqa: E402
import launch  # noqa: E402


class HomeSeed(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.TemporaryDirectory(); self.root = Path(self.dir.name)
        self.seed = self.root / 'home-seed'; (self.seed / 'Library' / 'Prefs').mkdir(parents=True)
        (self.seed / 'Library' / 'Prefs' / 'menu.json').write_text('{"tracked":["private"]}')
        self.binary = self.root / 'app'; self.binary.write_bytes(b'synthetic')

    def tearDown(self):
        self.dir.cleanup()

    def config(self, **extra):
        c = dict(profile='synthetic', binarySHA256=hashlib.sha256(b'synthetic').hexdigest(), argv=[str(self.binary)],
                 syntheticHome=str(self.root / 'home'), syntheticTmp=str(self.root / 'tmp'),
                 subjectPidPath=str(self.root / 'subject.pid'), stopPath=str(self.root / 'stop'),
                 syntheticHomeSeed=str(self.seed), syntheticHomeSeedSHA256=homeseed.tree_sha256(self.seed))
        c.update(extra); return c

    def execute(self, c):
        path = self.root / 'run.json'; path.write_text(json.dumps(c))
        child = MagicMock(pid=123, returncode=0)
        with patch.object(sys, 'argv', ['launch', '--config', str(path), '--execute']), \
             patch.object(launch, 'load_and_admit', lambda c: dict(c, lease=dict(runID='run', epoch='epoch'))), \
             patch.object(launch, 'mark_launching', return_value={}), patch.object(launch, 'register'), \
             patch.object(launch, 'supervise', return_value=None), \
             patch.object(launch.subprocess, 'Popen', return_value=child) as popen:
            try:
                launch.main()
            except SystemExit as exit:
                return exit.code, popen
        return None, popen

    def test_seed_is_copied_into_the_fresh_home_and_verified(self):
        status, popen = self.execute(self.config())
        self.assertEqual(status, 0); popen.assert_called_once()
        self.assertEqual((self.root / 'home' / 'Library' / 'Prefs' / 'menu.json').read_text(), '{"tracked":["private"]}')
        self.assertTrue(self.seed.exists())  # the seed itself is left untouched

    def test_changed_seed_is_refused_before_home_exists(self):
        c = self.config(); (self.seed / 'extra').write_text('x')
        with self.assertRaisesRegex(ValueError, 'home seed changed'):
            self.execute(c)
        self.assertFalse((self.root / 'home').exists())

    def test_symlink_or_outside_seed_is_refused(self):
        os.symlink('/etc/hosts', self.seed / 'link')
        with self.assertRaisesRegex(ValueError, 'symlink|non-regular'):
            homeseed.tree_sha256(self.seed)
        os.unlink(self.seed / 'link')
        other = Path(tempfile.mkdtemp()); (other / 'f').write_text('x')
        try:
            with self.assertRaisesRegex(ValueError, 'beside the synthetic HOME'):
                homeseed.check(self.config(syntheticHomeSeed=str(other), syntheticHomeSeedSHA256=homeseed.tree_sha256(other)))
        finally:
            (other / 'f').unlink(); other.rmdir()

    def test_missing_digest_is_refused(self):
        c = self.config(); del c['syntheticHomeSeedSHA256']
        with self.assertRaisesRegex(ValueError, 'set together'):
            homeseed.check(c)

    def test_dropping_only_the_seed_path_refuses_before_home(self):
        for blank in (None, ''):
            c = self.config()
            if blank is None: del c['syntheticHomeSeed']
            else: c['syntheticHomeSeed'] = blank
            with self.assertRaisesRegex(ValueError, 'set together'):
                self.execute(c)
            self.assertFalse((self.root / 'home').exists())

    def test_empty_directories_change_the_digest(self):
        before = homeseed.tree_sha256(self.seed)
        (self.seed / 'Library' / 'Empty').mkdir()
        self.assertNotEqual(before, homeseed.tree_sha256(self.seed))

    def test_read_only_seed_directory_copies(self):
        ro = self.seed / 'Library' / 'Prefs'; os.chmod(ro, 0o555)
        try:
            c = self.config()
            status, _ = self.execute(c)
            self.assertEqual(status, 0)
            self.assertEqual((self.root / 'home' / 'Library' / 'Prefs' / 'menu.json').read_text(), '{"tracked":["private"]}')
            self.assertEqual((self.root / 'home' / 'Library' / 'Prefs').stat().st_mode & 0o777, 0o555)
        finally:
            os.chmod(ro, 0o755)
            p = self.root / 'home' / 'Library' / 'Prefs'
            if p.exists(): os.chmod(p, 0o755)

    def test_no_seed_keeps_the_empty_home(self):
        c = self.config(); del c['syntheticHomeSeed']; del c['syntheticHomeSeedSHA256']
        status, _ = self.execute(c)
        self.assertEqual(status, 0); self.assertEqual(list((self.root / 'home').iterdir()), [])


if __name__ == '__main__':
    unittest.main()

# SPDX-License-Identifier: MIT
import stat
from pathlib import Path
import tempfile
import unittest
import zipfile
from candidate_archive import validate


class CandidateArchiveTests(unittest.TestCase):
    def archive(self, entries):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        path = Path(directory.name) / 'candidate.zip'
        with zipfile.ZipFile(path, 'w') as archive:
            for name, data, mode in entries:
                info = zipfile.ZipInfo(name)
                info.create_system = 3
                info.external_attr = mode << 16
                archive.writestr(info, data)
        return path

    def test_valid_internal_link_and_ordinary_files(self):
        path = self.archive([('ModelPlan Community.app/Contents/Info.plist', b'plist', stat.S_IFREG | 0o644),
                             ('ModelPlan Community.app/Contents/link', b'Info.plist', stat.S_IFLNK | 0o777)])
        validate(path)

    def test_rejects_traversal_and_symlink_escape(self):
        for entries in [[('../escape', b'x', stat.S_IFREG)],
                        [('ModelPlan Community.app/link', b'../../escape', stat.S_IFLNK)],
                        [('ModelPlan Community.app/link', b'Contents', stat.S_IFLNK),
                         ('ModelPlan Community.app/LINK/injected', b'x', stat.S_IFREG)],
                        [('ModelPlan Community.app/A', b'x', stat.S_IFREG),
                         ('ModelPlan Community.app/a', b'y', stat.S_IFREG)]]:
            with self.subTest(entries=entries), self.assertRaises(ValueError):
                validate(self.archive(entries))

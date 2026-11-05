#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Validate an untrusted candidate ZIP before extracting it on the verifier."""
import argparse
from pathlib import Path, PurePosixPath
import posixpath
import stat
import unicodedata
import zipfile

ROOT = 'ModelPlan Community.app'


def folded(value):
    return unicodedata.normalize('NFD', value).casefold()


def validate(path):
    if path.stat().st_size > 300 * 1024 * 1024:
        raise ValueError('archive too large')
    with zipfile.ZipFile(path) as archive:
        entries = archive.infolist()
        if not entries or len(entries) > 20000 or sum(e.file_size for e in entries) > 1024 * 1024 * 1024:
            raise ValueError('invalid archive inventory')
        names, links = set(), set()
        for item in entries:
            name = item.filename.rstrip('/')
            parts = PurePosixPath(name).parts
            mode = item.external_attr >> 16
            kind = stat.S_IFMT(mode)
            if (not name or folded(name) in names or '\\' in name or name.startswith('/') or
                any(p in ('.', '..') for p in name.split('/')) or name != str(PurePosixPath(name)) or not parts or parts[0] != ROOT or
                kind not in (0, stat.S_IFREG, stat.S_IFDIR, stat.S_IFLNK) or item.file_size > 128 * 1024 * 1024):
                raise ValueError('unsafe archive entry')
            names.add(folded(name))
            if kind == stat.S_IFLNK:
                if item.file_size > 4096:
                    raise ValueError('invalid link')
                target = archive.read(item).decode('utf-8')
                if not target or target.startswith('/') or '\\' in target or '\x00' in target:
                    raise ValueError('unsafe link')
                resolved = posixpath.normpath(posixpath.join(posixpath.dirname(name), target))
                if resolved != ROOT and not resolved.startswith(ROOT + '/'):
                    raise ValueError('link escapes app')
                links.add(folded(name))
        for name in names:
            parent = PurePosixPath(name).parent
            while str(parent) not in ('.', ''):
                if str(parent) in links:
                    raise ValueError('archive contains a symlink descendant')
                parent = parent.parent


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('archive', type=Path)
    validate(parser.parse_args().archive)

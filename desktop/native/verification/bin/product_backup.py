# SPDX-License-Identifier: MIT
"""Back up and restore exactly ModelPlan's own product paths in a real-profile HOME.

`launch.py` runs this around a real-profile subject when the run config says `backup: product`:
the backup is taken before the subject starts and restored after it has ended. The paths are fixed
here and nothing else is ever read, written or removed:

  ~/Library/Application Support/ModelPlan/Native/          (app state)
  ~/Library/Preferences/org.modelplan.community.swift.scaffold.plist
  ~/Library/Caches/modelplan/                             (engine store, cli/internal/store)
  ~/.config/modelplan/consent.json                         (shared reader consent)

Fail closed: a symlink anywhere below HOME on the way to or inside these paths, any name containing
`M0Bridge` (a running coordinator service), or a credential-looking file name refuses the backup.
The backup is a tar of regular files and directories plus a SHA-256 manifest. Restore verifies the
archive hash, refuses any member outside the fixed list, replaces each path with its backed-up
state (absent stays absent), and re-hashes every file against the manifest. Contents are hashed,
never printed. Standalone use, e.g. after a launcher that died before restoring:

  python3 product_backup.py restore --backup-dir <dir>      # prints the restore manifest
  python3 product_backup.py verify  --backup-dir <dir>      # compare HOME to the backup only
"""
import argparse
import hashlib
import io
import json
import os
from pathlib import Path, PurePosixPath
import shutil
import stat
import subprocess
import sys
import tarfile
import time

PRODUCT_PATHS = (
    'Library/Application Support/ModelPlan/Native',
    'Library/Preferences/org.modelplan.community.swift.scaffold.plist',
    'Library/Caches/modelplan',
    '.config/modelplan/consent.json',
)
PREFERENCES = 'Library/Preferences/org.modelplan.community.swift.scaffold.plist'
PREFERENCES_DOMAIN = 'org.modelplan.community.swift.scaffold'
DEFAULTS = '/usr/bin/defaults'
ARCHIVE, MANIFEST, RESTORE = 'product.tar', 'backup-manifest.json', 'restore-manifest.json'
# Never ModelPlan product state; refuse rather than copy. Matched on lower-cased names.
CREDENTIAL_NAMES = ('auth.json', 'credentials.json', '.credentials.json', 'oauth_creds.json')
CREDENTIAL_SUFFIXES = ('.pem', '.p12', '.key', '.keychain', '.keychain-db')


class Refused(ValueError):
    pass


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, 'rb') as stream:
        for block in iter(lambda: stream.read(1 << 20), b''):
            h.update(block)
    return h.hexdigest()


def check_name(rel):
    for part in PurePosixPath(rel).parts:
        low = part.lower()
        if 'm0bridge' in low:
            raise Refused(f'refusing a path named like M0Bridge: {rel}')
    low = PurePosixPath(rel).name.lower()
    if low in CREDENTIAL_NAMES or low.endswith(CREDENTIAL_SUFFIXES) or 'cookie' in low:
        raise Refused(f'refusing a credential-looking file: {rel}')


def inside_list(rel):
    rel = PurePosixPath(rel)
    if rel.is_absolute() or '..' in rel.parts or '.' in rel.parts:
        return False
    return any(rel == PurePosixPath(p) or PurePosixPath(p) in rel.parents for p in PRODUCT_PATHS)


def home_path(home):
    home = Path(home)
    if not home.is_absolute() or home == Path('/') or not home.is_dir() or home.is_symlink():
        raise Refused('backup needs the absolute, real HOME directory')
    return home


def check_parents(home, rel):
    """No symlink between HOME and the product path: a link could redirect a write elsewhere."""
    current = home
    for part in PurePosixPath(rel).parts[:-1]:
        current = current / part
        if current.is_symlink():
            raise Refused(f'refusing a symlinked parent: {current.relative_to(home)}')


def snapshot(home):
    """{root: kind}, [file records] for the fixed product paths. Hashes only; contents never leave."""
    home = home_path(home)
    roots, files = {}, []
    for rel in PRODUCT_PATHS:
        check_parents(home, rel)
        path = home / rel
        try:
            info = path.lstat()
        except FileNotFoundError:
            roots[rel] = 'absent'
            continue
        if stat.S_ISLNK(info.st_mode):
            raise Refused(f'refusing a symlink: {rel}')
        if stat.S_ISREG(info.st_mode):
            check_name(rel)
            roots[rel] = 'file'
            files.append(dict(path=rel, type='file', mode=stat.S_IMODE(info.st_mode), size=info.st_size,
                              sha256=sha256_file(path)))
            continue
        if not stat.S_ISDIR(info.st_mode):
            raise Refused(f'refusing a special file: {rel}')
        roots[rel] = 'dir'
        files.append(dict(path=rel, type='dir', mode=stat.S_IMODE(info.st_mode)))
        for parent, dirs, names in os.walk(path, followlinks=False):
            dirs.sort(); names.sort()
            for name in dirs + names:
                full = Path(parent) / name
                item = full.relative_to(home).as_posix()
                check_name(item)
                info = full.lstat()
                if stat.S_ISDIR(info.st_mode):
                    files.append(dict(path=item, type='dir', mode=stat.S_IMODE(info.st_mode)))
                elif stat.S_ISREG(info.st_mode):
                    files.append(dict(path=item, type='file', mode=stat.S_IMODE(info.st_mode), size=info.st_size,
                                      sha256=sha256_file(full)))
                else:
                    raise Refused(f'refusing a symlink or special file: {item}')
    return roots, files


def backup(home, dest, clock=time.time):
    """Write <dest>/product.tar and <dest>/backup-manifest.json; `dest` must not exist yet."""
    home = home_path(home)
    dest = Path(dest)
    if not dest.is_absolute():
        raise Refused('backupDir must be absolute')
    resolved = dest.resolve()
    for rel in PRODUCT_PATHS:
        root = (home / rel).resolve()
        if resolved == root or root in resolved.parents:
            raise Refused('backupDir must stay outside the product paths')
    roots, files = snapshot(home)
    dest.mkdir(mode=0o700, parents=False, exist_ok=False)
    archive = dest / ARCHIVE
    fd = os.open(archive, os.O_WRONLY | os.O_CREAT | os.O_EXCL | getattr(os, 'O_NOFOLLOW', 0), 0o600)
    with os.fdopen(fd, 'wb') as stream, tarfile.open(fileobj=stream, mode='w', format=tarfile.PAX_FORMAT, dereference=True) as tar:
        # dereference: a hard-linked file is archived as a regular member, which restore accepts.
        # snapshot has already refused every symlink.
        for record in files:
            full = home / record['path']
            info = tar.gettarinfo(str(full), arcname=record['path'])
            info.uid = info.gid = 0; info.uname = info.gname = ''
            if record['type'] == 'file':
                with open(full, 'rb') as source:
                    data = source.read()
                if hashlib.sha256(data).hexdigest() != record['sha256']:
                    raise Refused(f'file changed during backup: {record["path"]}')
                info.size = len(data)
                tar.addfile(info, io.BytesIO(data))
            else:
                tar.addfile(info)
    manifest = dict(schemaVersion=1, home=str(home), createdAt=clock(), productPaths=list(PRODUCT_PATHS),
                    roots=roots, files=files, archiveSHA256=sha256_file(archive))
    write_json(dest / MANIFEST, manifest)
    return manifest


def changes(before, after):
    """Names (never contents) of product files added, changed or removed between two snapshots."""
    old = {r['path']: r for r in before}; new = {r['path']: r for r in after}
    return dict(added=sorted(set(new) - set(old)), removed=sorted(set(old) - set(new)),
                changed=sorted(p for p in set(old) & set(new) if old[p] != new[p]))


def members(tar):
    out = []
    for member in tar.getmembers():
        name = member.name
        if not inside_list(name) or not (member.isfile() or member.isdir()):
            raise Refused(f'archive member outside the product paths: {name}')
        check_name(name)
        out.append(member)
    return out


def sync_preferences(home, dest, roots, runner):
    """cfprefsd caches preferences: import the backed-up domain (or delete it) through `defaults`
    before the file bytes are put back, so the cache and the file agree. macOS only."""
    if not Path(DEFAULTS).exists() and runner is subprocess.run:
        return 'skipped-no-defaults'
    env = dict(PATH='/usr/bin:/bin', HOME=str(home))
    if roots.get(PREFERENCES) == 'file':
        with tarfile.open(dest / ARCHIVE) as tar:
            data = tar.extractfile(PREFERENCES).read()
        staged = Path(dest) / 'preferences-import.plist'
        staged.write_bytes(data); staged.chmod(0o600)
        try:
            runner([DEFAULTS, 'import', PREFERENCES_DOMAIN, str(staged)], check=True, capture_output=True, env=env)
        finally:
            staged.unlink()
        return 'imported'
    runner([DEFAULTS, 'delete', PREFERENCES_DOMAIN], check=False, capture_output=True, env=env)
    return 'deleted'


def remove(path):
    try:
        info = path.lstat()
    except FileNotFoundError:
        return
    if stat.S_ISDIR(info.st_mode) and not stat.S_ISLNK(info.st_mode):
        shutil.rmtree(path)
    else:
        path.unlink()


def restore(dest, home=None, runner=subprocess.run, clock=time.time, sleep=time.sleep):
    """Put the product paths back to the backup. Returns (and writes) the restore manifest."""
    dest = Path(dest)
    manifest = json.loads((dest / MANIFEST).read_text())
    home = home_path(home or manifest['home'])
    if str(home) != manifest['home']:
        raise Refused('backup belongs to a different HOME')
    if list(manifest.get('productPaths', [])) != list(PRODUCT_PATHS):
        raise Refused('backup was taken for a different product path list')
    if sha256_file(dest / ARCHIVE) != manifest['archiveSHA256']:
        raise Refused('backup archive hash mismatch')
    with tarfile.open(dest / ARCHIVE) as tar:
        listed = members(tar)
        if sorted(m.name for m in listed) != sorted(r['path'] for r in manifest['files']):
            raise Refused('backup archive and manifest disagree')
    for rel in PRODUCT_PATHS:
        check_parents(home, rel)
    before = None
    try:
        before = snapshot(home)[1]
    except Refused:
        before = None  # the run left something odd; the restore below replaces it
    preferences = sync_preferences(home, dest, manifest['roots'], runner)
    for rel in PRODUCT_PATHS:
        remove(home / rel)
    with tarfile.open(dest / ARCHIVE) as tar:
        for member in members(tar):
            target = home / member.name
            if member.isdir():
                target.mkdir(parents=True, exist_ok=True)
            else:
                target.parent.mkdir(parents=True, exist_ok=True)
                fd = os.open(target, os.O_WRONLY | os.O_CREAT | os.O_EXCL | getattr(os, 'O_NOFOLLOW', 0), 0o600)
                with os.fdopen(fd, 'wb') as out:
                    shutil.copyfileobj(tar.extractfile(member), out)
            os.chmod(target, member.mode)
            os.utime(target, (member.mtime, member.mtime), follow_symlinks=False)
    mismatches = verify(manifest, home)
    if mismatches and preferences == 'imported':
        sleep(1.0)  # a late cfprefsd flush: put the bytes back once more
        with tarfile.open(dest / ARCHIVE) as tar:
            data = tar.extractfile(PREFERENCES).read()
        (home / PREFERENCES).write_bytes(data)
        mismatches = verify(manifest, home)
    result = dict(schemaVersion=1, restoredAt=clock(), home=str(home), archiveSHA256=manifest['archiveSHA256'],
                  preferences=preferences, restored=not mismatches, mismatches=mismatches,
                  runChanges=changes(manifest['files'], before) if before is not None else 'unreadable')
    write_json(dest / RESTORE, result, replace=True)
    return result


def verify(manifest, home):
    """Paths whose current state differs from the backup (roots that were absent must be absent)."""
    _, now = snapshot(home)
    diff = changes(manifest['files'], now)
    return sorted(diff['added'] + diff['removed'] + diff['changed'])


def write_json(path, data, replace=False):
    flags = os.O_WRONLY | os.O_CREAT | (os.O_TRUNC if replace else os.O_EXCL) | getattr(os, 'O_NOFOLLOW', 0)
    fd = os.open(path, flags, 0o600)
    with os.fdopen(fd, 'w', encoding='utf-8') as stream:
        json.dump(data, stream, sort_keys=True, indent=1)
        stream.flush(); os.fsync(stream.fileno())


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest='action', required=True)
    for name in ('restore', 'verify'):
        cmd = sub.add_parser(name)
        cmd.add_argument('--backup-dir', type=Path, required=True)
    args = parser.parse_args(argv)
    try:
        if args.action == 'restore':
            result = restore(args.backup_dir)
        else:
            manifest = json.loads((args.backup_dir / MANIFEST).read_text())
            mismatches = verify(manifest, home_path(manifest['home']))
            result = dict(matches=not mismatches, mismatches=mismatches)
    except (OSError, ValueError, KeyError, tarfile.TarError) as error:
        print(json.dumps(dict(error=str(error) or type(error).__name__)), file=sys.stderr)
        return 2
    print(json.dumps(result, sort_keys=True))
    return 0 if result.get('restored', result.get('matches')) else 3


if __name__ == '__main__':
    sys.exit(main())

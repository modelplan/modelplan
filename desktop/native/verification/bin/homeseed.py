# SPDX-License-Identifier: MIT
"""Optional synthetic HOME seed: a pre-built profile directory copied into the fresh HOME that launch.py creates.
The seed must be a plain tree (directories and regular files only) whose digest the run config pins."""
import hashlib,os,shutil
from pathlib import Path
def tree_sha256(root):
    root=Path(root)
    if root.is_symlink() or not root.is_dir():raise ValueError('home seed is not a plain directory')
    h=hashlib.sha256()
    for dirpath,dirs,files in os.walk(root,followlinks=False):
        dirs.sort();base=Path(dirpath)
        for name in dirs:
            if (base/name).is_symlink():raise ValueError('home seed contains a symlink')
        for name in sorted(files):
            f=base/name
            if f.is_symlink() or not f.is_file():raise ValueError('home seed contains a non-regular file')
            rel=f.relative_to(root).as_posix();h.update(f'{rel}\0{f.stat().st_mode & 0o777:o}\0'.encode());h.update(hashlib.sha256(f.read_bytes()).digest())
    return h.hexdigest()
def check(c):
    """None when the config names no seed; otherwise the verified (seed path, digest)."""
    if 'syntheticHomeSeed' not in c:return None
    seed=Path(c['syntheticHomeSeed']);want=c.get('syntheticHomeSeedSHA256')
    scratch=Path(c['syntheticHome']).parent.resolve()
    if not isinstance(want,str) or len(want)!=64:raise ValueError('home seed digest missing')
    if seed.resolve().parent!=scratch or seed.resolve()==Path(c['syntheticHome']).resolve():raise ValueError('home seed must sit beside the synthetic HOME in the run scratch')
    if tree_sha256(seed)!=want:raise ValueError('home seed changed')
    return seed,want
def copy_into(c,home):
    """Copy the verified seed into the freshly created HOME and verify the copy."""
    v=check(c)
    if v is None:return
    seed,want=v
    for dirpath,dirs,files in os.walk(seed,followlinks=False):
        rel=Path(dirpath).relative_to(seed);dst=home/rel
        dst.mkdir(mode=0o700,exist_ok=True)
        for name in files:shutil.copy2(Path(dirpath)/name,dst/name,follow_symlinks=False)
    if tree_sha256(home)!=want:raise ValueError('home seed copy mismatch')

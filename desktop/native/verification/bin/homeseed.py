# SPDX-License-Identifier: MIT
"""Optional synthetic HOME seed: a pre-built profile directory copied into the fresh HOME that launch.py creates.
The seed must be a plain tree (directories and regular files only) whose digest the run config pins."""
import hashlib,os,shutil,sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from artifact_paths import is_appledouble
def tree_sha256(root):
    root=Path(root)
    if root.is_symlink() or not root.is_dir():raise ValueError('home seed is not a plain directory')
    h=hashlib.sha256()
    for dirpath,dirs,files in os.walk(root,followlinks=False):
        dirs[:]=sorted(d for d in dirs if not is_appledouble(d));base=Path(dirpath)
        for name in dirs:
            d=base/name
            if d.is_symlink():raise ValueError('home seed contains a symlink')
            h.update(f'{d.relative_to(root).as_posix()}/\0{d.stat().st_mode & 0o777:o}\0'.encode()) # directories count too
        for name in sorted(files):
            if is_appledouble(name):continue
            f=base/name
            if f.is_symlink() or not f.is_file():raise ValueError('home seed contains a non-regular file')
            rel=f.relative_to(root).as_posix();h.update(f'{rel}\0{f.stat().st_mode & 0o777:o}\0'.encode());h.update(hashlib.sha256(f.read_bytes()).digest())
    return h.hexdigest()
def check(c):
    """None when the config names no seed; otherwise the verified (seed path, digest)."""
    path,want=c.get('syntheticHomeSeed'),c.get('syntheticHomeSeedSHA256')
    if path is None and want is None:return None
    if not path or not want:raise ValueError('home seed path and digest must be set together') # e.g. a dropped path with a pinned digest
    seed=Path(path)
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
    modes=[]
    for dirpath,dirs,files in os.walk(seed,followlinks=False):
        dirs[:]=[d for d in dirs if not is_appledouble(d)]
        rel=Path(dirpath).relative_to(seed);dst=home/rel
        dst.mkdir(mode=0o700,exist_ok=True)
        if rel!=Path('.'):modes.append((dst,Path(dirpath).stat().st_mode & 0o777))
        for name in files:
            if not is_appledouble(name):shutil.copy2(Path(dirpath)/name,dst/name,follow_symlinks=False)
    for dst,mode in reversed(modes):os.chmod(dst,mode) # seed directory modes last, deepest first, so read-only dirs still copy (macrev-332-3)
    if tree_sha256(home)!=want:raise ValueError('home seed copy mismatch')

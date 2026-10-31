# SPDX-License-Identifier: MIT
"""Read-only kit inventory check; AppleDouble is transport metadata, not proof."""
import argparse,hashlib,json,re,sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from artifact_paths import is_appledouble

def relative(name):
    if not isinstance(name,str) or not name or any(c in name for c in '\x00\r\n'):
        raise ValueError('invalid-artifact-name')
    path=Path(name)
    if path.is_absolute() or '..' in path.parts or '\\' in name or path.as_posix()!=name:
        raise ValueError('relative-artifact-required')
    return path

def verify(root,expected_head=None,filelist_sha256=None):
    root=Path(root)
    if root.is_symlink() or not root.is_dir():raise ValueError('kit-root-invalid')
    listing=root/'filelist.txt'
    if listing.is_symlink() or not listing.is_file():raise ValueError('kit-filelist-invalid')
    data=listing.read_bytes()
    if filelist_sha256 is not None and hashlib.sha256(data).hexdigest()!=filelist_sha256:
        raise ValueError('kit-filelist-pin-mismatch')
    expected={}
    for line in data.decode('utf-8').splitlines():
        digest,name=line.split('  ',1);path=relative(name)
        if is_appledouble(path):continue
        if name=='filelist.txt' or name in expected or not re.fullmatch('[a-f0-9]{64}',digest):
            raise ValueError('kit-filelist-entry-invalid')
        expected[path.as_posix()]=digest
    actual=set()
    for path in root.rglob('*'):
        if is_appledouble(path.relative_to(root)):continue
        if path.is_symlink():raise ValueError('kit-symlink')
        if not path.is_file() or path==listing:continue
        name=path.relative_to(root).as_posix();actual.add(name)
        if hashlib.sha256(path.read_bytes()).hexdigest()!=expected.get(name):raise ValueError('kit-file-pin-mismatch')
    if actual!=set(expected) or 'manifest.json' not in expected:raise ValueError('kit-inventory-mismatch')
    manifest=json.loads((root/'manifest.json').read_text())
    head=manifest.get('sourceHead')
    if not isinstance(head,str) or not re.fullmatch('[a-f0-9]{40}',head) or expected_head is not None and head!=expected_head:
        raise ValueError('kit-source-pin-mismatch')
    members={}
    for item in manifest['files']:
        path=relative(item['path'])
        if is_appledouble(path):continue
        name=path.as_posix()
        if name in members or item['sha256']!=expected.get(name) or type(item['size']) is not int or item['size']!=(root/path).stat().st_size:
            raise ValueError('kit-manifest-entry-mismatch')
        members[name]=item['sha256']
    if set(members)!=actual-{'manifest.json'}:raise ValueError('kit-manifest-inventory-mismatch')
    return dict(schema='u6-kit-integrity/1',sourceHead=head,verifiedFiles=len(actual))

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--kit',type=Path,required=True)
    p.add_argument('--head');p.add_argument('--filelist-sha256');args=p.parse_args()
    try:print(json.dumps(verify(args.kit,args.head,args.filelist_sha256)))
    except (OSError,ValueError,KeyError,TypeError):
        print('kit-integrity-failed',file=sys.stderr);raise SystemExit(2)

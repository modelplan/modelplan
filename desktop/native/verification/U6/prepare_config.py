# SPDX-License-Identifier: MIT
"""Prepare one pinned U6 synthetic seed and run config after M1's real booking start."""
import argparse,hashlib,json,sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[4]
sys.path[:0]=[str(ROOT/'tools/u14/engine_drive'),str(ROOT/'desktop/native/verification/bin')]
sys.path.insert(0,str(Path(__file__).resolve().parent))
from scenarios import Home
from homeseed import tree_sha256
from evidence_chain import verify_bundle_members,Missing,Contradiction

def sha(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def absolute(value):
    path=Path(value)
    if not path.is_absolute():raise ValueError('absolute-path-required')
    return path
def prepare(args,make_home=Home):
    names=('scratch','batch','ledger','lease','release','subject_pid','locks','resource_root','binary','package','kit_manifest')
    paths={name:absolute(getattr(args,name)) for name in names}
    scratch,batch,locks=paths['scratch'],paths['batch'],paths['locks']
    if not scratch.is_dir() or not batch.is_dir() or not locks.is_dir():raise ValueError('fresh-run-folders-required')
    for path in (scratch/'home',scratch/'tmp',scratch/'home-seed',batch/'run.json',batch/'synthetic-seed.json',batch/'stop.json'):
        if path.exists() or path.is_symlink():raise ValueError('run-path-not-fresh')
    lease=json.loads(paths['lease'].read_text())
    for key in ('runID','epoch','notBefore','expiresAt'):
        if key not in lease:raise ValueError('started-lease-identity-missing')
    manifest=json.loads(paths['kit_manifest'].read_text())
    if (manifest.get('sourceHead')!=args.head or sha(paths['binary'])!=manifest.get('binarySHA256')
        or sha(paths['package'])!=manifest.get('packageSHA256')):
        raise ValueError('candidate-pin-mismatch')
    helper=paths['binary'].parent.parent/'Helpers/modelplan'
    if helper.is_symlink() or sha(helper)!=manifest.get('helperSHA256'):raise ValueError('helper-pin-mismatch')
    try:verify_bundle_members(dict(argv=[str(paths['binary'])],binarySHA256=manifest['binarySHA256'],
        helperSHA256=manifest['helperSHA256'],packageSHA256=manifest['packageSHA256']),manifest,paths['package'])
    except (Missing,Contradiction) as error:raise ValueError('bundle-member-pin-mismatch') from error
    profile_path=ROOT/'tools/u14/engine_drive/profile.json';profile=json.loads(profile_path.read_text())
    title=args.private_title
    if (not isinstance(title,str) or not title or len(title)>128 or
        title.lower()!='copilot' or title.lower() not in profile.get('tools',[])
        or any(ord(c)<32 or ord(c)==127 for c in title)):
        raise ValueError('private-title-not-in-approved-profile')
    seed=scratch/'home-seed'
    synthetic=make_home(seed,helper,'http://127.0.0.1:1',profile)
    synthetic.allow();refresh=synthetic.refresh() # the approved Copilot runtime row is part of the seed
    if refresh.returncode!=0 or 'account.getQuota' not in synthetic.calls():
        raise ValueError('synthetic-private-reading-not-seeded')
    digest=tree_sha256(seed)
    config=dict(scenario='u6',profile='synthetic',head=args.head,binarySHA256=manifest['binarySHA256'],
        packageSHA256=manifest['packageSHA256'],helperSHA256=manifest['helperSHA256'],
        argv=[str(paths['binary']),'--u6-drive-contract',str(scratch/'native-guard.json')],
        scratch=str(scratch),batch=str(batch),locks=str(locks),resourceRoot=str(paths['resource_root']),
        syntheticHome=str(scratch/'home'),syntheticTmp=str(scratch/'tmp'),syntheticHomeSeed=str(seed),
        syntheticHomeSeedSHA256=digest,leasePath=str(paths['lease']),releasePath=str(paths['release']),
        stopPath=str(batch/'stop.json'),subjectPidPath=str(paths['subject_pid']),
        preparedReceiptPath=str(batch/'prepared.json'),requiredSeconds=300,quitGraceSeconds=5,
        booking=dict(id=args.booking_id,lane='M1',unit='U6',scenario='U6-DockMenu-synthetic',ledger=str(paths['ledger'])),
        expectedLease={key:lease[key] for key in ('runID','epoch','notBefore','expiresAt')})
    seed_receipt=dict(schema='u6-seed/1',runID=lease['runID'],epoch=lease['epoch'],homeSeedSHA256=digest,
        titleSHA256=hashlib.sha256(title.encode()).hexdigest(),profileSHA256=sha(profile_path))
    with (batch/'synthetic-seed.json').open('x') as stream:json.dump(seed_receipt,stream,sort_keys=True);stream.write('\n')
    with (batch/'run.json').open('x') as stream:json.dump(config,stream,indent=2);stream.write('\n')
    print(json.dumps(dict(runID=lease['runID'],epoch=lease['epoch'],head=args.head,seedSHA256=digest)))

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    for name in ('scratch','batch','ledger','booking-id','lease','release','subject-pid','locks','resource-root','binary','package','kit-manifest','head','private-title'):
        p.add_argument('--'+name,required=True)
    prepare(p.parse_args())

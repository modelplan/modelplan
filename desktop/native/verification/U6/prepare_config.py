# SPDX-License-Identifier: MIT
"""Build one attempt's pinned U6 synthetic seed and run config BEFORE `book.py start` (SKILL.md launch branch,
`scenario.py build`; macrev-332-16). It needs only the attempt's run ID/epoch and paths, never the lease: the run
config names `leasePath`, which the sequence reads before start, and the sequence binds `expectedLease` to the
started lease afterwards (refusing another run/epoch). Every attempt path must still be fresh."""
import argparse,hashlib,json,sys,shutil
from pathlib import Path

ROOT=Path(__file__).resolve().parents[4]
sys.path[:0]=[str(ROOT/'tools/u14/engine_drive'),str(ROOT/'desktop/native/verification/bin')]
sys.path.insert(0,str(Path(__file__).resolve().parent))
from scenarios import Home
from homeseed import tree_sha256
from evidence_chain import verify_bundle_members,Missing,Contradiction
from seed_probe import probe_seed

def sha(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def absolute(value):
    path=Path(value)
    if not path.is_absolute():raise ValueError('absolute-path-required')
    return path
def default_cache_dir(home,platform=sys.platform):
    if platform=='darwin':return Path(home)/'Library/Caches/modelplan'
    if platform.startswith('linux'):return Path(home)/'.cache/modelplan'
    raise ValueError('unsupported-seed-platform')

def relocate_cache(seed):
    custom=seed/'cache';default=default_cache_dir(seed)
    if custom.is_symlink() or default.exists():raise ValueError('seed-cache-invalid')
    default.parent.mkdir(parents=True,exist_ok=True)
    if custom.is_dir():shutil.move(str(custom),str(default))
    else:default.mkdir()

def prepare(args,make_home=Home,probe=probe_seed):
    names=('config','scratch','batch','ledger','lease','release','subject_pid','locks','resource_root','binary','package','kit_manifest')
    paths={name:absolute(getattr(args,name)) for name in names}
    scratch,batch,locks=paths['scratch'],paths['batch'],paths['locks']
    if not scratch.is_dir() or not batch.is_dir() or not locks.is_dir():raise ValueError('fresh-run-folders-required')
    if paths['config']!=batch/'run.json':raise ValueError('run-config-must-be-batch-run-json')
    for path in (scratch/'home',scratch/'tmp',scratch/'home-seed',batch/'run.json',batch/'synthetic-seed.json',batch/'stop.json',
                 paths['lease'],paths['release'],paths['subject_pid']): # the lease does not exist yet: start writes it
        if path.exists() or path.is_symlink():raise ValueError('run-path-not-fresh')
    run,epoch=args.run_id,args.epoch # the same values the sequence passes to book.py start
    if any(not isinstance(x,str) or not x or len(x)>128 or not x.isprintable() for x in (run,epoch)):raise ValueError('run-identity-invalid')
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
    tool=args.private_tool
    if tool!='copilot' or tool not in profile.get('tools',[]):raise ValueError('private-tool-not-in-approved-profile')
    seed=scratch/'home-seed'
    synthetic=make_home(seed,helper,'http://127.0.0.1:1',profile)
    synthetic.allow();relocate_cache(seed) # never refresh the real seed or edit its rate-limit state
    probe_tmp=scratch/'seed-probe-tmp';probe_tmp.mkdir()
    twin=scratch/'title-twin'
    try:
        other=make_home(twin,helper,'http://127.0.0.1:1',profile);other.allow();refresh=other.refresh()
        if refresh.returncode!=0 or 'account.getQuota' not in other.calls():raise ValueError('twin-reading-missing')
        relocate_cache(twin)
        title=probe(helper,twin,probe_tmp,tool,mode='refreshed')
        title_hash=hashlib.sha256(title.encode()).hexdigest()
        probe(helper,seed,probe_tmp,tool,mode='first',expected_title_hash=title_hash)
    finally:
        shutil.rmtree(probe_tmp)
        if twin.exists():shutil.rmtree(twin)
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
        expectedLease=dict(runID=run,epoch=epoch)) # the sequence adds notBefore/expiresAt from the started lease
    seed_receipt=dict(schema='u6-seed/1',runID=run,epoch=epoch,homeSeedSHA256=digest,
        toolID=tool,titleSHA256=title_hash,profileSHA256=sha(profile_path),firstAttempt=True)
    with (batch/'synthetic-seed.json').open('x') as stream:json.dump(seed_receipt,stream,sort_keys=True);stream.write('\n')
    with (batch/'run.json').open('x') as stream:json.dump(config,stream,indent=2);stream.write('\n')
    print(json.dumps(dict(runID=run,epoch=epoch,head=args.head,seedSHA256=digest)))

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    for name in ('config','scratch','batch','ledger','booking-id','run-id','epoch','lease','release','subject-pid','locks','resource-root','binary','package','kit-manifest','head','private-tool'):
        p.add_argument('--'+name,required=True)
    prepare(p.parse_args())

# SPDX-License-Identifier: MIT
"""Validate an explicit synthetic run; execute only with an existing fresh lease.

`launchMode` in the run config selects how the subject starts (default `direct`):
- direct: the subject is launch.py's own child behind an exec gate (same PID, registered before
  the subject code runs).
- launchservices: the pinned binary is copied into a minimal .app in run scratch (syntheticTmp)
  and opened with `open -n -W --env ...`, so macOS launches it like a user-opened app (cooperative
  activation refuses key/active state to processes spawned directly from an agent shell). The
  subject PID is found by its exact bundle executable path, registered, then supervised by its
  start identity.
Both modes record the run's scan scope (exact executable path and synthetic HOME) in the
reservation, so the guardian can prove closure even if the subject never registers.
"""
import argparse,hashlib,json,os,plistlib,re,shutil,signal,subprocess,sys,time
from pathlib import Path
from admission import validate,load_and_admit
from guardian import register,mark_launching,identity,stop_identities,cleanup
import process_scan
OPEN=['/usr/bin/open'];CODESIGN='/usr/bin/codesign';DISCOVERY_SECONDS=20.0
BUNDLE_ID=re.compile(r'[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+')
def sha256(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def subject_env(home,tmp):return {'PATH':'/usr/bin:/bin','HOME':str(home),'TMPDIR':str(tmp),'LANG':'en_US.UTF-8'}
def main():
    p=argparse.ArgumentParser(description=__doc__,formatter_class=argparse.RawDescriptionHelpFormatter);p.add_argument('--config',type=Path,required=True);p.add_argument('--execute',action='store_true');a=p.parse_args()
    c=json.loads(a.config.read_text())
    if not a.execute:validate(c,time.time());print('Run contract valid; no process launched');return
    c=load_and_admit(c) # Read external records before creating synthetic resources.
    mode=c.get('launchMode','direct')
    if mode=='launchservices' and not Path(OPEN[0]).exists():raise ValueError('launchservices mode needs macOS '+OPEN[0])
    home=Path(c['syntheticHome']);tmp=Path(c['syntheticTmp'])
    home.mkdir(exist_ok=False);tmp.mkdir(exist_ok=False)
    binary=Path(c['argv'][0]).resolve(strict=True)
    if sha256(binary)!=c['binarySHA256']:raise ValueError('binary identity changed')
    bundle=make_bundle(c,binary,tmp) if mode=='launchservices' else None
    c=load_and_admit(c) # Reread lease/release after filesystem/hash work, immediately before spawn.
    pid_path=Path(c['subjectPidPath']) # Required: the guardian supervises this subject.
    if bundle:return launch_services(c,bundle,pid_path,subject_env(home,tmp))
    # Until registered, the guardian reports closure unconfirmed unless its scope scan is empty.
    launcher=mark_launching(pid_path,scope=process_scan.scope_for(binary,home),mode=mode)
    # Exec gate: the child waits for one byte on stdin before exec'ing the subject (same PID). If launch
    # dies before releasing it, stdin reaches EOF and the child exits without ever running the subject.
    gate=[sys.executable,'-I','-c',GATE,*c['argv']]
    child=subprocess.Popen(gate,stdin=subprocess.PIPE,env=subject_env(home,tmp))
    def stop_child(*_):
        child.terminate()
        try:child.wait(10)
        except subprocess.TimeoutExpired:child.kill();child.wait()
        raise SystemExit(3)
    for sig in (signal.SIGTERM,signal.SIGINT,signal.SIGHUP):signal.signal(sig,stop_child)
    try:
        register(pid_path,child.pid,launcher)
        child.stdin.write(b'g');child.stdin.close() # Registered: release the gate.
    except BaseException:
        stop_child() # Never leave an unregistered child running.
    print(json.dumps({'runID':c['lease']['runID'],'epoch':c['lease']['epoch'],'ownedPID':child.pid,'launchMode':mode}),flush=True)
    # Stay attached: stop the child on the stop file, a stale guardian heartbeat, revocation or the deadline,
    # so a dead guardian still fails closed. Exit status 0 only when the child ended by itself.
    reason=supervise(child,c)
    print(json.dumps({'ownedPID':child.pid,'exit':child.returncode,'stoppedBy':reason,'launchMode':mode}))
    raise SystemExit(0 if reason is None else 3)
GATE='import os,sys\nif sys.stdin.buffer.read(1)!=b"g":sys.exit(97)\nos.execv(sys.argv[1],sys.argv[1:])'
def make_bundle(c,binary,tmp):
    """Minimal .app around a byte-identical copy of the pinned binary (never a link: the scan and
    PID discovery match this exact path). Optional: bundleIdentifier, bundleUIElement (default true,
    as packaged), bundleResources (absolute paths copied into Contents/Resources), bundleSign none|adhoc."""
    ident=c.get('bundleIdentifier','org.modelplan.verification.subject');ui=c.get('bundleUIElement',True)
    sign=c.get('bundleSign','none');resources=c.get('bundleResources',[])
    if not isinstance(ident,str) or not BUNDLE_ID.fullmatch(ident):raise ValueError('bundleIdentifier must be reverse-DNS')
    if type(ui) is not bool or sign not in ('none','adhoc'):raise ValueError('bundleUIElement must be boolean; bundleSign none or adhoc')
    if not isinstance(resources,list) or any(not isinstance(r,str) or not os.path.isabs(r) for r in resources):raise ValueError('bundleResources must be absolute paths')
    app=tmp/'.launchservices'/(binary.name+'.app');macos=app/'Contents'/'MacOS'
    macos.mkdir(parents=True,exist_ok=False)
    exe=macos/binary.name;shutil.copyfile(binary,exe);exe.chmod(0o755)
    if sha256(exe)!=c['binarySHA256']:raise ValueError('bundled binary identity changed')
    for r in resources:
        source=Path(r).resolve(strict=True);target=app/'Contents'/'Resources'/source.name
        target.parent.mkdir(exist_ok=True)
        shutil.copytree(source,target,symlinks=True) if source.is_dir() else shutil.copyfile(source,target)
    info=dict(CFBundleExecutable=binary.name,CFBundleIdentifier=ident,CFBundleName=binary.name,CFBundlePackageType='APPL',
              CFBundleInfoDictionaryVersion='6.0',CFBundleShortVersionString='0.0.0',CFBundleVersion='0',
              LSUIElement=ui,NSHighResolutionCapable=True)
    with (app/'Contents'/'Info.plist').open('xb') as f:plistlib.dump(info,f)
    if sign=='adhoc':subprocess.run([CODESIGN,'--force','--sign','-',str(app)],check=True,capture_output=True)
    return dict(app=app,exe=exe,evidence=dict(bundle=str(app),bundleIdentifier=ident,bundleUIElement=ui,bundleSign=sign,bundledSHA256=sha256(exe)))
class Owned:
    """A LaunchServices subject: not our child, so it is polled and signalled only by its start identity."""
    def __init__(self,ident,helper):self.ident=ident;self.pid=ident['pid'];self.helper=helper;self.returncode=None
    def alive(self):return cleanup.matches(identity(self.pid),self.ident)
    def poll(self):return None if self.alive() else 'exited'
    def send(self,sig):
        if self.alive():
            try:os.kill(self.pid,sig)
            except ProcessLookupError:pass
    def terminate(self):self.send(signal.SIGTERM)
    def kill(self):self.send(signal.SIGKILL)
    def wait(self,timeout=None):
        end=time.monotonic()+(5 if timeout is None else timeout)
        while self.alive():
            if time.monotonic()>=end:
                if timeout is None:return None
                raise subprocess.TimeoutExpired('subject',timeout)
            time.sleep(0.05)
        return None
def discover(exe,helper,c,timeout=DISCOVERY_SECONDS,clock=time.time,sleep=time.sleep,scan=None):
    """The one owned process whose executable is exactly the bundle executable; never a name match."""
    scan=scan or (lambda s:process_scan.scan(s,identity))
    scope={'executable':os.path.realpath(exe)};end=clock()+timeout
    while clock()<end:
        reason=stop_reason(c,clock())
        if reason:raise RuntimeError('stopped before registration: '+reason)
        found=scan(scope)
        if len(found)==1:return found[0]
        if len(found)>1:raise RuntimeError('ambiguous LaunchServices subject')
        if helper.poll() is not None:raise RuntimeError(f'open exited ({helper.returncode}) before the subject appeared')
        sleep(0.1)
    raise RuntimeError('LaunchServices subject never appeared')
def sweep(scope,helper):
    """Stop everything this run started, by exact path or synthetic HOME (includes the open helper)."""
    try:stop_identities(process_scan.scan(scope,identity),5.0,identity,os.kill,time.monotonic,time.sleep)
    finally:
        if helper.poll() is None:
            helper.terminate()
            try:helper.wait(5)
            except subprocess.TimeoutExpired:helper.kill();helper.wait()
def launch_services(c,bundle,pid_path,env):
    scope=process_scan.scope_for(bundle['exe'],env['HOME'])
    launcher=mark_launching(pid_path,scope=scope,mode='launchservices')
    logs=bundle['app'].parent;(logs/'subject.stdout').touch();(logs/'subject.stderr').touch()
    command=[*OPEN,'-n','-W',*[x for k,v in env.items() for x in ('--env',f'{k}={v}')],
             '--stdout',str(logs/'subject.stdout'),'--stderr',str(logs/'subject.stderr'),str(bundle['app'])]
    if len(c['argv'])>1:command+=['--args',*c['argv'][1:]]
    # The open helper carries the synthetic HOME too, so the scope scan covers it if launch.py dies.
    helper=subprocess.Popen(command,stdin=subprocess.DEVNULL,env=env)
    state={'child':None}
    def stop_child(*_):
        child=state['child']
        try:
            if child is not None:
                child.terminate()
                try:child.wait(10)
                except subprocess.TimeoutExpired:child.kill();child.wait()
        finally:sweep(scope,helper)
        raise SystemExit(3)
    for sig in (signal.SIGTERM,signal.SIGINT,signal.SIGHUP):signal.signal(sig,stop_child)
    try:
        found=discover(bundle['exe'],helper,c)
        register(pid_path,found['pid'],launcher) # Identity registered before the guardian supervises it.
        state['child']=child=Owned({k:found[k] for k in ('pid','startSeconds','startMicroseconds')},helper)
    except BaseException as error:
        print(json.dumps({'launchMode':'launchservices','registered':False,'error':str(error) or type(error).__name__}),file=sys.stderr,flush=True)
        stop_child() # Never leave an unregistered subject running.
    print(json.dumps({'runID':c['lease']['runID'],'epoch':c['lease']['epoch'],'ownedPID':child.pid,'launchMode':'launchservices',**bundle['evidence']}),flush=True)
    reason=supervise(child,c)
    sweep(scope,helper)
    print(json.dumps({'ownedPID':child.pid,'exit':None,'openExit':helper.returncode,'stoppedBy':reason,'launchMode':'launchservices'}))
    raise SystemExit(0 if reason is None else 3)
def stop_reason(c,now):
    if Path(c['stopPath']).exists():return 'stop-file'
    try:lease=json.loads(Path(c['leasePath']).read_text())
    except (OSError,ValueError):return 'lease-unreadable'
    if any(lease.get(k)!=c['lease'].get(k) for k in ('runID','epoch','notBefore','expiresAt')):return 'lease-identity-changed'
    if lease.get('ownerPreempted') is not False or lease.get('exclusive') is not True:return 'lease-revoked'
    if not isinstance(lease.get('guardianHeartbeatAt'),(int,float)) or now-lease['guardianHeartbeatAt']>3:return 'guardian-heartbeat-stale'
    if now>=lease['expiresAt']:return 'deadline'
    return None
def supervise(child,c,poll=0.5,clock=time.time,sleep=time.sleep):
    while child.poll() is None:
        reason=stop_reason(c,clock())
        if reason:
            child.terminate()
            try:child.wait(10)
            except subprocess.TimeoutExpired:child.kill();child.wait()
            return reason
        sleep(poll)
    return None
if __name__=='__main__':main()

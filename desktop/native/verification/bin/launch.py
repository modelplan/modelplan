# SPDX-License-Identifier: MIT
"""Validate an explicit synthetic run; execute only with an existing fresh lease.

`launchMode` in the run config selects how the subject starts (default `direct`):
- direct: the subject is launch.py's own child behind an exec gate (same PID, registered before
  the subject code runs).
- launchservices: the pinned binary is copied into a minimal .app in run scratch (syntheticTmp),
  or, with `subjectKind: app-zip`, a pinned zip of a full signed .app is extracted there (app-zip
  also works in direct mode: the extracted main executable is exec'd as the gated child),
  and opened with `open -n -W --env ...`, so macOS launches it like a user-opened app (cooperative
  activation refuses key/active state to processes spawned directly from an agent shell). The
  subject PID is found by its exact bundle executable path, registered, then supervised by its
  start identity.
Both modes record the run's scan scope in the reservation (exact executable path, the bundle's
scratch prefix, and the PID plus start time of each helper spawned here: the exec gate or the
`open` helper), so the guardian can prove closure even if the subject never registers. No
process's environment is ever read.
"""
import argparse,hashlib,json,os,plistlib,re,shutil,signal,subprocess,sys,time
from pathlib import Path
from admission import validate,load_and_admit
from guardian import register,mark_launching,add_helper,identity,stop_identities,cleanup
import process_scan
OPEN=['/usr/bin/open'];CODESIGN=['/usr/bin/codesign'];DISCOVERY_SECONDS=20.0
UNZIP=['/usr/bin/ditto','-x','-k','--noqtn'] # --noqtn: no quarantine, so Gatekeeper does not prompt
BUNDLE_ID=re.compile(r'[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+')
def sha256(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def subject_env(home,tmp):
    # HOME alone does not move Foundation's Application Support/preferences: CFFIXED_USER_HOME does.
    return {'PATH':'/usr/bin:/bin','HOME':str(home),'CFFIXED_USER_HOME':str(home),'TMPDIR':str(tmp),'LANG':'en_US.UTF-8'}
def real_home(tmp):
    """The real profile (owner decision 2026-11-05, M1/V1 hosts only) keeps the host user's own
    HOME and TMPDIR. This launcher never creates, moves, writes or deletes anything under it, and
    refuses a HOME at or inside run scratch, which later cleanup removes."""
    raw=os.getenv('HOME','')
    if not raw or not Path(raw).is_absolute() or Path(raw)==Path('/'):
        raise ValueError('real profile needs the host user\'s absolute HOME')
    home=Path(raw).resolve();scratch=tmp.resolve()
    if home==scratch or scratch in home.parents:
        raise ValueError('real HOME must stay outside run scratch')
    return home
def real_env():
    # Inherit the launcher's own environment (the bytes view carries every variable through
    # unchanged, including provider keys); CFFIXED_USER_HOME is removed explicitly so no stray
    # value can redirect Foundation paths: a real run must see the real profile, not a half-real
    # one. Only this process's environment is read, never any other process's.
    env={k.decode():v.decode('utf-8','surrogateescape') for k,v in os.environb.items() if k!=b'CFFIXED_USER_HOME'}
    env.setdefault('PATH','/usr/bin:/bin')
    return env
def main():
    p=argparse.ArgumentParser(description=__doc__,formatter_class=argparse.RawDescriptionHelpFormatter);p.add_argument('--config',type=Path,required=True);p.add_argument('--execute',action='store_true');a=p.parse_args()
    c=json.loads(a.config.read_text())
    if not a.execute:validate(c,time.time());print('Run contract valid; no process launched');return
    c=load_and_admit(c) # Read external records before creating synthetic resources.
    mode=c.get('launchMode','direct')
    profile=c.get('profile','synthetic')
    if mode=='launchservices' and not Path(OPEN[0]).exists():raise ValueError('launchservices mode needs macOS '+OPEN[0])
    tmp=Path(c['syntheticTmp'])
    if profile=='real':
        home=real_home(tmp);env=real_env() # same HOME across every launch of this run, never redirected
    else:
        home=Path(c['syntheticHome']);env=subject_env(home,tmp)
        home.mkdir(exist_ok=False)
    tmp.mkdir(exist_ok=False)
    binary=Path(c['argv'][0]).resolve(strict=True)
    if sha256(binary)!=c['binarySHA256']:raise ValueError('binary identity changed')
    kind=c.get('subjectKind','binary')
    if kind=='app-zip':bundle=extract_app(c,binary,tmp) # both modes: verified, extracted under run scratch
    else:bundle=make_bundle(c,binary,tmp) if mode=='launchservices' else None
    c=load_and_admit(c) # Reread lease/release after filesystem/hash work, immediately before spawn.
    pid_path=Path(c['subjectPidPath']) # Required: the guardian supervises this subject.
    if mode=='launchservices':return launch_services(c,bundle,pid_path,env)
    # Until registered, the guardian reports closure unconfirmed unless its scope scan is empty.
    if bundle:
        # app-zip, direct: exec the extracted bundle's main executable itself; scoped by its exact path
        # and the .app prefix, both under run scratch.
        argv=[str(bundle['exe']),*c['argv'][1:]];scope=process_scan.scope_for(bundle['exe'],prefix=bundle['app'])
    else:
        # The pinned binary may also be running outside this run, so it is never a scope path: the scope
        # is run scratch only, and the subject (the gate, same PID after exec) matches by PID plus start time.
        argv=c['argv'];scope=process_scan.scope_for(prefix=tmp)
    evidence=bundle['evidence'] if bundle else {}
    # Exec gate: the child waits for one byte on stdin before exec'ing the subject (same PID). If launch
    # dies before releasing it, stdin reaches EOF and the child exits without ever running the subject.
    gate=[sys.executable,'-I','-c',GATE,*argv]
    state={'child':None}
    def stop_child(*_):
        child=state['child']
        try:
            if child is not None:
                child.terminate()
                try:child.wait(10)
                except subprocess.TimeoutExpired:child.kill();child.wait()
        finally:raise SystemExit(3)
    for sig in (signal.SIGTERM,signal.SIGINT,signal.SIGHUP):signal.signal(sig,stop_child)
    def spawn():
        # Every launch (first or relaunch) reserves the slot first: the guardian admits a second
        # reservation only once the prior registered subject is gone, keeps the same controller
        # identity, and only then accepts the helper and the new registration.
        launcher=mark_launching(pid_path,scope=scope,mode=mode)
        child=spawn_gated(gate,env,pid_path,launcher,stop_child)
        state['child']=child
        return child
    child=spawn()
    home_field=str(home) # real: the host user's own HOME; synthetic: the run-scratch home
    print(json.dumps(subject_line(c,child.pid,profile,home_field,evidence)),flush=True)
    # Stay attached: stop the child on the stop file, a stale guardian heartbeat, revocation or the deadline,
    # so a dead guardian still fails closed. Exit status 0 only when the child ended by itself.
    def announce(token,pid):
        print(json.dumps(subject_line(c,pid,profile,home_field,evidence,token=token)),flush=True)
    reason=supervise(child,c,spawn=spawn,announce=announce)
    child=state['child']
    print(json.dumps({'ownedPID':child.pid,'exit':child.returncode,'stoppedBy':reason,'launchMode':mode,'profile':profile}))
    raise SystemExit(0 if reason is None else 3)
GATE='import os,sys\nif sys.stdin.buffer.read(1)!=b"g":sys.exit(97)\nos.execv(sys.argv[1],sys.argv[1:])'
def spawn_gated(gate,env,pid_path,launcher,on_unregistered):
    """Start one gated child and register it against a reservation this controller just made:
    helper identity first, registration second, then release the exec gate. Any failure kills the
    child and hands the failure to on_unregistered, so an unregistered subject never survives."""
    child=subprocess.Popen(gate,stdin=subprocess.PIPE,env=env)
    try:
        add_helper(pid_path,launcher,identity(child.pid)) # The gate is matched by PID plus start time.
        register(pid_path,child.pid,launcher)
        child.stdin.write(b'g');child.stdin.close() # Registered: release the gate.
    except BaseException:
        child.terminate() # never leave an unregistered child running ...
        try:child.wait(10)
        except subprocess.TimeoutExpired:child.kill();child.wait()
        on_unregistered() # ... and end the launch by supervision, not by a traceback
    return child
def subject_line(c,pid,profile,home,evidence,token=None):
    """One launch's JSON line for verify-run's consumer. A relaunch line repeats every identifying
    field of the first line, evidence included (the consumer matches on bundle), plus its token."""
    line=dict(runID=c['lease']['runID'],epoch=c['lease']['epoch'],ownedPID=pid,
              launchMode=c.get('launchMode','direct'),profile=profile,home=home,**evidence)
    if token is not None:
        line['relaunch']=token
    return line
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
    if sign=='adhoc':subprocess.run([*CODESIGN,'--force','--sign','-',str(app)],check=True,capture_output=True)
    return dict(app=app,exe=exe,evidence=dict(bundle=str(app),bundleIdentifier=ident,bundleUIElement=ui,bundleSign=sign,bundledSHA256=sha256(exe)))
def extract_app(c,archive,tmp):
    """Full .app subject: a pinned zip is copied into run scratch, re-hashed, extracted with ditto,
    and must hold exactly one top-level .app whose symlinks stay inside it and whose code signature
    verifies (ad-hoc accepted; the kind is recorded). The main executable is CFBundleExecutable."""
    root=tmp/'.launchservices';root.mkdir(parents=True,exist_ok=False)
    local=root/'subject.zip';shutil.copyfile(archive,local)
    if sha256(local)!=c['binarySHA256']:raise ValueError('app archive identity changed')
    out=root/'app';out.mkdir()
    subprocess.run([*UNZIP,str(local),str(out)],check=True,capture_output=True)
    entries=[p for p in out.iterdir() if p.name!='__MACOSX']
    if len(entries)!=1 or entries[0].suffix!='.app' or entries[0].is_symlink() or not entries[0].is_dir():
        raise ValueError('app archive must contain exactly one top-level .app')
    app=entries[0];inside=os.path.realpath(app)+'/'
    for p in app.rglob('*'):
        if p.is_symlink() and not os.path.realpath(p).startswith(inside):raise ValueError('app symlink leaves the bundle')
    info=plistlib.loads((app/'Contents'/'Info.plist').read_bytes())
    name=info.get('CFBundleExecutable')
    if not isinstance(name,str) or not name or '/' in name or name in ('.','..'):raise ValueError('CFBundleExecutable invalid')
    exe=app/'Contents'/'MacOS'/name
    if exe.is_symlink() or not exe.is_file() or not os.access(exe,os.X_OK):raise ValueError('bundle main executable missing')
    verify=subprocess.run([*CODESIGN,'--verify','--deep','--strict',str(app)],capture_output=True,text=True)
    if verify.returncode!=0:raise ValueError('app code signature does not verify')
    signature=signature_kind(subprocess.run([*CODESIGN,'-dv',str(app)],capture_output=True,text=True))
    return dict(app=app,exe=exe,evidence=dict(subjectKind='app-zip',bundle=str(app),bundleIdentifier=info.get('CFBundleIdentifier'),
        archiveSHA256=c['binarySHA256'],executableSHA256=sha256(exe),codeSignature=signature))
def signature_kind(details):
    """`codesign -dv` (details on stderr): adhoc, identity (an Authority line), else unknown."""
    if details.returncode!=0:return 'unknown'
    lines=[x.strip() for x in (details.stderr or '').splitlines()]
    if 'Signature=adhoc' in lines:return 'adhoc'
    if any(x.startswith('Authority=') and len(x)>len('Authority=') for x in lines):return 'identity'
    return 'unknown'
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
class OpenFailed(RuntimeError):
    def __init__(self,code):super().__init__(f'open exited ({code}) before the subject appeared');self.code=code
LS_ERROR=re.compile(r'error\s*\(?(-\d+)\)?')
def launch_services_error(path):
    """The LaunchServices error code `open` reported on its own stderr (for example -10810), if any."""
    try:found=LS_ERROR.findall(Path(path).read_text(errors='replace')[-4096:])
    except OSError:return None
    return int(found[-1]) if found else None
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
        if helper.poll() is not None:raise OpenFailed(helper.returncode)
        sleep(0.1)
    raise RuntimeError('LaunchServices subject never appeared')
def sweep(scope,helper):
    """Stop everything this run started: bundle path/prefix, plus recorded helpers (the open helper)."""
    try:stop_identities(process_scan.scan(scope['scope'],identity),5.0,identity,os.kill,time.monotonic,time.sleep)
    finally:
        if helper.poll() is None:
            helper.terminate()
            try:helper.wait(5)
            except subprocess.TimeoutExpired:helper.kill();helper.wait()
def launch_services(c,bundle,pid_path,env):
    scope={'scope':process_scan.scope_for(bundle['exe'],prefix=bundle['app'])}
    launcher=mark_launching(pid_path,scope=scope['scope'],mode='launchservices')
    logs=bundle['app'].parent;(logs/'subject.stdout').touch();(logs/'subject.stderr').touch()
    command=[*OPEN,'-n','-W',*[x for k,v in env.items() for x in ('--env',f'{k}={v}')],
             '--stdout',str(logs/'subject.stdout'),'--stderr',str(logs/'subject.stderr'),str(bundle['app'])]
    if len(c['argv'])>1:command+=['--args',*c['argv'][1:]]
    with (logs/'open.stderr').open('wb') as open_err: # open's own diagnostics, e.g. an LSOpen error code
        helper=subprocess.Popen(command,stdin=subprocess.DEVNULL,stderr=open_err,env=env)
    # Record the open helper by PID plus start time at once, so the guardian can stop it if launch.py dies.
    try:
        ident=identity(helper.pid)
        if ident is not None or helper.poll() is None:scope['scope']=add_helper(pid_path,launcher,ident) # else: already gone
    except BaseException:sweep(scope,helper);raise
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
        failure={'launchMode':'launchservices','registered':False,'error':str(error) or type(error).__name__}
        if isinstance(error,OpenFailed):failure.update(openExit=error.code,launchServicesError=launch_services_error(logs/'open.stderr'))
        print(json.dumps(failure),file=sys.stderr,flush=True)
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
def supervise(child,c,poll=0.5,clock=time.time,sleep=time.sleep,spawn=None,announce=None):
    """Stay attached until the subject ends by itself (returns None) or a stop condition fires
    (returns its reason). With `spawn`, a relaunch marker (an increasing integer in the config's
    relaunchPath) stops the current child and starts a fresh gated one with the same argv,
    environment and HOME: one supervised slot, several launches, identities never mixed."""
    marker=Path(c['relaunchPath']) if spawn is not None and c.get('relaunchPath') else None
    token=0
    while True:
        if child.poll() is None:
            reason=stop_reason(c,clock())
            if reason:
                child.terminate()
                try:child.wait(10)
                except subprocess.TimeoutExpired:child.kill();child.wait()
                return reason
            if marker is not None:
                try:value=int(marker.read_text().strip() or 0)
                except (OSError,ValueError):value=0
                if value>token:
                    token=value
                    child.terminate() # ended deliberately: a relaunch step, not a crash
                    try:child.wait(10)
                    except subprocess.TimeoutExpired:child.kill();child.wait()
                    try:
                        child=spawn()
                    except SystemExit:
                        raise
                    except BaseException:
                        # the re-reservation or the registration refused the relaunch: end by
                        # supervision (exit 3), never leak the slot or the subject
                        raise SystemExit(3)
                    if announce is not None:announce(token,child.pid)
                    continue
            if child.poll() is None:
                sleep(poll)
                continue
        return None
if __name__=='__main__':main()

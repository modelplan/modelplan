# SPDX-License-Identifier: MIT
"""One announced U11a attempt. No account access or input synthesis; only the authorized WebKit-family PID filter."""
import argparse,ctypes,functools,hashlib,re,http.server,importlib.util,json,os,selectors,signal,subprocess,sys,threading,time,uuid
from pathlib import Path
from launch import validate
from check_inputs import check
from role_counters import snapshot,qualify,rss
BASE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('cleanup',BASE/'cleanup-run.py');cleanup=importlib.util.module_from_spec(spec);spec.loader.exec_module(cleanup)
def write(path,value):
    path=Path(path);tmp=path.with_name(path.name+'.tmp');tmp.write_text(json.dumps(value));tmp.replace(path)
def read(path):return json.loads(Path(path).read_text())
def plan():return [(cycle,phase,60) for cycle in range(1,4) for phase in ('before-open','open','after-close')]
def valid(c,now):
    return c.get('GO') is True and c.get('announcementID') and c['start']<=now<c['expiresAt'] and 0<c['expiresAt']-c['start']<=1200 and c['expiresAt']-now>=690

def guardian(config):
    c=read(config);lease=Path(c['lease']);stop=Path(c['stop'])
    try:
        while time.time()<c['expiresAt'] and not stop.exists():
            try:os.kill(c['controllerPID'],0)
            except ProcessLookupError:break
            write(lease,dict(runID=c['runID'],epoch=c['epoch'],exclusive=True,ownerPreempted=False,notBefore=c['start'],expiresAt=c['expiresAt'],guardianHeartbeatAt=time.time()))
            time.sleep(.25)
    finally:write(lease,dict(runID=c['runID'],epoch=c['epoch'],exclusive=False,ownerPreempted=True,notBefore=c['start'],expiresAt=c['expiresAt'],guardianHeartbeatAt=time.time(),stage='revoked'))

class Files(http.server.SimpleHTTPRequestHandler):
    def log_message(self,*args):pass
    def end_headers(self):
        self.send_header('Content-Security-Policy',"default-src 'none'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self' data:; connect-src 'self'; media-src 'self'")
        super().end_headers()
    def do_GET(self):
        p=Path(self.translate_path(self.path)).resolve()
        if not p.is_relative_to(Path(self.directory).resolve()):self.send_error(403);return
        super().do_GET()

class LocalServer(http.server.ThreadingHTTPServer):
    def handle_error(self,request,client_address):
        # Closing a measured page may reset its own local connection. Never dump
        # peer/host data for that normal lifecycle event.
        if not isinstance(sys.exc_info()[1],(ConnectionResetError,BrokenPipeError)):
            print('Local input server error: '+type(sys.exc_info()[1]).__name__,flush=True)

class Attempt:
    def __init__(self,c):
        self.c=c;self.out=Path(c['batch']);self.scratch=Path(c['scratch']);self.children=[];self.rows=[];self.raw=None;self.stop=self.out/'stop.json';self.lease=self.scratch/'lease.json';self.control=self.scratch/'control.json';self.server=None;self.guard=None;self.topThread=None;self.topStop=threading.Event();self.roles={};self.known=[];self.snapshotBefore=None;self.snapshotIndex=0
    def live(self):
        if self.stop.exists() or time.time()>=self.c['expiresAt']-90:raise RuntimeError('stop-or-expiry')
        g=read(self.lease)
        if g.get('runID')!=self.c['runID'] or g.get('epoch')!=self.c['epoch'] or g.get('ownerPreempted') is not False or not 0<=time.time()-g['guardianHeartbeatAt']<=2:raise RuntimeError('guardian-not-live')
    def events(self):
        if not self.raw or not self.raw.exists():return []
        rows=[]
        for line in self.raw.read_text().splitlines():
            try:rows.append(json.loads(line))
            except ValueError:pass
        return rows
    def wait(self,seconds):
        end=time.monotonic()+seconds
        while time.monotonic()<end:
            self.live()
            if self.app.poll() is not None:raise RuntimeError('subject-exited')
            time.sleep(.2)
    def command(self,command,phase,cycle):
        self.live();nonce=uuid.uuid4().hex
        if command=='open':
            self.roles={};self.snapshotBefore=snapshot(self.c['runID'],cleanup.identity);self.snapshotIndex+=1
            write(self.out/('webkit-before-'+str(self.snapshotIndex)+'.json'),self.snapshotBefore)
        write(self.control,dict(runID=self.c['runID'],epoch=self.c['epoch'],nonce=nonce,command=command,phase=phase,cycle=cycle))
        end=time.monotonic()+30
        while time.monotonic()<end:
            self.live()
            if any(x.get('event')=='command-ack' and x.get('nonce')==nonce for x in self.events()):return
            if self.app.poll() is not None:raise RuntimeError('subject-exited')
            time.sleep(.2)
        raise RuntimeError('command-timeout')
    def launch(self,mode):
        self.raw=self.out/(mode+'-raw.jsonl')
        home=self.scratch/'home'/mode;tmp=self.scratch/'tmp'/mode;home.mkdir(parents=True);tmp.mkdir(parents=True)
        cfg=dict(runID=self.c['runID'],epoch=self.c['epoch'],lease=str(self.lease),control=str(self.control),stop=str(self.stop),output=str(self.raw),mode=mode,ownerObservationEstablished=(mode=='measure'),entryURL=self.entry,scripts=self.c['scripts'],resourceRoot=self.c['resourceRoot'])
        file=self.scratch/(mode+'-config.json');write(file,cfg)
        console=(self.scratch/(mode+'-console.log')).open('x')
        lease=read(self.lease);validate(dict(profile='synthetic',binarySHA256=self.c['binarySHA256'],argv=[self.c['binary']],lease=lease,release=lease|dict(guardianGO=True,m0DirectedAnnouncementConfirmed=True),requiredSeconds=690 if mode=='preflight' else 630,stop=self.stop.exists()),time.time())
        self.app=subprocess.Popen([self.c['binary'],str(file)],stdout=console,stderr=subprocess.STDOUT,env=dict(PATH='/usr/bin:/bin',HOME=str(home),TMPDIR=str(tmp),LANG='en_US.UTF-8'))
        console.close();ident=cleanup.identity(self.app.pid)
        if not ident:raise RuntimeError('subject-identity-unavailable')
        self.children.append((self.app,ident|dict(role=mode)))
    def ready(self):
        deadline=time.monotonic()+30
        while time.monotonic()<deadline:
            self.live();rows=self.events()
            opens=[x for x in rows if x.get('event')=='open-request']
            if opens and any(x.get('event')=='doctor' and x.get('viewID')==opens[-1].get('viewID') and x.get('elapsedSeconds',0)>=opens[-1]['elapsedSeconds'] and set(x.get('checks',{}))==set(('running','active','key','visible','WebKit','disk','lease')) and all(v is True for v in x['checks'].values()) and x.get('rafProof') for x in rows):
                logged=next((r for r in reversed(rows) if r.get('event')=='process-attribution' and r.get('viewID')==opens[-1].get('viewID')),{'status':'unsupported'})
                after=snapshot(self.c['runID'],cleanup.identity);roles=qualify(self.snapshotBefore,after,logged,self.known)
                write(self.out/('webkit-after-'+str(self.snapshotIndex)+'.json'),after);write(self.out/('role-map-'+str(self.snapshotIndex)+'.json'),roles)
                self.roles={k:v for k,v in roles.items() if k in ('WebContent','GPU') and v.get('status')=='attributed'}
                for v in roles.get('auxiliary',[]):self.roles['OtherWebKit:'+v['helper']]=v
                for v in [*self.roles.values(),*roles.get('auxiliary',[])]:
                    if v not in self.known:self.known.append(v)
                return
            if self.app.poll() is not None:raise RuntimeError('subject-exited')
            time.sleep(.2)
        raise RuntimeError('doctor-or-frame-timeout')
    def quit(self):
        self.live();write(self.control,dict(runID=self.c['runID'],epoch=self.c['epoch'],nonce=uuid.uuid4().hex,command='quit',phase='after-close',cycle=3))
        try:self.app.wait(timeout=5)
        except subprocess.TimeoutExpired:raise RuntimeError('subject-quit-timeout')
    def top_worker(self):
        with (self.out/'top-samples.jsonl').open('x') as f,(self.out/'pid-rss-samples.jsonl').open('x') as mem,(self.out/'auxiliary-top-samples.jsonl').open('x') as aux:
            while not self.topStop.is_set() and self.app.poll() is None:
                roles=self.roles.copy()
                if not roles:self.topStop.wait(.3);continue
                self.live();rows=self.events();before=rows[-1]
                roles={k:v for k,v in roles.items() if cleanup.matches(cleanup.identity(v['pid']),v)}
                if not roles:self.topStop.wait(.3);continue
                command=['/usr/bin/top','-l','2','-s','1','-stats','pid,cpu','-ncols','80']
                for v in roles.values():command+=['-pid',str(v['pid'])]
                try:
                    result=subprocess.run(command,stdout=subprocess.PIPE,stderr=subprocess.DEVNULL,text=True,timeout=5)
                    values={v['pid']:[] for v in roles.values()}
                    for line in result.stdout.splitlines():
                        m=re.fullmatch(r'\s*(\d+)[+-]?\s+([0-9]+(?:\.[0-9]+)?)\s*',line)
                        if m and int(m[1]) in values:values[int(m[1])].append(float(m[2]))
                    after=self.events()[-1];stamp=time.time()
                    if before['phase']!=after['phase'] or before['cycle']!=after['cycle']:continue
                    for role,v in roles.items():
                        if not cleanup.matches(cleanup.identity(v['pid']),v):continue
                        row=dict(run_id=self.c['runID'],scenario='A-cycle'+str(after['cycle']),timestamp=stamp,role=role,phase=after['phase'],pid=v['pid'],energy_impact=None)
                        if len(values[v['pid']])>=2:
                            target=f if role in ('WebContent','GPU') else aux
                            target.write(json.dumps(row|dict(cpu_percent=values[v['pid']][-1],rss_bytes=None))+'\n');target.flush()
                        resident=rss(v,cleanup.identity)
                        mem.write(json.dumps(row|dict(rss_bytes=resident,source='ps-rss',unit='bytes',startSeconds=v['startSeconds'],startMicroseconds=v['startMicroseconds']))+'\n');mem.flush()
                except (OSError,subprocess.TimeoutExpired):pass

    def run(self):
        c=self.c
        if not valid(c,time.time()):raise ValueError('announcement/GO/window/remaining-time invalid')
        if hashlib.sha256(Path(c['binary']).read_bytes()).hexdigest()!=c['binarySHA256']:raise ValueError('binary changed')
        if check(Path(c['inputRoot']),c['entry']):raise ValueError('relative-module-dependencies-missing')
        self.out.mkdir(exist_ok=False);self.scratch.mkdir(exist_ok=False)
        write(self.out/'README.json',dict(purpose='U11a synthetic observation; actual outcomes follow',runID=c['runID'],epoch=c['epoch'],head=c['head'],source='native-self-counters',noRealAccounts=True))
        locks=Path(c['locks']);self.lock=locks/'M1-candidate-gui';self.lock.mkdir();write(self.lock/'owner.json',dict(runID=c['runID'],epoch=c['epoch'],pid=os.getpid()))
        self.slot=None;reported=False
        while self.slot is None:
            if c['expiresAt']-time.time()<690:raise RuntimeError('resource-wait-left-insufficient-run-time')
            if list(locks.glob('slot*')):
                if not reported:print('Waiting for existing project heavy reservation',flush=True);reported=True
                time.sleep(.25);continue
            for n in (1,2):
                try:p=locks/f'slot{n}';p.mkdir();self.slot=p;write(p/'owner.json',dict(runID=c['runID'],pid=os.getpid()));break
                except FileExistsError:pass
            if self.slot is not None and len(list(locks.glob('slot*')))>1:
                (self.slot/'owner.json').unlink();self.slot.rmdir();self.slot=None
        build=sum(int(subprocess.check_output(['/usr/bin/du','-sk',p]).split()[0])*1024 for p in c['buildRoots'])
        if build>=3*1024**3:raise RuntimeError('build-quota')
        if __import__('shutil').disk_usage(c['resourceRoot']).free-2*(3*1024**3+200*1024**2)<8*1024**3:raise RuntimeError('resource-disk-floor')
        gc=self.scratch/'guardian-config.json';write(gc,c|dict(controllerPID=os.getpid(),lease=str(self.lease),stop=str(self.stop)))
        self.guard=subprocess.Popen([sys.executable,__file__,'--guardian',str(gc)])
        end=time.monotonic()+3
        while not self.lease.exists() and time.monotonic()<end:time.sleep(.1)
        self.server=LocalServer(('127.0.0.1',0),functools.partial(Files,directory=c['inputRoot']))
        threading.Thread(target=self.server.serve_forever,daemon=True).start()
        self.entry='http://127.0.0.1:'+str(self.server.server_port)+'/'+c['entry']
        result=dict(runID=c['runID'],epoch=c['epoch'],head=c['head'],outcome='not-run',budget='unsupported',GPU='unsupported-no-approved-isolated-session-snapshot',energy='unsupported')
        try:
            self.launch('preflight');self.command('open','preflight',0);self.ready();self.command('close','preflight',0);self.command('open','preflight',0);self.ready();self.quit()
            self.control.unlink(missing_ok=True)
            self.launch('measure')
            self.topThread=threading.Thread(target=self.top_worker,daemon=True);self.topThread.start()
            for cycle,phase,seconds in plan():
                command='open' if phase=='open' else 'close' if phase=='after-close' else 'phase'
                self.command(command,phase,cycle)
                if phase=='open':self.ready()
                self.wait(seconds)
            self.quit();result['outcome']='pass-observation-cycles';result['cycles']=3
        except BaseException as e:result['reason']=str(e);result['outcome']='not-run'
        finally:
            self.topStop.set()
            if self.topThread:self.topThread.join(timeout=8)
            if not self.stop.exists():write(self.stop,dict(stop=True,reason='run-ended',runID=c['runID'],epoch=c['epoch']))
            for proc,ident in self.children:
                if proc.poll() is None:cleanup.stop_owned(ident)
                try:proc.wait(timeout=5)
                except subprocess.TimeoutExpired:pass
            if self.guard:
                try:self.guard.wait(timeout=3)
                except subprocess.TimeoutExpired:self.guard.terminate();self.guard.wait(timeout=3)
            if self.server:self.server.shutdown();self.server.server_close()
            result['cleanup']=dict(ownedExited=all(p.poll() is not None for p,_ in self.children),guardianExited=self.guard is None or self.guard.poll() is not None,topObserverJoined=self.topThread is None or not self.topThread.is_alive(),scratchRemoved=cleanup.remove_scratch(self.scratch,['home','tmp']))
            for lock in (getattr(self,'slot',None),getattr(self,'lock',None)):
                if lock is not None and lock.exists() and read(lock/'owner.json').get('runID')==c['runID']:(lock/'owner.json').unlink();lock.rmdir()
            result['cleanup']['leaseReleased']=True
            result['ownedExitCodes']=[dict(role=i['role'],exitCode=p.returncode) for p,i in self.children]
            result['stopReason']=read(self.stop).get('reason')
            write(self.out/'result.json',result)
            print(json.dumps(result),flush=True)
        return result

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--config',type=Path);p.add_argument('--guardian',type=Path);p.add_argument('--dry-run',action='store_true');a=p.parse_args()
    if a.guardian:guardian(a.guardian);return
    if a.dry_run:print(json.dumps({'plan':plan(),'phaseSeconds':540,'preflight':'separate process, two-second native proof','noGUI':True}));return
    attempt=Attempt(read(a.config))
    try:attempt.run()
    except BaseException as e:
        if attempt.out.is_dir() and not (attempt.out/'result.json').exists():
            write(attempt.stop,dict(stop=True,reason='setup-failed',runID=attempt.c['runID'],epoch=attempt.c['epoch']))
            if attempt.guard:
                try:attempt.guard.wait(timeout=3)
                except subprocess.TimeoutExpired:attempt.guard.terminate();attempt.guard.wait(timeout=3)
            for lock in (getattr(attempt,'slot',None),getattr(attempt,'lock',None)):
                if lock is not None and lock.exists() and read(lock/'owner.json').get('runID')==attempt.c['runID']:(lock/'owner.json').unlink();lock.rmdir()
            write(attempt.out/'result.json',dict(runID=attempt.c['runID'],outcome='not-run',reason=str(e),AppLaunched=False,cleanup='setup resources released'))
        raise
if __name__=='__main__':main()

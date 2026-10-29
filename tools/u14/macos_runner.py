#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Hosted synthetic macOS infrastructure, consuming U14 parts A and B."""
import argparse
import os
from pathlib import Path
import platform
import plistlib
import re
import shutil
import signal
import subprocess
import tarfile
import threading
import time

from candidate import generate_bundle, git, regular_bytes
from contracts import ROOT, digest, encoded, load_json, new_directory, write_private
from engine_process import EngineFailure, EngineProcess, EngineTimeout
from shape_home import CASES, build_home

REPO = ROOT.parent.parent
UI_IDS = tuple(f'A{i:02d}' for i in range(1, 20))
# Feature DRIs register assertion functions here after their production consumers
# land. Empty infrastructure or a captured image never implies a scenario pass.
SCENARIO_DRIVERS = {}


class HarnessFailure(Exception):
    pass


class HarnessTimeout(HarnessFailure):
    pass


def select_scenarios(value):
    selected = list(UI_IDS) if value == 'all' else value.split(',')
    if not selected or len(selected) != len(set(selected)) or any(x not in UI_IDS for x in selected):
        raise ValueError('unknown or duplicate UI scenario')
    return selected


def child_environment(home):
    home = Path(home).absolute()
    scratch = home / '.u14-tmp'
    scratch.mkdir(mode=0o700, exist_ok=True)
    return {'HOME': str(home), 'CFFIXED_USER_HOME': str(home), 'TMPDIR': str(scratch)+'/',
            'CODEX_HOME': str(home/'.codex'), 'CLAUDE_CONFIG_DIR': str(home/'.claude'),
            'MODELPLAN_CACHE': str(home/'cache'), 'XDG_CONFIG_HOME': str(home/'.config'),
            'XDG_DATA_HOME': str(home/'.local/share'), 'PATH': str(home/'bin')+':/usr/bin:/bin',
            'MODELPLAN_READERS': 'off', 'MODELPLAN_NATIVE': 'off', 'MODELPLAN_HISTORY': 'off',
            'MODELPLAN_CODEX_ACCOUNT': 'off', 'MODELPLAN_CODEXBAR': 'off',
            'MODELPLAN_TASK_BRIEF': 'off', 'NO_COLOR': '1', 'LANG': 'en_US.UTF-8'}


def verify_home(home, baseline):
    for item in baseline['files']:
        path = home / item['path']
        if path.resolve() != path or not path.is_file() or digest(regular_bytes(path)) != item['sha256']:
            raise ValueError('synthetic baseline changed before launch')


def verify_app(app):
    app = Path(app).absolute()
    if app.resolve() != app or not app.is_dir():
        raise ValueError('invalid app bundle')
    info = plistlib.loads(regular_bytes(app/'Contents/Info.plist'))
    name = info.get('CFBundleExecutable')
    if not isinstance(name, str) or not re.fullmatch('[A-Za-z0-9_-]{1,80}',name):
        raise ValueError('invalid app executable')
    executable, helper = app/'Contents/MacOS'/name, app/'Contents/Helpers/modelplan'
    for path in (executable, helper):
        if not regular_bytes(path) or not os.access(path,os.X_OK):
            raise ValueError('missing app executable or bundled helper')
    expected = regular_bytes(app/'Contents/Resources/modelplan.sha256').decode().strip()
    if not re.fullmatch('[0-9a-f]{64}',expected) or digest(regular_bytes(helper)) != expected:
        raise ValueError('bundled helper hash mismatch')
    return executable, helper


def stop_owned(process):
    if process is None:
        return
    # The leader may have exited while its descendants still hold pipes/windows.
    # This function accepts only children launched with start_new_session=True.
    try:
        os.killpg(process.pid,signal.SIGTERM)
    except ProcessLookupError:
        pass
    try:
        process.wait(timeout=3)
    except subprocess.TimeoutExpired:
        try:
            os.killpg(process.pid,signal.SIGKILL)
        except ProcessLookupError:
            pass
        process.wait(timeout=3)


def command(args, cwd, env, timeout, log):
    """Bound both execution and output; never log a host environment or raw exception."""
    process = subprocess.Popen(args,cwd=cwd,env=env,stdout=subprocess.PIPE,
                               stderr=subprocess.STDOUT,start_new_session=True)
    output = bytearray()
    overflow = threading.Event()
    def drain():
        while data := process.stdout.read(8192):
            if len(output)+len(data) > 4 << 20:
                overflow.set()
                stop_owned(process)
                return
            output.extend(data)
    reader=threading.Thread(target=drain,daemon=True);reader.start()
    try:
        process.wait(timeout=timeout)
    except subprocess.TimeoutExpired:
        stop_owned(process)
        raise HarnessTimeout('command-timeout') from None
    finally:
        reader.join(timeout=4)
        if reader.is_alive():
            stop_owned(process)
            reader.join(timeout=3)
        process.stdout.close()
        # Build output contains public source paths only; normalize this run/source.
        text=bytes(output).replace(str(REPO).encode(),b'$SOURCE')
        write_private(log,text)
    if overflow.is_set() or reader.is_alive() or process.returncode:
        raise HarnessFailure('command-failed')
    return bytes(output)


def build_app(work):
    """Reuse the production packager; supply same-source real CLI archives."""
    archive = new_directory(work/'archives')
    env = dict(os.environ)
    env.update({'GOCACHE':str(work/'go-cache'),'GOMODCACHE':str(work/'go-mod'),
                'TMPDIR':str(work/'tmp'), 'CGO_ENABLED':'0','GOOS':'darwin','GOFLAGS':'-modcacherw'})
    (work/'tmp').mkdir(mode=0o700)
    version='0.0.0+u14.'+git(REPO,'rev-parse','HEAD')[:12]
    checksums=[]
    for architecture in ('arm64','amd64'):
        directory=new_directory(work/('modelplan_darwin_'+architecture))
        binary=directory/'modelplan'
        command(['go','build','-trimpath','-ldflags','-X main.version='+version,
                 '-o',str(binary),'./cmd/modelplan'],REPO/'cli',{**env,'GOARCH':architecture},
                300,work/('go-'+architecture+'.log'))
        shutil.copyfile(REPO/'cli/THIRD-PARTY-NOTICES.md',directory/'THIRD-PARTY-NOTICES.md')
        target=archive/(directory.name+'.tar.gz')
        with tarfile.open(target,'w:gz') as stream:
            stream.add(directory,arcname=directory.name)
        checksums.append(digest(target.read_bytes())+'  '+target.name)
    write_private(archive/'checksums.txt', ('\n'.join(checksums)+'\n').encode())
    command(['bash',str(REPO/'desktop/native/tools/package-neutral.sh'),str(archive),
             str(work/'package'),'--unverified'],REPO,env,1800,work/'package.log')
    app=work/'package/ModelPlan Community.app'
    verify_app(app)
    return app,version


class SandboxedEngine(EngineProcess):
    def __init__(self, helper, home, sandbox):
        super().__init__(helper,home,'s-u14-macos',arguments=('--offline',))
        self.environment=child_environment(home)
        self.sandbox=sandbox
    def __enter__(self):
        self.process=subprocess.Popen(['/usr/bin/sandbox-exec','-f',str(self.sandbox),
                                      str(self.binary),'app-server',*self.arguments],
                                     env=self.environment,stdin=subprocess.PIPE,stdout=subprocess.PIPE,
                                     stderr=subprocess.PIPE,bufsize=0,close_fds=True,start_new_session=True)
        os.set_blocking(self.process.stdin.fileno(),False)
        self.stderr_thread=threading.Thread(target=self._drain_stderr,daemon=True)
        self.stderr_thread.start()
        return self


def probe_checks(receipt,pid,directory):
    if receipt.get('schemaVersion') != 1 or receipt.get('pid') != pid:
        raise ValueError('probe did not observe the owned app')
    checks=[]
    report=directory/'report.json'
    for kind,id in [('ax','macos-ax-tree'),('screenshot','macos-offscreen-image')]:
        item=receipt.get(kind,{})
        if item.get('outcome') not in ('pass','fail','unsupported','timeout'):
            raise ValueError('invalid probe outcome')
        evidence=[str(report)]
        if item['outcome']=='pass':
            name='ax-tree.json' if kind=='ax' else 'window.png'
            data=regular_bytes(directory/name)
            if kind=='ax':
                tree=load_json(directory/name)
                def owned(node):
                    return (isinstance(node,dict) and node.get('pid')==pid and
                            all(owned(child) for child in node.get('children',[])))
                if (len(data)>2<<20 or tree.get('pid')!=pid or not tree.get('windows') or
                        not all(owned(node) for node in tree['windows'])):
                    raise ValueError('AX tree is missing or unowned')
            elif len(data)>32<<20 or not data.startswith(b'\x89PNG\r\n\x1a\n') or item.get('ownerPID')!=pid:
                raise ValueError('image is missing or unowned')
            evidence.append(str(directory/name))
        checks.append({'id':id,'outcome':item['outcome'],'evidence':evidence})
    return checks


class NativeContext:
    def __init__(self,app,home,process,probe,sandbox,work,deadline):
        self.app,self.home,self.process=app,home,process
        self.helper=app/'Contents/Helpers/modelplan'
        self.probe,self.sandbox,self.work,self.deadline=probe,sandbox,work,deadline
        self.captures=0
        self.capabilities={'app-server'}
    def capture(self):
        remaining=self.deadline-time.monotonic()
        if remaining<5 or self.process.poll() is not None:
            raise HarnessFailure('native-session-ended')
        self.captures+=1
        destination=new_directory(self.work/('capture-'+str(self.captures)))
        command(['/usr/bin/sandbox-exec','-f',str(self.sandbox),str(self.probe),
                 str(self.process.pid),str(self.app),str(destination),'30'],REPO,
                child_environment(self.home),min(60,remaining-3),self.work/('probe-'+str(self.captures)+'.log'))
        receipt=load_json(destination/'report.json')
        return receipt,probe_checks(receipt,self.process.pid,destination)


def drive_scenarios(context,selected):
    """Code-owned callbacks only; capability/evidence gates still apply in part B."""
    if set(SCENARIO_DRIVERS)-set(UI_IDS):
        raise ValueError('unknown scenario driver')
    results={}
    for id in selected:
        if id not in SCENARIO_DRIVERS:
            continue
        if time.monotonic()>=context.deadline or context.process.poll() is not None:
            raise HarnessTimeout('native-session-ended')
        result=SCENARIO_DRIVERS[id](context)
        if (not isinstance(result,dict) or set(result)!={'outcome','evidence'} or
                result['outcome'] not in ('pass','fail','unsupported','timeout','not-run') or
                not isinstance(result['evidence'],list) or
                any(not isinstance(path,str) for path in result['evidence']) or
                (result['outcome'] in ('pass','fail','timeout') and not result['evidence'])):
            raise ValueError('scenario driver must return an evidenced outcome')
        for path in result['evidence']:
            if not Path(path).absolute().is_relative_to(context.work):
                raise ValueError('scenario evidence must belong to this run')
            regular_bytes(path)
        results[id]={'id':id,**result}
    return results


def run_native(app,home,work,selected):
    executable,helper=verify_app(app)
    sandbox=work/'runtime.sb'
    write_private(sandbox,b'(version 1)\n(allow default)\n(deny network*)\n')
    probe=work/'macos-ax'
    command(['xcrun','swiftc','-parse-as-library','-target',platform.machine()+'-apple-macosx14.0',
             str(ROOT/'macos_ax.swift'),'-o',str(probe)],REPO,dict(os.environ),120,work/'probe-build.log')
    checks=[]
    engine=SandboxedEngine(helper,home,sandbox)
    process=None
    watchdog=None
    details={'schemaVersion':1,'scope':'hosted-synthetic-infrastructure',
             'nativeAppServerBinding':'unsupported-until-U6-U8','permissionPrompts':False,
             'runtimeNetwork':'denied','homeMode':'HOME+CFFIXED_USER_HOME','maxGuiSeconds':1200}
    try:
        with engine:
            hello=engine.initialize()
            if hello['data']['protocolVersion']!='1.0':
                raise HarnessFailure('invalid-bundled-engine')
            details['protocolVersion']='1.0'
            details['helperVersion']=hello['data']['serverVersion']
            engine_report=work/'engine.json'
            write_private(engine_report,encoded({'schemaVersion':1,'protocolVersion':'1.0',
                          'helperSha256':digest(regular_bytes(helper)),
                          'helperVersion':details['helperVersion'],'separateBundledProcess':True}))
            checks.append({'id':'macos-bundled-app-server','outcome':'pass','evidence':[str(engine_report)]})
            process=subprocess.Popen(['/usr/bin/sandbox-exec','-f',str(sandbox),str(executable)],
                                     env=child_environment(home),stdin=subprocess.DEVNULL,
                                     stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,start_new_session=True)
            deadline=time.monotonic()+1200
            def expire():
                try:stop_owned(process)
                finally:stop_owned(engine.process)
            watchdog=threading.Timer(1200,expire)
            watchdog.daemon=True;watchdog.start()
            print('U14 hosted synthetic GUI run started; maximum 1200s including cleanup.',flush=True)
            context=NativeContext(app,home,process,probe,sandbox,work,deadline)
            receipt,observations=context.capture()
            details['display']=receipt.get('display',{'state':'unsupported'})
            checks.extend(observations)
            checks.append({'id':'macos-owned-app-launch','outcome':'pass' if process.poll() is None else 'fail',
                           'evidence':[str(work/'capture-1/report.json')]})
            if any(c['id']=='macos-ax-tree' and c['outcome']=='pass' for c in checks):
                context.capabilities.update(('native-ui','accessibility'))
            if any(c['id']=='macos-offscreen-image' and c['outcome']=='pass' for c in checks):
                context.capabilities.add('offscreen-capture')
            results=drive_scenarios(context,selected)
            details['registeredDrivers']=sorted(SCENARIO_DRIVERS)
            capabilities=sorted(context.capabilities)
            engine.shutdown()
    finally:
        stop_owned(process)
        stop_owned(engine.process)
        if watchdog is not None:watchdog.cancel()
    return checks,details,results,capabilities


def bundle_spec(work,baseline,selected,checks,app,version,report,results=None,capabilities=(),display=None):
    results=results or {}
    return {'schemaVersion':1,'candidateId':'u14-part-e-'+git(REPO,'rev-parse','HEAD')[:12],
            'profile':'hosted-macos-part-e','intendedLevel':'L2',
            'build':{'type':'community','configuration':'release'},
            'sources':[{'repository':'modelplan/modelplan','path':str(REPO)}],
            'artifacts':{'app':str(app) if app else None,
                         'helper':str(app/'Contents/Helpers/modelplan') if app else None,
                         'helperVersion':version,'officialVisualsManifest':None,'visualBaselines':[]},
            'publicationRevision':None,'display':display or {'state':'unsupported'},
            'availableCapabilities':list(capabilities),
            'checks':checks,
            'results':[results[id] if id in selected and id in results else
                       {'id':id,'outcome':'unsupported','evidence':[str(report)]} for id in UI_IDS]}


def run(destination,case='coexistence',scenarios='all'):
    selected=select_scenarios(scenarios)
    if git(REPO,'status','--porcelain','--untracked-files=all'):
        raise ValueError('source must be clean before building evidence')
    work=new_directory(destination)
    baseline=build_home(load_json(ROOT/'examples/synthetic-shape.json'),work/'home',case)
    checks=[]
    details={'schemaVersion':1,'selectedScenarios':selected,'featureScenarios':'unsupported-until-U6-U8',
             'scope':'hosted-synthetic-infrastructure-only','nativeAppServerBinding':'unsupported-until-U6-U8'}
    app,version=None,None
    results,capabilities={},[]
    outcome='unsupported'
    try:
        if platform.system()!='Darwin' or os.environ.get('GITHUB_ACTIONS')!='true' or os.environ.get('RUNNER_OS')!='macOS':
            details['reason']='hosted-macos-profile-required'
        else:
            build=new_directory(work/'build')
            app,version=build_app(build)
            verify_home(work/'home',baseline)
            checks,observed,results,capabilities=run_native(app,work/'home',work,selected)
            if observed.get('helperVersion')!=version:raise HarnessFailure('helper-version-mismatch')
            details.update(observed)
            outcomes={r['outcome'] for r in [*checks,*results.values()]}
            outcome='timeout' if 'timeout' in outcomes else 'fail' if 'fail' in outcomes else 'pass'
    except (OSError,ValueError,HarnessFailure,EngineFailure,subprocess.SubprocessError) as exc:
        details['reason']=str(exc) if isinstance(exc,HarnessFailure) else type(exc).__name__
        outcome='timeout' if isinstance(exc,(subprocess.TimeoutExpired,HarnessTimeout,EngineTimeout)) else 'fail'
        # A partially packaged bundle is not an admitted artifact.
        if app is not None:
            try:verify_app(app)
            except (OSError,ValueError):app,version=None,None
    report=work/'report.json'
    write_private(report,encoded(details))
    # Bounded compiler/probe logs are public-source diagnostics, never runtime streams.
    logs=sorted(work.glob('build/*.log'))+sorted(work.glob('probe*.log'))
    checks.append({'id':'macos-harness','outcome':outcome,'evidence':[str(report),*[str(p) for p in logs]]})
    checks.append({'id':'macos-native-engine-binding','outcome':'unsupported','evidence':[str(report)]})
    spec=bundle_spec(work,baseline,selected,checks,app,version,report,results,capabilities,details.get('display'))
    bundle=generate_bundle(spec,baseline,work/'bundle')
    write_private(work/'summary.json',encoded({'schemaVersion':1,'infrastructure':outcome,
                  'scenarioOutcomes':{s['id']:s['outcome'] for s in bundle['scenarios'] if s['id'] in UI_IDS}}))
    return outcome!='fail' and outcome!='timeout'


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,required=True,help='new directory under git-ignored .tmp')
    parser.add_argument('--case',choices=CASES,default='coexistence')
    parser.add_argument('--scenarios',default='all',help='all or comma-separated A01–A19')
    args=parser.parse_args()
    try:
        success=run(args.output.absolute(),args.case,args.scenarios)
    except (ValueError,OSError,subprocess.SubprocessError):
        parser.exit(1,'U14 macOS harness failed before evidence generation.\n')
    if not success:parser.exit(1,'U14 macOS infrastructure failed; inspect the part-B bundle.\n')
    print('U14 part-B bundle created; UI feature scenarios remain unsupported.')


if __name__=='__main__':
    main()

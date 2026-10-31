# SPDX-License-Identifier: MIT
"""C2.7 package regression. CI supplies the CLI built from this checkout.

The CLI, builder, HOME copy, app-server, stub and Drive log copy are real. Native
menu/clear/quit rows are rendered synthetic unit-test observations, never GUI proof.
No refresh timestamp is edited and no provider other than the bound stub is used.
"""
import argparse,contextlib,hashlib,importlib.util,io,json,os,shutil,subprocess,sys,tempfile,time,unittest,zipfile
from pathlib import Path

VERIFICATION=Path(__file__).resolve().parent
ROOT=VERIFICATION.parents[2]
sys.path[:0]=[str(VERIFICATION/'U6'),str(VERIFICATION/'bin'),str(ROOT/'tools/u14')]
import synthetic_batch as sb
from prepare_config import prepare
from homeseed import copy_into
from engine_process import EngineProcess
from reading_fingerprint import reading_sha256
from u6_clock import system_uptime

def digest(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def rows(engine):
    deadline=time.monotonic()+5
    while time.monotonic()<deadline:
        response=engine.request('rows/subscribe')
        if 'error' not in response:return response['result']['data']
        if response['error'].get('code')!=-32023:raise AssertionError('rows-request-failed')
        time.sleep(.01)
    raise AssertionError('rows-publication-deadline')

class U6PackageTests(unittest.TestCase):
    def test_first_attempt_producers_through_real_final_entry(self):
        helper=os.environ.get('MODELPLAN_U6_TEST_CLI')
        if not helper:self.skipTest('CI must supply the head-built public CLI; no local Go build')
        helper=Path(helper).resolve()
        head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
        self.assertEqual(os.environ.get('MODELPLAN_U6_TEST_HEAD'),head,'CI helper source pin is required')
        with tempfile.TemporaryDirectory(prefix='u6-package-') as directory:
            root=Path(directory).resolve()
            binary=root/'Candidate.app/Contents/MacOS/App';binary.parent.mkdir(parents=True)
            binary.write_bytes(sb.BLOBS[sb.PINS['mainExecutable']]) # never executed
            bundled=binary.parent.parent/'Helpers/modelplan';bundled.parent.mkdir();shutil.copy2(helper,bundled)
            package=root/'candidate.zip'
            with zipfile.ZipFile(package,'w') as archive:
                for file in (binary,bundled):archive.write(file,file.relative_to(root).as_posix())
            manifest=dict(sourceHead=head,binarySHA256=digest(binary),helperSHA256=digest(bundled),packageSHA256=digest(package),
                bundleMembers={role:dict(path=path,sha256=digest(file)) for role,path,file in (
                    ('main','Contents/MacOS/App',binary),('engine','Contents/Helpers/modelplan',bundled),
                    ('consentHelper','Contents/Helpers/modelplan',bundled))})
            manifest_path=root/'kit-manifest.json';manifest_path.write_text(json.dumps(manifest))
            for name in ('scratch','batch','locks','resources'):(root/name).mkdir()
            args=argparse.Namespace(config=str(root/'batch/run.json'),scratch=str(root/'scratch'),batch=str(root/'batch'),
                ledger=str(root/'ledger.jsonl'),lease=str(root/'lease.json'),release=str(root/'release.json'),
                subject_pid=str(root/'subject.json'),locks=str(root/'locks'),resource_root=str(root/'resources'),
                binary=str(binary),package=str(package),kit_manifest=str(manifest_path),head=head,private_tool='copilot',
                run_id=sb.RUN,epoch=sb.EPOCH,booking_id='synthetic-offline-booking')
            with contextlib.redirect_stdout(io.StringIO()):prepare(args)
            config=json.loads((root/'batch/run.json').read_text());seed=json.loads((root/'batch/synthetic-seed.json').read_text())
            self.assertTrue(seed['firstAttempt']);self.assertFalse((root/'scratch/title-twin').exists())
            home=Path(config['syntheticHome']);home.mkdir();Path(config['syntheticTmp']).mkdir()
            copy_into(config,home)
            log=home/'.modelplan-stub/runtime-calls.jsonl';self.assertFalse(log.exists())
            engine=EngineProcess(bundled,home,'u6-package-first')
            engine.environment=dict(PATH='/usr/bin:/bin',HOME=str(home),TMPDIR=config['syntheticTmp'],LANG='en_US.UTF-8')
            self.assertEqual(set(engine.environment),{'PATH','HOME','TMPDIR','LANG'})
            with engine:
                engine.initialize();before=rows(engine)
                copilot=next(r for r in before['projection']['rows'] if r['id']=='copilot')
                self.assertEqual(copilot['accounts'],[]);self.assertFalse(log.exists())
                requested_mono=system_uptime();wire_id=engine.counter+1
                reply=engine.request('refresh/request');accepted_mono=system_uptime()
                self.assertEqual(reply['id'],wire_id)
                dispositions={r['scope']:r.get('disabledReason') or 'scheduled' for r in reply['result']['data']}
                self.assertEqual(dispositions['copilot.runtime_usage'],'scheduled')
                deadline=time.monotonic()+60
                while True:
                    after=rows(engine);copilot=next(r for r in after['projection']['rows'] if r['id']=='copilot')
                    if after['sequence']>before['sequence'] and copilot['accounts']:break
                    self.assertLess(time.monotonic(),deadline,'first refresh did not publish its reading')
                    time.sleep(.01)
                completed_mono=system_uptime()
                reading=reading_sha256(copilot['accounts']);self.assertEqual(reading,seed['readingSHA256'])
                # Observe the real cooldown without waiting it out or altering rate state.
                cooldown=engine.request('refresh/request')['result']['data']
                self.assertEqual(next(r for r in cooldown if r['scope']=='copilot.runtime_usage')['disabledReason'],'cooldown')
            spec=importlib.util.spec_from_file_location('package_drive',VERIFICATION/'bin/drive-u6.py')
            drive=importlib.util.module_from_spec(spec);spec.loader.exec_module(drive)
            copied_digest=drive.preserve_runtime_calls(config,sb.RUN,sb.EPOCH,sb.PID)
            copied=(root/'batch/runtime-calls.jsonl').read_bytes()
            self.assertEqual(copied,log.read_bytes());self.assertEqual(copied_digest,hashlib.sha256(copied).hexdigest())
            calls=[json.loads(line) for line in copied.splitlines()]
            self.assertTrue(any(r['method']=='account.getQuota' and requested_mono<r['mono']<completed_mono for r in calls))
            trace=sb.valid();shift=requested_mono-sb.m(21.05)
            for row in trace.native+trace.dock+trace.status+trace.clear:row['mono']+=shift
            for receipt in (trace.capture,trace.finish):receipt['mono']+=shift
            for key in ('startMono','endMono'):trace.reset[key]+=shift
            trace.one('refresh',phase='requested').update(engineRequestID=wire_id,rowsSequenceBefore=before['sequence'])
            accepted=trace.one('refresh',phase='accepted');accepted.update(engineRequestID=wire_id,dispositions=dispositions,
                mono=accepted_mono,at=sb.T0+accepted_mono-shift-sb.MONO0)
            terminal=trace.one('refresh',phase='completed');terminal.update(rowsSequenceAfter=after['sequence'],
                copilotAccountsAfter=len(copilot['accounts']),readingSHA256=reading,mono=completed_mono,
                at=sb.T0+completed_mono-shift-sb.MONO0)
            trace.native.sort(key=lambda r:r['mono']);trace.reseq()
            trace.capture['frameSeq']=trace.one('dock-surface-frame',state='expanded')['seq']
            for row in trace.find('menu-private-title-visible'):row['titleSHA256']=seed['titleSHA256']
            trace.reset['helperSHA256']=digest(bundled)
            files=trace.files();files['runtime-calls.jsonl']=copied
            files['result.json']=json.dumps(dict(runID=sb.RUN,epoch=sb.EPOCH,runtimeCallsSHA256=copied_digest)).encode()
            pins=dict(sb.PINS,engine=digest(bundled),consentHelper=digest(bundled))
            context=sb.context(pins=pins,launchedPins=pins,seedTitleSHA256=seed['titleSHA256'],seedReadingSHA256=reading)
            old_blob=sb.BLOBS.get(digest(bundled));sb.BLOBS[digest(bundled)]=bundled.read_bytes()
            try:
                final=root/'final';final.mkdir()
                command=sb.kit_batch(context,files,final)
                run_path=Path(command[1]);run=json.loads(run_path.read_text());batch=Path(command[3])
                run['head']=head;run['syntheticHomeSeedSHA256']=config['syntheticHomeSeedSHA256'];run_path.write_text(json.dumps(run))
                final_manifest_path=Path(command[7]);final_manifest=json.loads(final_manifest_path.read_text())
                final_manifest['sourceHead']=head;final_manifest_path.write_text(json.dumps(final_manifest))
                launch=json.loads((batch/'launch.json').read_text());launch['sourceHead']=head;(batch/'launch.json').write_text(json.dumps(launch))
                prepared=json.loads((batch/'prepared.json').read_text());prepared['homeSeedSHA256']=config['syntheticHomeSeedSHA256']
                (batch/'prepared.json').write_text(json.dumps(prepared));(batch/'synthetic-seed.json').write_text(json.dumps(seed))
                result=subprocess.run([sys.executable,'-B',str(VERIFICATION/'bin/evidence-u6.py'),*command],
                    text=True,capture_output=True,timeout=30)
                self.assertEqual(result.returncode,0,result.stderr)
                verdict=json.loads(result.stdout.strip().splitlines()[-1]);self.assertEqual(verdict['outcome'],'pass',verdict)
            finally:
                if old_blob is None:sb.BLOBS.pop(digest(bundled),None)
                else:sb.BLOBS[digest(bundled)]=old_blob

if __name__=='__main__':unittest.main()

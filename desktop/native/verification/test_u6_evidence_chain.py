# SPDX-License-Identifier: MIT
"""Complete offline C2.3 trace and negative mutations; no GUI or helper runs."""
import hashlib,importlib.util,json,tempfile,unittest,zipfile
from pathlib import Path

spec=importlib.util.spec_from_file_location('u6_chain',Path(__file__).parent/'U6/evidence_chain.py')
chain=importlib.util.module_from_spec(spec);spec.loader.exec_module(chain)
RUN='run';EPOCH='epoch';PID=42;REQUEST='aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa';TITLE=hashlib.sha256(b'Codex').hexdigest()

class U6ChainTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.root=Path(self.temp.name)
        app=self.root/'Test.app/Contents';self.binary=app/'MacOS/App';self.binary.parent.mkdir(parents=True);self.binary.write_bytes(b'app')
        helper=app/'Helpers/modelplan';helper.parent.mkdir();helper.write_bytes(b'helper')
        self.package=self.root/'candidate.zip'
        with zipfile.ZipFile(self.package,'w') as archive:
            archive.writestr('Test.app/Contents/MacOS/App',b'app')
            archive.writestr('Test.app/Contents/Helpers/modelplan',b'helper')
        self.config=dict(batch=str(self.root),argv=[str(self.binary)],head='a'*40,
            binarySHA256=hashlib.sha256(b'app').hexdigest(),helperSHA256=hashlib.sha256(b'helper').hexdigest(),
            packageSHA256=hashlib.sha256(self.package.read_bytes()).hexdigest(),syntheticHomeSeedSHA256='d'*64,
            syntheticHome=str(self.root/'scratch/home'),subjectPidPath=str(self.root/'subject.json'),
            expectedLease=dict(runID=RUN,epoch=EPOCH,notBefore=90,expiresAt=180))
        self.manifest=dict(sourceHead=self.config['head'],binarySHA256=self.config['binarySHA256'],
                           helperSHA256=self.config['helperSHA256'],packageSHA256=self.config['packageSHA256'],
                           bundleMembers={role:dict(path=path,sha256=digest) for role,path,digest in [
                               ('main','Contents/MacOS/App',self.config['binarySHA256']),
                               ('engine','Contents/Helpers/modelplan',self.config['helperSHA256']),
                               ('consentHelper','Contents/Helpers/modelplan',self.config['helperSHA256'])]})
        self.put('subject.json',dict(pid=PID,runID=RUN,epoch=EPOCH,state='running'))
        self.put('launch.json',dict(ownedPID=PID,runID=RUN,epoch=EPOCH,sourceHead=self.config['head']))
        self.put('prepared.json',dict(runID=RUN,epoch=EPOCH,homeSeedSHA256='d'*64))
        def row(seq,mono,event=None,checks=None,**fields):
            return dict(runID=RUN,epoch=EPOCH,pid=PID,seq=seq,mono=mono,at=mono,**({'event':event} if event else {}),
                        **({'checks':checks} if checks is not None else {}),**fields)
        self.native=[row(1,100,'started'),row(2,101,'dock-surface-frame',dict(state='sliver',windowNumber=77)),
            row(3,103,'dock-surface-frame',dict(state='expanded',windowNumber=77)),
            row(4,104,'status-item-frame',dict(cgX=20,cgY=20,width=20,height=20)),
            row(5,106,'menu-begin',dict(surface='status',menuObjectID='menu',sessionID='A')),
            row(6,107,'status-menu-action-arrived',dict(actionID='refresh',requestID=REQUEST,subjectPID=PID,
                deliveryMethod='axpress-menu-item',menuObjectID='menu',sessionID='A')),
            row(7,108,None,None,kind='refresh',phase='requested',requestId=REQUEST,rowsSequenceBefore=1,sessionID='A'),
            row(8,108.5,'menu-end',dict(menuObjectID='menu',sessionID='A',cause='other')),
            row(9,109,None,None,kind='refresh',phase='completed',requestId=REQUEST,rowsSequenceAfter=2,sessionID='A'),
            row(10,112,'menu-begin',dict(surface='status',menuObjectID='menu',sessionID='B')),
            row(11,112.2,'menu-private-title-visible',dict(menuObjectID='menu',sessionID='B',titleSHA256=TITLE,privateItemIDs=['item1'])),
            row(12,113,'clear-initiated',dict(clearID='clear',storeEpochAfter='new',generationAfter=1,openSessionIDs=['B'])),
            row(13,113.2,'menu-end',dict(sessionID='B',cause='clear',clearID='clear')),
            row(14,113.3,'accepted-clear',dict(clearID='clear',storeEpochAfter='new',generationAfter=1,scrubbedSessionIDs=['B'])),
            row(15,113.4,'menu-scrubbed',dict(clearID='clear',sessionID='B',itemStates=[dict(id='item1',state='cleared')],
                privateTitlePresent=False,privateAttributeCount=0)),
            row(16,115,'stop-or-lease-expired'),row(17,116,'terminate-completed')]
        self.write_native()
        for stem,events in [('dock-pointer',[('mouse-moved-posted','move',102)]),
            ('status-pointer',[('mouse-button-down-posted','click',105),('mouse-button-up-posted','click',105.1)]),
            ('status-pointer-clear',[('mouse-button-down-posted','click',111),('mouse-button-up-posted','click',111.1)])]:
            self.put(stem+'-plan.json',dict(runID=RUN,epoch=EPOCH,subjectPID=PID))
            self.write_lines(stem+'.jsonl',[dict(event=e,kind=k,mono=m,at=m,runID=RUN,epoch=EPOCH,targetPID=PID)
                for e,k,m in events]+[dict(event='pointer-result',outcome='posted',runID=RUN,epoch=EPOCH,targetPID=PID)])
        image=b'synthetic-window';(self.root/'dock-owned.png').write_bytes(image)
        self.put('dock-capture.json',dict(schema='u6-capture/1',runID=RUN,epoch=EPOCH,pid=PID,
            windowNumber=77,frameSeq=3,mono=103.5,file='dock-owned.png',sha256=hashlib.sha256(image).hexdigest()))
        self.write_lines('menu-drive.jsonl',[dict(event='status-menu-result',outcome='arrived',runID=RUN,epoch=EPOCH,
            subjectPID=PID,requestID=REQUEST)])
        self.put('synthetic-seed.json',dict(runID=RUN,epoch=EPOCH,homeSeedSHA256='d'*64,titleSHA256=TITLE))
        self.put('consent-reset.json',dict(schema='consent-reset/1',runID=RUN,epoch=EPOCH,targetPID=PID,sessionID='B',
            operation='consent-reset-confirmed',exitCode=0,outcome='success',helperSHA256=self.config['helperSHA256'],
            homeSHA256=hashlib.sha256(str(Path(self.config['syntheticHome']).resolve()).encode()).hexdigest(),
            startMono=112.9,endMono=114,storeEpochAfter='new',generationAfter=1))
        self.put('operator-finish.json',dict(schema='u6-actions/1',runID=RUN,epoch=EPOCH,mono=114.5,
            steps={key:'pass' for key in ('dock','menuA','refresh','menuB','privateTitle','trackedClear')}))
        self.put('launch-cleanup.json',dict(schema='launch-cleanup/1',runID=RUN,epoch=EPOCH,ok=True,failures=[],
            at='1970-01-01T00:02:00Z',leaseNotBefore=90,leaseExpiresAt=180,subjectStartedAt=100,closedAt=120,
            closedWithinLease=True,stopReasonRecorded=True,
            checks=dict(subjectGone=True,helpersGone=True,leaseClosable=True,locksReleased=True,
                syntheticHomeRemoved=True,syntheticTmpRemoved=True,stopPathPresent=True,
                controllerStatus=0,guardianStatus=0,scenarioStatus=0)))
    def tearDown(self):self.temp.cleanup()
    def put(self,name,value):(self.root/name).write_text(json.dumps(value))
    def write_lines(self,name,values):(self.root/name).write_text(''.join(json.dumps(x)+'\n' for x in values))
    def write_native(self):self.write_lines('native-observations.jsonl',self.native)
    def outcome(self):return chain.evaluate(self.config,self.root,self.package,self.manifest)
    def test_complete_trace_passes(self):self.assertEqual(self.outcome()['outcome'],'pass')
    def test_each_contradiction_or_missing_receipt_refuses_pass(self):
        def preclose():
            for row in self.native[11:]:row['seq']+=1
            self.native.insert(11,dict(self.native[12],seq=12,mono=112.8,at=112.8,
                checks=dict(sessionID='B',cause='other')))
        changes=[('wrong-pid',lambda:self.native[5].update(pid=99)),
            ('wrong-bundle-member',lambda:self.manifest['bundleMembers']['engine'].update(sha256='0'*64)),
            ('duplicate-terminal',lambda:self.native.append(dict(self.native[8],seq=18,mono=117,at=117))),
            ('stale-rows',lambda:self.native[8].update(rowsSequenceAfter=1)),
            ('preclose-b',preclose),
            ('wrong-epoch',lambda:self.native[11]['checks'].update(storeEpochAfter='other')),
            ('stale-title',lambda:self.native.append(dict(self.native[10],seq=18,mono=117,at=117))),
            ('private-item',lambda:self.native[14]['checks']['itemStates'][0].update(state='private')),
            ('late-closure',lambda:self.put('launch-cleanup.json',dict(chain.read(self.root/'launch-cleanup.json'),
                closedAt=181,closedWithinLease=False))),
            ('false-closure',lambda:self.put('launch-cleanup.json',dict(chain.read(self.root/'launch-cleanup.json'),checks=dict(chain.read(self.root/'launch-cleanup.json')['checks'],subjectGone=False))))]
        self.tearDown()
        for label,mutate in changes:
            with self.subTest(label=label):
                self.setUp()
                try:
                    mutate();self.write_native()
                    self.assertNotEqual(self.outcome()['outcome'],'pass',label)
                finally:self.tearDown()

if __name__=='__main__':unittest.main()

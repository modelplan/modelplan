# SPDX-License-Identifier: MIT
import hashlib, importlib.util, json, tempfile, unittest
from pathlib import Path

spec=importlib.util.spec_from_file_location('u6_receipt',Path(__file__).parent/'U6/evidence_receipt.py')
tool=importlib.util.module_from_spec(spec);spec.loader.exec_module(tool)

class U6ReceiptTests(unittest.TestCase):
    def test_missing_operator_proof_stays_not_run_and_bound_proof_passes(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);binary=root/'App';binary.write_bytes(b'binary')
            package=root/'App.zip';package.write_bytes(b'package')
            key='aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa'
            config=dict(batch=str(root),argv=[str(binary)],head='a'*40,binarySHA256=hashlib.sha256(b'binary').hexdigest(),
                packageSHA256=hashlib.sha256(b'package').hexdigest(),subjectPidPath=str(root/'subject.json'),
                syntheticHomeSeedSHA256='d'*64,expectedLease=dict(runID='run',epoch='epoch'))
            (root/'subject.json').write_text(json.dumps(dict(pid=42)))
            (root/'prepared.json').write_text(json.dumps(dict(runID='run',epoch='epoch',homeSeedSHA256='d'*64)))
            rows=[dict(event='started',runID='run',epoch='epoch',timestamp=100),
                dict(event='menu-begin',runID='run',epoch='epoch',timestamp=100.5,checks=dict(instanceID='m',surface='status',privateContent=True)),
                dict(event='status-menu-action-arrived',runID='run',epoch='epoch',checks=dict(actionID='refresh',requestID=key,menuInstanceID='m',deliveryMethod='axpress-menu-item')),
                dict(kind='refresh',phase='requested',runID='run',epoch='epoch',requestId=key,rowsSequenceBefore=1,at=101),
                dict(kind='refresh',phase='completed',runID='run',epoch='epoch',requestId=key,rowsSequenceAfter=2,at=102),
                dict(event='accepted-clear',runID='run',epoch='epoch',timestamp=103,checks=dict(priorPrivateContent=True,oldItemTitlesScrubbed=True,
                    oldItemPrivateAttributesScrubbed=True,scrubbedInstanceIDs=['m'])),
                dict(event='terminate-completed',runID='run',epoch='epoch',timestamp=109)]
            (root/'native-observations.jsonl').write_text(''.join(json.dumps(x)+'\n' for x in rows))
            (root/'result.json').write_text(json.dumps(dict(runID='run',epoch='epoch',appStarted=True,quit=dict(requested='native-contract-stop',appAcknowledged=True))))
            (root/'launch.json').write_text(json.dumps(dict(runID='run',epoch='epoch',ownedPID=42,sourceHead=config['head'])))
            (root/'launch-cleanup.json').write_text(json.dumps(dict(schema='launch-cleanup/1',runID='run',epoch='epoch',ok=True,failures=[],at='1970-01-01T00:01:50Z')))
            (root/'menu-request.json').write_text(json.dumps(dict(requestID=key)))
            (root/'menu-drive.jsonl').write_text(json.dumps(dict(event='status-menu-result',outcome='arrived',runID='run',epoch='epoch',requestID=key))+'\n')
            (root/'dock-owned.png').write_bytes(b'owned-image')
            tool.pointer.check=lambda *_:True
            tool.assemble(config,package)
            first=json.loads((root/'evidence-receipt.json').read_text())
            self.assertFalse(first['privateTitleObservedBeforeClear'])
            closure=json.loads((root/'launch-cleanup.json').read_text())
            self.assertEqual(tool.evidence.qualify(first,rows,closure),'not-run')
            (root/'evidence-receipt.json').unlink()
            tool.record_operator(config,now=101)
            tool.assemble(config,package)
            receipt=json.loads((root/'evidence-receipt.json').read_text())
            self.assertEqual(receipt['durationSeconds'],10)
            self.assertEqual(receipt['profileSHA256'],'d'*64)
            self.assertEqual(tool.evidence.qualify(receipt,rows,closure),'pass')

if __name__=='__main__':unittest.main()

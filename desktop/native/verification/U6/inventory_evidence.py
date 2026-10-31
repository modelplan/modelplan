# SPDX-License-Identifier: MIT
"""Inventory one completed U6 synthetic evidence batch without rewriting receipts."""
import argparse, hashlib, json
from pathlib import Path

def inventory(config):
    batch = Path(config['batch'])
    if not batch.is_dir() or batch.is_symlink(): raise ValueError('batch-invalid')
    manifest_path = batch/'manifest.json'
    manifest = json.loads(manifest_path.read_text())
    subject=manifest.get('subject',{})
    if (manifest.get('profile')!='synthetic' or manifest.get('headSHA')!=config['head']
        or any(subject.get(key)!=config.get(key) for key in
            ('head','binarySHA256','packageSHA256','helperSHA256','syntheticHomeSeedSHA256'))):
        raise ValueError('evidence-pins-mismatch')
    entries = []
    for path in sorted(batch.rglob('*')):
        if path.is_symlink(): raise ValueError('symlink-in-evidence')
        if not path.is_file() or path.name in ('README.md','filelist.txt'): continue
        rel = path.relative_to(batch).as_posix()
        entries.append((rel, hashlib.sha256(path.read_bytes()).hexdigest(), path.stat().st_size))
    if len(entries) < 5: raise ValueError('evidence-incomplete')
    lines = [f'{digest}  {name}\n' for name,digest,_ in entries]
    summary = {'runID':config['expectedLease']['runID'],'epoch':config['expectedLease']['epoch'],'sourceHead':config['head'],
        'binarySHA256':config['binarySHA256'],'packageSHA256':config['packageSHA256'],
        'profileSHA256':config['syntheticHomeSeedSHA256'],'durationSeconds':manifest.get('timing',{}).get('durationSeconds'),
        'outcome':manifest.get('scenarios',[{}])[0].get('outcome'),'fileCount':len(entries)}
    if not summary['runID'] or not summary['epoch'] or not summary['packageSHA256']:
        raise ValueError('evidence-pin-missing')
    with (batch/'filelist.txt').open('x') as stream:stream.writelines(lines)
    with (batch/'README.md').open('x') as stream:
        stream.write('# U6 synthetic device evidence\n\n')
        stream.write(json.dumps(summary,indent=2)+'\n\n')
        stream.write('The listed files are this one run’s bounded synthetic evidence. '
                     'An outcome is supplied by evidence-u6.py; file hashes do not upgrade missing GUI or cleanup proof.\n')
    print(json.dumps(summary))

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--config',type=Path,required=True)
    a=p.parse_args();inventory(json.loads(a.config.read_text()))

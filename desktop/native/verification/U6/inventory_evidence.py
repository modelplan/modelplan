# SPDX-License-Identifier: MIT
"""Inventory one completed U6 synthetic evidence batch without rewriting receipts."""
import argparse, hashlib, json
from pathlib import Path

def inventory(config):
    batch = Path(config['batch'])
    if not batch.is_dir() or batch.is_symlink(): raise ValueError('batch-invalid')
    receipt_path = batch/'evidence-receipt.json'
    manifest_path = batch/'manifest.json'
    receipt = json.loads(receipt_path.read_text())
    manifest = json.loads(manifest_path.read_text())
    if (receipt.get('profile') != 'synthetic' or receipt.get('headSHA') != config['head']
        or receipt.get('binarySHA256') != config['binarySHA256']
        or receipt.get('profileSHA256') != config['syntheticHomeSeedSHA256']
        or manifest.get('headSHA') != config['head']):
        raise ValueError('evidence-pins-mismatch')
    entries = []
    for path in sorted(batch.rglob('*')):
        if path.is_symlink(): raise ValueError('symlink-in-evidence')
        if not path.is_file() or path.name in ('README.md','filelist.txt'): continue
        rel = path.relative_to(batch).as_posix()
        entries.append((rel, hashlib.sha256(path.read_bytes()).hexdigest(), path.stat().st_size))
    if len(entries) < 5: raise ValueError('evidence-incomplete')
    lines = [f'{digest}  {name}\n' for name,digest,_ in entries]
    summary = {'runID':receipt.get('runID'),'epoch':receipt.get('epoch'),'sourceHead':config['head'],
        'binarySHA256':receipt['binarySHA256'],'packageSHA256':receipt.get('packageSHA256'),
        'profileSHA256':receipt['profileSHA256'],'durationSeconds':receipt.get('durationSeconds'),
        'outcome':manifest.get('scenarios',[{}])[0].get('outcome'),'fileCount':len(entries)}
    if not summary['runID'] or not summary['epoch'] or not summary['packageSHA256'] or not summary['durationSeconds']:
        raise ValueError('evidence-timing-or-pin-missing')
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

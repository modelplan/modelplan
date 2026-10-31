# SPDX-License-Identifier: MIT
"""Image export policy shared by U6 final evidence and its inventory."""
import hashlib,json
from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from artifact_paths import is_appledouble

IMAGE_SUFFIXES={'.png','.jpg','.jpeg','.heic','.tif','.tiff','.gif','.bmp','.webp'}
def image(path):return Path(path).suffix.lower() in IMAGE_SUFFIXES
def unpublished(path):return any(p.startswith('.u6-status-publish-') for p in Path(path).parts)

def approved_images(config,batch):
    batch=Path(batch);allowed=set();problems=[]
    paths=[p for p in batch.rglob('*') if not is_appledouble(p.relative_to(batch))]
    images=[p for p in paths if image(p) and (p.is_file() or p.is_symlink())]
    if not images:return allowed,problems
    try:
        reg=json.loads(Path(config['subjectPidPath']).read_text());pid=reg['pid']
        native=[json.loads(line) for line in (batch/'native-observations.jsonl').read_text().splitlines() if line.strip()]
    except (OSError,ValueError,KeyError):pid=None;native=[]
    run=config['expectedLease'];candidates={}
    for receipt in paths:
        if receipt.suffix!='.json' or receipt.is_symlink() or unpublished(receipt.relative_to(batch)):continue
        try:
            if receipt.stat().st_size>65536:continue
            value=json.loads(receipt.read_text())
            if not isinstance(value,dict) or value.get('schema')!='u6-capture/1':continue
            name=value.get('file')
            if not isinstance(name,str) or Path(name).name!=name or name in ('.','..'):continue
            target=receipt.parent/name
            if target!=batch/'dock-owned.png' or receipt!=batch/'dock-capture.json':continue
            if (value.get('runID'),value.get('epoch'),value.get('pid'))!=(run['runID'],run['epoch'],pid) or type(pid) is not int:continue
            event='dock-surface-frame'
            if not any(isinstance(r,dict) and r.get('runID')==run['runID'] and r.get('epoch')==run['epoch'] and r.get('pid')==pid
                       and r.get('seq')==value.get('frameSeq') and r.get('event')==event for r in native):continue
            candidates.setdefault(target,[]).append(value.get('sha256'))
        except (OSError,ValueError,TypeError):continue
    for path in images:
        rel=path.relative_to(batch)
        if path.is_symlink() or unpublished(rel) or len(candidates.get(path,[]))!=1:
            problems.append('orphan-image');continue
        try:
            digest_state=hashlib.sha256()
            with path.open('rb') as stream:
                for chunk in iter(lambda:stream.read(1024*1024),b''):digest_state.update(chunk)
            digest=digest_state.hexdigest()
        except OSError:problems.append('capture-image-unreadable');continue
        if digest!=candidates[path][0]:
            problems.append('capture-image-mismatch');continue
        allowed.add(rel.as_posix())
    return allowed,problems

def exportable(path,batch,allowed):
    rel=Path(path).relative_to(batch)
    return not is_appledouble(rel) and not unpublished(rel) and (not image(path) or rel.as_posix() in allowed)

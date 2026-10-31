# SPDX-License-Identifier: MIT
"""Bound the approved fixed synthetic Copilot runtime to one U6 attempt."""
import hashlib,json,os,sys
from pathlib import Path

def assert_unshadowed(home):
    for path in (Path('/usr/bin/copilot'),Path('/bin/copilot'),Path(home)/'.local/bin/copilot'):
        if os.path.lexists(path):raise ValueError('synthetic-stub-shadowed')

def verify_selection(home,expected_hash=None):
    assert_unshadowed(home)
    stub=Path(home)/'bin/copilot'
    if stub.is_symlink() or not stub.is_file() or not os.access(stub,os.X_OK):raise ValueError('synthetic-stub-not-resolved')
    digest=hashlib.sha256(stub.read_bytes()).hexdigest()
    if expected_hash is not None and digest!=expected_hash:raise ValueError('synthetic-stub-pin-mismatch')
    return digest

def install(home,run,epoch,template):
    assert_unshadowed(home);home=Path(home)
    old="    with (home/'runtime-calls').open('a') as log:log.write(method+'\\n')"
    replacement="""    binding=json.loads((home/'.modelplan-stub/binding.json').read_text())
    seq+=1
    mono=time.clock_gettime(time.CLOCK_UPTIME_RAW) if hasattr(time,'CLOCK_UPTIME_RAW') else time.monotonic()
    row={'schema':'runtime-calls/1','runID':binding['runID'],'epoch':binding['epoch'],'method':method,
         'pid':os.getpid(),'ppid':os.getppid(),'mono':mono,'seq':seq}
    with (home/'.modelplan-stub/runtime-calls.jsonl').open('a') as log:log.write(json.dumps(row)+'\\n')"""
    if template.count(old)!=1:raise ValueError('synthetic-runtime-template-drift')
    source=template.replace('PYTHON',sys.executable,1).replace(old,replacement)
    source=source.replace("home=Path(os.environ['HOME'])","home=Path(os.environ['HOME'])\nseq=0",1)
    directory=home/'.modelplan-stub';directory.mkdir(mode=0o700,exist_ok=True)
    (directory/'binding.json').write_text(json.dumps(dict(runID=run,epoch=epoch)))
    stub=home/'bin/copilot';stub.write_text(source);stub.chmod(0o700)
    return verify_selection(home)

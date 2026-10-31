# SPDX-License-Identifier: MIT
"""Validate an explicit synthetic run; execute only with an existing fresh lease."""
import argparse,hashlib,json,subprocess,time
from pathlib import Path
from admission import validate,load_and_admit
def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--config',type=Path,required=True);p.add_argument('--execute',action='store_true');a=p.parse_args()
    c=json.loads(a.config.read_text())
    if not a.execute:validate(c,time.time());print('Run contract valid; no process launched');return
    c=load_and_admit(c) # Read external records before creating synthetic resources.
    home=Path(c['syntheticHome']);tmp=Path(c['syntheticTmp'])
    home.mkdir(exist_ok=False);tmp.mkdir(exist_ok=False)
    binary=Path(c['argv'][0]).resolve(strict=True)
    if hashlib.sha256(binary.read_bytes()).hexdigest()!=c['binarySHA256']:raise ValueError('binary identity changed')
    c=load_and_admit(c) # Reread lease/release after filesystem/hash work, immediately before spawn.
    child=subprocess.Popen(c['argv'],env={'PATH':'/usr/bin:/bin','HOME':str(home),'TMPDIR':str(tmp),'LANG':'en_US.UTF-8'})
    print(json.dumps({'runID':c['lease']['runID'],'epoch':c['lease']['epoch'],'ownedPID':child.pid}))
if __name__=='__main__':main()

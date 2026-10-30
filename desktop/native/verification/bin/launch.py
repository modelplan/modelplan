# SPDX-License-Identifier: MIT
"""Validate an explicit synthetic run; execute only with an existing fresh lease."""
import argparse,hashlib,json,math,os,subprocess,time
from pathlib import Path
from book import admit
def validate(config,now):
    if config.get('profile')!='synthetic':raise ValueError('synthetic profile required')
    pin=config.get('binarySHA256','')
    if not isinstance(pin,str) or len(pin)!=64 or any(c not in '0123456789abcdef' for c in pin):raise ValueError('explicit binary SHA256 required')
    lease=config['lease'];release=config['release']
    for k in ('runID','epoch','notBefore','expiresAt'):
        if not lease.get(k) or lease[k]!=release.get(k):raise ValueError('lease/release identity mismatch')
    if (release.get('m1Released') is not True and release.get('guardianGO') is not True) or release.get('m0DirectedAnnouncementConfirmed') is not True:raise ValueError('release missing')
    values=[now,lease['notBefore'],lease['expiresAt'],lease.get('guardianHeartbeatAt'),config.get('requiredSeconds')]
    if any(type(x) not in (int,float) or not math.isfinite(x) for x in values):raise ValueError('invalid timing')
    if not 0<lease['expiresAt']-lease['notBefore']<=1200:raise ValueError('absolute window invalid')
    if not lease['notBefore']<=now<lease['expiresAt']:raise ValueError('outside window')
    if not 0<=now-lease['guardianHeartbeatAt']<=2:raise ValueError('heartbeat stale')
    if config.get('stop') is not False or lease.get('ownerPreempted') is not False or lease.get('exclusive') is not True:raise ValueError('stopped/not exclusive')
    if config['requiredSeconds']<=0 or lease['expiresAt']-now<config['requiredSeconds']:raise ValueError('insufficient phase+cleanup time')
    if not config.get('argv') or not all(isinstance(x,str) and x for x in config['argv']):raise ValueError('explicit executable arguments required')
    return True
def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--config',type=Path,required=True);p.add_argument('--execute',action='store_true');a=p.parse_args()
    c=json.loads(a.config.read_text());validate(c,time.time())
    if not a.execute:print('Run contract valid; no process launched');return
    # Resolve fresh external records again immediately before launch. This helper
    # is not a guardian; the pinned subject must consume that same lease/stop path.
    c['lease']=json.loads(Path(c['leasePath']).read_text());c['release']=json.loads(Path(c['releasePath']).read_text());c['stop']=Path(c['stopPath']).exists()
    validate(c,time.time())
    admit(c) # Live FIFO admission, before creating a home or starting any process.
    home=Path(c['syntheticHome']);tmp=Path(c['syntheticTmp'])
    home.mkdir(exist_ok=False);tmp.mkdir(exist_ok=False)
    binary=Path(c['argv'][0]).resolve(strict=True)
    if hashlib.sha256(binary.read_bytes()).hexdigest()!=c['binarySHA256']:raise ValueError('binary identity changed')
    validate(c,time.time());admit(c) # Recheck after filesystem/hash work; no queued retry.
    child=subprocess.Popen(c['argv'],env={'PATH':'/usr/bin:/bin','HOME':str(home),'TMPDIR':str(tmp),'LANG':'en_US.UTF-8'})
    print(json.dumps({'runID':c['lease']['runID'],'epoch':c['lease']['epoch'],'ownedPID':child.pid}))
if __name__=='__main__':main()

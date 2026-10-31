# SPDX-License-Identifier: MIT
"""Fingerprint only the fixed synthetic reading in an accepted rows projection."""
import datetime
import hashlib
import json
import math

def reading_sha256(accounts):
    if not isinstance(accounts,list) or len(accounts)!=1:
        raise ValueError('synthetic-reading-account-count')
    account=accounts[0]
    windows=[]
    for window in sorted(account['windows'],key=lambda value:value['id']):
        percent=window.get('remainingPercent')
        if percent is not None and (type(percent) not in (float,int) or not math.isfinite(percent)):
            raise ValueError('synthetic-reading-percent')
        # Swift's default rounded() is nearest, ties away from zero.
        bp=None if percent is None else int(math.copysign(math.floor(abs(percent*100)+0.5),percent))
        reset=window.get('resetsAt')
        seconds=None if reset is None else int(datetime.datetime.fromisoformat(reset.replace('Z','+00:00')).timestamp())
        windows.append(dict(id=window['id'],limitKey=window['limitKey'],poolKey=window['poolKey'],remainingBp=bp,resetsAt=seconds))
    value=dict(route=account['route'],plan=account['plan']['id'],windows=windows)
    return hashlib.sha256(json.dumps(value,sort_keys=True,separators=(',',':'),ensure_ascii=False).encode()).hexdigest()

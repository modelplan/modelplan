# SPDX-License-Identifier: MIT
"""Retired status-rectangle capture entry: candidate_app_window_only forbids it."""
import argparse,json,shutil
from pathlib import Path

def cleanup_owned_temporaries(private=None,stage=None):
    """Retain the -36 finally cleanup for previously allocated owned temporaries."""
    try:
        if private is not None:shutil.rmtree(private)
    finally:
        if stage is not None:shutil.rmtree(stage)

def capture(config,*_args,**_kwargs):
    # No screen tool, geometry crop or permission query is reachable here.
    try:
        lease=config['expectedLease']
        try:
            with (Path(config['batch'])/'status-capture-refusal.json').open('x') as out:
                json.dump(dict(schema='u6-status-capture-refusal/1',runID=lease['runID'],epoch=lease['epoch'],
                    reason='status-capture-disabled-by-policy'),out);out.write('\n')
        except FileExistsError:pass
        raise ValueError('status-capture-disabled-by-policy')
    finally:cleanup_owned_temporaries()

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--config',type=Path,required=True)
    a=p.parse_args();capture(json.loads(a.config.read_text()))

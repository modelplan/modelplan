# SPDX-License-Identifier: MIT
"""U6-only receipt qualification; shared Evidence remains the manifest/hash owner."""
import argparse, importlib.util, json
from pathlib import Path
def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--config',type=Path,required=True);parser.add_argument('--batch',type=Path,required=True)
    parser.add_argument('--package',type=Path,required=True);parser.add_argument('--kit-manifest',type=Path,required=True)
    args = parser.parse_args(argv)
    config=json.loads(args.config.read_text());kit_manifest=json.loads(args.kit_manifest.read_text())
    chain_spec=importlib.util.spec_from_file_location('u6_chain',Path(__file__).parent.parent/'U6/evidence_chain.py')
    chain=importlib.util.module_from_spec(chain_spec);chain_spec.loader.exec_module(chain)
    verdict=chain.evaluate(config,args.batch,args.package,kit_manifest)
    spec = importlib.util.spec_from_file_location('shared_evidence',Path(__file__).with_name('evidence.py'))
    shared = importlib.util.module_from_spec(spec); spec.loader.exec_module(shared)
    files=sorted(p.relative_to(args.batch).as_posix() for p in args.batch.rglob('*') if p.is_file()
                 and p.name not in ('manifest.json','filelist.txt','README.md') and not p.name.startswith('._'))
    report=dict(headSHA=config['head'],profile='synthetic',attributionMethod='c2.3-raw-run-bound-receipts',
        scenarios=[dict(id='U6-DockMenu-synthetic',outcome=verdict['outcome'],step=verdict['step'],reason=verdict['reason'])],files=files)
    result = shared.manifest(report,args.batch)
    result['subject'] = {key:config.get(key) for key in ('head','binarySHA256','packageSHA256','helperSHA256','syntheticHomeSeedSHA256')}
    result['timing'] = {'durationSeconds':verdict.get('durationSeconds')}
    with (args.batch/'manifest.json').open('x') as stream: json.dump(result,stream,indent=2)
    print(json.dumps(dict(scenario='U6-DockMenu-synthetic',**verdict)))
if __name__ == '__main__': main()

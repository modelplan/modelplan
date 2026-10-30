# SPDX-License-Identifier: MIT
"""Check a local HTML's relative module dependencies; never fetch or render."""
import argparse,json,re
from pathlib import Path
PATTERN=r'''(?:\b(?:import|export)\s+(?:[^;\n]*?\s+from\s*)?['"]([^'"]+)['"]|\bimport\(\s*['"]([^'"]+)['"])'''
def check(root,entry):
    root=Path(root).resolve();pending=[root/entry.split('?')[0]];seen=set();missing=[]
    while pending:
        p=pending.pop().resolve()
        if not p.is_relative_to(root):missing.append({'target':'outside-input-root'});continue
        if p in seen:continue
        seen.add(p)
        if not p.is_file():missing.append({'target':str(p.relative_to(root))});continue
        s=p.read_text(errors='replace')
        deps=re.findall(r'''(?:src|href)=["']([^"']+)["']''',s) if p.suffix=='.html' else [a or b for a,b in re.findall(PATTERN,s)]
        for dep in deps:
            if dep.startswith(('data:','http:','https:','#')):continue
            if p.suffix!='.html' and not dep.startswith('.'):continue
            target=(p.parent/dep.split('?')[0]).resolve()
            if not target.is_relative_to(root):missing.append({'from':str(p.relative_to(root)),'target':'outside-input-root'})
            elif not target.is_file():missing.append({'from':str(p.relative_to(root)),'target':str(target.relative_to(root))})
            elif target.suffix in ('.js','.mjs','.html'):pending.append(target)
    return missing
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('root',type=Path);p.add_argument('entry');a=p.parse_args();m=check(a.root,a.entry);print(json.dumps({'missing':m,'ready':not m}));raise SystemExit(bool(m))

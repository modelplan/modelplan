// SPDX-License-Identifier: MIT
import {isAbsolute} from 'node:path';

export function selectBuildEdition(args) {
 if(args.length===0)return 'community';
 if(args.length===1&&args[0]==='--official')return 'official';
 if(args.length===1&&args[0]==='--internal-acceptance')throw Error('internal-acceptance unavailable: reviewed helper, pins and resource mapping are not integrated');
 throw Error('Usage: node build.mjs [--official]');
}

// Integration seam only: callers must bind independently reviewed pins and an
// exact resource list in trusted code. No build currently supplies them.
export function collectInternalVisuals({edition,repository,assetTree,registrySha256,registryBytes,paths,createReader}) {
 const fail=()=>{throw Error('internal visual boundary rejected');};
 if(edition!=='internal-acceptance'||typeof repository!=='string'||!isAbsolute(repository)||
    typeof assetTree!=='string'||!/^[a-f0-9]{40}$/.test(assetTree)||
    typeof registrySha256!=='string'||!/^[a-f0-9]{64}$/.test(registrySha256)||
    !Buffer.isBuffer(registryBytes)||registryBytes.length===0||registryBytes.length>65536||
    !Array.isArray(paths)||paths.length===0||paths.length>64||typeof createReader!=='function')return fail();
 const seen=new Set(),requested=[...paths];
 for(const path of requested){
  if(typeof path!=='string'||!/^desktop\/official-visuals\/(?:[A-Za-z0-9_-][A-Za-z0-9._-]*\/)*[A-Za-z0-9_-][A-Za-z0-9._-]*$/.test(path)||
     path.split('/').some(part=>part==='.'||part==='..'||part.endsWith('.'))||path.length>512||seen.has(path))return fail();
  seen.add(path);
 }
 const registry=Buffer.from(registryBytes);
 const read=createReader({repository,assetTree,registrySha256});if(typeof read!=='function')return fail();
 const result=[];
 for(const path of requested){
  const bytes=read({edition,path,registryBytes:Buffer.from(registry)});
  if(!Buffer.isBuffer(bytes)||bytes.length>512*1024)return fail();
  result.push({path,bytes:Buffer.from(bytes)});
 }
 return result;
}

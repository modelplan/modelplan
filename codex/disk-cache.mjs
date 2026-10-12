// Node storage adapter for the shared ClientDataReader. No network or metric logic.
import { readFile, open, writeFile, mkdir, rename, unlink, stat, readdir, rm } from 'node:fs/promises';
import { homedir } from 'node:os';
import { join, dirname } from 'node:path';
import { randomUUID } from 'node:crypto';
import { encodePublicJSON, publicContentHash } from './lib/client-reader.mjs';

const hashID=/^[0-9a-f]{64}$/,releaseID=/^[0-9a-f]{24}$/;
export function cacheDirectory(){
  return process.env.MODELPLAN_CACHE || join(process.platform==='darwin'?join(homedir(),'Library/Caches'):
    process.platform==='win32'?process.env.LOCALAPPDATA||join(homedir(),'AppData/Local'):
    process.env.XDG_CACHE_HOME||join(homedir(),'.cache'),'modelplan');
}
async function atomic(path,bytes){
  await mkdir(dirname(path),{recursive:true});const tmp=path+'.tmp-'+randomUUID();
  try{const f=await open(tmp,'wx',0o600);try{await f.writeFile(bytes);await f.sync();}finally{await f.close();}await rename(tmp,path);}
  finally{await unlink(tmp).catch(()=>{});}
}
export function diskCache({dir=cacheDirectory(),base,now=Date.now}={}){
  const statePath=join(dir,'state.json'),manifestPath=id=>join(dir,'releases',id,'manifest.json'),objectPath=id=>join(dir,'objects',id+'.json');
  const state=async()=>{try{return JSON.parse(await readFile(statePath,'utf8'));}catch{return {};}};
  async function load(){
    const s=await state();if(s.base!==base||s.component!=='client'||!releaseID.test(s.publicationId??'')||!hashID.test(s.componentHash??''))return null;
    const manifest=JSON.parse(await readFile(manifestPath(s.publicationId),'utf8'));
    if(manifest.publicationId!==s.publicationId||manifest.components?.client?.hash!==s.componentHash)return null;
    return {manifest,component:JSON.parse(await readFile(objectPath(s.componentHash),'utf8'))};
  }
  async function save(value){
    const {manifest,component}=value,ref=manifest.components.client,s=await state();
    await atomic(objectPath(ref.hash),encodePublicJSON(component));
    await atomic(manifestPath(manifest.publicationId),encodePublicJSON(manifest));
    await atomic(statePath,JSON.stringify({base,publicationId:manifest.publicationId,manifestHash:await publicContentHash(encodePublicJSON(manifest)),
      publishedAt:manifest.publishedAt,component:'client',componentHash:ref.hash,
      previousPublicationId:s.publicationId!==manifest.publicationId?s.publicationId:s.previousPublicationId,
      verifiedAt:new Date(now()).toISOString(),checkedAt:new Date(now()).toISOString(),lastAttemptAt:new Date(now()).toISOString(),lastError:''}));
  }
  async function note({errorCode,etag}){
    const s=await state(),stamp=new Date(now()).toISOString();
    await atomic(statePath,JSON.stringify({...s,base,lastAttemptAt:stamp,lastError:errorCode??'',...(!errorCode?{checkedAt:stamp}:{}),...(etag?{etag}:{})}));
  }
  async function lock(){
    await mkdir(dir,{recursive:true});const path=join(dir,'sync.lock'),token=randomUUID();
    for(let i=0;i<2;i++){
      try{await writeFile(path,token,{flag:'wx',mode:0o600});return async()=>{if(await readFile(path,'utf8').catch(()=>null)===token)await unlink(path).catch(()=>{});};}
      catch(e){if(e.code!=='EEXIST')throw e;const age=now()-(await stat(path)).mtimeMs;if(age>120000){await unlink(path);continue;}throw Error('publication_sync_busy');}
    }throw Error('publication_sync_busy');
  }
  async function prune(){
    const s=await state(),keep=new Set([s.publicationId,s.previousPublicationId].filter(id=>releaseID.test(id??'')));
    const releases=await readdir(join(dir,'releases')).catch(()=>[]);
    if(keep.size<2){const other=await Promise.all(releases.filter(id=>releaseID.test(id)&&!keep.has(id)).map(async id=>({id,at:(await stat(manifestPath(id))).mtimeMs})));other.sort((a,b)=>b.at-a.at);if(other[0])keep.add(other[0].id);}
    const hashes=new Set();for(const id of keep){try{const m=JSON.parse(await readFile(manifestPath(id)));Object.values(m.components).forEach(c=>hashes.add(c.hash));}catch{}}
    for(const file of await readdir(join(dir,'objects')).catch(()=>[])){const h=file.replace(/\.json$/,'');if(!hashID.test(h)||hashes.has(h))continue;const p=join(dir,'objects',file);if(now()-(await stat(p)).mtimeMs>14*86400000)await unlink(p);}
    for(const id of releases)if(releaseID.test(id)&&!keep.has(id))await rm(join(dir,'releases',id),{recursive:true});
  }
  return {load,save,state,note,lock,prune};
}

import { ClientDataReader,verifyClientDigest } from './lib/client-reader.mjs';
import { diskCache } from './disk-cache.mjs';
export const DEFAULT_BASE='https://modelplan.ai';
export const recommendation=m=>m.configurations.find(c=>c.effort===m.recommended);

// A shape adapter only. The producer supplies every metric, basis and verdict.
export function projectClient({manifest,component}){
  const d=component.data,models=d.models.filter(m=>m.developerId==='openai').map(({efforts,...m})=>({...m,configurations:efforts}));
  return {schemaVersion:1,source:'client',clientScope:'codex-openai',publicationId:manifest.publicationId,publishedAt:manifest.publishedAt,
    ...(d.projectionVersion?{projectionVersion:d.projectionVersion,multipliers:d.multipliers.filter(m=>m.provider==='openai'),multiplierHorizon:d.multiplierHorizon}:{}),
    builtAt:d.builtAt,units:d.units,models,modelNames:Object.fromEntries(models.map(m=>[m.id,m.name])),
    lineup:d.lineups.find(l=>l.developerId==='openai')??null,
    resetFeed:{status:'published',publicationId:manifest.publicationId,events:d.resets.filter(r=>r.provider==='openai'),personalEligibility:'unknown'},
    speedTiers:(d.speedTiers??[]).filter(t=>t.harness==='codex'),
    windows:d.windows.filter(w=>w.provider==='openai'),sourceUrl:DEFAULT_BASE+'/v1/client'};
}
export function createReader({base=process.env.MODELPLAN_BASE||DEFAULT_BASE,cacheDir,fetcher=fetch,now=Date.now,ttlMs=600000}={}){
  let cache,etag;
  const reader=new ClientDataReader({baseUrl:base,fetcher:async(...args)=>{const r=await fetcher(...args);if(new URL(args[0]).pathname.endsWith('/current.json')&&r.ok)etag=r.headers.get('etag');return r;},
    cache:{load:()=>cache.load(),save:v=>cache.save(v)}});
  base=reader.baseUrl.href.replace(/\/$/,'');cache=diskCache({dir:cacheDir,base,now});
  let pending,memo;
  async function loadCached(){
    try{const v=await cache.load();if(v){await verifyClientDigest(v);reader.current=v;}}catch{/* The shared verifier rejects an invalid cache. */}
  }
  function response(v,s,errorCode=null){
    if(memo?.publicationId!==v.manifest.publicationId)memo=projectClient(v);
    return {...memo,sourceUrl:base+'/v1/client',verifiedAt:s.verifiedAt??null,checkedAt:s.checkedAt??null,
      stale:!!errorCode||now()-Date.parse(s.checkedAt)>48*3600000,status:errorCode?'last-good':'published',error:errorCode};
  }
  async function read(refresh){
    if(!reader.current)await loadCached();
    const s=await cache.state(),last=Math.max(Date.parse(s.checkedAt)||0,Date.parse(s.lastAttemptAt)||0);
    if(!refresh&&reader.current&&now()-last<ttlMs)return response(reader.current,s,s.lastError||null);
    let unlock;
    try{
      unlock=await cache.lock();
      // Another compatible client may have committed a complete digest since our last call.
      await loadCached();
      const r=await reader.refresh();await cache.note({errorCode:r.errorCode,etag});
      if(!r.digest)throw Error(r.errorCode||'publication_client_unavailable');
      await cache.prune().catch(()=>{});
      return response(r.digest,await cache.state(),r.errorCode);
    }catch(e){if(reader.current)return response(reader.current,await cache.state(),e.message);throw e;}
    finally{if(unlock)await unlock();}
  }
  return ({refresh=false}={})=>{if(!pending)pending=read(refresh).finally(()=>{pending=null;});return pending;};
}
export function filterDashboard(data,modelIds){
  if(!modelIds?.length)return data;const wanted=new Set(modelIds),missing=[...wanted].filter(id=>!data.models.some(m=>m.id===id));
  if(missing.length)throw Error('unknown_model_ids:'+missing.join(','));
  return {...data,models:data.models.filter(m=>wanted.has(m.id))};
}

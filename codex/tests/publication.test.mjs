import test from 'node:test';import assert from 'node:assert/strict';import {mkdtemp,rm,readFile,writeFile} from 'node:fs/promises';import {join} from 'node:path';import {tmpdir} from 'node:os';
import {createReader} from '../data.mjs';import {encodePublicJSON,publicContentHash} from '../lib/client-reader.mjs';
const v=JSON.parse(await readFile(new URL('./fixtures/client-publication.json',import.meta.url)));
async function fixture(t){const dir=await mkdtemp(join(tmpdir(),'mp-client-'));t.after(()=>rm(dir,{recursive:true,force:true}));let time=Date.parse('2026-10-11T09:00:00Z'),mode='good',calls=[];
 const mb=encodePublicJSON(v.manifest),cb=encodePublicJSON(v.component),mh=await publicContentHash(mb);
 const fetcher=async(input,options)=>{const path=new URL(input).pathname;calls.push({path,headers:options.headers});if(mode==='offline')throw Error('offline');
  if(path.endsWith('/current.json'))return mode==='304'?new Response(null,{status:304}):new Response(JSON.stringify({schemaVersion:1,publicationId:v.manifest.publicationId,manifestHash:mh,promotionId:'11111111-1111-4111-8111-111111111111'}),{headers:{etag:'"fixture"'}});
  if(path.endsWith('/manifest.json'))return new Response(mode==='bad-manifest'?'{}':mb);
  if(path===`/publications/objects/${v.manifest.components.client.hash}.json`)return new Response(mode==='bad-client'?'{}':cb);
  throw Error('Unexpected dependency download: '+path);
 };
 return {dir,calls,options:{cacheDir:dir,fetcher,now:()=>time},mode:m=>mode=m,advance:()=>time+=600001};
}
test('shared verifier downloads only pointer, manifest and client, with coalescing and persistent Go-compatible cache',async t=>{
 const f=await fixture(t),read=createReader(f.options),[a,b]=await Promise.all([read(),read()]);assert.equal(a.publicationId,b.publicationId);assert.equal(f.calls.length,3);assert.equal(a.source,'client');assert.equal(a.units.cost,'usdPerReferenceTask');
 const s=JSON.parse(await readFile(join(f.dir,'state.json')));assert.equal(s.component,'client');assert.equal(s.componentHash,v.manifest.components.client.hash);f.mode('offline');const cold=await createReader(f.options)();assert.equal(cold.publicationId,a.publicationId);assert.equal(f.calls.length,3);
});
test('a failed refresh retains the whole verified digest, original timestamps and published verdicts',async t=>{
 const f=await fixture(t),read=createReader(f.options),a=await read();f.advance();f.mode('offline');const b=await read();assert.equal(b.status,'last-good');assert.equal(b.publicationId,a.publicationId);assert.deepEqual(b.lineup,a.lineup);assert.deepEqual(b.resetFeed,a.resetFeed);assert.equal(b.checkedAt,a.checkedAt);await read();assert.equal(f.calls.length,4);
});
test('the shared reader handles ETag 304 and a corrupt first read never seeds a value',async t=>{
 const f=await fixture(t),read=createReader(f.options);await read();f.advance();f.mode('304');assert.equal((await read()).status,'published');assert.equal(f.calls.at(-1).headers['If-None-Match'],'"fixture"');
 for(const mode of ['bad-client','bad-manifest','offline']){const x=await fixture(t);x.mode(mode);await assert.rejects(createReader(x.options)(),/publication_/);}
});
test('an old models-only cache cannot be used as runtime fallback; corrupted client cache is not served offline',async t=>{
 const f=await fixture(t);await createReader(f.options)();const p=join(f.dir,'state.json'),s=JSON.parse(await readFile(p));await writeFile(join(f.dir,'objects',s.componentHash+'.json'),'bad');f.mode('offline');await assert.rejects(createReader(f.options)({refresh:true}),/publication_/);
 s.component='models';await writeFile(p,JSON.stringify(s));await assert.rejects(createReader(f.options)(),/publication_/);
});

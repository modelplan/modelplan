import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {ClientDataReader, encodePublicJSON, publicContentHash} from '../public-reader.mjs';
test('the public module contains only the licensed existing publication verifier', async()=>{
 const m=JSON.parse(await readFile(new URL('../manifest.json',import.meta.url),'utf8'));
 assert.deepEqual(Object.keys(m.files).sort(),['LICENSE','public-reader.d.mts','public-reader.mjs']);
 for(const [name,record] of Object.entries(m.files)){
  assert.equal(record.license,'MIT');
  assert.equal(createHash('sha256').update(await readFile(new URL('../'+name,import.meta.url))).digest('hex'),record.sha256);
 }
});
test('reader rejects credential-bearing/nonlocal plain HTTP bases',async()=>{
 for(const baseUrl of ['http://example.com','https://user:password@example.com','https://example.com/?token=x'])assert.throws(()=>new ClientDataReader({baseUrl}));
 assert.equal((await publicContentHash(encodePublicJSON({synthetic:true}))).length,64);
});
test('a manifest kind this reader does not know is skipped, never downloaded', async()=>{
 const v=JSON.parse(await readFile(new URL('../../codex/tests/fixtures/client-publication.json',import.meta.url),'utf8'));
 const {schemaVersion,comparisonVersion,methods}=v.manifest;
 const components={...v.manifest.components,'calendar-week-zh':{schemaVersion:2,hash:'d'.repeat(64),bytes:300000}};
 const publicationId=(await publicContentHash(encodePublicJSON({schemaVersion,comparisonVersion,methods,components}))).slice(0,24);
 const manifest={...v.manifest,components,publicationId},mb=encodePublicJSON(manifest),cb=encodePublicJSON(v.component),paths=[];
 const fetcher=async input=>{const path=new URL(input).pathname;paths.push(path);
  if(path.endsWith('/current.json'))return new Response(JSON.stringify({schemaVersion:1,publicationId,manifestHash:await publicContentHash(mb)}));
  if(path.endsWith('/manifest.json'))return new Response(mb);
  if(path===`/publications/objects/${components.client.hash}.json`)return new Response(cb);
  throw Error('unexpected download: '+path);
 };
 const r=await new ClientDataReader({baseUrl:'https://example.test/',fetcher}).refresh();
 assert.equal(r.state,'current',r.errorCode);
 assert.equal(r.digest.manifest.publicationId,publicationId);
 assert.equal(paths.length,3);
 const bad={...manifest,components:{...components,'Bad Kind':components.client}};
 const badBytes=encodePublicJSON(bad);
 const badFetcher=async input=>{const path=new URL(input).pathname;
  if(path.endsWith('/current.json'))return new Response(JSON.stringify({schemaVersion:1,publicationId,manifestHash:await publicContentHash(badBytes)}));
  if(path.endsWith('/manifest.json'))return new Response(badBytes);
  throw Error('unexpected download: '+path);
 };
 const rejected=await new ClientDataReader({baseUrl:'https://example.test/',fetcher:badFetcher}).refresh();
 assert.equal(rejected.state,'unavailable');
 assert.equal(rejected.errorCode,'publication_invalid_components');
});

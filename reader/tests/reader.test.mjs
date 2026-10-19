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

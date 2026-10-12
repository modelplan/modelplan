import test from 'node:test';import assert from 'node:assert/strict';import {readFile} from 'node:fs/promises';import {createHash} from 'node:crypto';
const kit=new URL('../ui/kit/',import.meta.url);
test('vendored kit matches the release fingerprints',async()=>{const hashes=JSON.parse(await readFile(new URL('source-hashes.json',kit)));for(const [name,hash]of Object.entries(hashes))assert.equal(createHash('sha256').update(await readFile(new URL(name,kit))).digest('hex'),hash,name);});

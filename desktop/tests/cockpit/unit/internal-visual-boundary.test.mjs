// SPDX-License-Identifier: MIT
import test from 'node:test';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {execFileSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {collectInternalVisuals,selectBuildEdition} from '../../../cockpit/internal-visual-boundary.mjs';

const tree='1'.repeat(40),edition='internal-acceptance',first='desktop/official-visuals/synthetic/a.txt',second='desktop/official-visuals/synthetic/b.txt';
const hash=bytes=>createHash('sha256').update(bytes).digest('hex');
test('the default remains community and only the existing official flag selects official',()=>{
 assert.equal(selectBuildEdition([]),'community');assert.equal(selectBuildEdition(['--official']),'official');
 for(const args of [['--community'],['--official','--internal-acceptance'],['--unknown']])assert.throws(()=>selectBuildEdition(args),/Usage/);
});
function fixture(){
 const content=new Map([[first,Buffer.from('fake a')],[second,Buffer.from('fake b')]]),digests=new Map([...content].map(([path,bytes])=>[path,hash(bytes)])),registryBytes=Buffer.from('synthetic registry'),calls=[];
 const pins={edition,repository:'/synthetic/repository',assetTree:tree,registrySha256:hash(registryBytes),registryBytes,paths:[first,second]};
 function createReader(anchors){
  if(anchors.repository!==pins.repository||anchors.assetTree!==tree||anchors.registrySha256!==pins.registrySha256)throw Error('synthetic pins rejected');
  return request=>{
   calls.push(request.path);
   if(request.edition!==edition||hash(request.registryBytes)!==pins.registrySha256||!content.has(request.path)||hash(content.get(request.path))!==digests.get(request.path))throw Error('synthetic reader rejected');
   return content.get(request.path);
  };
 }
 return {pins,content,calls,createReader};
}
test('every synthetic resource is read with the bound edition and pins',()=>{
 const f=fixture(),result=collectInternalVisuals({...f.pins,createReader:f.createReader});
 assert.deepEqual(f.calls,[first,second]);assert.deepEqual(result.map(x=>x.bytes.toString()),['fake a','fake b']);
 result[0].bytes[0]=0;assert.equal(f.content.get(first).toString(),'fake a');
});
test('resource requests are fixed before reader setup can mutate caller inputs',()=>{
 const f=fixture(),original=f.createReader;
 const result=collectInternalVisuals({...f.pins,createReader(anchors){const read=original(anchors);f.pins.paths.push('desktop/official-visuals/synthetic/unlisted.txt');f.pins.registryBytes.fill(0);return read;}});
 assert.deepEqual(f.calls,[first,second]);assert.equal(result.length,2);
});
test('other editions, missing or malformed pins, and unsafe paths fail closed',()=>{
 const f=fixture(),base={...f.pins,createReader:f.createReader};
 for(const change of [{edition:'community'},{edition:'official'},{edition:''},{assetTree:''},{assetTree:'2'.repeat(40)},{registrySha256:''},{registrySha256:'3'.repeat(64)},{registryBytes:Buffer.alloc(0)},{paths:[]},{paths:[first,first]},{paths:['desktop/official-visuals/../private']},{createReader:null}])
  assert.throws(()=>collectInternalVisuals({...base,...change}),/rejected/);
 assert.deepEqual(f.calls,[]);
});
test('unlisted resources, corrupted registry and unavailable reader fail closed',()=>{
 const f=fixture(),base={...f.pins,createReader:f.createReader};
 assert.throws(()=>collectInternalVisuals({...base,paths:[first,'desktop/official-visuals/synthetic/unlisted.txt']}),/rejected/);
 assert.throws(()=>collectInternalVisuals({...base,registryBytes:Buffer.from('tampered')}),/rejected/);
 f.content.set(second,Buffer.from('corrupted'));assert.throws(()=>collectInternalVisuals(base),/rejected/);
 f.content.delete(second);assert.throws(()=>collectInternalVisuals(base),/rejected/);
 assert.throws(()=>collectInternalVisuals({...base,createReader(){throw Error('reader unavailable');}}),/unavailable/);
 assert.throws(()=>collectInternalVisuals({...base,createReader(){return ()=>null;}}),/rejected/);
});
test('real internal edition stays unavailable without reviewed integration',()=>{
 const build=fileURLToPath(new URL('../../../cockpit/build.mjs',import.meta.url));
 assert.throws(()=>execFileSync(process.execPath,[build,'--internal-acceptance'],{stdio:'pipe'}),error=>/reviewed helper, pins and resource mapping are not integrated/.test(error.stderr.toString()));
});

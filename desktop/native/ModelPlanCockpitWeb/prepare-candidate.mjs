// SPDX-License-Identifier: MIT
// Stage the canonical web output for U10's existing Cockpit resource input.
import {cp,mkdir,readFile,rm,lstat,readdir} from 'node:fs/promises';
import {resolve,dirname} from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
const repo=resolve(dirname(fileURLToPath(import.meta.url)),'../../..');
const edition=process.argv[2];
if(!['community','official'].includes(edition)||process.argv.length!==3)throw Error('Use prepare-candidate.mjs community|official after the canonical web build');
const source=resolve(repo,'desktop/cockpit/.tmp',edition),destination=resolve(repo,'desktop/cockpit/dist');
const bytes=await readFile(resolve(source,'bundle-manifest.json')),manifest=JSON.parse(bytes);
if(manifest.schemaVersion!==1||manifest.edition!==edition||manifest.interfaceOnly!==true)throw Error('Unexpected web manifest');
const seen=new Set();
async function inspect(root,prefix='') {
 for(const name of await readdir(root)) {
  const path=resolve(root,name),relative=prefix+name,stat=await lstat(path);
  if(stat.isSymbolicLink())throw Error('Symlink in web output');
  if(stat.isDirectory()){await inspect(path,relative+'/');continue;}
  if(!stat.isFile())throw Error('Special file in web output');
  if(relative==='bundle-manifest.json')continue;
  if(createHash('sha256').update(await readFile(path)).digest('hex')!==manifest.files[relative])throw Error('Web output changed');
  seen.add(relative);
 }
}
await inspect(source);
if(seen.size!==Object.keys(manifest.files).length)throw Error('Web output inventory mismatch');
await rm(destination,{recursive:true,force:true});await mkdir(dirname(destination),{recursive:true});
await cp(source,destination,{recursive:true});
console.log(JSON.stringify({edition,manifestSHA256:createHash('sha256').update(bytes).digest('hex'),files:seen.size,output:'desktop/cockpit/dist'}));

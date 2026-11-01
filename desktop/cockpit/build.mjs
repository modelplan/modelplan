// SPDX-License-Identifier: MIT
import { cp,readFile,writeFile,mkdir,rm } from 'node:fs/promises';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { resolve,relative,dirname,sep } from 'node:path';
import { createHash } from 'node:crypto';
import { verifyVisualPack } from '../../scripts/check-visual-pack.mjs';
const here=fileURLToPath(new URL('.',import.meta.url)),repo=resolve(here,'../..');
const args=process.argv.slice(2),official=args.length===1&&args[0]==='--official';
if(args.length&&!official)throw Error('Usage: node build.mjs [--official]');
execFileSync(process.execPath,[resolve(here,'generate-wire.mjs'),'--check'],{stdio:'inherit'});
// Copy only this compile's emitted files: a removed source can leave stale JS
// and declarations in a reused compiler directory. Do not publish that cache.
const emitted=execFileSync(resolve(here,'node_modules/.bin/tsc'),['-p',here,'--listEmittedFiles'],{encoding:'utf8'})
  .split(/\r?\n/).filter(line=>line.startsWith('TSFILE: ')).map(line=>line.slice(8));
const compiled=resolve(here,'.tmp/compiled');
if(!emitted.includes(resolve(compiled,'src/main.js'))||!emitted.includes(resolve(compiled,'generated/wire.js')))throw Error('Missing emitted bundle entry');
const output=resolve(here,'.tmp',official?'official':'community');
await rm(output,{recursive:true,force:true});await mkdir(output,{recursive:true});
for(const file of emitted){
  const name=relative(compiled,file);
  if(!['src','generated'].includes(name.split(sep)[0]))throw Error('Unexpected emitted bundle path');
  const destination=resolve(output,name);await mkdir(dirname(destination),{recursive:true});await cp(file,destination);
}
await cp(resolve(here,'web/index.html'),resolve(output,'index.html'));
await cp(resolve(here,'prototype'),resolve(output,'prototype'),{recursive:true});
const sheets=['theme','style','rocket','cockpit-r5','engine','mfd','faders','shell6','hull-r3'];
let css=sheets.map(name=>`@import url('./prototype/prototype-${name}.css');`).join('\n')+'\n'+await readFile(resolve(here,'web/cockpit.css'),'utf8');
const notices=['MIT: cockpit bridge, schema adapter and community layout.'];
if (official) {
  // Only this explicit edition reads reserved artwork; the default never does.
  const assets=resolve(repo,'desktop/official-visuals');
  verifyVisualPack(repo);
  await cp(resolve(assets,'runtime'),resolve(output,'runtime'),{recursive:true});
  css+='\n'+await readFile(resolve(assets,'cockpit/cockpit.css'),'utf8');
  await cp(resolve(assets,'LICENSE.md'),resolve(output,'VISUAL-LICENSE.md'));
  // Fonts are independently public OFL assets; keep their notices beside them.
  await cp(resolve(repo,'desktop/third-party/fonts'),resolve(output,'fonts'),{recursive:true});
  css="@import url('./fonts/fonts.css');\n"+css;
  notices.push('Official appearance/artwork: LicenseRef-ModelPlan-Visuals-1.0; see VISUAL-LICENSE.md.','Fonts: OFL-1.1; see fonts/*/OFL.txt and fonts/README.md.');
} else {
  notices.push('Community edition excludes reserved artwork.');
}
await writeFile(resolve(output,'cockpit.css'),css);
await cp(resolve(repo,'LICENSE'),resolve(output,'LICENSE.txt'));
await writeFile(resolve(output,'NOTICES.txt'),notices.join('\n')+'\n');
const files={};
async function inventory(path,prefix='') {
  const {readdir}=await import('node:fs/promises');
  for(const entry of await readdir(path,{withFileTypes:true})) {
    const name=prefix+entry.name;
    if(entry.isDirectory())await inventory(resolve(path,entry.name),name+'/');
    else if(entry.isFile())files[name]=createHash('sha256').update(await readFile(resolve(path,entry.name))).digest('hex');
    else throw Error('Bundle must not contain links');
  }
}
await inventory(output);
await writeFile(resolve(output,'bundle-manifest.json'),JSON.stringify({schemaVersion:1,edition:official?'official':'community',interfaceOnly:true,files},null,2)+'\n');
console.log(output);

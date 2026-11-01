// SPDX-License-Identifier: MIT
import { cp,readFile,writeFile,mkdir,rm } from 'node:fs/promises';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { resolve,relative,dirname,sep } from 'node:path';
import { createHash } from 'node:crypto';
import { verifyVisualPack } from '../../scripts/check-visual-pack.mjs';
import { verifyCockpitVisuals } from '../../scripts/check-cockpit-visuals.mjs';
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
await cp(resolve(here,'web/neutral.png'),resolve(output,'neutral.png'));
await cp(resolve(here,'prototype'),resolve(output,'prototype'),{recursive:true});
await cp(resolve(here,'study'),resolve(output,'study'),{recursive:true});
await cp(resolve(repo,'desktop/third-party/vendor-marks'),resolve(output,'vendor-marks'),{recursive:true});
const sheets=['theme','style','rocket','cockpit-r5','engine','mfd','faders','shell6','hull-r3'];
let css=sheets.map(name=>`@import url('./prototype/prototype-${name}.css');`).join('\n')+"\n@import url('./study/rocket-r1/cockpit-r5.css');\n@import url('./study/rocket-r1/engine.css');\n"+await readFile(resolve(here,'web/cockpit.css'),'utf8');
const notices=['MIT: cockpit bridge, schema adapter and community layout.','Vendor identity marks: third-party rights; see vendor-marks/SOURCES.md.'];
{
  // Both cockpit editions use the same verified, licence-noticed visual pack.
  const assets=resolve(repo,'desktop/official-visuals');
  verifyVisualPack(repo);
  const visualManifest=verifyCockpitVisuals(repo);
  await writeFile(resolve(output,'VISUAL-MANIFEST.json'),JSON.stringify(visualManifest,null,2)+'\n');
  // Historical-MIT rocket vector; community keeps the neutral mark.
  await cp(resolve(assets,'logo.svg'),resolve(output,'brand-mark.svg'));
  css+="\n#cockpit .s6-brand-mark{background-image:url('./brand-mark.svg')}#cockpit .s6-brand-mark::before{content:none}\n";
  await cp(resolve(assets,'runtime'),resolve(output,'runtime'),{recursive:true});
  await cp(resolve(assets,'cockpit/study-strip'),resolve(output,'study-strip'),{recursive:true});
  await cp(resolve(assets,'cockpit/SOURCES.md'),resolve(output,'study-strip/SOURCES.md'));
  // Preserve prototype CSS bytes and resolve its original relative URLs with
  // copies drawn exclusively from the verified reserved pack.
  await cp(resolve(assets,'cockpit/shell6.css'),resolve(output,'study/rocket-r1/shell6.css'));
  await mkdir(resolve(output,'study/assets/shell6'),{recursive:true});
  await cp(resolve(assets,'cockpit/study-strip/canopy-2x.png'),resolve(output,'study/assets/shell6/canopy-2x.png'));
  const stripPath=resolve(output,'clients/official-visuals/study/strip-integration');
  await mkdir(stripPath,{recursive:true});
  await cp(resolve(assets,'cockpit/study-strip.css'),resolve(stripPath,'strip.css'));
  await cp(resolve(assets,'cockpit/study-strip'),resolve(stripPath,'study-strip'),{recursive:true});
  css="@import url('./study/rocket-r1/shell6.css');\n"+css;
  css+='\n'+await readFile(resolve(assets,'cockpit/study-strip.css'),'utf8');
  css+='\n'+await readFile(resolve(assets,'cockpit/cockpit.css'),'utf8');
  await cp(resolve(assets,'LICENSE.md'),resolve(output,'VISUAL-LICENSE.md'));
  // Fonts are independently public OFL assets; keep their notices beside them.
  await cp(resolve(repo,'desktop/third-party/fonts'),resolve(output,'fonts'),{recursive:true});
  // The unchanged study CSS uses legacy variable-font URLs. Bind those local
  // URLs to approved OFL static faces; the full weight-specific faces are also
  // registered by fonts.css, and system fonts cover unsupported glyphs.
  await mkdir(resolve(output,'study/assets'),{recursive:true});
  await cp(resolve(output,'fonts/dm-sans/dm-sans-latin-400-normal.woff2'),resolve(output,'study/assets/dm-sans-latin-wght-normal.woff2'));
  await cp(resolve(output,'fonts/dm-sans/dm-sans-latin-400-normal.woff2'),resolve(output,'study/assets/dm-sans-latin-ext-wght-normal.woff2'));
  await cp(resolve(output,'fonts/jetbrains-mono/jetbrains-mono-latin-400-normal.woff2'),resolve(output,'study/assets/jetbrains-mono-latin-wght-normal.woff2'));
  css="@import url('./fonts/fonts.css');\n"+css;
  notices.push('Official appearance/artwork: LicenseRef-ModelPlan-Visuals-1.0; see VISUAL-LICENSE.md.','Fonts: OFL-1.1; see fonts/*/OFL.txt and fonts/README.md.');
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

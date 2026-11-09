// SPDX-License-Identifier: MIT
import { cp,readFile,writeFile,mkdir,rm } from 'node:fs/promises';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { resolve,relative,dirname,sep } from 'node:path';
import { createHash } from 'node:crypto';
import { verifyVisualPack } from '../../scripts/check-visual-pack.mjs';
import { selectBuildEdition } from './internal-visual-boundary.mjs';
const here=fileURLToPath(new URL('.',import.meta.url)),repo=resolve(here,'../..');
// Internal integration is deliberately unavailable until its independently
// reviewed helper, trust anchors and exact resource mapping are integrated.
const official=selectBuildEdition(process.argv.slice(2))==='official';
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
// Renderer code only. Visual resources are managed separately by their owner.
const studyModules=[
  'chart-colours.js','colour-mode.js','empty-bays.js','engine-model.js','engine-view.js','fader-view.js','help-routing.js','i18n.js',
  'mfd-pages/engine-fmt.js','mfd-pages/fmt.js','mfd-pages/frontier.js','mfd-pages/overview.js','mfd-pages/plans.js',
  'mfd-pages/public-helpers.js','mfd-pages/scope.js','mfd-pages/tune.js','mfd-pages/views.js','mfd-pages/where.js',
  'project-attribution.js','short-label.js','strings/common.js','strings/engine.js','strings/faders.js',
  'strings/mfd.js','strings/review49.js','window-time.js',
];
for(const name of studyModules){
  const target=resolve(output,'study/rocket-r1',name);await mkdir(dirname(target),{recursive:true});
  await cp(resolve(here,'study/rocket-r1',name),target);
}
const sheets=['theme','style','rocket','cockpit-r5','engine','mfd','faders','shell6','hull-r3'];
let css=sheets.map(name=>`@import url('./prototype/prototype-${name}.css');`).join('\n')+'\n'+await readFile(resolve(here,'web/cockpit.css'),'utf8');
const notices=['MIT: cockpit bridge, schema adapter and community layout.'];
if (official) {
  // Only this explicit edition reads reserved artwork; the default never does.
  const assets=resolve(repo,'desktop/official-visuals');
  verifyVisualPack(repo);
  await cp(resolve(assets,'runtime'),resolve(output,'runtime'),{recursive:true});
  await cp(resolve(here,'web/field.html'),resolve(output,'field.html'));
  // D43: the field scene draws vendor marks on its plates and asks for them by these names under ./assets/brands/;
  // the engine keys use the same folder (G3-47 review: the key marks pointed at a folder that never shipped).
  const marks=resolve(repo,'desktop/third-party/dock-resources/Resources/Marks'),brands=resolve(output,'assets/brands');await mkdir(brands,{recursive:true});
  for(const [name,source] of Object.entries({'openai-white.svg':'openai.svg','claude-rounded.svg':'claude.svg','zhipu.svg':'zhipu.svg','x-white.svg':'x.svg','qwen.svg':'qwen.svg','deepseek.svg':'deepseek.svg','kimi-white.svg':'kimi.svg','minimax.svg':'minimax.svg','gemini.svg':'gemini.svg','xiaomi.svg':'xiaomi.svg','cursor.svg':'cursor.svg','copilot.svg':'copilot.svg','opencode.svg':'opencode.svg','zai-white.svg':'zai-white.svg','SOURCES.md':'SOURCES.md'}))await cp(resolve(marks,source),resolve(brands,name));
  // The CSP forbids fetch, so the porthole still's placement table ships as a module carrying the
  // default public fleet's four projections (src/porthole-still.ts). Derived from the reserved pack,
  // it carries the pack's licence; the community edition gets null below.
  const pack=JSON.parse(await readFile(resolve(assets,'runtime/porthole-stills/manifest.json'),'utf8'));
  const fleet=pack.projections.find(p=>p.id===pack.defaultProjectionId)?.models.map(m=>m.id).join();
  if(!fleet)throw Error('Porthole default projection missing');
  const layer=l=>l&&{left:l.left,top:l.top,width:l.width,height:l.height,file:l.file};
  // The published display name is what joins a rocket to a published model; roster IDs differ from public IDs.
  const names=new Map(pack.sprites.map(s=>[s.modelId,s.name]));
  const stills={base:'runtime/porthole-stills/',projections:[]};
  for(const theme of ['night','day'])for(const layout of [890,640]){
    const matches=pack.projections.filter(p=>p.theme===theme&&p.layout===layout&&p.models.map(m=>m.id).join()===fleet);
    if(matches.length!==1)throw Error(`Porthole default fleet needs exactly one ${theme} ${layout} projection`);
    const p=matches[0];
    stills.projections.push({id:p.id,theme,layout,width:p.width,height:p.height,background:p.background,
      models:p.models.map(m=>({id:m.id,name:names.get(m.id),nozzle:m.nozzle??{x:m.root.x,y:(m.flame??m.body).top},body:layer(m.body),flame:layer(m.flame),halo:layer(m.halo)}))});
  }
  await writeFile(resolve(output,'src/porthole-stills-data.js'),'// SPDX-License-Identifier: LicenseRef-ModelPlan-Visuals-1.0\nexport default '+JSON.stringify(stills)+';\n');
  css+='\n'+await readFile(resolve(assets,'cockpit/cockpit.css'),'utf8');
  const strip=resolve(assets,'cockpit/strip'),stripCss=await readFile(resolve(strip,'strip.css'));
  if(createHash('sha256').update(stripCss).digest('hex')!=='d160299c2eb59a6e3da2bf08b2d0003ca3b971c425dea1ed790a8d4af1828dee')throw Error('Unapproved cockpit strip stylesheet');
  const stripFiles=['close-hover@3x.png','close-normal@3x.png','close-pressed@3x.png','gear-hover@3x.png','gear-normal@3x.png','gear-pressed@3x.png','lamp-amber-body@3x.png','lamp-amber-glow@3x.png','lamp-amber-pressed-body@3x.png','lamp-amber-pressed-glow@3x.png','lamp-off-body@3x.png','lamp-off-glow@3x.png','lamp-off-pressed-body@3x.png','lamp-off-pressed-glow@3x.png','lamp-red-body@3x.png','lamp-red-glow@3x.png','lamp-red-pressed-body@3x.png','lamp-red-pressed-glow@3x.png','shutter-material@3x.png','slider-track@3x.png','strip-panel@3x.png','thumb-closed@3x.png','thumb-open@3x.png','wordmark@3x.png'];
  const policy=JSON.parse(await readFile(resolve(repo,'source-policy.json'),'utf8'));
  await mkdir(resolve(output,'assets'),{recursive:true});
  for(const name of stripFiles){
    const bytes=await readFile(resolve(strip,'assets',name)),expected=policy.reservedVisuals.binaries['desktop/official-visuals/cockpit/strip/assets/'+name];
    if(!expected||createHash('sha256').update(bytes).digest('hex')!==expected)throw Error('Unapproved cockpit strip resource: '+name);
    await writeFile(resolve(output,'assets',name),bytes);
  }
  await cp(resolve(strip,'SOURCES.md'),resolve(output,'assets/SOURCES.md'));
  css+='\n'+stripCss.toString('utf8');
  // G3-47: the released base-bell rasters (owner 2026-11-08), each checked against the reserved-visuals registry.
  const bells=resolve(assets,'cockpit/bells'),bellFiles=['bell-night-2x.png','bell-night-3x.png','bell-silver-2x.png'];
  await mkdir(resolve(output,'assets/bells'),{recursive:true});
  for(const name of bellFiles){
    const bytes=await readFile(resolve(bells,'assets',name)),expected=policy.reservedVisuals.binaries['desktop/official-visuals/cockpit/bells/assets/'+name];
    if(!expected||createHash('sha256').update(bytes).digest('hex')!==expected)throw Error('Unapproved cockpit bell resource: '+name);
    await writeFile(resolve(output,'assets/bells',name),bytes);
  }
  await cp(resolve(bells,'SOURCES.md'),resolve(output,'assets/bells/SOURCES.md'));
  css+='\n'+await readFile(resolve(bells,'bells.css'),'utf8');
  // D68: the r3 hull's plain plates (owner 2026-11-08), each checked against the reserved-visuals registry.
  const hull=resolve(assets,'cockpit/hull'),hullFiles=[];
  for(const part of ['crown','upper','lower','cone','aft','engine-gutter','console-gutter','record-gutter'])for(const h of [890,640])for(const d of ['1x','2x'])hullFiles.push(`${part}-${h}-${d}.png`);
  hullFiles.push('lower-skin-890-1x.png','lower-skin-890-2x.png'); // side walls: the study's canopy-h1 lower skin
  hullFiles.push('aft-closed-1x.png','aft-closed-2x.png','cap-slab.svg'); // closed shell (D72): aft plate and cap slab
  await mkdir(resolve(output,'assets/hull'),{recursive:true});
  for(const name of hullFiles){
    const bytes=await readFile(resolve(hull,'assets',name)),expected=policy.reservedVisuals.binaries['desktop/official-visuals/cockpit/hull/assets/'+name];
    if(!expected||createHash('sha256').update(bytes).digest('hex')!==expected)throw Error('Unapproved cockpit hull resource: '+name);
    await writeFile(resolve(output,'assets/hull',name),bytes);
  }
  await cp(resolve(hull,'SOURCES.md'),resolve(output,'assets/hull/SOURCES.md'));
  css+='\n'+await readFile(resolve(hull,'hull.css'),'utf8');
  await cp(resolve(assets,'LICENSE.md'),resolve(output,'VISUAL-LICENSE.md'));
  // Fonts are independently public OFL assets; keep their notices beside them.
  await cp(resolve(repo,'desktop/third-party/fonts'),resolve(output,'fonts'),{recursive:true});
  css="@import url('./fonts/fonts.css');\n"+css;
  notices.push('Official appearance/artwork: LicenseRef-ModelPlan-Visuals-1.0; see VISUAL-LICENSE.md.','Fonts: OFL-1.1; see fonts/*/OFL.txt and fonts/README.md.','Vendor marks: third-party trademarks, not under our licences; see assets/brands/SOURCES.md.');
} else {
  notices.push('Community edition excludes reserved artwork.');
  // The launch field is official only; its page has no place in this edition.
  await rm(resolve(output,'src/field-page.js'),{force:true});
  await writeFile(resolve(output,'src/porthole-stills-data.js'),'// SPDX-License-Identifier: MIT\nexport default null;\n');
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

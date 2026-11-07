// SPDX-License-Identifier: MIT
import test from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { readFileSync,existsSync,rmSync,mkdirSync,writeFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { verifyRuntimeGraph } from '../runtime-graph.mjs';
const project=fileURLToPath(new URL('../../../cockpit/',import.meta.url));
const digest=bytes=>createHash('sha256').update(bytes).digest('hex');
test('both editions have reproducible bounded manifests; community excludes reserved assets',()=>{
  for(const edition of ['community','official']) {
    // A reused compilation directory must not ship a deleted source.
    mkdirSync(project+'.tmp/compiled/src',{recursive:true});
    for(const suffix of ['js','d.ts'])writeFileSync(project+'.tmp/compiled/src/removed-module.'+suffix,'export const retired = true;\n');
    rmSync(project+'.tmp/'+edition,{recursive:true,force:true});
    execFileSync(process.execPath,[project+'build.mjs',...(edition==='official'?['--official']:[])],{stdio:'pipe'});
    const root=project+'.tmp/'+edition+'/',manifest=JSON.parse(readFileSync(root+'bundle-manifest.json'));
    assert.equal(manifest.edition,edition);assert.equal(manifest.interfaceOnly,true);
    if(edition==='community')verifyRuntimeGraph(root,manifest);
    for(const suffix of ['js','d.ts'])assert.equal(existsSync(root+'src/removed-module.'+suffix),false,'stale compiled files must not ship');
    assert.ok(!Object.keys(manifest.files).some(name=>name.includes('session-state')));
    assert.doesNotMatch(readFileSync(root+'cockpit.css','utf8'),/--session-|session-transition-flash|[.]session-state/);
    for(const [name,hash]of Object.entries(manifest.files))assert.equal(digest(readFileSync(root+name)),hash,name);
    for(const name of Object.keys(manifest.files).filter(name=>name.endsWith('.css'))){
      const css=readFileSync(root+name,'utf8');
      const cursor='#cockpit[data-active="true"][data-shell="open"] .ck-tape .t-cur{animation:cockpit-running-cursor 1.06s steps(1,end) infinite!important}';
      // Owner D39/D-H: the porthole flicker is the one other infinite animation, gated like the cursor and on Reduce Motion.
      const flicker='@media (prefers-reduced-motion:no-preference){\nhtml:not([data-reduce-motion="true"]) #cockpit[data-active="true"][data-shell="open"] .ck-still .ck-flicker{animation:cockpit-porthole-flicker .43s ease-in-out 0s infinite alternate!important}';
      if(name==='cockpit.css'){assert.equal(css.split(cursor).length-1,1,'one scoped running-cursor animation');assert.equal(css.split(flicker).length-1,1,'one gated porthole flicker');}
      assert.doesNotMatch(css.replace(cursor,'').replace(flicker,''),/\binfinite\b/i,name);
    }
    const html=readFileSync(root+'index.html','utf8');
    for(const rule of ["connect-src 'none'","frame-src 'none'","object-src 'none'","base-uri 'none'","form-action 'none'"])assert.ok(html.includes(rule));
    const script=readFileSync(root+'src/main.js','utf8')+readFileSync(root+'src/view.js','utf8');
    assert.doesNotMatch(script,/\b(?:setTimeout|setInterval|requestAnimationFrame)\s*\(/);
    // Owner D39/D-A: the reserved launch-field scene is the one runtime script; it schedules its own (on-demand,
    // 30 fps capped) frames and is loaded only when the enlarged view opens, never by the page's module graph.
    const scene='runtime/field-scene/cockpit-scene.bundle.js';
    assert.equal(Object.hasOwn(manifest.files,scene),edition==='official',scene);
    // Only the field's own page names the scene, and it imports it dynamically (glm-618-2: the ban covers every other file).
    for(const name of Object.keys(manifest.files).filter(name=>/\.(?:js|html|css)$/.test(name)&&name!==scene&&name!=='src/field-page.js'&&!name.startsWith('runtime/')))assert.doesNotMatch(readFileSync(root+name,'utf8'),/field-scene|cockpit-scene/,name);
    assert.equal(Object.hasOwn(manifest.files,'field.html'),edition==='official','field.html');
    if(edition==='official')assert.match(readFileSync(root+'src/field-page.js','utf8'),/await import\(url\)/);
    else assert.equal(Object.hasOwn(manifest.files,'src/field-page.js'),false);
    for(const name of Object.keys(manifest.files).filter(name=>name.endsWith('.js')&&name!==scene))assert.doesNotMatch(readFileSync(root+name,'utf8'),/\b(?:setTimeout|setInterval|requestAnimationFrame)\s*\(/,name);
    if(edition==='official'){assert.ok(Object.hasOwn(manifest.files,'assets/brands/SOURCES.md'));assert.match(readFileSync(root+'NOTICES.txt','utf8'),/Vendor marks: third-party trademarks.*assets\/brands\/SOURCES[.]md/);}
    else assert.equal(existsSync(root+'assets/brands'),false,'community has no vendor marks');
    const provenance=JSON.parse(readFileSync(root+'prototype/source.json'));
    assert.equal(provenance.sourceCommit,'1d3f82429f1b853314ee120d4bd0007f84fc051d');
    assert.equal(provenance.fixtureAudit.copied,false);
    for(const name of Object.keys(manifest.files)){
      assert.doesNotMatch(name,/workbench-data|three[.]/i);
      const brands=['openai-white','claude-rounded','zhipu','x-white','qwen','deepseek','kimi-white','minimax','gemini','xiaomi'].map(mark=>`assets/brands/${mark}.svg`);
      if(name.endsWith('.svg'))assert.ok(edition==='official'&&['assets/detach.svg','assets/put-back.svg',...brands].includes(name),`unapproved SVG: ${name}`);
      // Published U12 PNGs may join the verified pack; no runtime scene code.
      if(name.startsWith('runtime/')&&name!==scene)assert.match(name,/(?:\.(png|json|md|txt)|\/SHA256SUMS)$/i);
    }
    execFileSync(process.execPath,[project+'build.mjs',...(edition==='official'?['--official']:[])],{stdio:'pipe'});
    assert.deepEqual(JSON.parse(readFileSync(root+'bundle-manifest.json')),manifest);
    // Porthole still placement: null without the reserved pack; the official edition carries exactly the
    // default fleet's night/day x 890/640 projections, and every layer they name is a bundled file.
    const stills=readFileSync(root+'src/porthole-stills-data.js','utf8');
    if(edition==='community')assert.equal(stills,'// SPDX-License-Identifier: MIT\nexport default null;\n');
    else{
      assert.match(stills,/^\/\/ SPDX-License-Identifier: LicenseRef-ModelPlan-Visuals-1\.0\n/);
      const pack=JSON.parse(stills.split('\n')[1].replace(/^export default /,'').replace(/;$/,''));
      assert.deepEqual(pack.projections.map(p=>`${p.theme}-${p.layout}-${p.id}`),['night-890-4ff2bad27654','night-640-a92b7ce62cfe','day-890-52b72f54aee9','day-640-28592ba812cd']);
      for(const p of pack.projections){
        assert.deepEqual(p.models.map(m=>m.id),['sol','glm','opus','luna','sonnet','astra','haiku']);
        for(const file of [p.background,...p.models.flatMap(m=>[m.body,m.flame,m.halo].filter(Boolean).map(l=>l.file))])
          assert.ok(Object.hasOwn(manifest.files,pack.base+file),file);
      }
    }
    if(edition==='community') {
      assert.equal(existsSync(root+'runtime'),false);assert.equal(existsSync(root+'VISUAL-LICENSE.md'),false);
      assert.equal(existsSync(root+'fonts'),false);
    }else{
      assert.match(readFileSync(root+'VISUAL-LICENSE.md','utf8'),/ModelPlan Official Visuals/);
      assert.equal(existsSync(root+'fonts/manrope/OFL.txt'),true);
      assert.equal(existsSync(root+'prototype/prototype-cockpit-r5.css'),true);
      for(const name of Object.keys(manifest.files).filter(name=>name.startsWith('prototype/')&&name.endsWith('.css')))assert.doesNotMatch(readFileSync(root+name,'utf8'),/url\s*\(|@import|data:image/i);
    }
  }
});

test('ported prototype keeps the full and compact layout calculation',async()=>{
  const {cockpitLayout}=await import('../../../cockpit/.tmp/compiled/src/prototype-layout.js');
  assert.deepEqual(cockpitLayout(890),{h:890,console:257,tapeLines:5,tapeH:94,eng:226});
  assert.deepEqual(cockpitLayout(640),{h:640,console:217,tapeLines:3,tapeH:58,eng:220});
});

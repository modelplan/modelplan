// SPDX-License-Identifier: MIT
import test from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { readFileSync,existsSync,rmSync,mkdirSync,writeFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { verifyRuntimeGraph } from '../runtime-graph.mjs';
const project=fileURLToPath(new URL('../../../cockpit/',import.meta.url));
// build.mjs compiles into a private directory: the shared .tmp/compiled is imported by parallel unit tests.
const buildEnv={...process.env,MODELPLAN_COCKPIT_COMPILED:project+'.tmp/bundle-compiled'};
const digest=bytes=>createHash('sha256').update(bytes).digest('hex');
test('both editions have reproducible bounded manifests; community excludes reserved assets',()=>{
  for(const edition of ['community','official']) {
    // A reused compilation directory must not ship a deleted source.
    mkdirSync(project+'.tmp/bundle-compiled/src',{recursive:true});
    for(const suffix of ['js','d.ts'])writeFileSync(project+'.tmp/bundle-compiled/src/removed-module.'+suffix,'export const retired = true;\n');
    rmSync(project+'.tmp/'+edition,{recursive:true,force:true});
    execFileSync(process.execPath,[project+'build.mjs',...(edition==='official'?['--official']:[])],{stdio:'pipe',env:buildEnv});
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
      // V1-FINAL §16 / MOT-2.3-05: the porthole flames step through five levels per sweep instead of easing every frame.
      const flicker='@media (prefers-reduced-motion:no-preference){\nhtml:not([data-reduce-motion="true"]) #cockpit[data-active="true"][data-shell="open"] .ck-still .ck-flicker{animation:cockpit-porthole-flicker .43s steps(5,jump-none) 0s infinite alternate!important}';
      // CKP-ENG-19 / MOT-2.3-05 (D294): the working light's slow breathing and the landing burn's flutter, gated the same way.
      const sel='html:not([data-reduce-motion="true"]) #cockpit[data-active="true"][data-shell="open"] .ck-base .bz.work .bz-sheet';
      const breathe='@media (prefers-reduced-motion:no-preference){\n'+sel+'::before,'+sel+'::after{animation:cockpit-light-breathe 2.6s ease-in-out var(--fo,0s) infinite alternate!important}\n}';
      const burn='@media (prefers-reduced-motion:no-preference){\nhtml:not([data-reduce-motion="true"]) #cockpit[data-active="true"][data-shell="open"][data-ignite="true"] .ck-base :is(.bz,.bz-empty)::after{animation:cockpit-bell-flare .22s cubic-bezier(.2,.8,.3,1) both,cockpit-bell-burn .36s steps(3,end) .22s infinite}\n}';
      // D454/D459: the official bells' blue thrust flipbook (frames 1-2-3-2) while the cockpit burns full thrust, gated the same way; bells.css rides inside the official cockpit.css.
      const flip='@media (prefers-reduced-motion:no-preference){\nhtml:not([data-reduce-motion="true"]) #cockpit[data-active="true"][data-shell="open"][data-thrust="full"] .ck-base .bz-flame{animation:cockpit-flame-flip .44s steps(1,end) var(--fo,0s) infinite}\n}';
      if(name==='cockpit.css'){assert.equal(css.split(cursor).length-1,1,'one scoped running-cursor animation');assert.equal(css.split(flicker).length-1,1,'one gated porthole flicker');assert.equal(css.split(breathe).length-1,1,'one gated working-light breathing');assert.equal(css.split(burn).length-1,1,'one gated landing-burn flutter');}
      assert.doesNotMatch(css.replace(cursor,'').replace(flicker,'').replace(breathe,'').replace(burn,'').replace(flip,''),/\binfinite\b/i,name);
    }
    const html=readFileSync(root+'index.html','utf8');
    for(const rule of ["connect-src 'none'","frame-src 'none'","object-src 'none'","base-uri 'none'","form-action 'none'"])assert.ok(html.includes(rule));
    const script=readFileSync(root+'src/main.js','utf8')+readFileSync(root+'src/view.js','utf8');
    assert.doesNotMatch(script,/\b(?:setTimeout|setInterval|requestAnimationFrame)\s*\(/);
    // WP-22 (D298, was D39/D-A): the reserved launch-field component is the one runtime script; it schedules its own
    // frames and is loaded only when the enlarged view opens, never by the page's module graph.
    const scene='runtime/field-scene/launch-field.js';
    assert.equal(Object.hasOwn(manifest.files,scene),edition==='official',scene);
    assert.equal(Object.hasOwn(manifest.files,'runtime/field-scene/cockpit-scene.bundle.js'),false,'the D39 scene is gone');
    // Only the field's own page (script and stylesheet link) names the component, and the script imports it dynamically
    // (glm-618-2: the ban covers every other file).
    for(const name of Object.keys(manifest.files).filter(name=>/\.(?:js|html|css)$/.test(name)&&name!==scene&&name!=='src/field-page.js'&&name!=='field.html'&&!name.startsWith('runtime/')))assert.doesNotMatch(readFileSync(root+name,"utf8"),/field-scene|cockpit-scene/,name);
    assert.equal(Object.hasOwn(manifest.files,'field.html'),edition==='official','field.html');
    if(edition==='official'){
      assert.match(readFileSync(root+'src/field-page.js','utf8'),/await import\(url\)/);
      assert.match(readFileSync(root+'src/field-page.js','utf8'),/dim:false/,'native paints the dim (D298)');
      assert.match(readFileSync(root+'field.html','utf8'),/href="runtime\/field-scene\/launch-field\.css"/);
    }
    else for(const gone of ['src/field-page.js','src/field-shape.js'])assert.equal(Object.hasOwn(manifest.files,gone),false);
    for(const name of Object.keys(manifest.files).filter(name=>name.endsWith('.js')&&name!==scene))assert.doesNotMatch(readFileSync(root+name,'utf8'),/\b(?:setTimeout|setInterval|requestAnimationFrame)\s*\(/,name);
    if(edition==='official'){assert.ok(Object.hasOwn(manifest.files,'assets/brands/SOURCES.md'));assert.match(readFileSync(root+'NOTICES.txt','utf8'),/Vendor marks: third-party trademarks.*assets\/brands\/SOURCES[.]md/);}
    else assert.equal(existsSync(root+'assets/brands'),false,'community has no vendor marks');
    // D207: the scene flies the website's fleet r4 rockets; their atlases ship once, beside the vendor marks under the
    // scene's base URL (./assets/), byte-equal to the reserved registry, and the community edition has none.
    const atlases=Object.keys(manifest.files).filter(name=>name.startsWith('assets/art/rockets/'));
    if(edition==='official'){
      const policy=JSON.parse(readFileSync(project+'../../source-policy.json','utf8')).reservedVisuals.binaries;
      const vehicles=['falcon9','falcon-heavy','new-glenn','vulcan','long-march-2f','long-march-5','long-march-3b','starship'];
      const sprites=atlases.filter(name=>name.startsWith('assets/art/rockets/flat/'));
      assert.deepEqual(atlases.filter(name=>!sprites.includes(name)).sort(),vehicles.flatMap(v=>['512','256','mat'].map(p=>`assets/art/rockets/${v}-${p}.webp`)).sort());
      assert.equal(sprites.length,114,'WP-22: the 2D fallback sprites ship with the official edition');
      for(const name of atlases)assert.equal(manifest.files[name],policy['desktop/official-visuals/runtime/field-scene/rockets/'+name.slice(19)],name);
      assert.ok(!Object.keys(manifest.files).some(name=>name.startsWith('runtime/field-scene/rockets/')),'atlases ship once');
      const code=readFileSync(root+scene,'utf8');assert.match(code,/art\/rockets\//);assert.match(code,/art\/rockets\/flat\//);
      // Offline only: the component names no network host but the three.js shader citation and the SVG/XHTML namespaces.
      assert.deepEqual([...new Set(code.match(/https?:\/\/[a-z0-9.-]+/gi))].sort(),['http://www.w3.org','https://jcgt.org']);
    } else assert.deepEqual(atlases,[]);
    const provenance=JSON.parse(readFileSync(root+'prototype/source.json'));
    assert.equal(provenance.sourceCommit,'1d3f82429f1b853314ee120d4bd0007f84fc051d');
    assert.equal(provenance.fixtureAudit.copied,false);
    for(const name of Object.keys(manifest.files)){
      assert.doesNotMatch(name,/workbench-data|three[.]/i);
      const brands=['openai-white','claude-rounded','claude','cursor','copilot','opencode','zai-white','zhipu','x-white','qwen','alibaba','deepseek','kimi-white','minimax','gemini','xiaomi'].map(mark=>`assets/brands/${mark}.svg`);
      if(name.endsWith('.svg'))assert.ok(edition==='official'&&['assets/detach.svg','assets/put-back.svg','assets/hull/cap-slab.svg','assets/logo.svg',...brands].includes(name),`unapproved SVG: ${name}`);
      // Published U12 PNGs may join the verified pack; no runtime scene code but the component's script and its stylesheet.
      if(name.startsWith('runtime/')&&name!==scene&&name!=='runtime/field-scene/launch-field.css')assert.match(name,/(?:\.(png|json|md|txt)|\/SHA256SUMS)$/i);
      if(name.endsWith('.webp'))assert.ok(edition==='official'&&name.startsWith('assets/art/rockets/'),`unapproved WebP: ${name}`);
    }
    execFileSync(process.execPath,[project+'build.mjs',...(edition==='official'?['--official']:[])],{stdio:'pipe',env:buildEnv});
    assert.deepEqual(JSON.parse(readFileSync(root+'bundle-manifest.json')),manifest);
    // Porthole still placement: null without the reserved pack; the official edition carries exactly the
    // default fleet's night/day projections at 890 (D444: one layout), and every layer they name is a bundled file.
    const stills=readFileSync(root+'src/porthole-stills-data.js','utf8');
    if(edition==='community')assert.equal(stills,'// SPDX-License-Identifier: MIT\nexport default null;\n');
    else{
      assert.match(stills,/^\/\/ SPDX-License-Identifier: LicenseRef-ModelPlan-Visuals-1\.0\n/);
      const pack=JSON.parse(stills.split('\n')[1].replace(/^export default /,'').replace(/;$/,''));
      assert.deepEqual(pack.projections.map(p=>`${p.theme}-${p.layout}-${p.id}`),['night-890-4ff2bad27654','day-890-52b72f54aee9']);
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

test('ported prototype keeps the full layout calculation (D444: the only layout)',async()=>{
  const {cockpitLayout}=await import('../../../cockpit/.tmp/compiled/src/prototype-layout.js');
  assert.deepEqual(cockpitLayout(890),{h:890,console:257,tapeLines:5,tapeH:94,eng:226});
});

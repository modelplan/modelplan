// SPDX-License-Identifier: MIT
import test from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { readFileSync,existsSync,rmSync,mkdirSync,writeFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { fileURLToPath } from 'node:url';
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
    for(const suffix of ['js','d.ts'])assert.equal(existsSync(root+'src/removed-module.'+suffix),false,'stale compiled files must not ship');
    assert.ok(!Object.keys(manifest.files).some(name=>name.includes('session-state')));
    assert.doesNotMatch(readFileSync(root+'cockpit.css','utf8'),/--session-|session-transition-flash|[.]session-state/);
    for(const [name,hash]of Object.entries(manifest.files))assert.equal(digest(readFileSync(root+name)),hash,name);
    for(const name of Object.keys(manifest.files).filter(name=>name.endsWith('.css')))assert.doesNotMatch(readFileSync(root+name,'utf8'),/\binfinite\b/i,name);
    const html=readFileSync(root+'index.html','utf8');
    for(const rule of ["connect-src 'none'","frame-src 'none'","object-src 'none'","base-uri 'none'","form-action 'none'"])assert.ok(html.includes(rule));
    const script=readFileSync(root+'src/main.js','utf8')+readFileSync(root+'src/view.js','utf8');
    assert.doesNotMatch(script,/\b(?:setTimeout|setInterval|requestAnimationFrame)\s*\(/);
    for(const name of Object.keys(manifest.files).filter(name=>name.endsWith('.js')))assert.doesNotMatch(readFileSync(root+name,'utf8'),/\b(?:setTimeout|setInterval|requestAnimationFrame)\s*\(/,name);
    const provenance=JSON.parse(readFileSync(root+'prototype/source.json'));
    assert.equal(provenance.sourceCommit,'1d3f82429f1b853314ee120d4bd0007f84fc051d');
    assert.equal(provenance.fixtureAudit.copied,false);
    for(const name of Object.keys(manifest.files)){
      assert.doesNotMatch(name,/workbench-data|three[.]|\.svg$/i);
      // Published U12 PNGs may join the verified pack; no runtime scene code.
      if(name.startsWith('runtime/'))assert.match(name,/(?:\.(png|json|md|txt)|\/SHA256SUMS)$/i);
    }
    execFileSync(process.execPath,[project+'build.mjs',...(edition==='official'?['--official']:[])],{stdio:'pipe'});
    assert.deepEqual(JSON.parse(readFileSync(root+'bundle-manifest.json')),manifest);
    if(edition==='community') {
      assert.equal(existsSync(root+'runtime'),false);assert.equal(existsSync(root+'VISUAL-LICENSE.md'),false);
      assert.equal(existsSync(root+'fonts'),false);
    }else{
      assert.match(readFileSync(root+'VISUAL-LICENSE.md','utf8'),/ModelPlan Official Visuals/);
      assert.equal(existsSync(root+'fonts/manrope/OFL.txt'),true);
      assert.equal(existsSync(root+'prototype/prototype-cockpit-r5.css'),true);
      for(const name of Object.keys(manifest.files))assert.ok(!name.endsWith('.svg'));
      for(const name of Object.keys(manifest.files).filter(name=>name.startsWith('prototype/')&&name.endsWith('.css')))assert.doesNotMatch(readFileSync(root+name,'utf8'),/url\s*\(|@import|data:image/i);
    }
  }
});

test('ported prototype keeps the full and compact layout calculation',async()=>{
  const {cockpitLayout}=await import('../../../cockpit/.tmp/compiled/src/prototype-layout.js');
  assert.deepEqual(cockpitLayout(890),{h:890,console:257,tapeLines:5,tapeH:94,eng:226});
  assert.deepEqual(cockpitLayout(640),{h:640,console:217,tapeLines:3,tapeH:58,eng:220});
});

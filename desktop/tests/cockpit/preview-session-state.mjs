// SPDX-License-Identifier: MIT
// Owner preview only. Uses the official bundle and synthetic Go display capture.
import {readFile,writeFile,mkdir,copyFile} from 'node:fs/promises';
import {resolve,dirname,extname} from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {spawn,execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {setTimeout as sleep} from 'node:timers/promises';
import {webkit} from '../../cockpit/node_modules/playwright-core/index.mjs';
import {commands,appearance,pageId,sample} from './fixture.mjs';
const repo=resolve(dirname(fileURLToPath(import.meta.url)),'../../..');
const bundle=resolve(repo,'desktop/cockpit/.tmp/official');
const output=resolve(process.argv[2]??resolve(repo,'.tmp/session-state-preview'));
await mkdir(output,{recursive:true});
// Expand only assets already in the verified official bundle, keeping HTML offline.
async function inlineCSS(file){
 let css=await readFile(file,'utf8');
 for(const m of [...css.matchAll(/@import\s+url\(['"]?([^'"\)]+)['"]?\);/g)])css=css.replace(m[0],await inlineCSS(resolve(dirname(file),m[1])));
 for(const m of [...css.matchAll(/url\(['"]?([^'"\)]+)['"]?\)/g)]){
  if(m[1].startsWith('data:'))continue;
  const path=resolve(dirname(file),m[1]);if(!path.startsWith(bundle+'/'))throw Error('Preview resource outside bundle');
  const mime={'.png':'image/png','.woff2':'font/woff2'}[extname(path)];if(!mime)throw Error('Unreviewed preview resource');
  css=css.replace(m[0],`url('data:${mime};base64,${(await readFile(path)).toString('base64')}')`);
 }
 return css;
}
const css=(await inlineCSS(resolve(bundle,'cockpit.css'))).split('\n').filter(line=>!line.includes('data-session-palette=darker')).join('\n');
const component=(await readFile(resolve(bundle,'src/session-state.js'),'utf8')).replace(/^export /gm,'');
let server,browser;
try{
 server=spawn(process.execPath,[resolve(repo,'desktop/tests/cockpit/serve.mjs')],{cwd:repo,stdio:'ignore'});
 await sleep(200);if(server.exitCode!==null)throw Error('Owned preview server did not start');
 browser=await webkit.launch({headless:true});
 const source=await browser.newPage();await source.goto('http://127.0.0.1:41783/?pageId='+pageId);
 const send=commands(),data=sample();
 [75,45,12].forEach((pct,i)=>data.projection.rows[i].accounts[0].windows[0].remainingPercent=pct);
 for(const raw of [send('load',{appearance}),send('visibility',{visible:true,occluded:false,key:true}),send('display',{data})]){
  if(!await source.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw))throw Error('Synthetic display rejected');
 }
 const cockpit=await source.evaluate(()=>{
  const root=document.getElementById('cockpit').cloneNode(true);
  root.querySelectorAll('.state-pulse,.is-flashing').forEach(e=>e.classList.remove('state-pulse','is-flashing'));
  root.querySelector('.ck-tape').innerHTML='<!--SESSION_ROWS-->';return root.outerHTML;
 });
 await source.close();
 const esc=value=>String(value).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
 // Newly authored synthetic text. Borrow only the released P6 record-strip
 // hierarchy (.ck-tape > .t-lines > .tl) and five native 16px row slots.
 const sessions=[
  ['Codex','sample-ui','Polish empty state','now','working'],
  ['Claude Code','sample-api','Review retry budget','6m ago','idle'],
  ['OpenCode','sample-cli','Add parser checks','12m ago','done'],
  ['Gemini CLI','sample-docs','Check broken links','18m ago','error'],
  ['Codex','sample-notes','Outline next steps','1h ago','idle'],
 ];
 const row=(values,indicator)=>{
  const [tool,project,title,age,state]=values;
  return `<div class="tl preview-session-row"><span class="t-tool">${esc(tool)}</span><span class="t-proj">${esc(project)}</span><span class="t-title">${esc(title)}</span><span class="t-time">${esc(age)}</span>${indicator??`<span class="session-state" data-state="${state}" role="img" aria-label="Session state: ${state}"></span>`}</div>`;
 };
 const layout=`
 body{margin:0;background:#dce1e7;color:#17212d;font-family:'DM Sans',sans-serif}
 .owner-sheet{padding:24px;width:1308px;margin:auto}.owner-title{margin:0 0 8px;font-size:26px;letter-spacing:-.6px;font-weight:600}.owner-subtitle{font-size:13px;color:#536171;line-height:1.6;margin-bottom:20px}
 .preview-board{display:grid;grid-template-columns:620px 620px;gap:20px}.preview-panel h2{font-size:16px;margin:0 0 8px}.preview-panel p{font-size:12px;margin:0 0 10px;color:#536171}iframe{border:0;border-radius:8px;display:block}
 .crop{position:relative;width:620px;height:400px;overflow:hidden;background:var(--metal-3)}
 .crop #cockpit.ck{position:absolute!important;bottom:0!important;top:auto!important;height:890px;max-height:none!important;margin:0!important}
 .ck-tape{display:block!important;padding:6px 10px!important;overflow:hidden!important}
 .t-lines{display:grid;grid-template-rows:repeat(5,16px)}
 .preview-session-row{display:grid;grid-template-columns:90px 94px minmax(0,1fr) 48px 12px;column-gap:8px;align-items:center;width:100%;height:16px;font:11px/16px var(--f-lcd);color:var(--lcd-ink)}
 .preview-session-row .t-proj{color:var(--lcd-muted)}.preview-session-row .t-title{color:var(--lcd-ink)}.preview-session-row .t-time{padding:0;color:var(--lcd-muted);font-size:10px;text-align:right}.preview-session-row .session-state{justify-self:end;overflow:visible}
 .flash-strip{padding:24px;width:1308px;background:#dce1e7;color:#17212d}.flash-strip h2{font-size:18px;margin:0 0 8px}.flash-strip>p{font-size:12px;color:#536171;margin:0 0 18px}
 .strip{--f-lcd:'JetBrains Mono',ui-monospace,monospace;--bezel:0 1px 0 var(--bz-lip-b),0 0 0 1px var(--bz-lip),var(--bz-in);padding:16px 22px;width:620px;background:linear-gradient(var(--metal-1),var(--metal-3));color:var(--lcd-ink)}.frame{margin:0 0 16px}.frame h3{font:10px var(--f-lcd);color:var(--silk);margin:0 0 6px}.frame .ck-tape{position:relative;min-height:34px;height:34px;border:2px solid var(--bz-ring);border-radius:6px;background:var(--lcd-glass);box-shadow:var(--bezel)}.frame .ck-tape::before{display:none}
 `;
 const bootstrap=`${component}\nwindow.previewFixture={mountSessionState,SessionStateTracker};`;
 const inner=(theme,body)=>`<!doctype html><html lang="en" data-theme="${theme}"><head><meta charset="utf-8"><meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; font-src data:; img-src data:; connect-src 'none'; frame-src 'none'; object-src 'none'; base-uri 'none'"><style>${css}\n${layout}</style></head><body>${body}</body></html>`;
 const iframe=(theme,body,height)=>`<iframe title="${theme} session area" width="620" height="${height}" srcdoc="${esc(inner(theme,body))}"></iframe>`;
 const list='<div class="t-lines">'+sessions.map(value=>row(value)).join('')+'</div>';
 const panel=theme=>`<section class="preview-panel"><h2>${theme==='night'?'Night':'Day'}</h2><p>Working / done ${theme==='night'?'#7fb2ff':'#2f6bd8'} · square at the row’s right edge</p>${iframe(theme,`<div class="crop">${cockpit.replace('<!--SESSION_ROWS-->',list)}</div>`,400)}</section>`;
 const pageHTML=strip=>`<!doctype html><html lang="en" data-theme="night"><head><meta charset="utf-8"><meta name="viewport" content="width=1308"><meta http-equiv="Content-Security-Policy" content="default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; font-src data:; img-src data:; connect-src 'none'; frame-src 'self'; object-src 'none'; base-uri 'none'"><title>Session rows · owner preview</title><style>${css}\n${layout}</style></head><body><main class="owner-sheet" id="owner-sheet"><h1 class="owner-title">A square at the end of each session row</h1><p class="owner-subtitle">Approved P6 bottom record-strip layout · five synthetic sessions · 12 px squares in native 16 px rows.<br>#355 currently shows observation timestamps here. This session list is a study-layout preview, not a shipped session feed.</p><div class="preview-board">${panel('night')}${panel('day')}</div></main>${strip??''}<script>${bootstrap}</script></body></html>`;
 await writeFile(resolve(output,'index.html'),pageHTML());
 const context=await browser.newContext({viewport:{width:1308,height:1100},deviceScaleFactor:1});
 const page=await context.newPage();await page.goto(pathToFileURL(resolve(output,'index.html')).href);await page.evaluate(()=>document.fonts.ready);
 // Capture actual CSS animation samples, then freeze their values into a strip.
 const frames=[];
 for(const [i,time]of [null,0,80,120,160].entries()){
  const sample=await page.evaluate(({i,time})=>{
   const fixture=window.previewFixture;
   if(i===0){const e=document.createElement('span');e.id='capture-state';document.body.append(e);window.captureModel=new fixture.SessionStateTracker();window.captureIndicator=fixture.mountSessionState(e,window.captureModel,'flash-example','idle',()=>100);}
   if(i===1){window.captureIndicator.update('working');window.captureAnimation=document.getElementById('capture-state').getAnimations()[0];window.captureAnimation.pause();}
   if(time!==null)window.captureAnimation.currentTime=time;
   if(i===3)window.captureIndicator.update('done');
   if(i===4)window.captureAnimation.cancel();
   const root=document.getElementById('capture-state'),opacity=getComputedStyle(root).opacity,clone=root.cloneNode(true);
   clone.removeAttribute('id');clone.classList.remove('is-flashing');clone.style.opacity=opacity;
   return {html:clone.outerHTML,opacity,state:root.dataset.state};
  },{i,time});
  frames.push(`<article class="frame"><h3>${['Before · idle','Working · 0 ms · first opacity step','Working · 80 ms · second opacity step','Done · 120 ms · same coalesced flash','Done · 160 ms · static, no loop'][i]}</h3><section class="ck-tape">${row(['Codex','sample-ui','Polish empty state','now',sample.state],sample.html)}</section></article>`);
 }
 const strip=`<section class="flash-strip" id="flash-strip"><h2>One session · idle → working → done</h2><p>Only the row’s square flashes. Rapid completion shares one 160 ms, two-step flash; row text stays static.</p><div class="preview-board">${['night','day'].map(theme=>iframe(theme,`<div class="strip">${frames.join('')}</div>`,400)).join('')}</div></section>`;
 await writeFile(resolve(output,'index.html'),pageHTML(strip));await context.close();
 for(const scale of [1,4]){
  const context=await browser.newContext({viewport:{width:1308,height:1400},deviceScaleFactor:scale});const page=await context.newPage();
  await page.goto(pathToFileURL(resolve(output,'index.html')).href);for(const frame of page.frames())await frame.evaluate(()=>document.fonts.ready);
  for(const frame of page.frames().slice(1))await frame.evaluate(()=>{
   if(document.getAnimations().length)throw Error('Static row preview must not animate');
   const theme=document.documentElement.dataset.theme;
   const palette=theme==='night'?{idle:'rgb(133, 141, 153)',working:'rgb(127, 178, 255)',done:'rgb(127, 178, 255)',error:'rgb(239, 68, 68)'}:{idle:'rgb(93, 99, 107)',working:'rgb(47, 107, 216)',done:'rgb(47, 107, 216)',error:'rgb(196, 43, 43)'};
   const rows=[...document.querySelectorAll('.preview-session-row')];if(rows.length!==5)throw Error('Expected five native session rows');
   for(const row of rows){
    const square=row.lastElementChild,style=getComputedStyle(square),tool=row.querySelector('.t-tool');
    if(!square.classList.contains('session-state')||style.width!=='12px'||style.height!=='12px'||style.color!==palette[square.dataset.state])throw Error('Incorrect final square or palette');
    if(getComputedStyle(row).fontSize!=='11px'||getComputedStyle(row).lineHeight!=='16px'||tool.scrollWidth>tool.clientWidth)throw Error('Native study typography or tool label changed');
    if(Math.abs(row.getBoundingClientRect().right-square.getBoundingClientRect().right)>.5)throw Error('Square must end the row');
   }
  });
  await page.locator('#owner-sheet').screenshot({path:resolve(output,scale===1?'session-states-native.png':'session-states-4x.png')});
  await page.locator('#flash-strip').screenshot({path:resolve(output,scale===1?'transition-flash-native.png':'transition-flash-4x.png')});await context.close();
 }
 await copyFile(resolve(bundle,'VISUAL-LICENSE.md'),resolve(output,'VISUAL-LICENSE.md'));
 for(const family of ['dm-sans','share-tech-mono','manrope','jetbrains-mono'])await copyFile(resolve(bundle,'fonts',family,'OFL.txt'),resolve(output,`OFL-${family}.txt`));
 await copyFile(resolve(bundle,'fonts/README.md'),resolve(output,'FONTS-README.md'));
 await copyFile(resolve(bundle,'LICENSE.txt'),resolve(output,'MIT-LICENSE.txt'));
 await copyFile(resolve(bundle,'NOTICES.txt'),resolve(output,'NOTICES.txt'));
 const hashes={};for(const name of ['index.html','session-states-native.png','session-states-4x.png','transition-flash-native.png','transition-flash-4x.png'])hashes[name]=createHash('sha256').update(await readFile(resolve(output,name))).digest('hex');
 await writeFile(resolve(output,'source.json'),JSON.stringify({label:'Owner preview; study bottom session list; not current #355 session functionality',head:execFileSync('git',['rev-parse','HEAD'],{cwd:repo,encoding:'utf8'}).trim(),workingTreeDirty:execFileSync('git',['status','--porcelain'],{cwd:repo,encoding:'utf8'}).trim().length>0,bundleManifestSha256:createHash('sha256').update(await readFile(resolve(bundle,'bundle-manifest.json'))).digest('hex'),browser:'Playwright 1.55.0 WebKit 2203 Ubuntu arm64',nativeSquareCSSPixels:12,scales:[1,4],layout:'Approved P6 .ck-tape > .t-lines > .tl, five 16px slots; tool/project/title/age, square last',studyCommit:'1d3f82429f1b853314ee120d4bd0007f84fc051d',studyFile:'design-handoffs/opus-r7/src/rocket-r1/tape.js',studySha256:'928814efead0ccd2108df13f2c105d1f6106286720a060be82e570031e45233f',dayBlue:'#2f6bd8',hashes},null,2)+'\n');
 await writeFile(resolve(output,'README.md'),'# Session rows owner preview\n\nOpen index.html offline. Native and 4x PNGs show the bottom cockpit in night/day with five new synthetic session rows, each ending in its square. Day blue is #2f6bd8 only. The strip follows one full row idle → working → done; only its square flashes, and rapid completion coalesces into that single flash.\n\n#355 has no session list yet: its tape displays observation timestamps. This preview uses the approved P6 study’s bottom record-strip structure and public cockpit skin, not a new product renderer/feed. No state is inferred from quota. Old files remain in old/. Source/artifact hashes are in source.json. This is owner placement review, not native/U11a evidence. Appearance/fonts retain the accompanying reserved/OFL notices.\n');
 console.log(output);
}finally{if(browser)await browser.close();if(server)server.kill('SIGTERM');}

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
const css=await inlineCSS(resolve(bundle,'cockpit.css'));
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
 const quota=await source.evaluate(()=>Array.from(document.querySelectorAll('.ck-eng .qcell')).slice(0,3).map((node,i)=>{
  // Explicit fixture bands, not a client-side quota classifier.
  node.style.setProperty('--qf',`var(--st-${['ok','mid','low'][i]})`);return node.outerHTML;
 }));
 await source.close();
 const labels=['idle','working','done','error'];
 const quotas=()=>`<div class="ck-eng preview-quota">${quota.join('')}</div>`;
 const rows=prefix=>labels.map((state,i)=>`<div class="state-row"><div class="session-label"><span class="session-state" data-state="${state}" role="img" aria-label="Session state: ${state}" data-state-example="${state}" data-example-id="${prefix}-${i}"></span><span><b>${state[0].toUpperCase()+state.slice(1)}</b><small>${['Hollow square','Solid square','Square + tick','Square + !'][i]}</small></span></div>${quotas()}</div>`).join('');
 const panel=(theme,title,alternate=false)=>`<section class="preview-panel" data-theme="${theme}" ${alternate?'data-session-palette="darker"':''}><header><h2>${title}</h2><span>${theme==='night'?'Blue #7fb2ff':alternate?'Blue #2a5fc4':'Blue #2f6bd8'}</span></header><div class="column-head"><span>SESSION STATE · 12 PX</span><span>QUOTA · OK / MID / LOW</span></div>${rows(title)}</section>`;
 const layout=`
 body{margin:0;background:#dce1e7;color:#17212d;font-family:'DM Sans',sans-serif}
 .owner-sheet{padding:28px;width:1240px;margin:auto}.owner-title{margin:0 0 8px;font-size:28px;letter-spacing:-.6px;font-weight:600}.owner-subtitle{font-size:13px;color:#536171;line-height:1.6;margin-bottom:22px}
 .preview-board{display:grid;grid-template-columns:1fr 1fr;gap:20px}.preview-panel{padding:22px;border-radius:12px;border:1px solid #c3cbd4;background:#eef1f4;color:#17212d}.preview-panel[data-theme=night]{background:#161d26;color:#e8edf3;border-color:#263543}
 .preview-panel header{display:flex;justify-content:space-between;align-items:center;margin-bottom:24px}.preview-panel h2{font-size:18px;letter-spacing:-.2px}.preview-panel header>span{font:11px 'Share Tech Mono',monospace;opacity:.75}
 .column-head{display:grid;grid-template-columns:142px 1fr;gap:12px;font:9px 'Share Tech Mono',monospace;letter-spacing:.8px;opacity:.65;margin-bottom:8px}.state-row{display:grid;grid-template-columns:142px 1fr;gap:12px;align-items:center;padding:11px 0;border-top:1px solid #78899a26}.session-label{display:flex;align-items:center;gap:12px}.session-label b{display:block;font-size:13px;font-weight:600}.session-label small{display:block;font-size:10px;opacity:.65;margin-top:4px}
 .preview-quota.ck-eng{display:flex!important;grid-area:auto;grid-row:auto;grid-column:auto;width:100%;height:auto;gap:10px;min-height:0;border-radius:5px;background:var(--lcd-glass);padding:7px 9px;overflow:visible}.preview-quota .qcell{width:75px;min-width:0;flex:1;padding:3px 0}.preview-quota .qtxt{font-size:8px}.preview-quota .qnum{font-size:20px}.preview-quota .qnum small{font-size:9px}.preview-quota .qbar{gap:2px}.preview-quota .qbar i{min-width:3px}
 .alternate{margin-top:20px}.alternate .state-row{grid-template-columns:142px 1fr}.alternate-grid{display:grid;grid-template-columns:1fr 1fr;gap:0 40px}.alternate header{margin-bottom:12px}.legend{margin:17px 2px 0;font-size:12px;line-height:1.6;color:#4c5968}.demo{margin-top:16px;display:flex;gap:12px;align-items:center;font-size:12px}.demo button{border:1px solid #9aa8b8;border-radius:6px;padding:8px 12px;color:#17212d;background:#f7f9fb}
 .flash-strip{padding:24px;width:1240px;background:#161d26;color:#e8edf3}.flash-strip h2{font-size:18px;margin:0 0 8px}.flash-strip p{font-size:12px;color:#a8b4c1;margin:0 0 20px}.frames{display:grid;grid-template-columns:repeat(5,1fr);gap:16px}.frame{border:1px solid #344354;border-radius:8px;padding:14px;background:#111820}.frame h3{font:11px 'Share Tech Mono',monospace;color:#a8b4c1;margin:0 0 16px}.frame-state{display:flex;gap:10px;align-items:center;font-size:12px;margin-bottom:14px}.frame .preview-quota .qcell{min-width:0}.frame .preview-quota{padding:8px}.frame .qtxt{font-size:9px}
 `;
 const bootstrap=`${component}
 const tracker=new SessionStateTracker();
 for(const root of document.querySelectorAll('[data-state-example]'))mountSessionState(root,tracker,root.dataset.exampleId,root.dataset.stateExample);
 const demo=mountSessionState(document.getElementById('demo-state'),tracker,'interactive-demo','idle');let step=0;
 document.getElementById('advance-state').onclick=()=>{const state=['working','done','error','idle'][step++%4];demo.update(state);document.getElementById('demo-label').textContent=state;};
 window.previewFixture={tracker,mountSessionState,SessionStateTracker};`;
 const shell=strip=>`<!doctype html><html lang="en" data-theme="night"><head><meta charset="utf-8"><meta name="viewport" content="width=1240"><meta http-equiv="Content-Security-Policy" content="default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; font-src data:; img-src data:; connect-src 'none'; frame-src 'none'; object-src 'none'; base-uri 'none'"><title>Session state · owner preview</title><style>${css}\n${layout}</style></head><body><main class="owner-sheet" id="owner-sheet"><h1 class="owner-title">Session state, clearly separated from quota</h1><p class="owner-subtitle">Colour + shape, at native size. Blue means working or done; teal and amber remain quota colours.<br>All sessions and readings are synthetic. No data connection.</p><div class="preview-board">${panel('night','Night')}${panel('day','Day · standard')}</div><section class="preview-panel alternate" data-theme="day" data-session-palette="darker"><header><h2>Day · darker blue option</h2><span>Blue #2a5fc4 · default above is #2f6bd8</span></header><div class="alternate-grid">${rows('darker')}</div></section><p class="legend">Idle is hollow; working is solid; done adds a tick; error adds !. The quota bars reuse the cockpit renderer and public teal / amber / red tokens.</p><div class="demo"><button id="advance-state" type="button">Advance demo state</button><span id="demo-state"></span><span id="demo-label">idle</span><span>Two opacity steps. One flash per session per 30 s. Rapid changes share one flash.</span></div></main>${strip??''}<script>${bootstrap}</script></body></html>`;
 const pageHTML=strip=>shell(strip).replace('<div class="demo">','<div class="demo" data-theme="day">');
 await writeFile(resolve(output,'index.html'),pageHTML());
 const context=await browser.newContext({viewport:{width:1240,height:1100},deviceScaleFactor:1});
 const page=await context.newPage();await page.goto(pathToFileURL(resolve(output,'index.html')).href);await page.evaluate(()=>document.fonts.ready);
 // Capture actual CSS animation samples, then freeze their values into a strip.
 const frames=[];
 for(const [i,time]of [null,0,80,160,null].entries()){
  const sample=await page.evaluate(({i,time})=>{
   const fixture=window.previewFixture;
   if(i===0){const e=document.createElement('span');e.id='capture-state';document.body.append(e);window.captureModel=new fixture.SessionStateTracker();window.captureIndicator=fixture.mountSessionState(e,window.captureModel,'flash-example','idle',()=>100);}
   if(i===1){window.captureIndicator.update('working');window.captureAnimation=document.getElementById('capture-state').getAnimations()[0];window.captureAnimation.pause();}
   if(time!==null)window.captureAnimation.currentTime=time;
   if(i===4)window.captureAnimation.cancel();
   const root=document.getElementById('capture-state'),opacity=getComputedStyle(root).opacity,clone=root.cloneNode(true);
   clone.removeAttribute('id');clone.classList.remove('is-flashing');clone.style.opacity=opacity;
   return {html:clone.outerHTML,opacity,state:root.dataset.state};
  },{i,time});
  frames.push(`<article class="frame"><h3>${['Before · idle','t = 0 ms','t = 80 ms','t = 160 ms','Settled · no loop'][i]}</h3><div class="frame-state">${sample.html}<span>${sample.state} · opacity ${sample.opacity}</span></div><div class="ck-eng preview-quota">${quota[0]}</div></article>`);
 }
 const strip=`<section class="flash-strip" id="flash-strip" data-theme="night"><h2>One transition flash · idle → working</h2><p>Two opacity steps over 160 ms, then static. No repeated animation; quota stays unchanged.</p><div class="frames">${frames.join('')}</div></section>`;
 await writeFile(resolve(output,'index.html'),pageHTML(strip));await context.close();
 for(const scale of [1,4]){
  const context=await browser.newContext({viewport:{width:1240,height:1400},deviceScaleFactor:scale});const page=await context.newPage();
  await page.goto(pathToFileURL(resolve(output,'index.html')).href);await page.evaluate(()=>document.fonts.ready);
  await page.locator('#owner-sheet').screenshot({path:resolve(output,scale===1?'session-states-native.png':'session-states-4x.png')});
  await page.locator('#flash-strip').screenshot({path:resolve(output,scale===1?'transition-flash-native.png':'transition-flash-4x.png')});await context.close();
 }
 await copyFile(resolve(bundle,'VISUAL-LICENSE.md'),resolve(output,'VISUAL-LICENSE.md'));
 for(const family of ['dm-sans','share-tech-mono','manrope','jetbrains-mono'])await copyFile(resolve(bundle,'fonts',family,'OFL.txt'),resolve(output,`OFL-${family}.txt`));
 await copyFile(resolve(bundle,'fonts/README.md'),resolve(output,'FONTS-README.md'));
 await copyFile(resolve(bundle,'LICENSE.txt'),resolve(output,'MIT-LICENSE.txt'));
 await copyFile(resolve(bundle,'NOTICES.txt'),resolve(output,'NOTICES.txt'));
 const hashes={};for(const name of ['index.html','session-states-native.png','session-states-4x.png','transition-flash-native.png','transition-flash-4x.png'])hashes[name]=createHash('sha256').update(await readFile(resolve(output,name))).digest('hex');
 await writeFile(resolve(output,'source.json'),JSON.stringify({label:'Owner preview; synthetic explicit session states; interface only',head:execFileSync('git',['rev-parse','HEAD'],{cwd:repo,encoding:'utf8'}).trim(),workingTreeDirty:execFileSync('git',['status','--porcelain'],{cwd:repo,encoding:'utf8'}).trim().length>0,bundleManifestSha256:createHash('sha256').update(await readFile(resolve(bundle,'bundle-manifest.json'))).digest('hex'),browser:'Playwright 1.55.0 WebKit 2203 Ubuntu arm64',nativeSquareCSSPixels:12,scales:[1,4],quota:'actual cockpit-rendered qcell DOM; explicit synthetic ok/mid/low bands',hashes},null,2)+'\n');
 await writeFile(resolve(output,'README.md'),'# Session state owner preview\n\nOpen index.html directly; it is self-contained and works offline. Native and 4x PNGs show all four states, day/night, and both day blues beside the actual cockpit quota indicators. The separate strip samples one real two-step CSS flash. The button advances a synthetic state; cooldown is 30 s per session and no idle timers run.\n\nThis is a design/component preview, not native wiring or U11a evidence. WireCockpitData currently supplies no session-state feed; production state binding remains a consumer contract. No state is inferred from quota. Shape/colour sources keep the official visuals license; embedded public fonts keep their attached OFL notices.\n');
 console.log(output);
}finally{if(browser)await browser.close();if(server)server.kill('SIGTERM');}

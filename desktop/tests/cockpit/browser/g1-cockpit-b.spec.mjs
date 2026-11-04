// SPDX-License-Identifier: MIT
// G1 web checks use the built page and synthetic data through its normal bridge.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';

async function open(page,data=visualFixture().data,init=null) {
 if(init)await page.addInitScript(init);
 await page.addInitScript(()=>{window.__g1Messages=[];window.webkit={messageHandlers:{cockpit:{postMessage(raw){window.__g1Messages.push(JSON.parse(raw));}}}};});
 await page.clock.setFixedTime(new Date('2026-11-04T12:00:00Z'));
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance,shell,redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data}))).toBe(true);
 return {send,receive,data};
}

const readonlyProbe=()=>()=>{
 window.__net={fetch:0,xhr:0,ws:0,beacon:0,worker:0,es:0};
 const rawFetch=window.fetch;window.fetch=(...a)=>{window.__net.fetch++;return rawFetch.apply(window,a);};
 const rawOpen=XMLHttpRequest.prototype.open;XMLHttpRequest.prototype.open=function(...a){window.__net.xhr++;return rawOpen.apply(this,a);};
 window.WebSocket=new Proxy(window.WebSocket,{construct(target,args){window.__net.ws++;return Reflect.construct(target,args);}});
 window.EventSource=new Proxy(window.EventSource,{construct(target,args){window.__net.es++;return Reflect.construct(target,args);}});
 window.Worker=new Proxy(window.Worker,{construct(target,args){window.__net.worker++;return Reflect.construct(target,args);}});
 navigator.sendBeacon=(...a)=>{window.__net.beacon++;return navigator.__rawBeacon.apply(navigator,a);};
 navigator.__rawBeacon=navigator.sendBeacon.bind(navigator);
};

const storageSnapshot=page=>page.evaluate(()=>JSON.stringify({local:Object.entries(localStorage),session:Object.entries(sessionStorage),cookie:document.cookie}));

test('CKP-SHELL-03 detach keeps its slot between gear and close on one shared strip key geometry',async({page})=>{
 await open(page);
 const keys=await page.evaluate(()=>{
  const read=selector=>{const el=document.querySelector('.ck-head '+selector);const r=el.getBoundingClientRect(),s=getComputedStyle(el);
   return {x:r.x,y:r.y,w:r.width,h:r.height,radius:s.borderRadius,mat:el.dataset.mat,pressable:el.tagName==='BUTTON'};};
  return {gear:read('[data-settings]'),detach:read('[data-detach]'),close:read('[data-close]')};
 });
 const {gear,detach,close}=keys;
 for(const [name,key] of Object.entries({gear,detach,close})){
  expect(key.pressable,name).toBe(true);
  expect(key.mat,name).toBe('part');
  expect(key.w,name).toBeCloseTo(32,0);
  expect(key.h,name).toBeCloseTo(32,0);
  expect(key.radius,name).toBe('4px');
  expect(key.y,name).toBeCloseTo(gear.y,0);
 }
 // detach occupies the existing slot: gear < detach < close at the 42 px pitch with 10 px gaps
 expect(gear.x).toBeLessThan(detach.x);expect(detach.x).toBeLessThan(close.x);
 const center=k=>k.x+k.w/2;
 expect(center(detach)-center(gear)).toBeCloseTo(42,0);
 expect(center(close)-center(detach)).toBeCloseTo(42,0);
 expect(detach.x-(gear.x+gear.w)).toBeCloseTo(10,0);
 expect(close.x-(detach.x+detach.w)).toBeCloseTo(10,0);
});

test('CKP-SHELL-14 canopy c01 lays frozen glass over pane geometry above the HUD and joins the strip directly',async({page})=>{
 const {send,receive}=await open(page);
 const read=()=>page.evaluate(()=>{
  const rect=e=>{const r=e.getBoundingClientRect();return {x:r.x,y:r.y,w:r.width,h:r.height};};
  const portrow=document.querySelector('.ck-portrow'),port=document.querySelector('.ck-port');
  const canopy=getComputedStyle(portrow,'::before'),pane=getComputedStyle(port,'::before');
  return {
   canopy:{image:canopy.backgroundImage,size:canopy.backgroundSize,repeat:canopy.backgroundRepeat,z:canopy.zIndex},
   pane:{image:pane.backgroundImage,size:pane.backgroundSize,repeat:pane.backgroundRepeat,z:pane.zIndex},
   hudZ:getComputedStyle(document.querySelector('.hud')).zIndex,
   portrow:rect(portrow),port:rect(port),
   faceTop:document.querySelector('.ck-head').getBoundingClientRect().y-9,
  };
 });
 let g=await read();
 expect(g.canopy.image).toContain('canopy-c01/canopy-890-2x.png');
 expect(g.canopy.size).toBe('100% 100%');expect(g.canopy.repeat).toBe('no-repeat');
 expect(g.pane.image).toContain('canopy-c01/pane-890-2x.png');
 expect(g.pane.size).toBe('100% 100%');expect(g.pane.repeat).toBe('no-repeat');
 // frozen glass over the pane with the HUD painted between the two
 expect(Number(g.pane.z)).toBeLessThan(Number(g.hudZ));expect(Number(g.hudZ)).toBeLessThan(Number(g.canopy.z));
 // the canopy is one continuous sheet covering the whole window with no exposed seam
 const canopy={x:g.portrow.x-30,y:g.portrow.y-1,w:g.portrow.w+60,h:g.portrow.h+2};
 expect(canopy.x).toBeLessThanOrEqual(g.port.x);expect(canopy.y).toBeLessThanOrEqual(g.port.y);
 expect(canopy.x+canopy.w).toBeGreaterThanOrEqual(g.port.x+g.port.w);
 expect(canopy.y+canopy.h).toBeGreaterThanOrEqual(g.port.y+g.port.h);
 // solid metal meets the strip face directly: the canopy bottom reaches the strip face top
 expect(canopy.y+canopy.h).toBeGreaterThanOrEqual(g.faceTop-0.5);
 expect(Math.abs(g.portrow.y+g.portrow.h-g.faceTop)).toBeLessThan(1.5);
 // the 640 profile keeps the same canopy composition with its own pane geometry
 expect(await receive(send('shell',{...shell,tier:'compact'}))).toBe(true);
 g=await read();
 expect(await page.evaluate(()=>document.documentElement.dataset.profile)).toBe('compact');
 expect(g.canopy.image).toContain('canopy-c01/canopy-640-2x.png');
 expect(g.pane.image).toContain('canopy-c01/pane-640-2x.png');
 expect(Number(g.pane.z)).toBeLessThan(Number(g.hudZ));expect(Number(g.hudZ)).toBeLessThan(Number(g.canopy.z));
});

test('CKP-SHELL-16 hull stays the r3 conical interstage silhouette with both section seams on the restored gutters',async({page})=>{
 await open(page);
 const g=await page.evaluate(()=>{
  const shell=document.querySelector('.ck-shell');
  const q=s=>shell.querySelector(s);
  const box=e=>{const s=shell.getBoundingClientRect(),r=e.getBoundingClientRect();return {top:r.top-s.top,bottom:s.bottom-r.bottom,left:r.left-s.left,w:r.width,h:r.height};};
  const seam=sel=>{const s=getComputedStyle(document.querySelector(sel),'::before');
   return {left:parseFloat(s.left),right:parseFloat(s.right),top:parseFloat(s.top),h:parseFloat(s.height),size:s.backgroundSize,repeat:s.backgroundRepeat,image:s.backgroundImage};};
  const cockpit=getComputedStyle(document.querySelector('#cockpit'));
  const aft=getComputedStyle(shell,'::after');
  return {body:parseFloat(cockpit.height),
   consoleH:parseFloat(cockpit.getPropertyValue('--console-h')),tapeH:parseFloat(cockpit.getPropertyValue('--tape-h')),engH:parseFloat(cockpit.getPropertyValue('--eng-h')),
   order:[...shell.children].map(e=>e.className),
   crown:box(q('.hull-crown')),upper:box(q('.hull-upper')),cone:box(q('.hull-cone')),lower:box(q('.hull-lower')),record:box(q('.hull-record')),
   aft:{bottom:parseFloat(aft.bottom),h:parseFloat(aft.height),size:aft.backgroundSize,image:aft.backgroundImage},
   eng:seam('.ck-eng'),deck:seam('.ck-deck')};
 });
 // the r3 stack order is fixed: five hull layers, no inserted or revised sections
 expect(g.order.slice(0,5)).toEqual(['hull-crown','hull-upper','hull-cone','hull-lower','hull-record']);
 // every hull layer is one 636 px sheet overhanging the 620 px window by 8 px per side
 for(const [name,layer] of Object.entries({crown:g.crown,upper:g.upper,cone:g.cone,lower:g.lower,record:g.record})){
  expect(layer.left,name).toBe(-8);expect(layer.w,name).toBe(636);
 }
 // conical interstage: 64 px crown cap, 24 px cone centred on the restored cone top, sections joined without gaps
 expect(g.crown.h).toBeCloseTo(64,1);expect(g.crown.top).toBeCloseTo(0,1);
 const coneTop=g.body-g.consoleH-g.tapeH-35.5-24/2;
 expect(g.cone.top).toBeCloseTo(coneTop,1);expect(g.cone.h).toBeCloseTo(24,1);
 expect(g.upper.top).toBeCloseTo(g.crown.h,1);expect(g.upper.h).toBeCloseTo(coneTop-g.crown.h,1);
 expect(g.lower.top).toBeCloseTo(coneTop+24,1);
 expect(g.lower.bottom).toBeCloseTo(31+g.tapeH,1);
 expect(g.record.h).toBeCloseTo(g.tapeH,1);expect(g.record.bottom).toBeCloseTo(22,1);
 expect(g.aft.h).toBeCloseTo(22,1);expect(g.aft.bottom).toBeCloseTo(0,1);expect(g.aft.size).toBe('636px 22px');
 // the record seam between lower hull and record section stays a 9 px gutter
 expect(g.record.top-(g.body-g.lower.bottom)).toBeCloseTo(9,1);
 // both section seams are 9 px gutters restored to the 636 px sheets
 for(const [name,seam] of [['engine',g.eng],['console',g.deck]]){
  expect(seam.top,name).toBeCloseTo(-9,1);expect(seam.h,name).toBeCloseTo(9,1);
  expect(seam.left,name).toBe(-24);expect(seam.right,name).toBe(-24);
  expect(seam.size,name).toBe('636px 9px');expect(seam.repeat,name).toBe('no-repeat');
 }
 // and the served r3 sheet wires each seam to its own reserved gutter art channel
 const sheet=await (await page.request.get('/prototype/prototype-hull-r3.css')).text();
 expect(sheet).toMatch(/\.ck-eng::before\{background-image:var\(--hull-engine-gutter\)\}/);
 expect(sheet).toMatch(/\.ck-deck::before\{background-image:var\(--hull-console-gutter\)\}/);
});

test('CKP-SHELL-21 try controls stay local comparisons: shell keys only, no reads, no uploads',async({page})=>{
 const popups=[];page.on('popup',p=>popups.push(p));
 const {send,receive}=await open(page,visualFixture().data,readonlyProbe());
 const messages=()=>page.evaluate(()=>window.__g1Messages.length);
 const quiet=async fn=>{const before=await messages();await fn();expect(await messages()).toBe(before);};
 const storageBefore=await storageSnapshot(page),url=page.url();
 const tryKeys=async(choice=true)=>{
  // MFD option keys and fader try keys re-render local comparisons only
  const button=page.locator('.mfd-ok button').first(),other=button.locator('[data-choice]:not(.on)').first();
  if(choice&&await other.count()){
   const value=await other.getAttribute('data-choice');
   await quiet(()=>other.click());
   await expect(button.locator('[data-choice].on')).toHaveAttribute('data-choice',value);
  }
  await quiet(()=>page.locator('.fd-scale .sc-l').first().click());
  await expect(page.locator('.fd-scale .sc-l').first()).toHaveClass(/\bna\b/);
  await expect(page.locator('.fd-ch .fd-cap[hidden]')).toHaveCount(3);
  await quiet(()=>page.locator('[data-caution]').click());
 };
 await page.getByRole('button',{name:'Overview',exact:true}).click();
 await tryKeys();
 await page.getByRole('button',{name:'Subscription',exact:true}).click();
 await tryKeys(false);
 // the engine scope key is the one control that talks to the host, and only as a shell action
 let count=await messages();await page.locator('.eng-keys .ek[data-sub]').first().click();
 expect(await messages()).toBe(count+1);
 let last=await page.evaluate(()=>window.__g1Messages.at(-1));
 expect(last.type).toBe('action');expect(last.action).toBe('scopeSelect');
 for(const [selector,action] of [['[data-shutter]','shutterToggle'],['[data-detach]','detach'],['[data-settings]','openSettings'],['[data-close]','close']]){
  count=await messages();await page.locator('.ck-head '+selector).click();
  expect(await messages()).toBe(count+1);
  last=await page.evaluate(()=>window.__g1Messages.at(-1));
  expect(last.type).toBe('action');expect(last.action).toBe(action);
 }
 // every outbound message stays inside the read-only envelope; none carries a model or effort write
 const all=await page.evaluate(()=>window.__g1Messages);
 const envelope=['version','pageId','sessionId','storeEpoch','generation','viewRevision','sequence','type','requestId'];
 const extras={ready:['appearanceVersion','capabilities'],rendered:[],cleared:[],nextDeadline:['deadlineUnixMs'],action:['action','key','tool']};
 for(const m of all){
  expect(['ready','rendered','cleared','nextDeadline','action']).toContain(m.type);
  const allowed=[...envelope,...extras[m.type]];
  for(const key of Object.keys(m))expect(allowed).toContain(key);
  if(m.type==='action')expect(['chooseSetup','openSettings','openHistory','close','detach','putBack','shutterToggle','scopeSelect']).toContain(m.action);
 }
 // nothing was fetched, uploaded, stored, or navigated during the whole tour
 const net=await page.evaluate(()=>window.__net);
 for(const [channel,count] of Object.entries(net))expect(count,channel).toBe(0);
 expect(await storageSnapshot(page)).toBe(storageBefore);
 expect(page.url()).toBe(url);
 expect(popups).toEqual([]);
 expect(await receive(send('clear',{generation:'42',viewRevision:'4'}))).toBe(true);
 await expect(page.locator('.ec-empty')).toBeVisible();
});

test('CKP-SHELL-22 only the host bridge fills data: stored or URL-carried rows never render',async({page})=>{
 const probe=JSON.stringify({projection:{rows:[{id:'probe',name:{en:'Injection Probe',zh:'注入'}}]}});
 await page.addInitScript(source=>{
  localStorage.setItem('modelplan-cockpit-cache',source);
  sessionStorage.setItem('modelplan-cockpit-data',source);
 },probe);
 await page.clock.setFixedTime(new Date('2026-11-04T12:00:00Z'));
 await page.goto('/?pageId='+pageId+'&data='+encodeURIComponent(probe));
 await page.waitForFunction(()=>!!window.modelPlanCockpit);
 // one frozen adapter is the only ingress surface the page exposes
 expect(await page.evaluate(()=>({frozen:Object.isFrozen(window.modelPlanCockpit),keys:Object.keys(window.modelPlanCockpit)}))).toEqual({frozen:true,keys:['receive','clear','state']});
 // nothing renders from storage, the URL, or any bundled demo set before the bridge speaks
 expect(await page.evaluate(()=>document.querySelector('#cockpit').dataset.detailsAvailable)).toBe('false');
 await expect(page.locator('.ec-empty')).toBeVisible();
 await expect(page.locator('.eng-keys .ek[data-sub]')).toHaveCount(0);
 await expect(page.locator('.qvalue')).toHaveCount(0);
 await expect(page.locator('.ck-tape .t-observed')).toHaveCount(0);
 expect(await page.evaluate(()=>document.body.innerText)).not.toContain('Injection Probe');
 const stub=await page.evaluate(async()=>{const m=await import('/src/prototype-details-fixture-adapter.js');return m.unavailablePrototypeDetailsFixture();});
 expect(stub).toEqual({liveSessions:null,publication:null,resetEvents:null,history:null});
 // delivered bridge data renders; the injected sources still never do
 const data=visualFixture().data,send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance,shell,redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data}))).toBe(true);
 await expect(page.locator('.eng-keys .ek[data-sub]')).toHaveCount(data.projection.rows.length);
 await expect(page.locator('.eng-keys .ek-name').first()).toContainText('Codex');
 expect(await page.evaluate(()=>document.body.innerText)).not.toContain('Injection Probe');
 expect(await page.evaluate(()=>JSON.stringify({local:Object.entries(localStorage),session:Object.entries(sessionStorage)}))).toEqual(
  await page.evaluate(source=>JSON.stringify({local:[['modelplan-cockpit-cache',source]],session:[['modelplan-cockpit-data',source]]}),probe));
});

test('CKP-SHELL-23 views stay framework-free render functions behind the single frozen adapter',async({page})=>{
 const {send,receive}=await open(page);
 // every module in the built page graph is a local file import; no framework or bare package enters
 const origin=new URL(page.url()).origin;
 const seen=new Set(),queue=[origin+'/src/main.js'],specs=[];
 while(queue.length&&seen.size<200){
  const url=queue.pop();if(seen.has(url))continue;seen.add(url);
  const text=await (await page.request.get(url)).text();
  for(const match of text.matchAll(/\bimport\s*(?:\{[^}]*\}|[\w$*]+\s*,?)?\s*(?:from\s*)?['"]([^'"]+)['"]|\bimport\s*\(\s*['"]([^'"]+)['"]/g)){
   const spec=match[1]??match[2];if(!spec)continue;
   specs.push(spec);
   if(spec.startsWith('.'))queue.push(new URL(spec,url).href);
  }
 }
 expect(seen.size).toBeGreaterThan(10);
 for(const spec of specs){
  expect(spec.startsWith('./')||spec.startsWith('../'),spec).toBe(true);
  expect(spec,'framework import').not.toMatch(/react|vue|svelte|angular|jquery|preact|lit-|solid-js/i);
 }
 const roots=await page.evaluate(()=>Object.keys(window).filter(k=>/cockpit|bridge|modelplan/i.test(k)&&!['__g1Messages','webkit'].includes(k)));
 expect(roots).toEqual(['modelPlanCockpit']);
 // a second mount behind the same contract renders identical DOM from identical data, and again on re-render
 const mounts=await page.evaluate(async data=>{
  const {mountPrototypeDeck}=await import('/src/prototype-deck.js');
  const mount=()=>{const root=document.createElement('div');root.innerHTML='<div class="fd-scale"></div><div class="fd-chs"></div><div class="fd-bank"></div><div class="dk-mfd"></div>';
   const deck=mountPrototypeDeck(root);deck.render(data,1762248000000);return {html:root.innerHTML,detailsAvailable:root.dataset.detailsAvailable};};
  const first=mount(),second=mount();
  return {first,second};
 },visualFixture().data);
 expect(mounts.first.detailsAvailable).toBe('true');
 expect(mounts.first.html.length).toBeGreaterThan(500);
 expect(mounts.second.html).toBe(mounts.first.html);
 expect(await receive(send('clear',{generation:'42',viewRevision:'4'}))).toBe(true);
 await expect(page.locator('#cockpit')).toHaveAttribute('data-details-available','false');
});

test('CKP-STRIP-01 strip is one row with the keyed right end and no legends, second row or help key',async({page})=>{
 await open(page);
 const head=page.locator('.ck-head');
 // exactly the six built-in strip elements, all on one visual row
 const strip=await head.evaluate(h=>({children:[...h.children].map(k=>k.tagName+'.'+String(k.className).split(' ')[0]),
  row:(()=>{const hr=h.getBoundingClientRect();return {mid:hr.y+hr.height/2,kids:[...h.children].map(k=>{const r=k.getBoundingClientRect();return {cy:r.y+r.height/2,x:r.x,text:k.textContent};})};})()}));
 expect(strip.children).toEqual(['SPAN.ck-brand','BUTTON.shutter-slider','SPAN.ck-lamp','BUTTON.key','BUTTON.key','BUTTON.key']);
 for(const kid of strip.row.kids)expect(Math.abs(kid.cy-strip.row.mid),'row alignment').toBeLessThan(3);
 // the machine keys carry no text legends; the ALERT lamp keeps its English legend
 for(const kid of [strip.row.kids[1],...strip.row.kids.slice(3)])expect(kid.text,'legend').toBe('');
 await expect(head.locator('[data-caution]')).toContainText('ALERT');
 // no help key, no ? glyph anywhere on the strip
 await expect(head.locator('[data-help],button[aria-label="Help"],button[aria-label*="help" i]')).toHaveCount(0);
 expect(await head.innerText()).not.toContain('?');
 // the left end is the official logo plus the live wordmark
 await expect(head.locator('.ck-brand .brand-mark')).toHaveAttribute('aria-label','ModelPlan');
 await expect(head.locator('.ck-brand .wordmark')).toHaveText('ModelPlan');
});

test('CKP-STRIP-02 the strip wordmark is one word, ModelPlan, painted from the reserved art in every locale',async({page})=>{
 const {send,receive}=await open(page);
 const wordmark=page.locator('.ck-head .wordmark');
 await expect(wordmark).toHaveText('ModelPlan');
 await expect(wordmark.locator('b')).toHaveText('Plan');
 const painted=await wordmark.evaluate(e=>{const r=e.getBoundingClientRect(),s=getComputedStyle(e),b=getComputedStyle(e,'::before'),a=getComputedStyle(e,'::after');
  return {fontSize:s.fontSize,w:r.width,h:r.height,before:b.backgroundImage,after:a.backgroundImage,beforeClip:b.clipPath,afterClip:a.clipPath};});
 // the visible glyphs are the fixed wordmark art in its 112x20 box, not flowing text
 expect(painted.fontSize).toBe('0px');
 expect(painted.w).toBeCloseTo(112,0);expect(painted.h).toBeCloseTo(20,0);
 expect(painted.before).toContain('wordmark@3x.png');expect(painted.after).toContain('wordmark@3x.png');
 expect(painted.beforeClip).not.toBe(painted.afterClip);
 // brand copy is not localised
 expect(await receive(send('appearance',{...appearance,locale:'zh-CN'}))).toBe(true);
 await expect(wordmark).toHaveText('ModelPlan');
 await expect(wordmark.locator('b')).toHaveText('Plan');
});

test('CKP-STRIP-03 strip face spans the table insets on one sheet and keys keep the registered art box',async({page})=>{
 await open(page);
 const m=await page.evaluate(()=>{
  const q=s=>document.querySelector(s);
  const face=getComputedStyle(q('.ck-head'),'::before'),key=q('.ck-head [data-detach]'),keyFace=getComputedStyle(key,'::before'),gear=q('.ck-head [data-settings]'),close=q('.ck-head [data-close]');
  const win=q('#cockpit').getBoundingClientRect(),head=q('.ck-head').getBoundingClientRect(),eng=q('.ck-eng').getBoundingClientRect();
  return {padX:getComputedStyle(q('#cockpit')).getPropertyValue('--pad-x').trim(),
   face:{left:face.left,right:face.right,height:face.height,size:face.backgroundSize,repeat:face.backgroundRepeat,image:face.backgroundImage},
   span:{engInset:eng.x-win.x,faceX:head.x+parseFloat(face.left)-win.x,faceW:head.width-parseFloat(face.left)-parseFloat(face.right)},
   detach:{inset:keyFace.inset,size:keyFace.backgroundSize,repeat:keyFace.backgroundRepeat,base:key.dataset.mat,art:keyFace.backgroundImage},
   gearArt:getComputedStyle(gear,'::before').backgroundImage,closeArt:getComputedStyle(close,'::before').backgroundImage};
 });
 expect(m.padX).toBe('16px');
 // the face is one 620 px sheet overhanging the head by the same --pad-x the table sections use
 expect(m.span.engInset).toBeCloseTo(16,1);
 expect(m.span.faceX).toBeCloseTo(0,1);expect(m.span.faceW).toBeCloseTo(620,1);
 expect(m.face.left).toBe('-16px');expect(m.face.right).toBe('-16px');
 expect(m.face.size).toBe('620px 48px');expect(m.face.repeat).toBe('no-repeat');
 expect(m.face.image).toContain('strip-panel@3x.png');
 // each key face is one registered 40 px art sheet keyed to its own normal art
 expect(m.detach.inset).toBe('-4px');
 expect(m.detach.size.split(',').map(s=>s.trim())).toEqual(['40px 40px','40px 40px']);
 expect(m.detach.repeat.split(',').map(s=>s.trim())).toEqual(['no-repeat','no-repeat']);
 expect(m.detach.art).toContain('detach-normal@3x.png');
 expect(m.gearArt).toContain('gear-normal@3x.png');
 expect(m.closeArt).toContain('close-normal@3x.png');
});

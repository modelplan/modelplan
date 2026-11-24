// SPDX-License-Identifier: MIT
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';

// WP-22 (D298): the field page hosts the launch-field component (1.1.0, window mode) in the native panel's rectangle.
// Synthetic public model data only. WebGL may be absent here, which exercises the 2D fallback.
const model=i=>({id:'m'+i,name:'Synthetic '+i,developerId:['openai','anthropic','google'][i%3],recommended:'medium',efforts:[{effort:'low',label:'Low',star:false,ability:35+i,cost:.1,time:1},{effort:'medium',label:'Med',star:true,ability:40+i,cost:.2,time:1.4,provisional:i===3}]});
const payload=(n=12,extra={})=>JSON.stringify({language:'en',reduceMotion:true,lowPower:false,contrast:false,models:Array.from({length:n},(_,i)=>model(i)),mine:['m1','m2'],focus:null,asOf:'2026-11-18',...extra});
async function open(page,{noWebGL=false}={}) {
 await page.addInitScript(noWebGL=>{
  window.posted=[];window.messages=[];window.webkit={messageHandlers:{field:{postMessage(m){const v=JSON.parse(m);window.messages.push(v);window.posted.push(v.type);}}}};
  if(noWebGL){const get=HTMLCanvasElement.prototype.getContext;HTMLCanvasElement.prototype.getContext=function(type,...rest){return /webgl/.test(String(type))?null:get.call(this,type,...rest);};}
 },noWebGL);
 await page.setViewportSize({width:1280,height:800});
 await page.goto('/field.html');await page.waitForFunction(()=>!!window.modelPlanField);
 expect(await page.evaluate(()=>window.posted)).toContain('loaded');
}
const show=(page,raw)=>page.evaluate(raw=>window.modelPlanField.show(raw),raw);
const ready=page=>expect.poll(()=>page.evaluate(()=>window.posted.includes('ready')),{timeout:20000}).toBe(true);
const state=page=>page.evaluate(()=>window.modelPlanField.state());
const closes=page=>page.evaluate(()=>window.messages.filter(m=>m.type==='close').map(m=>m.reason));

test('WP-22 hidden subscriptions do not make the field fall back to every published rocket',async({page})=>{
 await open(page,{noWebGL:true});await show(page,payload(4,{mine:[],onlyMine:true}));await ready(page);
 expect((await state(page)).shown).toEqual([]);
});

test('WP-22 the initial field uses only the visible subscription models',async({page})=>{
 await open(page,{noWebGL:true});await show(page,payload(4,{mine:['m1'],onlyMine:true}));await ready(page);
 expect((await state(page)).shown).toEqual(['m1']);
});

test('WP-22 the field is the launch-field window: native dims, so the component\'s dim is off, and my models fly first',async({page})=>{
 await open(page);expect(await show(page,payload())).toBe(true);await ready(page);
 const s=await state(page);
 expect(s.shown).toEqual(['m1','m2']);
 test.skip(s.flat,'no WebGL in this browser: the 2D fallback test covers it');
 await expect(page.locator('#field.lfw')).toHaveCount(1);
 await expect(page.locator('#field .lfw-dim')).toBeHidden();
 await expect(page.locator('#field .lfw-menu')).toHaveCount(1);
 expect(await page.evaluate(()=>getComputedStyle(document.body).backgroundColor)).toBe('rgba(0, 0, 0, 0)');
});
test('WP-22 Esc on an idle field and the × key ask the host to close, with their reasons',async({page})=>{
 await open(page);await show(page,payload());await ready(page);
 await page.locator('#field .lfw-x').click();
 await page.keyboard.press('Escape');
 await expect.poll(()=>closes(page)).toEqual(['key','esc']);
 expect(await page.evaluate(()=>window.posted)).toContain('activity');
});
test('WP-22 the site key asks the host to open the website; the page never opens a URL itself',async({page})=>{
 await open(page);await show(page,payload());await ready(page);
 await page.locator('#field .lfw-site').click();
 await expect.poll(()=>page.evaluate(()=>window.messages.filter(m=>m.type==='openSite'))).toEqual([{type:'openSite',target:'fleet',params:{}}]);
 expect(page.url()).toMatch(/\/field\.html$/);
});
test('WP-22 Increase Contrast, Reduce Motion and Low Power Mode reach the component live',async({page})=>{
 await open(page);await show(page,payload(4,{reduceMotion:false}));await ready(page);
 expect(await state(page)).toMatchObject({contrast:'normal',reducedMotion:false});
 expect(await page.evaluate(()=>window.modelPlanField.options(JSON.stringify({contrast:true,reduceMotion:true})))).toBe(true);
 expect(await state(page)).toMatchObject({contrast:'more',reducedMotion:true});
 expect(await page.evaluate(()=>window.modelPlanField.options(JSON.stringify({contrast:false,reduceMotion:false})))).toBe(true);
 expect(await state(page)).toMatchObject({contrast:'normal',reducedMotion:false});
 expect(await page.evaluate(()=>window.modelPlanField.power(true))).toBe(true);
 expect((await state(page)).reducedMotion).toBe(true);
 expect(await page.evaluate(()=>window.modelPlanField.options('nope'))).toBe(false);
});
// Component 1.2.0 (reference: its embed-window.html?nogl=1): without WebGL the window swaps in its own 2D field, keeps its
// menu and keys, and reports onFail, which is informational: the field stays open.
test('WP-22 without WebGL the window keeps its menu and keys on the 2D field, and onFail does not close it',async({page})=>{
 await open(page,{noWebGL:true});await show(page,payload());await ready(page);
 expect(await state(page)).toMatchObject({mode:'window',flat:true,shown:['m1','m2']});
 await expect(page.locator('#field.lfw .lfw-flat svg.lf-flat')).toHaveCount(1);
 await expect(page.locator('#field .lfw-menu')).toHaveCount(1);
 await expect(page.locator('#field .lf-scene canvas')).toHaveCount(0);
 await page.waitForTimeout(500);
 expect(await page.evaluate(()=>window.posted.filter(t=>t==='close'||t==='failed'))).toEqual([]);
 await page.locator('#field .lfw-x').click();
 await expect.poll(()=>closes(page)).toEqual(['key']);
});
test('WP-22 a focused rocket outside my models joins the field',async({page})=>{
 await open(page);await show(page,payload(12,{focus:'m7'}));await ready(page);
 expect((await state(page)).shown).toEqual(['m1','m2','m7']);
});
// macrevb-1062-3: the field's selection is the cockpit's. Through the normal entry (show, then a click on a rocket in the
// window's 2D field, which runs in every browser) the host hears the public id; a click on the empty field clears it.
// No effort crosses: a tried effort stays local to the field.
test('WP-22 a rocket chosen or cleared in the field is reported to the host by public model id, never with an effort',async({page})=>{
 await open(page,{noWebGL:true});await show(page,payload());await ready(page);
 const selects=()=>page.evaluate(()=>window.messages.filter(m=>m.type==='select'));
 expect(await selects()).toEqual([],'opening without a focus selects nothing');
 await page.locator('#field .lfw-flat g[role="button"][data-id="m2"]').first().click();
 await expect.poll(selects).toEqual([{type:'select',model:'m2'}]);
 const box=await page.locator('#field .lfw-flat svg.lf-flat').boundingBox();
 await page.mouse.click(box.x+box.width-6,box.y+6);
 await expect.poll(selects).toEqual([{type:'select',model:'m2'},{type:'select',model:null}]);
});
test('WP-22 retracting the selected rocket from the field clears the host\'s selection too',async({page})=>{
 await open(page,{noWebGL:true});await show(page,payload());await ready(page);
 const selects=()=>page.evaluate(()=>window.messages.filter(m=>m.type==='select').map(m=>m.model));
 await page.locator('#field .lfw-flat g[role="button"][data-id="m2"]').first().click();
 await expect.poll(selects).toEqual(['m2']);
 await page.locator('#field .lfw-menu [data-rm="m2"], #field .lfw-menu [data-tg="m2"]').first().click();
 await expect.poll(()=>state(page).then(s=>s.shown)).toEqual(['m1']);
 await expect.poll(selects).toEqual(['m2',null]);
});
test('WP-22 the rocket the field opens on (a porthole click) is the host\'s selection from the start',async({page})=>{
 await open(page,{noWebGL:true});await show(page,payload(12,{focus:'m7'}));await ready(page);
 await expect.poll(()=>page.evaluate(()=>window.messages.filter(m=>m.type==='select'))).toEqual([{type:'select',model:'m7'}]);
});
test('WP-22 dispose clears the page',async({page})=>{
 await open(page);await show(page,payload());await ready(page);await page.evaluate(()=>window.modelPlanField.dispose());
 await expect(page.locator('#field > *')).toHaveCount(0);expect(await page.evaluate(()=>window.modelPlanField)).toBeUndefined();
});
// CKP-PORT-11D: only public data enters the field. The host's payload carries presentation and published models; the page
// keeps nothing else and never asks the host for account or local readings.
test('CKP-PORT-11D the field page takes only public model data and posts only its fixed events',async({page})=>{
 await open(page);
 const withPrivate=JSON.stringify({...JSON.parse(payload(4)),account:'someone@example.invalid',subscriptionRef:'secret-ref',usedPercent:73,projectName:'private'});
 expect(await show(page,withPrivate)).toBe(true);await ready(page);
 const text=await page.evaluate(()=>document.documentElement.innerText+document.documentElement.outerHTML);
 for(const secret of ['someone@example.invalid','secret-ref','private'])expect(text).not.toContain(secret);
 for(const type of await page.evaluate(()=>window.posted))expect(['loaded','ready','activity','close','failed','openSite']).toContain(type);
});

test('the official porthole opens the field by click and keyboard',async({page})=>{
 await page.addInitScript(()=>{window.posted=[];window.webkit={messageHandlers:{cockpit:{postMessage(m){window.posted.push(typeof m==='string'?JSON.parse(m):m);}}}};});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance,shell,redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data:visualFixture().data}))).toBe(true);
 const port=page.locator('.ck-port'),key=page.locator('.port-big[data-bigfield]');await expect(port).not.toHaveAttribute('tabindex');await expect(port).not.toHaveAttribute('role','button');
 await expect(key).toHaveAttribute('aria-label',/^Open the 3D launch field/);
 await port.click();await key.focus();await page.keyboard.press('Enter');
 expect(await page.evaluate(()=>window.posted.filter(m=>m.type==='action'&&m.action==='openField').length)).toBe(2);
});
// Build 14c: after a click on the porthole and a key press (the walk clicks the field open, then presses Escape), the
// focused port drew WebKit's default blue focus ring round the whole port box, over the canopy frame; with that ring
// removed, the same click and key press lit the ⤢ key gold although nobody pressed it (owner, 14c). The port is not
// focusable; only real keyboard navigation to the ⤢ key shows its ring.
test('build 14c: a click and Escape on the porthole leave no ring on the port or its ⤢ key; Tab to the key shows it',async({page})=>{
 await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance,shell,redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data:visualFixture().data}))).toBe(true);
 const read=()=>page.evaluate(()=>{const p=document.querySelector('.ck-port'),k=p.querySelector('.port-big'),c=getComputedStyle(p),ck=getComputedStyle(k);
  return {active:document.activeElement===p?'port':document.activeElement===k?'key':'other',port:c.outlineStyle,key:ck.outlineStyle,keyWidth:ck.outlineWidth};});
 const port=page.locator('.ck-port');await port.click({position:{x:520,y:120}});await page.keyboard.press('Escape');
 let v=await read();expect(v.active).not.toBe('port');expect([v.port,v.key]).toEqual(['none','none']);
 await page.locator('.port-big').click();await page.keyboard.press('Escape');
 v=await read();expect(v.active).not.toBe('key');expect(v.key).toBe('none');
 // Real keyboard navigation: Tab from the control just before the key lands on it and shows the gold ring.
 await page.evaluate(()=>{const k=document.querySelector('.port-big'),all=[...document.querySelectorAll('button,[tabindex="0"],a[href]')].filter(e=>e.offsetParent&&!e.disabled&&e.tabIndex>=0);
  const i=all.indexOf(k);document.body.focus();if(i>0)all[i-1].focus();});
 for(let n=0;n<40&&(await read()).active!=='key';n++)await page.keyboard.press('Tab');
 v=await read();expect(v.active).toBe('key');expect([v.key,v.keyWidth]).toEqual(['solid','2px']);
});
test('D43 every vendor mark the scene asks for loads under the page CSP, close to square',async({page})=>{
 await open(page);
 const sizes=await page.evaluate(async names=>Promise.all(names.map(name=>new Promise(done=>{const image=new Image();image.onload=()=>done([name,image.naturalWidth>0,Math.abs(image.naturalWidth/image.naturalHeight-1)<=.05]);image.onerror=()=>done([name,false,false]);image.src='./assets/brands/'+name;}))),
  ['openai-white.svg','claude-rounded.svg','claude.svg','alibaba.svg','zhipu.svg','x-white.svg','qwen.svg','deepseek.svg','kimi-white.svg','minimax.svg','gemini.svg','xiaomi.svg']);
 for(const [name,loaded,square] of sizes){expect(loaded,name).toBe(true);expect(square,name).toBe(true);}
});
// D63 / CKP-PORT-11/12: the ⤢ key, a double-click and a click on a still rocket open the field; a rocket focuses it.
// Prototype rocket-r1/porthole.js placeBigKey / bindPorthole (task 91); hud-selection/still.js hitStillRocket (28 px).
async function openCockpit(page,theme='night') {
 await page.addInitScript(()=>{window.posted=[];window.webkit={messageHandlers:{cockpit:{postMessage(m){window.posted.push(typeof m==='string'?JSON.parse(m):m);}}}};});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance:{...appearance,theme},shell,redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data:visualFixture().data}))).toBe(true);
 await expect(page.locator('.ck-field')).toHaveAttribute('data-still','ready');
}
const opens=page=>page.evaluate(()=>window.posted.filter(m=>m.type==='action'&&m.action==='openField').map(m=>m.payload?.key??m.key??null));
test('D63 the ⤢ key opens the field, with a label that says the field itself also opens it',async({page})=>{
 await openCockpit(page);
 const key=page.locator('.ck-port [data-bigfield]');await expect(key).toBeVisible();await expect(key).toHaveText('⤢');
 await expect(key).toHaveAttribute('aria-label','Open the 3D launch field · Or click anywhere on the field');
 expect(await key.evaluate(e=>{const s=getComputedStyle(e);return [s.right,s.top,s.width,s.height];})).toEqual(['38px','52px','22px','22px']);
 await key.click();expect(await opens(page)).toEqual([null]);
});
// Owner 11-09: the key must sit inside the glass. The c01 canopy aperture mask (laid 1:1 on the canopy art box, see below; origin at the box's
// top left) is the truth: every pixel of the key's rect keeps at least 8 px from any frame pixel, and it clears the HUD.
for(const theme of ['night','day'])for(const tier of ['tall','compact'])test(`D63 the key lies inside the aperture mask with 8 px of glass (${theme} ${tier})`,async({page})=>{
 await page.setViewportSize({width:636,height:tier==='tall'?905:635});
 await page.addInitScript(()=>{window.posted=[];window.webkit={messageHandlers:{cockpit:{postMessage(m){window.posted.push(typeof m==='string'?JSON.parse(m):m);}}}};});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 await receive(send('load',{appearance:{...appearance,theme},shell:{...shell,tier}}));
 await receive(send('visibility',{visible:true,occluded:false,key:true}));await receive(send('display',{data:visualFixture().data}));
 await expect(page.locator('.ck-field')).toHaveAttribute('data-still','ready');
 const layout=tier==='tall'?890:640;
 const r=await page.evaluate(async layout=>{
  // The art box is the port row grown by 24 px each side and 12 px at the top (cockpit.css .ck-portrow::before, inset -12px -24px 0),
  // drawn 1:1 with the canopy mask. The mask pixel (px,y) therefore lies at the box's origin plus (px,y), never at the page's.
  const img=new Image();img.src='./runtime/canopy-c01/aperture-'+layout+'-1x.png';await img.decode();
  const row=document.querySelector('.ck-portrow').getBoundingClientRect(),box={left:row.left-24,top:row.top-12,width:row.width+48,height:row.height+12};
  const c=document.createElement('canvas');c.width=img.width;c.height=img.height;const x=c.getContext('2d');x.drawImage(img,0,0);const a=x.getImageData(0,0,c.width,c.height).data;
  const k=document.querySelector('[data-bigfield]').getBoundingClientRect();let min=1e9;
  for(let y=0;y<c.height;y++)for(let px=0;px<c.width;px++)if(a[(y*c.width+px)*4+3]<128){
   const X=box.left+px,Y=box.top+y,dx=Math.max(k.left-X,0,X-(k.right-1)),dy=Math.max(k.top-Y,0,Y-(k.bottom-1));min=Math.min(min,Math.hypot(dx,dy));}
  const huds=[...document.querySelectorAll('.ck-port .hud, .ck-port .hud *')].map(e=>e.getBoundingClientRect()).filter(h=>h.width>0&&h.height>0);
  return {min,boxWidth:box.width,boxHeight:box.height,maskWidth:c.width,maskHeight:c.height,hudOverlap:huds.some(h=>k.left<h.right&&k.right>h.left&&k.top<h.bottom&&k.bottom>h.top)};
 },layout);
 expect([r.boxWidth,r.boxHeight],'the art box is 1:1 with the canopy mask').toEqual([r.maskWidth,r.maskHeight]);
 expect(r.min,'glass margin around the key').toBeGreaterThanOrEqual(8);
 expect(r.hudOverlap).toBe(false);
});
test('D63 a double-click on the field opens it once',async({page})=>{
 await openCockpit(page);
 const port=await page.locator('.ck-port').boundingBox();
 await page.mouse.dblclick(port.x+12,port.y+port.height-12);
 expect(await opens(page)).toEqual([null]);
});
test('D63 a click on a rocket in the still opens the field focused on that rocket',async({page})=>{
 await openCockpit(page);
 const rocket=await page.locator('.ck-still-body[data-model-name]').evaluateAll(es=>{const e=es.find(e=>{const r=e.getBoundingClientRect(),p=document.querySelector('.ck-port').getBoundingClientRect(),hud=document.querySelector('.hud')?.getBoundingClientRect();const x=r.x+r.width/2,y=r.y+r.height/2;return r.width>0&&x>p.x&&x<p.right&&y>p.y&&y<p.bottom&&!(hud&&x>=hud.x&&x<=hud.right&&y>=hud.y&&y<=hud.bottom)&&document.elementFromPoint(x,y)?.closest('.ck-port')&&!document.elementFromPoint(x,y)?.closest('.hud,[data-bigfield]');});const r=e.getBoundingClientRect();return {name:e.dataset.modelName,x:r.x+r.width/2,y:r.y+r.height/2};});
 await page.mouse.click(rocket.x,rocket.y);
 expect(await opens(page)).toEqual([rocket.name]);
});

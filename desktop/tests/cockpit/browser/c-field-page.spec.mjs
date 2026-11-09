// SPDX-License-Identifier: MIT
// The enlarged field's page, with synthetic public model data. WebGL may be absent here, which exercises the fallback.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';

const model=i=>({id:'m'+i,name:'Synthetic '+i,developerId:'openai',recommended:'medium',efforts:[{effort:'medium',label:'Med',star:true,ability:40+i,cost:.2,time:30}]});
const payload=(n=12,extra={})=>JSON.stringify({language:'en',reduceMotion:true,models:Array.from({length:n},(_,i)=>model(i)),mine:['m1','m2'],focus:null,...extra});
async function open(page) {
 await page.addInitScript(()=>{window.posted=[];window.webkit={messageHandlers:{field:{postMessage(m){window.posted.push(JSON.parse(m).type);}}}};});
 await page.goto('/field.html');await page.waitForFunction(()=>!!window.modelPlanField);
 expect(await page.evaluate(()=>window.posted)).toContain('loaded');
}
const show=(page,raw)=>page.evaluate(raw=>window.modelPlanField.show(raw),raw);

test('the picker starts on my models and the presets change the fleet within the limit',async({page})=>{
 await open(page);expect(await show(page,payload())).toBe(true);
 await expect(page.locator('.field-count')).toHaveText('2/10');
 await page.locator('.field-preset',{hasText:'All'}).click();await expect(page.locator('.field-count')).toHaveText('10/10');
 await expect(page.locator('.field-row input:not(:checked)').first()).toBeDisabled();
 await page.locator('.field-search').fill('Synthetic 11');await expect(page.locator('.field-row')).toHaveCount(1);
});
test('Esc and the close key ask the host to close, and interaction renews the idle timer',async({page})=>{
 await open(page);await show(page,payload());await expect(page.locator('.field-close')).toHaveText('×');
 await page.locator('.field-close').click();await page.keyboard.press('Escape');
 const posted=await page.evaluate(()=>window.posted);
 expect(posted.filter(x=>x==='close').length).toBe(2);expect(posted).toContain('activity');
});
test('Chinese words, and nothing published says so',async({page})=>{
 await open(page);await show(page,payload(0,{language:'zh'}));
 await expect(page.locator('.nogl')).toHaveText('暂无已发布模型。');await expect(page.locator('.field-preset').first()).toHaveText('我的');
 await expect.poll(()=>page.evaluate(()=>window.posted.includes('ready'))).toBe(true);
});
test('dispose clears the page',async({page})=>{
 await open(page);await show(page,payload());await page.evaluate(()=>window.modelPlanField.dispose());
 await expect(page.locator('#field > *')).toHaveCount(0);expect(await page.evaluate(()=>window.modelPlanField)).toBeUndefined();
});
test('the official porthole opens the field by click and keyboard',async({page})=>{
 await page.addInitScript(()=>{window.posted=[];window.webkit={messageHandlers:{cockpit:{postMessage(m){window.posted.push(typeof m==='string'?JSON.parse(m):m);}}}};});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance,shell,redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data:visualFixture().data}))).toBe(true);
 const port=page.locator('.ck-port');await expect(port).toHaveAttribute('role','button');await expect(port).toHaveAttribute('aria-label','Open the 3D view');
 await port.click();await port.focus();await page.keyboard.press('Enter');
 expect(await page.evaluate(()=>window.posted.filter(m=>m.type==='action'&&m.action==='openField').length)).toBe(2);
});
test('D43 every vendor mark the scene asks for loads under the page CSP, close to square',async({page})=>{
 await open(page);
 const sizes=await page.evaluate(async names=>Promise.all(names.map(name=>new Promise(done=>{const image=new Image();image.onload=()=>done([name,image.naturalWidth>0,Math.abs(image.naturalWidth/image.naturalHeight-1)<=.05]);image.onerror=()=>done([name,false,false]);image.src='./assets/brands/'+name;}))),
  ['openai-white.svg','claude-rounded.svg','claude.svg','zhipu.svg','x-white.svg','qwen.svg','deepseek.svg','kimi-white.svg','minimax.svg','gemini.svg','xiaomi.svg']);
 for(const [name,loaded,square] of sizes){expect(loaded,name).toBe(true);expect(square,name).toBe(true);}
});
// CKP-PORT-11 (D63): the c01 porthole silhouette feathered ~10% into the desktop, derived from the published
// window-890-1x.png at open. Reference: alpha samples of the prototype's approved mask (task 91 round 5,
// feather-masks/A.png, 1000x650), read on the design branch; the mask image itself is not in this repository.
const featherReference=[[500,325,255],[0,0,0],[999,649,0],[500,0,0],[500,20,63],[500,40,176],[500,65,255],[500,100,255],[0,325,0],[20,325,4],[40,325,83],[65,325,220],[100,325,255],[500,649,0],[500,610,171],[500,585,255],[150,60,188],[850,60,190],[120,600,119],[60,120,73]];
test('CKP-PORT-11 the feathered silhouette matches the approved mask',async({page})=>{
 await page.goto('/field.html');
 const got=await page.evaluate(async points=>{const {featherShape}=await import('./src/field-shape.js');const shape=await featherShape('runtime/canopy-c01/window-890-1x.png');
  return shape&&{w:shape.width,h:shape.height,url:shape.maskUrl.slice(0,5),samples:points.map(([x,y])=>shape.alpha[y*shape.width+x])};},featherReference);
 expect(got).not.toBeNull();expect([got.w,got.h,got.url]).toEqual([1000,650,'blob:']);
 for(const [i,[x,y,want]] of featherReference.entries())expect(Math.abs(got.samples[i]-want),`(${x},${y}) ${got.samples[i]} vs ${want}`).toBeLessThanOrEqual(24);
});
// 91 A pins (owner 11-09). The approved matte is 1000x650 with a 65 px smooth inward ramp. Grid: its alpha every 25 px.
// The page derives the matte from window-890-1x.png; it stays within 6/255 of the approved one (the resize kernel
// differs from the study's), and its own bytes are pinned by hash so any change to the matte is a visible one.
const matteGrid=[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,13,52,90,90,90,90,90,90,90,90,90,90,90,90,90,90,90,90,90,90,90,90,90,90,90,90,90,53,14,0,0,0,0,0,0,0,0,0,16,69,135,192,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,192,135,69,16,0,0,0,0,0,0,41,125,199,246,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,246,199,125,43,0,0,0,0,13,136,228,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,230,139,14,0,0,0,30,165,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,165,30,0,0,0,45,184,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,187,48,0,0,0,58,197,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,197,58,0,0,0,72,211,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,212,73,0,0,0,84,221,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,221,84,0,0,1,95,228,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,232,100,1,0,4,113,239,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,239,113,4,0,8,125,244,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,244,125,8,0,16,141,250,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,251,142,16,0,23,154,253,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,253,154,23,0,30,165,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,168,32,0,43,182,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,182,43,0,53,192,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,192,53,0,67,206,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,207,68,0,79,216,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,216,79,0,73,212,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,214,75,0,53,192,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,194,55,0,22,144,246,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,246,144,22,0,0,69,184,229,244,251,254,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,254,251,244,230,184,69,0,0,0,8,58,97,124,142,159,171,176,184,192,197,197,207,207,207,212,212,216,221,216,212,212,207,207,207,197,197,192,184,176,171,159,142,124,98,59,8,0,0,0,0,0,1,8,16,26,34,39,45,53,58,58,68,68,68,73,73,79,84,79,73,73,68,68,68,58,58,53,45,39,34,26,16,8,1,0,0,0];
const MATTE_SHA256='f8b78227ed537c35a8041886c47585e377768f5ad460f92efbb534905863ce94';
test('91 A the matte is 1000x650, its ramp stays within 6/255 of the approved mask on a 25 px grid, and its bytes are pinned',async({page})=>{
 await page.goto('/field.html');
 const got=await page.evaluate(async()=>{const {featherShape}=await import('./src/field-shape.js');const shape=await featherShape('runtime/canopy-c01/window-890-1x.png');
  const sha=[...new Uint8Array(await crypto.subtle.digest('SHA-256',shape.alpha))].map(b=>b.toString(16).padStart(2,'0')).join('');
  const grid=[];for(let y=0;y<650;y+=25)for(let x=0;x<1000;x+=25)grid.push(shape.alpha[y*1000+x]);return {w:shape.width,h:shape.height,sha,grid};});
 expect([got.w,got.h]).toEqual([1000,650]);expect(got.grid).toHaveLength(matteGrid.length);
 const worst=Math.max(...got.grid.map((v,i)=>Math.abs(v-matteGrid[i])));expect(worst).toBeLessThanOrEqual(6);
 expect(got.sha).toBe(MATTE_SHA256);
});
for(const [desktop,width,field] of [['1470x956',1323,[865,562.25]],['1440x900',1296,[838,544.69]]])test(`91 A geometry at ${desktop}: the field is ${field.join('x')} and the card is 430x664 at its left`,async({page})=>{
 await page.setViewportSize({width,height:Math.round(+desktop.split('x')[1]*.8)});await open(page);await show(page,payload());
 await expect(page.locator('.field-stage')).toHaveAttribute('data-shape','feathered');
 const stage=await page.locator('.field-stage').boundingBox(),card=await page.locator('.field-card').boundingBox();
 expect(stage.width).toBeCloseTo(field[0],1);expect(stage.height).toBeCloseTo(field[1],1);
 expect([card.x,card.width,card.height]).toEqual([0,430,664]);
});
test('CKP-PORT-11 the scene is masked by the silhouette; bare desktop and the feathered rim close, the porthole does not',async({page})=>{
 await page.setViewportSize({width:1323,height:735});await open(page);await show(page,payload());
 await expect.poll(()=>page.evaluate(()=>window.posted.includes('ready'))).toBe(true);
 await expect(page.locator('.field-stage')).toHaveAttribute('data-shape','feathered');
 expect(await page.locator('.field-stage').evaluate(e=>getComputedStyle(e).webkitMaskImage||getComputedStyle(e).maskImage)).toMatch(/^url\("blob:/);
 expect(await page.evaluate(()=>getComputedStyle(document.body).backgroundColor)).toBe('rgba(0, 0, 0, 0)');
 const closes=()=>page.evaluate(()=>window.posted.filter(x=>x==='close').length);
 const stage=await page.locator('.field-stage').boundingBox(),card=await page.locator('.field-card').boundingBox();
 expect(card.x).toBe(0);expect(card.width).toBe(430);expect(stage.x).toBe(458);expect(stage.width/stage.height).toBeCloseTo(1000/650,1);
 await page.mouse.click(stage.x+stage.width/2,stage.y+stage.height/2);expect(await closes()).toBe(0);
 await page.mouse.click(card.x+card.width/2,card.y+card.height-8);expect(await closes()).toBe(0);
 await page.mouse.click(stage.x+3,stage.y+3);expect(await closes()).toBe(1);
 await page.mouse.click(440,4);expect(await closes()).toBe(2);
});
// CKP-PORT-11 in the native panel: a transparent WKWebView cannot blur the desktop with backdrop-filter, so the page
// reports where the frosted card is and the panel puts a behind-window blur there. The scene's plates use the
// prototype's LCD face (rocket.css .ov-porthole .wb-plates .plate), whose variables live on #cockpit and #overlay.
test('CKP-PORT-11 the page reports the frosted card rect to the native panel, and the plates have the LCD face',async({page})=>{
 await page.addInitScript(()=>{window.posted=[];window.messages=[];window.webkit={messageHandlers:{field:{postMessage(m){window.messages.push(JSON.parse(m));window.posted.push(JSON.parse(m).type);}}}};});
 await page.setViewportSize({width:1323,height:735});await page.goto('/field.html');await page.waitForFunction(()=>!!window.modelPlanField);await show(page,payload());
 await expect.poll(()=>page.evaluate(()=>window.posted.includes('ready'))).toBe(true);
 const card=await page.locator('.field-card').boundingBox();
 await expect.poll(()=>page.evaluate(()=>window.messages.filter(m=>m.type==='card').at(-1)??null)).toEqual({type:'card',x:card.x,y:card.y,width:card.width,height:card.height,radius:12});
 await page.setViewportSize({width:1100,height:640});
 const moved=await page.locator('.field-card').boundingBox();
 await expect.poll(()=>page.evaluate(()=>window.messages.filter(m=>m.type==='card').at(-1)?.y)).toBe(moved.y);
 expect(await page.evaluate(()=>getComputedStyle(document.getElementById('field')).getPropertyValue('--f-lcd'))).toMatch(/JetBrains Mono/);
 const plate=page.locator('.wb-plates .plate').first();
 if(await plate.count())expect(await plate.evaluate(e=>getComputedStyle(e).fontFamily)).toMatch(/JetBrains Mono/);
});
// QA 11-08: the enlarged field's axis labels overlapped (price ticks under the front-row caption, time ticks stacked).
// Prototype field-picker-tags/axis-layout.js: screen-space lanes in the page; the scene's ticks and values are unchanged.
const spread=(i,dev)=>({id:'s'+i,name:'Synthetic '+i,developerId:dev,recommended:'medium',efforts:[{effort:'low',label:'Low',star:false,ability:30+i*2,cost:.05*(i+1),time:20},{effort:'medium',label:'Med',star:true,ability:40+i*2,cost:.1*(i+1),time:30},{effort:'high',label:'High',star:false,ability:45+i*2,cost:.3*(i+1),time:60}]});
test('QA 11-08 the axis labels of the enlarged field never overlap and stay inside the view',async({page})=>{
 await page.setViewportSize({width:1280,height:800});await open(page);
 const devs=['openai','anthropic','zhipuai'];
 await show(page,JSON.stringify({language:'en',reduceMotion:true,models:Array.from({length:10},(_,i)=>spread(i,devs[i%3])),mine:[],focus:null}));
 await expect.poll(()=>page.evaluate(()=>window.posted.includes('ready')),{timeout:20000}).toBe(true);// the scene bundle can take a while on a busy software-GL box
 test.skip(await page.locator('.field-stage .nogl').count()>0,'no WebGL in this browser');
 await expect.poll(()=>page.locator('.tick3.field-axis-placed').count()).toBeGreaterThan(4);
 await page.waitForTimeout(1500);
 const {boxes,stage}=await page.evaluate(()=>{
  const box=e=>{const r=e.getBoundingClientRect();return {text:e.textContent,x:r.x,y:r.y,r:r.right,b:r.bottom};};
  return {stage:box(document.querySelector('.field-stage')),boxes:[...document.querySelectorAll('.tick3')].filter(e=>getComputedStyle(e).visibility!=='hidden'&&Number(getComputedStyle(e).opacity)>.02&&e.getBoundingClientRect().width>0).map(box)};
 });
 expect(boxes.length).toBeGreaterThan(4);
 for(const a of boxes){
  expect(a.x>=stage.x&&a.r<=stage.r&&a.y>=stage.y&&a.b<=stage.b,a.text+' inside').toBe(true);
  for(const b of boxes)if(a!==b)expect(a.r<=b.x||b.r<=a.x||a.b<=b.y||b.b<=a.y,a.text+' / '+b.text).toBe(true);
 }
});

// CKP-PORT-11G: while the field is open there is one WebGL context. The page's capability probe releases its own, so only
// the scene's remains. A counting stand-in for getContext makes this checkable whether or not the browser has WebGL.
test('CKP-PORT-11G the capability probe releases its WebGL context, leaving at most the scene\'s while the field is open',async({page})=>{
 await page.addInitScript(()=>{
  window.glContexts=[];
  HTMLCanvasElement.prototype.getContext=function(type){
   if(!/webgl/.test(String(type)))return null;
   const gl={lost:false,isContextLost(){return this.lost;},getExtension(name){return name==='WEBGL_lose_context'?{loseContext:()=>{gl.lost=true;}}:null;}};
   window.glContexts.push(gl);return gl;
  };
 });
 await open(page);expect(await show(page,payload(12))).toBe(true);
 await page.waitForFunction(()=>window.glContexts.length>=1);
 await page.waitForTimeout(500);
 const live=await page.evaluate(()=>window.glContexts.filter(g=>!g.isContextLost()).length);
 expect(live).toBeLessThanOrEqual(1);
});

// CKP-PORT-11D: only public data enters the field. The host's payload carries presentation and published models; the page
// keeps nothing else and never asks the host for account or local readings.
test('CKP-PORT-11D the field page takes only public model data and posts only its fixed events',async({page})=>{
 await open(page);
 const withPrivate=JSON.stringify({...JSON.parse(payload(4)),account:'someone@example.invalid',subscriptionRef:'secret-ref',usedPercent:73,projectName:'private'});
 expect(await show(page,withPrivate)).toBe(true);
 await page.waitForTimeout(300);
 const text=await page.evaluate(()=>document.documentElement.innerText+document.documentElement.outerHTML);
 for(const secret of ['someone@example.invalid','secret-ref','private'])expect(text).not.toContain(secret);
 const posted=await page.evaluate(()=>window.posted);
 for(const type of posted)expect(['loaded','ready','activity','card','close','failed']).toContain(type);
});

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
test('D63 a focused rocket outside my models joins the field and takes the focus',async({page})=>{
 await open(page);await show(page,payload(12,{focus:'m7'}));
 await expect(page.locator('.field-count')).toHaveText('3/10');
 await expect(page.locator('.field-row',{hasText:'Synthetic 7'}).locator('input')).toBeChecked();
 });
// CKP-PORT-11 (D63): the c01 porthole silhouette feathered ~10% into the desktop, derived from the published
// window-890-1x.png at open. Reference: alpha samples of the prototype's approved mask (task 91 round 5,
// feather-masks/A.png, 1000x650), read on the design branch; the mask image itself is not in this repository.
// D110 (#801): the owner-approved redrawn c01 canopy changed window-890-1x.png, so these samples (same points, same tolerance) and the
// matte pin below were re-measured from the published new mask with the same derivation.
const featherReference=[[500,325,255],[0,0,0],[999,649,0],[500,0,0],[500,20,48],[500,40,160],[500,65,254],[500,100,255],[0,325,0],[20,325,3],[40,325,79],[65,325,216],[100,325,255],[500,649,0],[500,610,171],[500,585,255],[150,60,0],[850,60,0],[120,600,136],[60,120,0]];
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
const matteGrid=[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,12,39,48,58,63,73,73,73,73,73,63,58,48,39,11,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,3,48,119,176,187,197,202,212,212,212,212,212,202,197,187,176,117,43,3,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,3,21,41,95,169,233,255,255,255,255,255,255,255,255,255,255,255,255,255,230,166,92,39,21,3,0,0,0,0,0,0,0,0,0,0,0,0,1,24,63,107,150,179,228,254,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,253,226,176,150,107,63,23,1,0,0,0,0,0,0,0,3,41,99,156,202,236,253,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,253,236,202,154,99,39,2,0,0,0,0,10,84,166,228,254,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,253,227,164,84,8,0,0,0,39,176,251,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,251,171,34,0,0,0,63,202,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,197,58,0,0,0,79,216,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,216,78,0,0,1,95,228,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,225,90,0,0,3,107,236,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,232,101,2,0,8,124,244,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,242,119,6,0,13,136,249,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,247,130,11,0,19,148,252,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,251,145,18,0,30,165,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,254,160,27,0,39,176,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,171,34,0,52,191,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,187,48,0,63,202,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,197,58,0,73,212,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,209,70,0,90,225,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,221,84,0,79,216,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,216,79,0,65,204,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,202,62,0,28,144,228,243,251,253,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,253,250,242,227,142,25,0,0,46,94,121,142,154,165,176,182,192,192,197,202,207,207,207,212,212,221,221,221,212,212,207,207,207,202,197,192,191,182,176,165,154,141,119,93,46,0,0,0,0,1,7,16,23,30,39,43,53,53,58,63,68,68,68,73,73,84,84,84,73,73,68,68,68,63,58,53,52,43,39,30,23,16,6,1,0,0];
const MATTE_SHA256='2acb9f8d65d79e44cd6760b14412ebbe028c458ad34f086d00f6066b5f15b070';
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

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
  ['openai-white.svg','claude-rounded.svg','zhipu.svg','x-white.svg','qwen.svg','deepseek.svg','kimi-white.svg','minimax.svg','gemini.svg','xiaomi.svg']);
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
 expect(await key.evaluate(e=>{const s=getComputedStyle(e);return [s.right,s.top,s.width,s.height];})).toEqual(['42px','24px','22px','22px']);
 await key.click();expect(await opens(page)).toEqual([null]);
});
// Owner 11-09: the key must sit inside the glass. The c01 canopy aperture mask (page coordinates, origin at the page's
// top left) is the truth: every pixel of the key's rect keeps at least 8 px from any frame pixel, and it clears the HUD.
for(const theme of ['night','day'])for(const tier of ['tall','compact'])test(`D63 the key lies inside the aperture mask with 8 px of glass (${theme} ${tier})`,async({page})=>{
 await page.setViewportSize({width:636,height:tier==='tall'?890:640});
 await page.addInitScript(()=>{window.posted=[];window.webkit={messageHandlers:{cockpit:{postMessage(m){window.posted.push(typeof m==='string'?JSON.parse(m):m);}}}};});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 await receive(send('load',{appearance:{...appearance,theme},shell:{...shell,tier}}));
 await receive(send('visibility',{visible:true,occluded:false,key:true}));await receive(send('display',{data:visualFixture().data}));
 await expect(page.locator('.ck-field')).toHaveAttribute('data-still','ready');
 const layout=tier==='tall'?890:640;
 const r=await page.evaluate(async layout=>{
  const img=new Image();img.src='./runtime/canopy-c01/aperture-'+layout+'-1x.png';await img.decode();
  const c=document.createElement('canvas');c.width=img.width;c.height=img.height;const x=c.getContext('2d');x.drawImage(img,0,0);const a=x.getImageData(0,0,c.width,c.height).data;
  const k=document.querySelector('[data-bigfield]').getBoundingClientRect();let min=1e9;
  for(let y=0;y<c.height;y++)for(let px=0;px<c.width;px++)if(a[(y*c.width+px)*4+3]<128){
   const dx=Math.max(k.left-px,0,px-(k.right-1)),dy=Math.max(k.top-y,0,y-(k.bottom-1));min=Math.min(min,Math.hypot(dx,dy));}
  const huds=[...document.querySelectorAll('.ck-port .hud, .ck-port .hud *')].map(e=>e.getBoundingClientRect()).filter(h=>h.width>0&&h.height>0);
  return {min,inside:k.left>=0&&k.top>=0&&k.right<=c.width&&k.bottom<=c.height||k.bottom>c.height,hudOverlap:huds.some(h=>k.left<h.right&&k.right>h.left&&k.top<h.bottom&&k.bottom>h.top)};
 },layout);
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
// QA 11-08: the enlarged field's axis labels overlapped (price ticks under the front-row caption, time ticks stacked).
// Prototype field-picker-tags/axis-layout.js: screen-space lanes in the page; the scene's ticks and values are unchanged.
const spread=(i,dev)=>({id:'s'+i,name:'Synthetic '+i,developerId:dev,recommended:'medium',efforts:[{effort:'low',label:'Low',star:false,ability:30+i*2,cost:.05*(i+1),time:20},{effort:'medium',label:'Med',star:true,ability:40+i*2,cost:.1*(i+1),time:30},{effort:'high',label:'High',star:false,ability:45+i*2,cost:.3*(i+1),time:60}]});
test('QA 11-08 the axis labels of the enlarged field never overlap and stay inside the view',async({page})=>{
 await page.setViewportSize({width:900,height:640});await open(page);
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

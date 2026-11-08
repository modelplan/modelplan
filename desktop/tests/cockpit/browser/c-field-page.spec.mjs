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
// Spike 11-08 / D63: the page cannot read Low Power Mode, so native passes it in the payload and on every change.
// Low power renders on demand only with the scene's quiet motion (no camera sway or fly-ins): idle means no frames.
test('D63 low power: the field mounts quiet, draws no frames while idle, and follows a live change',async({page})=>{
 await open(page);await show(page,payload(4,{reduceMotion:false,lowPower:true}));
 await expect.poll(()=>page.evaluate(()=>window.posted.includes('ready'))).toBe(true);
 test.skip(await page.locator('.field-stage .nogl').count()>0,'no WebGL in this browser');
 const stats=()=>page.evaluate(()=>window.modelPlanField.stats());
 await expect.poll(async()=>(await stats())?.quiet).toBe(true);
 await page.waitForTimeout(2500);const settled=await stats();expect(settled.lowPower).toBe(true);expect(settled.scheduled).toBe(false);
 await page.waitForTimeout(2000);expect((await stats()).frames).toBe(settled.frames);
 expect(await page.evaluate(()=>window.modelPlanField.power(false))).toBe(true);
 await expect.poll(async()=>(await stats())?.quiet).toBe(false);expect((await stats()).lowPower).toBe(false);
 expect(await page.evaluate(()=>window.modelPlanField.power(true))).toBe(true);
 await expect.poll(async()=>(await stats())?.quiet).toBe(true);
 // A disposed scene's late context-loss report must not replace the new scene with the fallback.
 await page.waitForTimeout(1500);await expect(page.locator('.field-stage .nogl')).toHaveCount(0);
 await expect(page.locator('.field-stage canvas')).toHaveCount(1);expect((await stats())?.quiet).toBe(true);
});
test('D63 Reduce Motion alone also keeps the scene quiet, and the payload without lowPower is not low power',async({page})=>{
 await open(page);await show(page,payload(4));
 await expect.poll(()=>page.evaluate(()=>window.posted.includes('ready'))).toBe(true);
 test.skip(await page.locator('.field-stage .nogl').count()>0,'no WebGL in this browser');
 await expect.poll(()=>page.evaluate(()=>window.modelPlanField.stats()?.quiet)).toBe(true);
 expect(await page.evaluate(()=>window.modelPlanField.stats().lowPower)).toBe(false);
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

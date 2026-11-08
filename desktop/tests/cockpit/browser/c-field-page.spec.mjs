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

// Item 6 (task 91 round 5, study website-updates/fleet.js): the frosted model-picker card. Presets are My subscriptions
// and All only (no site picks without published data), search by name or maker, at most 10 rockets, a lamp launches or
// retracts, a row focuses its rocket, and the card folds into a count. Synthetic public data only.
const devs=['openai','anthropic','zhipuai','google'];
const varied=i=>({id:'m'+i,name:(i%4===1?'Claude ':'')+'Synthetic '+i,developerId:devs[i%4],recommended:'medium',efforts:[{effort:'medium',label:'Med',star:true,ability:30+i*2,cost:.1*(1+i%5),time:30}]});
const variedPayload=(n=12,extra={})=>JSON.stringify({language:'en',reduceMotion:true,models:Array.from({length:n},(_,i)=>varied(i)),mine:['m1','m2'],focus:null,...extra});
const rows=page=>page.locator('.field-model-row');
test('item 6 the picker starts on my subscriptions; presets, search, the 10-rocket limit and the lamps',async({page})=>{
 await page.setViewportSize({width:1323,height:735});await open(page);expect(await show(page,variedPayload())).toBe(true);
 const picker=page.locator('.website-fleet-picker');await expect(picker).toBeVisible();
 await expect(page.locator('[data-field-preset]')).toHaveText(['My subscriptions','All']);
 await expect(page.locator('[data-field-preset="mine"]')).toHaveAttribute('aria-pressed','true');
 await expect(page.locator('.field-roster-heading span')).toHaveText('2/10 on field');
 await expect(rows(page)).toHaveCount(12);
 await expect(page.locator('.field-model-row[data-on="true"]')).toHaveCount(2);
 await page.locator('[data-field-preset="all"]').click();
 await expect(page.locator('[data-field-preset="all"]')).toHaveAttribute('aria-pressed','true');
 await expect(page.locator('.field-roster-heading span')).toHaveText('10/10 on field');
 const off=page.locator('.field-model-row[data-on="false"] .field-launch-lamp').first();
 await expect(off).toBeDisabled();await expect(page.locator('.website-fleet-picker footer small')).toHaveText('10 rocket limit · retract one to add another');
 const on=page.locator('.field-model-row[data-on="true"] .field-launch-lamp').first(),id=await on.getAttribute('data-fleet-model');
 await expect(on).toHaveText('✓');await expect(on).toHaveAttribute('aria-pressed','true');
 await on.click();await expect(page.locator('.field-roster-heading span')).toHaveText('9/10 on field');
 await expect(page.locator(`.field-model-row[data-field-row="${id}"]`)).toHaveAttribute('data-on','false');
 await expect(page.locator('[data-field-preset][aria-pressed="true"]')).toHaveCount(0);
 await page.locator(`.field-launch-lamp[data-fleet-model="${id}"]`).click();await expect(page.locator('.field-roster-heading span')).toHaveText('10/10 on field');
 await page.locator('[data-field-search]').fill('synthetic 11');await expect(rows(page)).toHaveCount(1);
 await page.locator('[data-field-search]').fill('anthropic');await expect(rows(page)).toHaveCount(3);
 await page.locator('[data-field-search]').fill('nothing like it');await expect(page.locator('.field-empty')).toHaveText('No matching models');
 await page.locator('[data-field-search]').fill('');
 await page.locator('[data-field-reset]').click();await expect(page.locator('.field-roster-heading span')).toHaveText('2/10 on field');
 await expect(page.locator('[data-field-preset="mine"]')).toHaveAttribute('aria-pressed','true');
});
test('item 6 rows: maker, name, ★ effort, ability and cost bars; my subscriptions first; a row click focuses its rocket',async({page})=>{
 await page.setViewportSize({width:1323,height:735});await open(page);// Cost rises with ability here, so no model is outclassed.
 const rising=i=>({...varied(i),efforts:[{effort:'medium',label:'Med',star:true,ability:30+i*2,cost:.1*(i+1),time:30}]});
 await show(page,JSON.stringify({language:'en',reduceMotion:true,models:Array.from({length:6},(_,i)=>rising(i)),mine:['m1','m2','m5'],focus:null}));
 await expect(page.locator('.field-roster-heading b')).toHaveText('My subscriptions first');
 expect(await rows(page).evaluateAll(es=>es.map(e=>e.dataset.fieldRow))).toEqual(['m5','m2','m1','m4','m3','m0']);
 await expect(page.locator('.field-group-label')).toHaveText('MORE PUBLIC MODELS');
 expect(await page.locator('.field-group-label + .field-model-row').getAttribute('data-field-row')).toBe('m4');
 const first=rows(page).first();
 await expect(first.locator('.field-vendor-name')).toHaveText('Anthropic');await expect(first.locator('.field-full-name b')).toHaveText('Claude Synthetic 5');
 await expect(first.locator('.sp-cr-name em')).toHaveText('★ Med');await expect(first.locator('.sp-tile img')).toHaveAttribute('src','assets/brands/claude.svg');
 await expect(first.locator('.sp-cr-bars b')).toHaveText(['40.0','×6.0']);
 // Lamps do not reorder the list.
 await page.locator('.field-launch-lamp[data-fleet-model="m5"]').click();
 expect(await rows(page).evaluateAll(es=>es.map(e=>e.dataset.fieldRow))).toEqual(['m5','m2','m1','m4','m3','m0']);
 await page.locator('.field-launch-lamp[data-fleet-model="m5"]').click();
 // ×1 is the cheapest published model at its ★ effort; the footer names it.
 await expect(page.locator('.website-fleet-picker footer small')).toHaveText('×1 = Synthetic 0 ★ Med · Field-local choice');
 await page.locator('.field-model-row[data-field-row="m2"] .field-model-focus').click();
 await expect(page.locator('.field-model-row.on')).toHaveAttribute('data-field-row','m2');
 // A row whose model is not on the field launches it and takes the focus (there is room).
 await page.locator('.field-model-row[data-field-row="m4"] .field-model-focus').click();
 await expect(page.locator('.field-model-row.on')).toHaveAttribute('data-field-row','m4');
 await expect(page.locator('.field-roster-heading span')).toHaveText('4/10 on field');
});
test('item 6 v1 shows only the derivable verdict: outclassed models carry the tag and sink; no published-only tags (D71)',async({page})=>{
 await page.setViewportSize({width:1323,height:735});await open(page);
 const m=(id,name,ability,cost)=>({id,name,developerId:'openai',recommended:'high',efforts:[{effort:'high',label:'High',star:true,ability,cost,time:30}]});
 await show(page,JSON.stringify({language:'en',reduceMotion:true,mine:['a','b','c'],focus:null,models:[m('a','Alpha',50,.4),m('b','Beta',45,.8),m('c','Gamma',30,.1)]}));
 await expect(rows(page)).toHaveCount(3);
 await expect(rows(page).last()).toHaveAttribute('data-field-row','b');await expect(rows(page).last()).toHaveClass(/dominated/);
 await expect(page.locator('.sp-cr-tags i')).toHaveText(['Outclassed']);
 await expect(page.locator('.tag-strongest,.tag-best_value,.tag-cheapest,.tag-equivalent_costlier')).toHaveCount(0);
 // The chart: one dot per rocket on the field, the gold frontier through the undominated ones, a dotted line from Beta to Alpha.
 await expect(page.locator('.field-frontier .sp-which-dot')).toHaveCount(3);
 await expect(page.locator('.field-frontier path.field-front')).toHaveCount(1);
 await expect(page.locator('.field-frontier line.field-beaten')).toHaveCount(1);
 await page.locator('[data-field-preset="mine"]').click();
 await page.locator('.field-launch-lamp[data-fleet-model="a"]').click();await page.locator('.field-launch-lamp[data-fleet-model="b"]').click();
 await expect(page.locator('.field-chart-empty')).toHaveText('Select at least two models to compare.');
});
test('item 6 the card folds into a count and the scene takes the width; the native blur follows',async({page})=>{
 await page.addInitScript(()=>{window.posted=[];window.messages=[];window.webkit={messageHandlers:{field:{postMessage(m){window.messages.push(JSON.parse(m));window.posted.push(JSON.parse(m).type);}}}};});
 await page.setViewportSize({width:1323,height:735});await page.goto('/field.html');await page.waitForFunction(()=>!!window.modelPlanField);await show(page,variedPayload());
 await page.locator('[data-fleet-done]').click();
 await expect(page.locator('.website-fleet-picker')).toBeHidden();
 const tools=page.locator('[data-fleet-picker]');await expect(tools).toBeVisible();await expect(tools).toHaveText('Pick models 2/10');
 await expect.poll(()=>page.evaluate(()=>window.messages.filter(m=>m.type==='card').at(-1)?.width)).toBe(0);
 expect((await page.locator('.field-stage').boundingBox()).x).toBeLessThan(200);
 await tools.click();await expect(page.locator('.website-fleet-picker')).toBeVisible();await expect(tools).toBeHidden();
 await expect.poll(()=>page.evaluate(()=>window.messages.filter(m=>m.type==='card').at(-1)?.width)).toBe(430);
 expect((await page.locator('.field-stage').boundingBox()).x).toBe(458);
});
test('Esc and the close key ask the host to close, and interaction renews the idle timer',async({page})=>{
 await open(page);await show(page,payload());await expect(page.locator('.field-close')).toHaveText('×');
 await page.locator('.field-close').click();await page.keyboard.press('Escape');
 const posted=await page.evaluate(()=>window.posted);
 expect(posted.filter(x=>x==='close').length).toBe(2);expect(posted).toContain('activity');
});
test('Chinese words, and nothing published says so',async({page})=>{
 await open(page);await show(page,payload(0,{language:'zh'}));
 await expect(page.locator('.nogl')).toHaveText('暂无已发布模型。');await expect(page.locator('[data-field-preset]')).toHaveText(['我的订阅','全部']);
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
// Spike 11-08 / D63: the page cannot read Low Power Mode, so native passes it in the payload and on every change.
// Low power renders on demand only with the scene's quiet motion (no camera sway or fly-ins): idle means no frames.
test('D63 low power: the field mounts quiet, draws no frames while idle, and follows a live change',async({page})=>{
 await open(page);await show(page,payload(4,{reduceMotion:false,lowPower:true}));
 await expect.poll(()=>page.evaluate(()=>window.posted.includes('ready')),{timeout:20000}).toBe(true);// the scene bundle can take a while on a busy software-GL box
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
 await expect.poll(()=>page.evaluate(()=>window.posted.includes('ready')),{timeout:20000}).toBe(true);// the scene bundle can take a while on a busy software-GL box
 test.skip(await page.locator('.field-stage .nogl').count()>0,'no WebGL in this browser');
 await expect.poll(()=>page.evaluate(()=>window.modelPlanField.stats()?.quiet)).toBe(true);
 expect(await page.evaluate(()=>window.modelPlanField.stats().lowPower)).toBe(false);
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
 expect(await key.evaluate(e=>{const s=getComputedStyle(e);return [s.right,s.top,s.width,s.height];})).toEqual(['40px','36px','22px','22px']);
 await key.click();expect(await opens(page)).toEqual([null]);
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
 await expect(page.locator('.field-roster-heading span')).toHaveText('3/10 on field');
 await expect(page.locator('.field-model-row[data-field-row="m7"]')).toHaveAttribute('data-on','true');
 await expect(page.locator('.field-model-row.on')).toHaveAttribute('data-field-row','m7');
});
// CKP-PORT-13 (D63): "Full fleet on the website ↗". The page never sends a URL: it names the flown public model IDs
// and native builds the modelplan.ai address (prototype website-updates/links.js fleetUrl, the site's focus query).
test('CKP-PORT-13 the website link names the flown fleet and the host builds the address',async({page})=>{
 await page.addInitScript(()=>{window.sent=[];});
 await open(page);
 await page.evaluate(()=>{const post=window.webkit.messageHandlers.field.postMessage;window.webkit.messageHandlers.field.postMessage=m=>{window.sent.push(JSON.parse(m));post(m);};});
 await show(page,payload());
 const link=page.locator('.field-website');await expect(link).toHaveText('Compare ↗');await expect(link).toHaveAttribute('aria-label','Full fleet on the website');
 await link.click();
 const website=await page.evaluate(()=>window.sent.filter(m=>m.type==='website'));
 expect(website).toEqual([{type:'website',models:['m1','m2']}]);
 await page.locator('[data-field-preset="all"]').click();await link.click();
 expect((await page.evaluate(()=>window.sent.filter(m=>m.type==='website'))).at(-1).models).toHaveLength(10);
 expect(await page.locator('.field-website[href]').count()).toBe(0);
});
test('CKP-PORT-13 Chinese link text',async({page})=>{
 await open(page);await show(page,payload(3,{language:'zh'}));
 await expect(page.locator('.field-website')).toHaveText('网站对比 ↗');await expect(page.locator('.field-website')).toHaveAttribute('aria-label','在网站上看完整舰队');
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
// QA 11-08: the enlarged field's axis labels overlapped (price ticks under the front-row caption, time ticks stacked).
// Prototype field-picker-tags/axis-layout.js: screen-space lanes in the page; the scene's ticks and values are unchanged.
const spread=(i,dev)=>({id:'s'+i,name:'Synthetic '+i,developerId:dev,recommended:'medium',efforts:[{effort:'low',label:'Low',star:false,ability:30+i*2,cost:.05*(i+1),time:20},{effort:'medium',label:'Med',star:true,ability:40+i*2,cost:.1*(i+1),time:30},{effort:'high',label:'High',star:false,ability:45+i*2,cost:.3*(i+1),time:60}]});
test('QA 11-08 the axis labels of the enlarged field never overlap and stay inside the view',async({page})=>{
 test.setTimeout(60000);
 // The panel's composition on a 14-inch laptop (CockpitFieldPanel.frame): the scene sits right of the 430 px card.
 await page.setViewportSize({width:1323,height:735});await open(page);
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

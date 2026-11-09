// SPDX-License-Identifier: MIT
// The enlarged field's page, with synthetic public model data. WebGL may be absent here, which exercises the fallback.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {createHash} from 'node:crypto';
import {readFileSync} from 'node:fs';
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
test('item 6 v1 shows the derivable verdict: outclassed models carry the tag and sink; no published-only tags (D71)',async({page})=>{
 await page.setViewportSize({width:1323,height:735});await open(page);
 const m=(id,name,ability,cost)=>({id,name,developerId:'openai',recommended:'high',efforts:[{effort:'high',label:'High',star:true,ability,cost,time:30}]});
 await show(page,JSON.stringify({language:'en',reduceMotion:true,mine:['a','b','c'],focus:null,models:[m('a','Alpha',50,.4),m('b','Beta',45,.8),m('c','Gamma',30,.1)]}));
 await expect(rows(page)).toHaveCount(3);
 await expect(rows(page).last()).toHaveAttribute('data-field-row','b');await expect(rows(page).last()).toHaveClass(/dominated/);
 await expect(page.locator('.sp-cr-tags i')).toHaveText(['Outclassed']);// no published tags in this payload, so no verdict label (D92)
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
// D92 (revised): the picker labels each model with the published lineup verdicts its `tags` carry (strongest, best_value,
// cheapest), the same as the website; nothing is computed in the field, and a model with no published tags shows none.
const tagModel=(id,ability,cost,tags)=>({id,name:'Tag '+id,developerId:'openai',recommended:'medium',efforts:[{effort:'medium',label:'Med',star:true,ability,cost,time:30}],...(tags?{tags}:{})});
const tagRows=async page=>{await page.waitForSelector('.field-model-row');return page.evaluate(()=>Object.fromEntries([...document.querySelectorAll('.field-model-row')].map(r=>[r.dataset.fieldRow,[...r.querySelectorAll('.sp-cr-tags i:not(.tag-dominated)')].map(i=>i.className.replace('tag-','')+':'+i.textContent)])));};
async function tagged(page,models,mine,language='en'){await open(page);await show(page,JSON.stringify({language,reduceMotion:true,models,mine,focus:null}));return tagRows(page);}
test('D92 each model shows the published verdicts it carries, in the fixed order, whatever the field holds',async({page})=>{
 const rows=await tagged(page,[tagModel('a',50,2,['cheapest','strongest']),tagModel('b',60,3,['best_value']),tagModel('c',40,1),tagModel('d',99,.1,['strongest'])],['a','b']);
 expect(rows).toEqual({a:['strongest:Strongest','cheapest:Cheapest'],b:['best_value:Best value'],c:[],d:['strongest:Strongest']});
});
test('D92 the Chinese labels, with 最值 for best value as on the website',async({page})=>{
 const rows=await tagged(page,[tagModel('a',50,2,['strongest']),tagModel('b',60,3,['best_value']),tagModel('c',40,1,['cheapest'])],['a','b','c'],'zh');
 expect([rows.a,rows.b,rows.c]).toEqual([['strongest:最强'],['best_value:最值'],['cheapest:最省']]);
});
test('D92 a publication without tags (an older CLI) shows no label, and unknown tags are ignored',async({page})=>{
 expect(await tagged(page,[tagModel('a',50,2),tagModel('b',60,3)],['a','b'])).toEqual({a:[],b:[]});
 expect(await tagged(page,[tagModel('a',50,2,['dominated','equivalent_costlier','mystery']),tagModel('b',60,3,[])],['a','b'])).toEqual({a:[],b:[]});
});
test('D92 published ties and several verdicts on one model are shown as published',async({page})=>{
 expect(await tagged(page,[tagModel('a',60,2,['strongest','best_value','cheapest']),tagModel('b',60,3,['strongest']),tagModel('c',40,2,['cheapest'])],['a','b','c'])).toEqual({a:['strongest:Strongest','best_value:Best value','cheapest:Cheapest'],b:['strongest:Strongest'],c:['cheapest:Cheapest']});
});
// D93: the Site picks tab is the website's default focus set (`defaultSelected` on the published model), between
// My subscriptions and All; it is hidden for a publication without that field (an older CLI) and capped at ten.
const siteModels=(n,picked)=>Array.from({length:n},(_,i)=>({...tagModel('s'+i,40+i,.1*(i+1)),...(picked===null?{}:{defaultSelected:picked.includes(i)})}));
const siteField=async(page,models,language='en')=>{await open(page);await show(page,JSON.stringify({language,reduceMotion:true,models,mine:['s0'],focus:null}));await page.waitForSelector('.field-model-row');};
const flownIds=page=>page.evaluate(()=>[...document.querySelectorAll('.field-model-row[data-on="true"]')].map(r=>r.dataset.fieldRow).sort((a,b)=>a.localeCompare(b,'en',{numeric:true})));
test('D93 Site picks lists exactly the defaultSelected models, between My subscriptions and All',async({page})=>{
 await siteField(page,siteModels(8,[1,3,4]));
 await expect(page.locator('[data-field-preset]')).toHaveText(['My subscriptions','Site picks','All']);
 expect(await flownIds(page)).toEqual(['s0']);
 await page.locator('[data-field-preset="site"]').click();
 await expect(page.locator('[data-field-preset="site"]')).toHaveAttribute('aria-pressed','true');
 expect(await flownIds(page)).toEqual(['s1','s3','s4']);
 await page.locator('[data-field-preset="all"]').click();expect(await flownIds(page)).toHaveLength(8);
});
test('D93 Site picks is capped at ten, in publication order',async({page})=>{
 await siteField(page,siteModels(14,[...Array(13).keys()].map(i=>i+1)));
 await page.locator('[data-field-preset="site"]').click();
 expect(await flownIds(page)).toEqual(Array.from({length:10},(_,i)=>'s'+(i+1)));
 await expect(page.locator('.field-count,.field-roster-heading span').first()).toBeVisible();
});
test('D93 the tab is hidden when the publication has no defaultSelected, or none is selected',async({page})=>{
 await siteField(page,siteModels(6,null));
 await expect(page.locator('[data-field-preset]')).toHaveText(['My subscriptions','All']);
 await siteField(page,siteModels(6,[]));
 await expect(page.locator('[data-field-preset]')).toHaveText(['My subscriptions','All']);
});
test('D93 the Chinese label',async({page})=>{
 await siteField(page,siteModels(6,[2]),'zh');
 await expect(page.locator('[data-field-preset]')).toHaveText(['我的订阅','网站推荐','全部']);
});
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
test('CKP-PORT-13 the link lives only in the picker card footer (the study), with no top bar, and is disabled at 0/10',async({page})=>{
 await open(page);await show(page,payload());
 await expect(page.locator('.field-website')).toHaveCount(1);
 await expect(page.locator('.field-card footer .field-website')).toHaveCount(1);
 await expect(page.locator('.field-bar')).toHaveCount(0);
 const link=page.locator('.field-website');await expect(link).toBeEnabled();
 while(await page.locator('.field-model-row[data-on="true"] .field-launch-lamp').count())await page.locator('.field-model-row[data-on="true"] .field-launch-lamp').first().click();
 await expect(link).toBeDisabled();
});
test('CKP-PORT-13 Chinese link text',async({page})=>{
 await open(page);await show(page,payload(3,{language:'zh'}));
 await expect(page.locator('.field-website')).toHaveText('网站对比 ↗');await expect(page.locator('.field-website')).toHaveAttribute('aria-label','在网站上看完整舰队');
});
// CKP-PORT-11 (D63): the c01 porthole silhouette feathered ~10% into the desktop, derived from the published
// window-890-1x.png at open. Reference: alpha samples of the prototype's approved mask (task 91 round 5,
// feather-masks/A.png, 1000x650), read on the design branch; the mask image itself is not in this repository.
// 91 A pins (owner 11-09): the approved matte (task 91 A, feather-masks/A.png) ships byte for byte and the page reads it.
const MATTE_ASSET_SHA256='4c476c2a5dcb902065b20f9e365a2df5d1ac0cab8857f0d154dd45fb8f31ec41';
const matteGrid=[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,13,52,90,90,90,90,90,90,90,90,90,90,90,90,90,90,90,90,90,90,90,90,90,90,90,90,90,53,14,0,0,0,0,0,0,0,0,0,16,69,135,192,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,192,135,69,16,0,0,0,0,0,0,41,125,199,246,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,246,199,125,43,0,0,0,0,13,136,228,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,230,139,14,0,0,0,30,165,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,165,30,0,0,0,45,184,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,187,48,0,0,0,58,197,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,197,58,0,0,0,72,211,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,212,73,0,0,0,84,221,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,221,84,0,0,1,95,228,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,232,100,1,0,4,113,239,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,239,113,4,0,8,125,244,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,244,125,8,0,16,141,250,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,251,142,16,0,23,154,253,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,253,154,23,0,30,165,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,168,32,0,43,182,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,182,43,0,53,192,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,192,53,0,67,206,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,207,68,0,79,216,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,216,79,0,73,212,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,214,75,0,53,192,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,194,55,0,22,144,246,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,246,144,22,0,0,69,184,229,244,251,254,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,254,251,244,230,184,69,0,0,0,8,58,97,124,142,159,171,176,184,192,197,197,207,207,207,212,212,216,221,216,212,212,207,207,207,197,197,192,184,176,171,159,142,124,98,59,8,0,0,0,0,0,1,8,16,26,34,39,45,53,58,58,68,68,68,73,73,79,84,79,73,73,68,68,68,58,58,53,45,39,34,26,16,8,1,0,0,0];
test('91 A the approved matte ships byte for byte, is 1000x650, and the page reads exactly its alpha',async({page})=>{
 await page.goto('/field.html');
 const got=await page.evaluate(async()=>{const url='runtime/canopy-c01/field-matte-A-1000x650.png';
  const {featherShape}=await import('./src/field-shape.js');const shape=await featherShape(url);
  const grid=[];for(let y=0;y<650;y+=25)for(let x=0;x<1000;x+=25)grid.push(shape.alpha[y*1000+x]);return {w:shape.width,h:shape.height,grid,mask:shape.maskUrl.endsWith('field-matte-A-1000x650.png')};});
 expect(createHash('sha256').update(readFileSync(new URL('../../../official-visuals/runtime/canopy-c01/field-matte-A-1000x650.png',import.meta.url))).digest('hex')).toBe(MATTE_ASSET_SHA256);expect([got.w,got.h]).toEqual([1000,650]);
 expect(got.grid).toEqual(matteGrid);expect(got.mask).toBe(true);
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
 expect(await page.locator('.field-stage').evaluate(e=>getComputedStyle(e).webkitMaskImage||getComputedStyle(e).maskImage)).toMatch(/^url\("http:\/\/[^"]+\/runtime\/canopy-c01\/field-matte-A-1000x650\.png"\)$/);
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

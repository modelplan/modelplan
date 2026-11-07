// SPDX-License-Identifier: MIT
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {readFileSync} from 'node:fs';
import {commands,pageId,appearance,shell,sample,excludePortholeFlicker} from '../fixture.mjs';
test.beforeEach(async({page})=>excludePortholeFlicker(page));
const start='2026-10-29T12:00:00Z',at='2026-10-29T12:02:00Z',week='2026-10-29T12:20:00Z';
function dataFor(details=false){
 const data=sample(),projection=JSON.parse(readFileSync(new URL('../../../../schema/app-cli/captures/rows-model-scope.json',import.meta.url)));delete projection.consentGeneration;data.projection=projection;const row=projection.rows[0],a=row.accounts[0],w=a.windows[0];delete w.modelScope;row.expiresAt=at;a.valueState='current';a.lastFailure=null;a.observedAt=start;a.freshUntil=week;
 a.windows=[{...w,id:'session:18000:main:main',role:'session',durationSeconds:18000,label:{en:'Session',zh:'会话'},remainingPercent:0,current:true,observedAt:start,resetsAt:at,validUntil:at},{...w,id:'weekly:604800:main:main',role:'weekly',durationSeconds:604800,label:{en:'Weekly',zh:'每周'},remainingPercent:80,current:true,observedAt:start,resetsAt:week,validUntil:week}];
 if(details)data.details={version:1,sources:['quota-thresholds'],subscriptions:[],sessions:[],sessionCoverage:'unavailable',resetEvents:[],alerts:[{source:row.id,subscriptionRef:a.subscriptionRef,windowId:a.windows[0].id,severity:'critical',remainingPercent:0}]};return data;
}
async function open(page,data){
 await page.addInitScript(()=>{window.__messages=[];window.webkit={messageHandlers:{cockpit:{postMessage(raw){window.__messages.push(JSON.parse(raw));}}}};});
 await page.clock.install({time:new Date(start)});await page.clock.pauseAt(new Date(start));await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit?.receive(raw)??false,raw),tick=(time,reason='deadline',extra={})=>receive(send('tick',{nowUnixMs:String(Date.parse(time)),reason,...extra}));
 expect(await receive(send('load',{appearance,shell}))).toBe(true);expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);expect(await receive(send('display',{data}))).toBe(true);return {send,receive,tick};
}
async function check(page,expired){const first=page.locator('.eng-cols .ec').first().locator('.qcell[data-row="first"]'),weekly=page.locator('.eng-cols .ec').first().locator('.qcell[data-row="second"]');await expect(first.locator('.qvalue')).toHaveText(expired?'--':'0');await expect(weekly.locator('.qvalue')).toHaveText('80');if(expired){await expect(page.locator('.s6-alert')).not.toHaveClass(/lit|red/);await expect(page.locator('.mfd-page .al-red')).toHaveCount(0);}else{await expect(page.locator('.s6-alert')).toHaveClass(/red/);await expect(page.locator('.mfd-page .al-red')).toHaveCount(1);}}
async function reports(page){return page.evaluate(()=>window.__messages.filter(m=>m.type==='nextDeadline'));}
for(const details of [false,true])test(`native tick withdraws elapsed current zero (${details?'details':'no details'})`,async({page})=>{
 const {tick}=await open(page,dataFor(details));await check(page,false);expect((await reports(page)).at(-1).deadlineUnixMs).toBe(String(Date.parse(at)));
 expect(await tick('2026-10-29T12:01:59.999Z')).toBe(true);await check(page,false);
 expect(await tick(at)).toBe(true);await check(page,true);expect((await reports(page)).at(-1).deadlineUnixMs).toBe(String(Date.parse(week)));
 expect(await tick('2026-10-29T12:02:01Z')).toBe(true);await check(page,true);
});
test('reset event has its own deadline and tick',async({page})=>{
 const data=dataFor(true),a=data.projection.rows[0].accounts[0];a.windows[0].remainingPercent=80;a.windows[0].validUntil=week;a.windows[0].resetsAt=week;data.projection.rows[0].expiresAt=week;data.details.alerts=[];data.details.resetEvents=[{version:1,id:'synthetic-reset',provider:'openai',rowId:data.projection.rows[0].id,status:'announced',publishedAt:start,expiresAt:at,source:{kind:'publication',publicationId:'0123456789abcdef01234567'}}];
 const {tick}=await open(page,data);expect((await reports(page)).at(-1).deadlineUnixMs).toBe(String(Date.parse(at)));await expect(page.locator('.s6-alert')).not.toHaveClass(/lit|amber|red/);await expect(page.locator('.pg-overview .mfd-alerts li.al-blue')).toContainText('Reset announced');expect(await tick(at)).toBe(true);await expect(page.locator('.pg-overview .mfd-alerts li')).toHaveCount(0);await expect(page.locator('.s6-alert')).not.toHaveClass(/lit|amber|red/);expect((await reports(page)).at(-1).deadlineUnixMs).toBe(String(Date.parse(week)));
});
test('replacement, stale context, hidden and show tick preserve current data',async({page})=>{
 const data=dataFor(),{send,receive,tick}=await open(page,data);data.projection.rows[0].accounts[0].windows[0].resetsAt=week;data.projection.rows[0].accounts[0].windows[0].validUntil=week;data.projection.rows[0].expiresAt=week;expect(await receive(send('display',{data}))).toBe(true);expect((await reports(page)).at(-1).deadlineUnixMs).toBe(String(Date.parse(week)));
 expect(await tick(at,'deadline',{generation:'40'})).toBe(false);expect(await tick(at)).toBe(true);await check(page,false);
 expect(await receive(send('visibility',{visible:false,occluded:false,key:false}))).toBe(true);const n=(await reports(page)).length;expect(await tick(week)).toBe(false);expect((await reports(page)).length).toBe(n);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);expect((await reports(page)).length).toBe(n);expect(await tick(week,'show')).toBe(true);await expect(page.locator('.eng-cols .ec').first().locator('.qcell[data-row="first"] .qvalue')).toHaveText('--');await expect(page.locator('.s6-alert')).not.toHaveClass(/lit|red/);expect((await reports(page)).at(-1).deadlineUnixMs).toBeNull();
});
for(const end of ['clear','unload'])test(`${end} forbids later tick or deadline report`,async({page})=>{
 const {send,receive,tick}=await open(page,dataFor());expect(await receive(send(end,end==='clear'?{viewRevision:'4'}:{}))).toBe(true);const n=(await reports(page)).length;
 expect(await tick(at)).toBe(false);expect((await reports(page)).length).toBe(n);await expect(page.locator('.qcell')).toHaveCount(0);
});
test('expiry tick preserves scope, page, focus and fader node identity',async({page})=>{
 const data=dataFor(true),{send,receive,tick}=await open(page,data);expect(await receive(send('shell',{...shell,scope:data.projection.rows[0].accounts[0].subscriptionRef}))).toBe(true);
 const plans=page.getByRole('button',{name:'Subscription',exact:true});await plans.click();await plans.focus();await page.evaluate(()=>window.__channel=document.querySelector('.fd-ch'));
 expect(await tick(at)).toBe(true);await expect(plans).toBeFocused();await expect(plans).toHaveAttribute('aria-pressed','true');await expect(page.locator('#cockpit')).toHaveAttribute('data-scope','subscription');expect(await page.evaluate(()=>window.__channel===document.querySelector('.fd-ch'))).toBe(true);
 const windows=page.locator('.mfd-page .sp-w');await expect(windows.filter({hasText:'Session'})).toContainText('--');await expect(windows.filter({hasText:'Weekly'})).toContainText('80%');
});
test('native expiry preserves an active shutter drag',async({page})=>{
 const {tick}=await open(page,dataFor());const shutter=page.locator('[data-shutter]'),box=await shutter.boundingBox();expect(box).not.toBeNull();
 await page.mouse.move(box.x+box.width/2,box.y+box.height/2);await page.mouse.down();await page.mouse.move(box.x+box.width/2+20,box.y+box.height/2);
 const before=await shutter.evaluate(e=>e.style.getPropertyValue('--shutter-travel'));expect(before).not.toBe('');expect(await tick(at)).toBe(true);
 expect(await shutter.evaluate(e=>e.style.getPropertyValue('--shutter-travel'))).toBe(before);await page.mouse.up();
});
test('document hidden blocks ticks and show resumes only on native event',async({page})=>{
 const {tick}=await open(page,dataFor());await page.evaluate(()=>{Object.defineProperty(document,'hidden',{configurable:true,value:true});document.dispatchEvent(new Event('visibilitychange'));});
 const n=(await reports(page)).length;expect(await tick(at)).toBe(false);expect((await reports(page)).length).toBe(n);
 await page.evaluate(()=>{Object.defineProperty(document,'hidden',{configurable:true,value:false});document.dispatchEvent(new Event('visibilitychange'));});expect((await reports(page)).length).toBe(n);expect(await tick(at,'show')).toBe(true);await check(page,true);
});
test('engine page and focus remain on the selected page through a native tick',async({page})=>{
 const data=dataFor(),base=data.projection.rows[0];for(let i=1;i<7;i++){const row=structuredClone(base);row.id='tool'+i;row.name={en:'Tool '+i,zh:'工具 '+i};row.accounts[0].subscriptionRef=null;data.projection.rows.push(row);}
 const {tick}=await open(page,data);const pageTwo=page.getByRole('button',{name:'Page 2'});await pageTwo.click();await pageTwo.focus();expect(await tick(at)).toBe(true);await expect(page.getByRole('button',{name:'Page 2'})).toHaveAttribute('aria-current','true');await expect(page.getByRole('button',{name:'Page 2'})).toBeFocused();
});
test('unknown, absent and retained stay distinct from a current zero',async({page})=>{
 const data=dataFor(),a=data.projection.rows[0].accounts[0],first=a.windows[0];first.remainingPercent=null;first.current=false;data.projection.rows[0].expiresAt=week;
 const {send,receive}=await open(page,data);const cell=()=>page.locator('.eng-cols .ec').first().locator('.qcell[data-row="first"]');await expect(cell().locator('.qvalue')).toHaveText('--');await expect(page.locator('.s6-alert')).not.toHaveClass(/lit|red/);
 a.windows=a.windows.slice(1);data.projection.rows[0].expiresAt=week;expect(await receive(send('display',{data}))).toBe(true);await expect(cell().locator('.qvalue')).toHaveCount(0);
 first.remainingPercent=75;first.current=false;a.valueState='retained';a.lastFailure={code:'network',at:start};a.windows.unshift(first);for(const w of a.windows)w.current=false;const row=data.projection.rows[0],stale=row.stateAfterExpiry;row.state=stale.state;row.reason=stale.reason;row.nextStep=stale.nextStep;row.expiresAt=null;row.stateAfterExpiry=null;
 expect(await receive(send('display',{data}))).toBe(true);await expect(cell().locator('.qvalue')).toHaveText('75');await expect(page.locator('.s6-alert')).not.toHaveClass(/lit|red/);
});
for(const attached of [true,false])test(`visible non-key ${attached?'attached':'detached'} cockpit processes expiry without enabling actions`,async({page})=>{
 const {send,receive,tick}=await open(page,dataFor());
 expect(await receive(send('shell',{...shell,attached}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:false}))).toBe(true);
 const initial=(await reports(page)).length;expect(await receive(send('display',{data:dataFor()}))).toBe(true);expect((await reports(page)).length).toBe(initial+1);
 const before=(await reports(page)).length;expect(await tick(at)).toBe(true);await check(page,true);expect((await reports(page)).length).toBe(before+1);
 await expect(page.getByRole('button',{name:'Settings',exact:true})).toBeDisabled();
});
test('appearance at quota expiry reports its request and preserves live peer',async({page})=>{
 const {send,receive}=await open(page,dataFor());await check(page,false);const previous=(await reports(page)).at(-1);
 await page.clock.setSystemTime(new Date(at));const appearance=JSON.parse(send('appearance',{theme:'night',locale:'zh-CN',reduceMotion:true,reduceTransparency:false,showProjectNames:true}));expect(await receive(JSON.stringify(appearance))).toBe(true);
 const report=(await reports(page)).at(-1);expect(report.requestId).toBe(appearance.requestId);expect(BigInt(report.sequence)).toBeGreaterThan(BigInt(previous.sequence));expect(report.deadlineUnixMs).toBe(String(Date.parse(week)));await check(page,true);
});
test('appearance at reset expiry reports the next authoritative deadline',async({page})=>{
 const data=dataFor(true),a=data.projection.rows[0].accounts[0];a.windows[0].remainingPercent=80;a.windows[0].validUntil=week;a.windows[0].resetsAt=week;data.projection.rows[0].expiresAt=week;data.details.alerts=[];data.details.resetEvents=[{version:1,id:'synthetic-reset',provider:'openai',rowId:data.projection.rows[0].id,status:'announced',publishedAt:start,expiresAt:at,source:{kind:'publication',publicationId:'0123456789abcdef01234567'}}];
 const {send,receive}=await open(page,data);await expect(page.locator('.s6-alert')).not.toHaveClass(/lit|amber|red/);await expect(page.locator('.pg-overview .mfd-alerts li.al-blue')).toHaveCount(1);await page.clock.setSystemTime(new Date(at));const appearance=JSON.parse(send('appearance',{theme:'night',locale:'en',reduceMotion:true,reduceTransparency:false,showProjectNames:true}));expect(await receive(JSON.stringify(appearance))).toBe(true);
 const report=(await reports(page)).at(-1);expect(report.requestId).toBe(appearance.requestId);expect(report.deadlineUnixMs).toBe(String(Date.parse(week)));await expect(page.locator('.s6-alert')).not.toHaveClass(/lit|amber|red/);
});
test('appearance at expiry preserves engine page, scope and focused control',async({page})=>{
 const data=dataFor(),base=data.projection.rows[0];for(let i=1;i<7;i++){const row=structuredClone(base);row.id='tool'+i;row.name={en:'Tool '+i,zh:'工具 '+i};row.accounts[0].subscriptionRef=null;data.projection.rows.push(row);}
 const {send,receive}=await open(page,data);expect(await receive(send('shell',{...shell,scope:base.accounts[0].subscriptionRef}))).toBe(true);
 const control=page.getByRole('button',{name:'Page 2'});await control.click();await control.focus();await page.clock.setSystemTime(new Date(at));
 expect(await receive(send('appearance',{theme:'night',locale:'en',reduceMotion:true,reduceTransparency:false,showProjectNames:true}))).toBe(true);
 await expect(page.getByRole('button',{name:'Page 2'})).toHaveAttribute('aria-current','true');await expect(page.getByRole('button',{name:'Page 2'})).toBeFocused();await expect(page.locator('#cockpit')).toHaveAttribute('data-scope','subscription');
});
test('appearance repaint preserves an active shutter drag',async({page})=>{
 const {send,receive}=await open(page,dataFor()),shutter=page.locator('[data-shutter]'),box=await shutter.boundingBox();expect(box).not.toBeNull();
 await page.mouse.move(box.x+box.width/2,box.y+box.height/2);await page.mouse.down();await page.mouse.move(box.x+box.width/2+20,box.y+box.height/2);
 const before=await shutter.evaluate(e=>e.style.getPropertyValue('--shutter-travel'));expect(before).not.toBe('');await page.clock.setSystemTime(new Date(at));expect(await receive(send('appearance',{theme:'night',locale:'en',reduceMotion:true,reduceTransparency:false,showProjectNames:true}))).toBe(true);
 expect(await shutter.evaluate(e=>e.style.getPropertyValue('--shutter-travel'))).toBe(before);await page.mouse.up();
});
for(const [from,to,fromLabel,toLabel] of [['en','zh-CN','＋ Add a subscription','＋ 添加订阅'],['zh-CN','en','＋ 添加订阅','＋ Add a subscription']])test(`Add subscription focus survives ${from} to ${to} and expiry`,async({page})=>{
 const {send,receive,tick}=await open(page,dataFor());
 if(from!=='en')expect(await receive(send('appearance',{theme:'night',locale:from,reduceMotion:true,reduceTransparency:false,showProjectNames:true}))).toBe(true);
 const add=page.locator('.eng-keys button[data-add-subscription]').nth(1);await expect(add).toHaveAttribute('aria-label',fromLabel);await add.focus();await expect(add).toBeFocused();
 expect(await receive(send('appearance',{theme:'night',locale:to,reduceMotion:true,reduceTransparency:false,showProjectNames:true}))).toBe(true);
 const translated=page.locator('.eng-keys button[data-add-subscription]').nth(1);await expect(translated).toHaveAttribute('aria-label',toLabel);await expect(translated).toBeFocused();
 expect(await tick(at)).toBe(true);await expect(translated).toBeFocused();await expect(translated).toHaveAttribute('aria-label',toLabel);
});
test('localization preserves focus on a non-Add control',async({page})=>{
 const {send,receive}=await open(page,dataFor());const all=page.locator('.eng-krow button[data-all]');await all.focus();await expect(all).toBeFocused();
 expect(await receive(send('appearance',{theme:'night',locale:'zh-CN',reduceMotion:true,reduceTransparency:false,showProjectNames:true}))).toBe(true);
 await expect(page.locator('.eng-krow button[data-all]')).toBeFocused();await expect(page.locator('.eng-keys button[data-add-subscription]').first()).not.toBeFocused();
});
test('display update preserves focused Add subscription and scope',async({page})=>{
 const data=dataFor(),{send,receive}=await open(page,data),ref=data.projection.rows[0].accounts[0].subscriptionRef;
 expect(await receive(send('shell',{...shell,scope:ref}))).toBe(true);const add=page.locator('.eng-keys button[data-add-subscription]').nth(1);await add.focus();await expect(add).toBeFocused();
 data.projection.rows[0].accounts[0].windows[1].remainingPercent=70;expect(await receive(send('display',{data}))).toBe(true);
 const after=page.locator('.eng-keys button[data-add-subscription]').nth(1);await expect(after).toBeFocused();await expect(after).toHaveAttribute('aria-label','＋ Add a subscription');await expect(page.locator('#cockpit')).toHaveAttribute('data-scope','subscription');
});
test('display update does not steal focus from a non-Add control',async({page})=>{
 const data=dataFor(),{send,receive}=await open(page,data);const settings=page.getByRole('button',{name:'Settings',exact:true});await settings.focus();await expect(settings).toBeFocused();
 data.projection.rows[0].accounts[0].windows[1].remainingPercent=70;expect(await receive(send('display',{data}))).toBe(true);
 await expect(settings).toBeFocused();await expect(page.locator('.eng-keys button[data-add-subscription]').first()).not.toBeFocused();
});
test('display update does not move focus when the focused Add bay disappears',async({page})=>{
 const data=dataFor(),{send,receive}=await open(page,data),add=page.locator('.eng-keys button[data-add-subscription]').nth(1);await add.focus();await expect(add).toBeFocused();
 const base=data.projection.rows[0];for(let i=1;i<3;i++){const row=structuredClone(base);row.id='tool'+i;row.name={en:'Tool '+i,zh:'工具 '+i};row.accounts[0].subscriptionRef=null;data.projection.rows.push(row);}
 expect(await receive(send('display',{data}))).toBe(true);await expect(page.locator('.eng-keys button[data-add-subscription]')).toHaveCount(0);expect(await page.evaluate(()=>document.activeElement===document.body)).toBe(true);
});
test('display update keeps the current page and focused Add bay when that page still exists',async({page})=>{
 const data=dataFor(),base=data.projection.rows[0];for(let i=1;i<7;i++){const row=structuredClone(base);row.id='tool'+i;row.name={en:'Tool '+i,zh:'工具 '+i};row.accounts[0].subscriptionRef=null;data.projection.rows.push(row);}
 const {send,receive}=await open(page,data);await page.getByRole('button',{name:'Page 2'}).click();await expect(page.getByRole('button',{name:'Page 2'})).toHaveAttribute('aria-current','true');
 const add=page.locator('.eng-keys button[data-add-subscription]').nth(1);await add.focus();await expect(add).toBeFocused();data.projection.rows[0].accounts[0].windows[1].remainingPercent=70;
 expect(await receive(send('display',{data}))).toBe(true);await expect(page.getByRole('button',{name:'Page 2'})).toHaveAttribute('aria-current','true');await expect(page.locator('.eng-keys button[data-add-subscription]').nth(1)).toBeFocused();
});
test('display update does not transfer Add focus to another page when its page disappears',async({page})=>{
 const data=dataFor(),base=data.projection.rows[0];for(let i=1;i<7;i++){const row=structuredClone(base);row.id='tool'+i;row.name={en:'Tool '+i,zh:'工具 '+i};row.accounts[0].subscriptionRef=null;data.projection.rows.push(row);}
 const {send,receive}=await open(page,data);await page.getByRole('button',{name:'Page 2'}).click();const add=page.locator('.eng-keys button[data-add-subscription]').nth(1);await add.focus();await expect(add).toBeFocused();
 data.projection.rows=[base];expect(await receive(send('display',{data}))).toBe(true);await expect(page.locator('.eng-keys button[data-add-subscription]')).toHaveCount(2);expect(await page.evaluate(()=>document.activeElement===document.body)).toBe(true);
});
test('display update clamps a removed page without transferring Add focus',async({page})=>{
 const data=dataFor(),base=data.projection.rows[0];for(let i=1;i<13;i++){const row=structuredClone(base);row.id='tool'+i;row.name={en:'Tool '+i,zh:'工具 '+i};row.accounts[0].subscriptionRef=null;data.projection.rows.push(row);}
 const {send,receive}=await open(page,data);await page.getByRole('button',{name:'Page 3'}).click();const add=page.locator('.eng-keys button[data-add-subscription]').nth(1);await add.focus();await expect(add).toBeFocused();
 data.projection.rows=data.projection.rows.slice(0,7);expect(await receive(send('display',{data}))).toBe(true);
 await expect(page.getByRole('button',{name:'Page 2'})).toHaveAttribute('aria-current','true');await expect(page.getByRole('button',{name:'Page 3'})).toHaveCount(0);expect(await page.evaluate(()=>document.activeElement===document.body)).toBe(true);
});
test('hidden display and stale delivery after clear cannot restore Add focus',async({page})=>{
 const data=dataFor(),{send,receive}=await open(page,data),add=page.locator('.eng-keys button[data-add-subscription]').nth(1);await add.focus();await expect(add).toBeFocused();
 expect(await receive(send('visibility',{visible:false,occluded:false,key:false}))).toBe(true);expect(await receive(send('display',{data}))).toBe(true);expect(await page.evaluate(()=>document.activeElement===document.body)).toBe(true);
 const old=send('display',{data});expect(await receive(send('clear',{generation:'42',viewRevision:'4'}))).toBe(true);expect(await receive(old)).toBe(false);await expect(page.locator('.eng-keys button[data-add-subscription]')).toHaveCount(0);expect(await page.evaluate(()=>document.activeElement===document.body)).toBe(true);
});
test('display update preserves focus on the Engine All control',async({page})=>{
 const data=dataFor(),{send,receive}=await open(page,data),all=page.locator('.eng-krow button[data-all]');await all.focus();await expect(all).toBeFocused();data.projection.rows[0].accounts[0].windows[1].remainingPercent=70;
 expect(await receive(send('display',{data}))).toBe(true);await expect(page.locator('.eng-krow button[data-all]')).toBeFocused();await expect(page.locator('.eng-keys button[data-add-subscription]').first()).not.toBeFocused();
});
test('display removal of a focused subscription does not focus another member',async({page})=>{
 const data=dataFor(),{send,receive}=await open(page,data),selected=page.getByRole('button',{name:/^Codex · Shortcut key 1$/});await selected.focus();await expect(selected).toBeFocused();
 const row=structuredClone(data.projection.rows[0]);row.id='tool-replacement';row.name={en:'Replacement',zh:'替代'};row.accounts[0].subscriptionRef=null;data.projection.rows=[row];
 expect(await receive(send('display',{data}))).toBe(true);await expect(page.getByRole('button',{name:/^Replacement · Shortcut key 1$/})).not.toBeFocused();expect(await page.evaluate(()=>document.activeElement===document.body)).toBe(true);
});
function twoVerified(){
 const data=dataFor(),row=data.projection.rows[0],a=row.accounts[0],b=structuredClone(a),ref='fedcba9876543210';b.subscriptionRef=ref;b.plan.name={en:'Plan B',zh:'方案 B'};
 for(const account of [a,b]){const w=account.windows[0];w.role='monthly';w.durationSeconds=2592000;w.id='monthly:2592000:main:main';w.label={en:'Monthly',zh:'每月'};}
 row.accounts.push(b);const sub=structuredClone(data.subscriptions[0]);sub.subscriptionRef=ref;data.subscriptions.push(sub);return data;
}
test('filling the focused Add slot does not focus a different remaining slot',async({page})=>{
 const data=dataFor(),{send,receive}=await open(page,data),add=page.locator('.eng-keys button[data-add-subscription]').first();await add.focus();await expect(add).toBeFocused();
 const row=structuredClone(data.projection.rows[0]);row.id='tool-new';row.name={en:'New',zh:'新'};row.accounts[0].subscriptionRef=null;data.projection.rows.push(row);
 expect(await receive(send('display',{data}))).toBe(true);await expect(page.locator('.eng-keys button[data-add-subscription]')).toHaveCount(1);expect(await page.evaluate(()=>document.activeElement===document.body)).toBe(true);
});
test('focused quota cell follows its verified member across reorder and never another after removal',async({page})=>{
 const data=twoVerified(),{send,receive}=await open(page,data),ref='0123456789abcdef';const cell=()=>page.locator(`.eng-cols .ec[data-col="${ref}"] .qcell[data-row="other"]`);await cell().focus();await expect(cell()).toBeFocused();
 data.projection.rows[0].accounts.reverse();expect(await receive(send('display',{data}))).toBe(true);await expect(cell()).toBeFocused();
 data.projection.rows[0].accounts=data.projection.rows[0].accounts.filter(a=>a.subscriptionRef!==ref);data.subscriptions=data.subscriptions.filter(s=>s.subscriptionRef!==ref);expect(await receive(send('display',{data}))).toBe(true);
 await expect(page.locator('.eng-cols .ec .qcell[data-row="other"]')).not.toBeFocused();expect(await page.evaluate(()=>document.activeElement===document.body)).toBe(true);
});
test('MFD focus follows its verified member across reorder and never a replacement',async({page})=>{
 const data=twoVerified(),{send,receive}=await open(page,data);await page.getByRole('button',{name:'Subscription',exact:true}).click();const first=page.locator('.mfd-page .sa').first();await first.focus();await expect(first).toBeFocused();
 data.projection.rows[0].accounts.reverse();expect(await receive(send('display',{data}))).toBe(true);await expect(page.locator('.mfd-page .sa').nth(1)).toBeFocused();
 data.projection.rows[0].accounts=data.projection.rows[0].accounts.filter(a=>a.subscriptionRef!=='0123456789abcdef');data.subscriptions=data.subscriptions.filter(s=>s.subscriptionRef!=='0123456789abcdef');expect(await receive(send('display',{data}))).toBe(true);await expect(page.locator('.mfd-page .sa').first()).not.toBeFocused();expect(await page.evaluate(()=>document.activeElement===document.body)).toBe(true);
});
test('off-page unstable selected scope falls back on replacement',async({page})=>{
 const data=dataFor(),row=data.projection.rows[0],dup=structuredClone(row.accounts[0]);row.accounts[0].subscriptionRef=null;dup.subscriptionRef=null;row.accounts.push(dup);data.subscriptions=[];
 for(let i=1;i<7;i++){const r=structuredClone(row);r.id='tool'+i;r.name={en:'Tool '+i,zh:'工具 '+i};r.accounts=[structuredClone(dup)];data.projection.rows.push(r);}
 const {send,receive}=await open(page,data);expect(await receive(send('shell',{...shell,scope:'codex#unknown#2'}))).toBe(true);await expect(page.locator('#cockpit')).toHaveAttribute('data-scope','subscription');await page.getByRole('button',{name:'Page 2'}).click();
 row.accounts.reverse();expect(await receive(send('display',{data}))).toBe(true);await expect(page.locator('#cockpit')).toHaveAttribute('data-scope','all');
 expect(await receive(send('shell',{...shell,scope:'codex#unknown#2'}))).toBe(true);await expect(page.locator('#cockpit')).toHaveAttribute('data-scope','all');
 await page.getByRole('button',{name:'Page 1'}).click();await page.locator('.eng-keys button[data-scope="codex#unknown#2"]').click();
 expect(await receive(send('shell',{...shell,scope:'codex#unknown#2'}))).toBe(true);await expect(page.locator('#cockpit')).toHaveAttribute('data-scope','subscription');
});
test('pointer release after replacing a target never activates another member',async({page})=>{
 const data=twoVerified(),{send,receive}=await open(page,data),target=page.locator('.eng-keys button[data-scope="0123456789abcdef"]'),box=await target.boundingBox();expect(box).not.toBeNull();
 await page.mouse.move(box.x+box.width/2,box.y+box.height/2);await page.mouse.down();data.projection.rows[0].accounts.reverse();expect(await receive(send('display',{data}))).toBe(true);await page.mouse.up();
 const actions=await page.evaluate(()=>window.__messages.filter(m=>m.type==='action'&&m.action==='scopeSelect'));expect(actions.length).toBeLessThanOrEqual(1);if(actions.length)expect(actions[0].key).toBe('0123456789abcdef');
});
test('focus moved externally during redraw is not stolen back',async({page})=>{
 const data=dataFor(),{send,receive}=await open(page,data),add=page.locator('.eng-keys button[data-add-subscription]').first();await add.focus();await expect(add).toBeFocused();
 await page.evaluate(()=>{const host=document.querySelector('.ck-eng'),original=host.replaceChildren.bind(host);host.replaceChildren=(...nodes)=>{original(...nodes);document.querySelector('.ck-head button[aria-label="Settings"]').focus();};});
 expect(await receive(send('display',{data}))).toBe(true);await expect(page.getByRole('button',{name:'Settings',exact:true})).toBeFocused();
});
function twoUnverified(){const data=dataFor(),row=data.projection.rows[0],a=row.accounts[0],b=structuredClone(a);a.subscriptionRef=null;b.subscriptionRef=null;a.plan.name={en:'Plan A',zh:'方案 A'};b.plan.name={en:'Plan B',zh:'方案 B'};row.accounts.push(b);data.subscriptions=[];return data;}
test('unstable duplicate Engine focus is not reassigned on reorder',async({page})=>{
 const data=twoUnverified(),{send,receive}=await open(page,data),key=page.locator('.eng-keys button[data-scope="codex#unknown#2"]');await key.focus();await expect(key).toBeFocused();
 data.projection.rows[0].accounts.reverse();expect(await receive(send('display',{data}))).toBe(true);await expect(page.locator('.eng-keys button[data-scope="codex#unknown#2"]')).not.toBeFocused();expect(await page.evaluate(()=>document.activeElement===document.body)).toBe(true);
});
test('unstable duplicate MFD focus is not reassigned on reorder',async({page})=>{
 const data=twoUnverified(),{send,receive}=await open(page,data);await page.getByRole('button',{name:'Subscription',exact:true}).click();const second=page.locator('.mfd-page .sa').nth(1);await second.focus();await expect(second).toBeFocused();
 data.projection.rows[0].accounts.reverse();expect(await receive(send('display',{data}))).toBe(true);await expect(page.locator('.mfd-page .sa').nth(1)).not.toBeFocused();expect(await page.evaluate(()=>document.activeElement===document.body)).toBe(true);
});
test('changed quota identity with the same label does not inherit focus',async({page})=>{
 const data=twoVerified(),{send,receive}=await open(page,data),ref='0123456789abcdef',cell=page.locator(`.eng-cols .ec[data-col="${ref}"] .qcell[data-row="other"]`);await cell.focus();await expect(cell).toBeFocused();
 data.projection.rows[0].accounts[0].windows[0].id='monthly:2592000:main:main:2';expect(await receive(send('display',{data}))).toBe(true);await expect(page.locator(`.eng-cols .ec[data-col="${ref}"] .qcell[data-row="other"]`)).not.toBeFocused();expect(await page.evaluate(()=>document.activeElement===document.body)).toBe(true);
});
for(const gate of ['hidden','non-key','clear'])test(`pointer release after ${gate} does not activate a stale target`,async({page})=>{
 const data=twoVerified(),{send,receive}=await open(page,data),target=page.locator('.eng-keys button[data-scope="0123456789abcdef"]'),box=await target.boundingBox();expect(box).not.toBeNull();
 await page.mouse.move(box.x+box.width/2,box.y+box.height/2);await page.mouse.down();
 if(gate==='clear')expect(await receive(send('clear',{generation:'42',viewRevision:'4'}))).toBe(true);else expect(await receive(send('visibility',{visible:gate==='non-key',occluded:false,key:false}))).toBe(true);
 await page.mouse.up();expect(await page.evaluate(()=>window.__messages.filter(m=>m.type==='action'&&m.action==='scopeSelect'))).toEqual([]);
});
test('same verified quota keeps focus across value and observation updates',async({page})=>{
 const data=twoVerified(),{send,receive}=await open(page,data),ref='0123456789abcdef',cell=()=>page.locator(`.eng-cols .ec[data-col="${ref}"] .qcell[data-row="other"]`);await cell().focus();await expect(cell()).toBeFocused();
 const w=data.projection.rows[0].accounts[0].windows[0];w.remainingPercent=10;w.observedAt='2026-10-29T11:59:59Z';expect(await receive(send('display',{data}))).toBe(true);await expect(cell()).toBeFocused();await expect(cell().locator('.qvalue')).toHaveText('10');
});
test('irrelevant window changes do not remove verified quota focus',async({page})=>{
 const data=twoVerified(),{send,receive}=await open(page,data),cell=()=>page.locator('.eng-cols .ec[data-col="0123456789abcdef"] .qcell[data-row="other"]');await cell().focus();await expect(cell()).toBeFocused();
 data.projection.rows[0].accounts[0].windows[1].remainingPercent=70;expect(await receive(send('display',{data}))).toBe(true);await expect(cell()).toBeFocused();
});
function twoOtherWindows(){const data=twoVerified(),a=data.projection.rows[0].accounts[0],other=structuredClone(a.windows[0]);other.id='monthly:2592000:main:main:2';other.remainingPercent=20;other.resetsAt=week;other.validUntil=week;a.windows.push(other);return data;}
test('Other focus falls back when expiry selects a different underlying window',async({page})=>{
 const data=twoOtherWindows(),other=data.projection.rows[0].accounts[0].windows[2];other.durationSeconds=2592001;other.id='monthly:2592001:main:main';const {tick}=await open(page,data),cell=()=>page.locator('.eng-cols .ec[data-col="0123456789abcdef"] .qcell[data-row="other"]');await cell().focus();await expect(cell()).toBeFocused();await expect(cell().locator('.qvalue')).toHaveText('0');
 expect(await tick(at)).toBe(true);await expect(cell().locator('.qvalue')).toHaveText('20');await expect(cell()).not.toBeFocused();expect(await page.evaluate(()=>document.activeElement===document.body)).toBe(true);
});
test('duplicate window IDs do not prove quota focus identity',async({page})=>{
 const data=twoOtherWindows(),a=data.projection.rows[0].accounts[0];a.windows[2].id=a.windows[0].id;const {send,receive}=await open(page,data),cell=()=>page.locator('.eng-cols .ec[data-col="0123456789abcdef"] .qcell[data-row="other"]');await cell().focus();await expect(cell()).toBeFocused();
 a.windows[0].remainingPercent=10;expect(await receive(send('display',{data}))).toBe(true);await expect(cell()).not.toBeFocused();expect(await page.evaluate(()=>document.activeElement===document.body)).toBe(true);
});
test('window reorder keeps the same verified quota focused',async({page})=>{
 const data=twoVerified(),{send,receive}=await open(page,data),cell=()=>page.locator('.eng-cols .ec[data-col="0123456789abcdef"] .qcell[data-row="other"]');await cell().focus();await expect(cell()).toBeFocused();
 data.projection.rows[0].accounts[0].windows.reverse();expect(await receive(send('display',{data}))).toBe(true);await expect(cell()).toBeFocused();
});
test('removing the focused quota never focuses a different window',async({page})=>{
 const data=twoOtherWindows(),{send,receive}=await open(page,data),cell=()=>page.locator('.eng-cols .ec[data-col="0123456789abcdef"] .qcell[data-row="other"]');await cell().focus();await expect(cell()).toBeFocused();
 data.projection.rows[0].accounts[0].windows.shift();expect(await receive(send('display',{data}))).toBe(true);await expect(cell()).not.toBeFocused();expect(await page.evaluate(()=>document.activeElement===document.body)).toBe(true);
});
test('distinct IDs with indistinguishable window semantics do not prove focus identity',async({page})=>{
 const data=twoOtherWindows(),{send,receive}=await open(page,data),cell=()=>page.locator('.eng-cols .ec[data-col="0123456789abcdef"] .qcell[data-row="other"]');await cell().focus();await expect(cell()).toBeFocused();
 data.projection.rows[0].accounts[0].windows[1].remainingPercent=70;expect(await receive(send('display',{data}))).toBe(true);await expect(cell()).not.toBeFocused();expect(await page.evaluate(()=>document.activeElement===document.body)).toBe(true);
});
test('adding an unrelated Other window keeps focus when the primary is unchanged and unique',async({page})=>{
 const data=twoVerified(),{send,receive}=await open(page,data),account=data.projection.rows[0].accounts[0],cell=()=>page.locator('.eng-cols .ec[data-col="0123456789abcdef"] .qcell[data-row="other"]');await cell().focus();await expect(cell()).toBeFocused();
 const other=structuredClone(account.windows[0]);other.durationSeconds=2592001;other.id='monthly:2592001:main:main';other.remainingPercent=20;other.resetsAt=week;other.validUntil=week;account.windows.push(other);
 expect(await receive(send('display',{data}))).toBe(true);await expect(cell()).toBeFocused();await expect(cell().locator('.qvalue')).toHaveText('0');
});
test('a reused window ID with changed semantics cannot inherit focus',async({page})=>{
 const data=twoVerified(),{send,receive}=await open(page,data),cell=()=>page.locator('.eng-cols .ec[data-col="0123456789abcdef"] .qcell[data-row="other"]');await cell().focus();await expect(cell()).toBeFocused();
 data.projection.rows[0].accounts[0].windows[0].durationSeconds=2592001;expect(await receive(send('display',{data}))).toBe(true);await expect(cell()).not.toBeFocused();expect(await page.evaluate(()=>document.activeElement===document.body)).toBe(true);
});
test('focused verified quota moved off page does not change page or steal focus',async({page})=>{
 const data=twoVerified(),row=data.projection.rows[0],seed=row.accounts[1];for(let i=2;i<7;i++){const account=structuredClone(seed),ref=(i+1).toString(16).padStart(16,'0');account.subscriptionRef=ref;row.accounts.push(account);const sub=structuredClone(data.subscriptions[0]);sub.subscriptionRef=ref;data.subscriptions.push(sub);}
 const {send,receive}=await open(page,data),cell=page.locator('.eng-cols .ec[data-col="0123456789abcdef"] .qcell[data-row="other"]');await cell.focus();await expect(cell).toBeFocused();row.accounts.push(row.accounts.shift());expect(await receive(send('display',{data}))).toBe(true);
 await expect(page.getByRole('button',{name:'Page 1'})).toHaveAttribute('aria-current','true');await expect(page.locator('.eng-cols .ec[data-col="0123456789abcdef"]')).toHaveCount(0);expect(await page.evaluate(()=>document.activeElement===document.body)).toBe(true);
});
test('same window becoming unknown at expiry retains verified quota focus',async({page})=>{
 const data=twoVerified(),{tick}=await open(page,data),cell=()=>page.locator('.eng-cols .ec[data-col="0123456789abcdef"] .qcell[data-row="other"]');await cell().focus();await expect(cell()).toBeFocused();
 expect(await tick(at)).toBe(true);await expect(cell().locator('.qvalue')).toHaveText('--');await expect(cell()).toBeFocused();
});
test('hidden and cleared quota focus cannot be revived by an old display',async({page})=>{
 const data=twoVerified(),{send,receive}=await open(page,data),cell=page.locator('.eng-cols .ec[data-col="0123456789abcdef"] .qcell[data-row="other"]');await cell.focus();await expect(cell).toBeFocused();
 expect(await receive(send('visibility',{visible:false,occluded:false,key:false}))).toBe(true);expect(await receive(send('display',{data}))).toBe(true);expect(await page.evaluate(()=>document.activeElement===document.body)).toBe(true);
 const old=send('display',{data});expect(await receive(send('clear',{generation:'42',viewRevision:'4'}))).toBe(true);expect(await receive(old)).toBe(false);await expect(page.locator('.eng-cols .ec')).toHaveCount(0);expect(await page.evaluate(()=>document.activeElement===document.body)).toBe(true);
});
function ordinalQuota(withSibling){
 const data=twoVerified(),a=data.projection.rows[0].accounts[0],base='monthly:2592000:main:main',chosen=a.windows[0];chosen.modelScope={models:['opus']};chosen.id=withSibling?base+':2':base;
 if(withSibling){const sibling=structuredClone(chosen);delete sibling.modelScope;sibling.id=base+':1';sibling.remainingPercent=50;a.windows=[sibling,chosen,a.windows[1]];}
 return data;
}
test('uniquely scoped quota keeps focus when a same-base sibling adds an ordinal',async({page})=>{
 const data=ordinalQuota(false),{send,receive}=await open(page,data),a=data.projection.rows[0].accounts[0],cell=()=>page.locator('.eng-cols .ec[data-col="0123456789abcdef"] .qcell[data-row="other"]');await cell().focus();await expect(cell()).toBeFocused();
 const chosen=a.windows[0],sibling=structuredClone(chosen);delete sibling.modelScope;sibling.id='monthly:2592000:main:main:1';sibling.remainingPercent=50;chosen.id='monthly:2592000:main:main:2';a.windows=[sibling,chosen,a.windows[1]];
 expect(await receive(send('display',{data}))).toBe(true);await expect(cell()).toBeFocused();await expect(cell().locator('.qvalue')).toHaveText('0');
});
test('uniquely scoped quota keeps focus when sibling removal removes its ordinal',async({page})=>{
 const data=ordinalQuota(true),{send,receive}=await open(page,data),a=data.projection.rows[0].accounts[0],cell=()=>page.locator('.eng-cols .ec[data-col="0123456789abcdef"] .qcell[data-row="other"]');await cell().focus();await expect(cell()).toBeFocused();
 const chosen=a.windows[1];chosen.id='monthly:2592000:main:main';a.windows=[chosen,a.windows[2]];expect(await receive(send('display',{data}))).toBe(true);await expect(cell()).toBeFocused();
});
test('indistinguishable same-base siblings cannot inherit quota focus',async({page})=>{
 const data=ordinalQuota(false),{send,receive}=await open(page,data),a=data.projection.rows[0].accounts[0],cell=()=>page.locator('.eng-cols .ec[data-col="0123456789abcdef"] .qcell[data-row="other"]');await cell().focus();await expect(cell()).toBeFocused();
 const chosen=a.windows[0],sibling=structuredClone(chosen);chosen.id='monthly:2592000:main:main:1';sibling.id='monthly:2592000:main:main:2';sibling.remainingPercent=50;a.windows=[chosen,sibling,a.windows[1]];
 expect(await receive(send('display',{data}))).toBe(true);await expect(cell()).not.toBeFocused();expect(await page.evaluate(()=>document.activeElement===document.body)).toBe(true);
});
test('reset mode cannot distinguish otherwise identical quota siblings',async({page})=>{
 const data=ordinalQuota(true),a=data.projection.rows[0].accounts[0];a.windows[0].modelScope={models:['opus']};a.windows[0].resetMode='rolling';
 const {send,receive}=await open(page,data),cell=()=>page.locator('.eng-cols .ec[data-col="0123456789abcdef"] .qcell[data-row="other"]');await cell().focus();await expect(cell()).toBeFocused();
 a.windows[2].remainingPercent=70;expect(await receive(send('display',{data}))).toBe(true);await expect(cell()).not.toBeFocused();expect(await page.evaluate(()=>document.activeElement===document.body)).toBe(true);
});
function sevenRows(){const data=dataFor(),base=data.projection.rows[0];for(let i=1;i<7;i++){const row=structuredClone(base);row.id='tool'+i;row.name={en:'Tool '+i,zh:'工具 '+i};row.accounts[0].subscriptionRef=null;data.projection.rows.push(row);}return data;}
test('appearance followed by unchanged selected shell preserves page and Add focus',async({page})=>{
 const data=sevenRows(),ref=data.projection.rows[0].accounts[0].subscriptionRef,{send,receive}=await open(page,data);expect(await receive(send('shell',{...shell,scope:ref}))).toBe(true);await page.getByRole('button',{name:'Page 2'}).click();
 const add=page.locator('.eng-keys button[data-add-subscription]').nth(1);await add.focus();await expect(add).toBeFocused();expect(await receive(send('appearance',{theme:'night',locale:'zh-CN',reduceMotion:true,reduceTransparency:false,showProjectNames:true}))).toBe(true);await expect(add).toBeFocused();
 expect(await receive(send('shell',{...shell,scope:ref}))).toBe(true);await expect(page.getByRole('button',{name:'第 2 页'})).toHaveAttribute('aria-current','true');await expect(page.locator('.eng-keys button[data-add-subscription]').nth(1)).toBeFocused();await expect(page.locator('#cockpit')).toHaveAttribute('data-scope','subscription');
});
test('appearance followed by unchanged All shell preserves focused MFD member',async({page})=>{
 const data=twoVerified(),{send,receive}=await open(page,data);await page.getByRole('button',{name:'Subscription',exact:true}).click();await page.locator('.mfd-page .sa').first().focus();
 expect(await receive(send('appearance',{theme:'night',locale:'zh-CN',reduceMotion:true,reduceTransparency:false,showProjectNames:true}))).toBe(true);await expect(page.locator('.mfd-page .sa').first()).toBeFocused();expect(await receive(send('shell',{...shell,scope:'all'}))).toBe(true);await expect(page.locator('.mfd-page .sa').first()).toBeFocused();
});
test('actual scope change retains its page behavior without moving focus to another bay',async({page})=>{
 const data=sevenRows(),ref=data.projection.rows[0].accounts[0].subscriptionRef,{send,receive}=await open(page,data);await page.getByRole('button',{name:'Page 2'}).click();await page.locator('.eng-keys button[data-add-subscription]').nth(1).focus();
 expect(await receive(send('appearance',{theme:'night',locale:'en',reduceMotion:true,reduceTransparency:false,showProjectNames:true}))).toBe(true);expect(await receive(send('shell',{...shell,scope:ref}))).toBe(true);await expect(page.getByRole('button',{name:'Page 1'})).toHaveAttribute('aria-current','true');expect(await page.evaluate(()=>document.activeElement===document.body)).toBe(true);
});
test('appearance and shell cannot steal external focus or revive cleared state',async({page})=>{
 const data=dataFor(),{send,receive}=await open(page,data);await page.locator('.eng-keys button[data-add-subscription]').first().focus();expect(await receive(send('appearance',{theme:'night',locale:'zh-CN',reduceMotion:true,reduceTransparency:false,showProjectNames:true}))).toBe(true);
 const settings=page.getByRole('button',{name:'设置',exact:true});await settings.focus();expect(await receive(send('shell',{...shell,scope:'all'}))).toBe(true);await expect(settings).toBeFocused();
 expect(await receive(send('visibility',{visible:false,occluded:false,key:false}))).toBe(true);const old=send('shell',{...shell,scope:'all'});expect(await receive(send('clear',{generation:'42',viewRevision:'4'}))).toBe(true);expect(await receive(old)).toBe(false);await expect(page.locator('.eng-keys button[data-add-subscription]')).toHaveCount(0);
});

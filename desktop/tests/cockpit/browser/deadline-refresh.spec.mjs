// SPDX-License-Identifier: MIT
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {commands,pageId,appearance,shell,sample} from '../fixture.mjs';
const start='2026-10-29T12:00:00Z',later='2026-10-29T12:10:00Z',weekly='2026-10-29T12:20:00Z';
function dataFor(withDetails=false){
 const data=sample(),row=data.projection.rows[0],account=row.accounts[0],seed=account.windows[0];data.projection.rows=[row];account.valueState='current';
 account.windows=[
  {...seed,id:'live-five',role:'session',durationSeconds:18000,label:{en:'5h',zh:'5小时'},remainingPercent:0,current:true,observedAt:start,resetsAt:'2026-10-29T12:02:00Z',validUntil:'2026-10-29T12:02:00Z'},
  {...seed,id:'live-week',role:'weekly',durationSeconds:604800,label:{en:'Weekly',zh:'每周'},remainingPercent:80,current:true,observedAt:start,resetsAt:weekly,validUntil:weekly}
 ];
 if(withDetails)data.details={version:1,sources:['quota-thresholds'],subscriptions:[],sessions:[],sessionCoverage:'unavailable',resetEvents:[],alerts:[{source:row.id,subscriptionRef:account.subscriptionRef,windowId:'live-five',severity:'critical',remainingPercent:0}]};
 return data;
}
async function open(page,data,captureTimers=false){
 await page.addInitScript(()=>{window.__messages=[];window.webkit={messageHandlers:{cockpit:{postMessage(raw){window.__messages.push(JSON.parse(raw));}}}};});
 await page.clock.install({time:new Date(start)});await page.clock.pauseAt(new Date(start));await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 if(captureTimers)await page.evaluate(()=>{const original=window.setTimeout;window.__deadlineCallbacks=[];window.setTimeout=function(callback,delay,...args){if(typeof callback==='function'&&delay===60000)window.__deadlineCallbacks.push(()=>callback(...args));return original(callback,delay,...args);};});
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance,shell}))).toBe(true);expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);expect(await receive(send('display',{data}))).toBe(true);
 return {send,receive};
}
async function check(page,expired){
 const first=page.locator('.eng-cols .ec').first().locator('.qcell[data-row="first"]'),week=page.locator('.eng-cols .ec').first().locator('.qcell[data-row="second"]');
 await expect(first.locator('.qvalue')).toHaveText(expired?'--':'0');await expect(week.locator('.qvalue')).toHaveText('80');
 if(expired){await expect(page.locator('.s6-alert')).not.toHaveClass(/lit|red/);await expect(page.locator('.mfd-page .al-red')).toHaveCount(0);}
 else{await expect(page.locator('.s6-alert')).toHaveClass(/lit/);await expect(page.locator('.s6-alert')).toHaveClass(/red/);await expect(page.locator('.mfd-page .al-red')).toHaveCount(1);}
}
for(const details of [false,true])test(`deadline withdraws current reading without delivery (${details?'details':'no details'})`,async({page})=>{
 await open(page,dataFor(details));await check(page,false);const messageCount=await page.evaluate(()=>window.__messages.length);
 await page.clock.fastForward(119999);await check(page,false);
 await page.clock.fastForward(1);await check(page,true);
 await page.clock.fastForward(1000);await check(page,true);expect(await page.evaluate(()=>window.__messages.length)).toBe(messageCount);
});
test('replacement cancels old deadline and preserves the newer reading',async({page})=>{
 const data=dataFor(),{send,receive}=await open(page,data,true);await page.clock.fastForward(30000);
 data.projection.rows[0].accounts[0].windows[0].validUntil=later;data.projection.rows[0].accounts[0].windows[0].resetsAt=later;
 expect(await receive(send('display',{data}))).toBe(true);await page.evaluate(()=>window.__deadlineCallbacks[0]());await check(page,false);await page.clock.fastForward(90000);await check(page,false);
 await page.clock.fastForward(480000);await check(page,true);
});
for(const end of ['clear','unload'])test(`${end} retires deadline callbacks`,async({page})=>{
 const data=dataFor(),{send,receive}=await open(page,data,true);
 expect(await page.evaluate(()=>window.__deadlineCallbacks.length)).toBeGreaterThan(0);
 if(end==='clear')expect(await receive(send('clear',{viewRevision:'4'}))).toBe(true);else expect(await receive(send('unload'))).toBe(true);
 await page.evaluate(()=>window.__deadlineCallbacks[0]());await page.clock.fastForward(180000);await expect(page.locator('.qcell')).toHaveCount(0);await expect(page.locator('.mfd-page .al-red')).toHaveCount(0);
});
test('returning visible after a clock jump recomputes without delivery',async({page})=>{
 const {send,receive}=await open(page,dataFor(true),true);await check(page,false);
 expect(await receive(send('visibility',{visible:false,occluded:false,key:false}))).toBe(true);
 await page.clock.setSystemTime(new Date('2026-10-29T12:03:00Z'));
 await page.evaluate(()=>window.__deadlineCallbacks[0]());await check(page,false);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);await check(page,true);
});

test('deadline refresh preserves scope, engine page, focus and fader nodes',async({page})=>{
 const data=dataFor(),base=data.projection.rows[0];
 for(let i=1;i<7;i++){const row=structuredClone(base);row.id='tool'+i;row.name={en:'Tool '+i,zh:'工具 '+i};row.accounts[0].subscriptionRef=null;data.projection.rows.push(row);}
 const {send,receive}=await open(page,data);
 expect(await receive(send('shell',{...shell,scope:base.accounts[0].subscriptionRef}))).toBe(true);
 const pageTwo=page.getByRole('button',{name:'Page 2'});await pageTwo.click();await pageTwo.focus();
 await expect(pageTwo).toHaveAttribute('aria-current','true');
 await page.evaluate(()=>{window.__scaleNode=document.querySelector('.fd-scale .sc-l');window.__channelNode=document.querySelector('.fd-ch');});
 await page.clock.fastForward(120000);
 await expect(page.getByRole('button',{name:'Page 2'})).toHaveAttribute('aria-current','true');
 await expect(page.getByRole('button',{name:'Page 2'})).toBeFocused();
 await expect(page.locator('#cockpit')).toHaveAttribute('data-scope','subscription');
 expect(await page.evaluate(()=>window.__scaleNode===document.querySelector('.fd-scale .sc-l')&&window.__channelNode===document.querySelector('.fd-ch'))).toBe(true);
});

test('clock jumps are bounded and do not create a zero-delay loop',async({page})=>{
 const data=dataFor(),{send,receive}=await open(page,data,true);
 await page.clock.setSystemTime(new Date('2026-10-29T11:58:00Z'));await page.clock.fastForward(60000);await check(page,false);
 await page.clock.setSystemTime(new Date('2026-10-29T12:03:00Z'));await page.clock.fastForward(60000);await check(page,true);
 expect(await page.evaluate(()=>window.__deadlineCallbacks.length)).toBeLessThan(10);
 // An already expired or missing deadline must not schedule an immediate loop.
 data.projection.rows[0].accounts[0].windows[0].validUntil=start;data.projection.rows[0].accounts[0].windows[1].validUntil=null;
 expect(await receive(send('display',{data}))).toBe(true);const before=await page.evaluate(()=>window.__deadlineCallbacks.length);await page.clock.fastForward(180000);expect(await page.evaluate(()=>window.__deadlineCallbacks.length)).toBe(before);
});

test('document visibility resumes with fresh data and retires hidden callbacks',async({page})=>{
 await open(page,dataFor(),true);await check(page,false);
 await page.evaluate(()=>{Object.defineProperty(document,'hidden',{configurable:true,value:true});document.dispatchEvent(new Event('visibilitychange'));});
 await page.clock.setSystemTime(new Date('2026-10-29T12:03:00Z'));await page.evaluate(()=>window.__deadlineCallbacks[0]());await check(page,false);
 await page.evaluate(()=>{Object.defineProperty(document,'hidden',{configurable:true,value:false});document.dispatchEvent(new Event('visibilitychange'));});await check(page,true);
});

test('deadline refresh preserves scoped MFD page and focus',async({page})=>{
 const data=dataFor(true),{send,receive}=await open(page,data);
 expect(await receive(send('shell',{...shell,scope:data.projection.rows[0].accounts[0].subscriptionRef}))).toBe(true);
 const plans=page.getByRole('button',{name:'Plans',exact:true});await plans.click();await plans.focus();
 await page.clock.fastForward(120000);
 await expect(plans).toHaveAttribute('aria-pressed','true');await expect(plans).toBeFocused();
 const windows=page.locator('.mfd-page .sp-w');await expect(windows.filter({hasText:'5h'})).toContainText('--');await expect(windows.filter({hasText:'Weekly'})).toContainText('80%');
 await expect(page.locator('.s6-alert')).not.toHaveClass(/lit|red/);
});

test('far deadlines are bounded to one positive recheck timer',async({page})=>{
 const data=dataFor();for(const w of data.projection.rows[0].accounts[0].windows){w.validUntil='9999-12-31T23:59:59Z';w.resetsAt=null;}
 await open(page,data,true);expect(await page.evaluate(()=>window.__deadlineCallbacks.length)).toBe(1);
 await page.clock.fastForward(60000);await check(page,false);expect(await page.evaluate(()=>window.__deadlineCallbacks.length)).toBe(2);
});

test('deadline crossed during display schedules one follow-up without a host update',async({page})=>{
 const data=dataFor(),{send,receive}=await open(page,data);
 // Simulate the deadline falling between Engine and MFD work in one delivery.
 await page.clock.setSystemTime(new Date('2026-10-29T12:02:00Z'));
 await page.evaluate(()=>{const at=Date.parse('2026-10-29T12:02:00Z');let calls=0;window.__realNow=Date.now;Date.now=()=>++calls<=2?at-1:at;});
 expect(await receive(send('display',{data}))).toBe(true);
 await expect(page.locator('.eng-cols .ec').first().locator('.qcell[data-row="first"] .qvalue')).toHaveText('0');
 await page.evaluate(()=>{Date.now=window.__realNow;});await page.clock.fastForward(1);await check(page,true);
});

test('an admitted reset notice expires without another delivery',async({page})=>{
 const data=dataFor(true),account=data.projection.rows[0].accounts[0];account.windows[0].remainingPercent=80;data.details.alerts=[];
 data.details.resetEvents=[{version:1,id:'synthetic-reset',provider:'openai',rowId:data.projection.rows[0].id,status:'announced',publishedAt:start,expiresAt:'2026-10-29T12:02:00Z',source:{kind:'publication',publicationId:'0123456789abcdef01234567'}}];
 await open(page,data);await expect(page.locator('.s6-alert')).toHaveClass(/amber/);await expect(page.locator('.mfd-page .al-amber')).toHaveCount(1);
 await page.clock.fastForward(120000);await expect(page.locator('.s6-alert')).not.toHaveClass(/lit|amber|red/);await expect(page.locator('.mfd-page .al-amber')).toHaveCount(0);
 await expect(page.locator('.eng-cols .ec').first().locator('.qcell[data-row="second"] .qvalue')).toHaveText('80');
});

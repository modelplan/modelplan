// SPDX-License-Identifier: MIT
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {readFileSync} from 'node:fs';
import {commands,pageId,appearance,shell,sample} from '../fixture.mjs';
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
 const {tick}=await open(page,data);expect((await reports(page)).at(-1).deadlineUnixMs).toBe(String(Date.parse(at)));await expect(page.locator('.s6-alert')).toHaveClass(/amber/);expect(await tick(at)).toBe(true);await expect(page.locator('.s6-alert')).not.toHaveClass(/lit|amber|red/);expect((await reports(page)).at(-1).deadlineUnixMs).toBe(String(Date.parse(week)));
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

// SPDX-License-Identifier: MIT
// G3-56 / CKP-STRIP-06: a new caution blinks until pressed or ten seconds; pressing acknowledges it. Only a red
// escalation or a true recurrence (the condition cleared on a real reading and came back) blinks again. Changing
// numbers, a refresh, a close/reopen, a pending read or an app restart never re-blink. Built page, synthetic data only.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell,excludePortholeFlicker} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';

test.beforeEach(async({page})=>excludePortholeFlicker(page));
function zeroData(){
 const data=visualFixture().data;data.details=null;data.projection.rows=data.projection.rows.slice(0,1);
 const account=data.projection.rows[0].accounts[0];for(const w of account.windows)w.remainingPercent=75;
 return {data,account,windows:account.windows};
}
async function open(page,data,acked){
 await page.addInitScript(()=>{window.posted=[];window.webkit={messageHandlers:{cockpit:{postMessage(m){window.posted.push(m);}}}};});
 await page.clock.setFixedTime(new Date('2026-11-04T12:00:00Z'));
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance,shell,redBelow:25,...(acked?{ackedCautions:acked}:{})}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data}))).toBe(true);
 return {send,receive,lamp:page.locator('[data-caution]')};
}
const flash=/\bflash\b/;
async function pressed(page,lamp){await page.getByRole('button',{name:'Subscription',exact:true}).click();await lamp.click();await expect(page.locator('.pg-alerts .mfd-alerts.all.ack')).toBeVisible();await page.keyboard.press('Escape');await expect(lamp).not.toHaveClass(flash);}

test('G3-56 a pressed 0% caution stays steady through refreshes with the same state',async({page})=>{
 const {data,windows}=zeroData(),{send,receive,lamp}=await open(page,(()=>{return data;})());
 windows[0].remainingPercent=0;expect(await receive(send('display',{data}))).toBe(true);
 await expect(lamp).toHaveClass(flash);await pressed(page,lamp);
 // A refresh that moves the reset time, or the number, is the same caution.
 windows[0].resetsAt=new Date(Date.parse(windows[0].resetsAt??'2026-11-04T17:00:00Z')+60000).toISOString().replace('.000Z','Z');
 for(const pct of [0,0,3,0]){windows[0].remainingPercent=pct;expect(await receive(send('display',{data}))).toBe(true);await expect(lamp).not.toHaveClass(flash);await expect(lamp).toHaveClass(/\blit\b/);}
});

test('G3-56 a pending read between two 0% readings is not a clear',async({page})=>{
 const {data,account,windows}=zeroData(),{send,receive,lamp}=await open(page,data);
 windows[0].remainingPercent=0;expect(await receive(send('display',{data}))).toBe(true);await expect(lamp).toHaveClass(flash);await pressed(page,lamp);
 account.valueState='retained';expect(await receive(send('display',{data}))).toBe(true);
 account.valueState='current';expect(await receive(send('display',{data}))).toBe(true);
 await expect(lamp).not.toHaveClass(flash);await expect(lamp).toHaveClass(/\blit\b/);
});

test('G3-56 a pressed caution stays steady after the cockpit closes and reopens',async({page})=>{
 const {data,windows}=zeroData(),{send,receive,lamp}=await open(page,data);
 windows[0].remainingPercent=0;expect(await receive(send('display',{data}))).toBe(true);await expect(lamp).toHaveClass(flash);await pressed(page,lamp);
 expect(await receive(send('shell',{...shell,profile:'closed'}))).toBe(true);
 expect(await receive(send('shell',shell))).toBe(true);expect(await receive(send('display',{data}))).toBe(true);
 await expect(lamp).not.toHaveClass(flash);
});

// The page reports each acknowledgement to the host (action cautionAck), which keeps it in the app's preferences and
// returns it in the next load. The page's own web view keeps nothing.
const posted=page=>page.evaluate(()=>window.posted.map(m=>typeof m==='string'?JSON.parse(m):m).filter(m=>m.type==='action'&&m.action==='cautionAck').map(m=>m.ids));
test('G3-56 a pressed caution is reported to the host and stays steady after an app restart',async({page})=>{
 const {data,windows}=zeroData();windows[0].remainingPercent=0;
 let o=await open(page,data);await expect(o.lamp).toHaveClass(flash);await pressed(page,o.lamp);
 const reports=await posted(page);expect(reports).toHaveLength(1);expect(reports[0]).toHaveLength(1);
 const ids=reports[0];
 // Restart: a fresh page whose load carries what the host remembered.
 o=await open(page,data,ids);await expect(o.lamp).toHaveClass(/\blit\b/);await expect(o.lamp).not.toHaveClass(flash);
 expect(await posted(page)).toEqual([]);
 // Without the host's memory the same page blinks again, so the memory is what keeps it steady.
 o=await open(page,data);await expect(o.lamp).toHaveClass(flash);
});

test('G3-56 a recurrence is reported so the host forgets the cleared caution',async({page})=>{
 const {data,windows}=zeroData();windows[0].remainingPercent=0;
 const {send,receive,lamp}=await open(page,data);await expect(lamp).toHaveClass(flash);await pressed(page,lamp);
 for(const w of windows)w.remainingPercent=75;expect(await receive(send('display',{data}))).toBe(true);
 expect((await posted(page)).at(-1)).toEqual([]);
});

test('G3-56 a real clear and return blinks again, and so does a second window going red',async({page})=>{
 const {data,windows}=zeroData(),{send,receive,lamp}=await open(page,data);
 windows[0].remainingPercent=0;expect(await receive(send('display',{data}))).toBe(true);await expect(lamp).toHaveClass(flash);await pressed(page,lamp);
 windows[1].remainingPercent=10;expect(await receive(send('display',{data}))).toBe(true);await expect(lamp).toHaveClass(flash);await pressed(page,lamp);
 for(const w of windows)w.remainingPercent=75;expect(await receive(send('display',{data}))).toBe(true);await expect(lamp).not.toHaveClass(/\b(lit|flash)\b/);
 windows[0].remainingPercent=0;expect(await receive(send('display',{data}))).toBe(true);await expect(lamp).toHaveClass(flash);
});

test('G3-56 pressing the lamp flashes the newest acknowledged caution row once, steady under Reduce Motion',async({page})=>{
 const {data,windows}=zeroData(),{send,receive,lamp}=await open(page,data);
 windows[0].remainingPercent=0;expect(await receive(send('display',{data}))).toBe(true);
 windows[1].remainingPercent=10;expect(await receive(send('display',{data}))).toBe(true);
 await page.getByRole('button',{name:'Subscription',exact:true}).click();await lamp.click();
 const marked=page.locator('.pg-alerts .mfd-alerts li.al-mark');await expect(marked).toHaveCount(1);
 await expect(marked).toHaveClass(/\bal-flash\b/);
 const animation=await marked.evaluate(e=>{const s=getComputedStyle(e);return {name:s.animationName,count:s.animationIterationCount};});
 expect(animation.name).not.toBe('none');expect(animation.count).toBe('1');
 // It is the row of the caution that arrived last (the second window), and a refresh does not replay the flash.
 await expect(marked).toContainText('10%');
 expect(await receive(send('display',{data}))).toBe(true);await expect(marked).toHaveCount(1);await expect(marked).not.toHaveClass(/\bal-flash\b/);
 await page.keyboard.press('Escape');
 expect(await receive(send('appearance',{...appearance,reduceMotion:true}))).toBe(true);
 await lamp.click();await expect(marked).toHaveCount(1);
 expect(await marked.evaluate(e=>getComputedStyle(e).animationName)).toBe('none');
 expect(await marked.evaluate(e=>getComputedStyle(e).backgroundColor)).not.toBe('rgba(0, 0, 0, 0)');
});

test('G3-56 a pressed amber caution that escalates to red blinks again',async({page})=>{
 const iso=minutes=>new Date(Date.parse('2026-11-04T12:00:00Z')+minutes*60000).toISOString();
 const data=visualFixture().data,row=data.projection.rows[0],account=row.accounts[0],w=account.windows[0];
 for(const r of data.projection.rows)for(const a of r.accounts)for(const x of a.windows)if(x.remainingPercent!==null)x.remainingPercent=90;
 w.remainingPercent=60;w.resetsAt=iso(300);
 data.details.forecasts=[{source:row.id,subscriptionRef:account.subscriptionRef,windowId:w.id,runsOutAt:iso(40),pace:'tight',basis:'recent-rate',observedAt:iso(-2),}];
 const {send,receive,lamp}=await open(page,data);
 await expect(lamp).toHaveClass(/\bamber\b/);await expect(lamp).toHaveClass(flash);await pressed(page,lamp);
 // The same amber caution with other numbers stays steady.
 w.remainingPercent=55;expect(await receive(send('display',{data}))).toBe(true);await expect(lamp).not.toHaveClass(flash);
 // Crossing the red line is an escalation: a different severity, so it blinks.
 w.remainingPercent=20;expect(await receive(send('display',{data}))).toBe(true);
 await expect(lamp).toHaveClass(/\bred\b/);await expect(lamp).toHaveClass(flash);
});

test('G3-56 a fallback member (no verified subscription reference) is acknowledged in memory only',async({page})=>{
 const {data,windows}=zeroData();windows[0].remainingPercent=0;
 // No verified subscription: the member is keyed row#route, which names a different account after a restart.
 data.subscriptions=[];for(const a of data.projection.rows[0].accounts)a.subscriptionRef=null;
 let o=await open(page,data);await expect(o.lamp).toHaveClass(flash);await pressed(page,o.lamp);
 expect(await posted(page)).toEqual([]);
 // This session: a refresh stays steady.
 expect(await o.receive(o.send('display',{data}))).toBe(true);await expect(o.lamp).not.toHaveClass(flash);
 // A host that was handed such an id anyway (an older build) cannot suppress a blink with it.
 const id=JSON.stringify([data.projection.rows[0].id+'#'+data.projection.rows[0].accounts[0].route,windows[0].id,'red']);
 o=await open(page,data,[id]);await expect(o.lamp).toHaveClass(flash);
});

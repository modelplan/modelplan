// SPDX-License-Identifier: MIT
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,currentSample,pageId,shell} from '../fixture.mjs';

test('S7 general and scoped windows keep named rows, tightest Other, plus count and unknown',async({page})=>{
 await page.clock.setFixedTime(new Date('2026-11-03T12:00:00Z'));await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const data=currentSample(),row=data.projection.rows[0],account=row.accounts[0],seed=account.windows[0];data.projection.rows=[row];data.subscriptions=[];account.subscriptionRef=null;account.accountLocator=null;
 const w=(role,duration,limit,pool,remaining)=>({...structuredClone(seed),id:`${role}:${duration}:${limit}:${pool}`,role,durationSeconds:duration,limitKey:limit,poolKey:pool,remainingPercent:remaining,current:true,validUntil:'2030-01-01T00:00:00Z',resetsAt:null});
 const five=w('session',18000,'main','main',70),weekly=w('weekly',604800,'main','main',60),special=w('weekly',604800,'code_review','code_review',10),monthly=w('monthly',2592000,'main','main',30);
 special.modelScope={models:['opus']};account.windows=[special,monthly,weekly,five];
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 for(const raw of [send('load',{appearance,shell,redBelow:25}),send('visibility',{visible:true,occluded:false,key:true}),send('display',{data})])expect(await receive(raw)).toBe(true);
 const col=page.locator('.eng-cols .ec').first(),cell=name=>col.locator(`.qcell[data-row="${name}"]`);
 await expect(cell('first').locator('.qvalue')).toHaveText('70');await expect(cell('second').locator('.qvalue')).toHaveText('60');await expect(cell('other').locator('.qvalue')).toHaveText('10');await expect(cell('other').locator('.qtxt')).toContainText('+1');await expect(cell('other')).toHaveAttribute('data-more','1');
 special.remainingPercent=0;expect(await receive(send('display',{data}))).toBe(true);await expect(cell('other').locator('.qvalue')).toHaveText('0');await expect(cell('other')).toHaveAttribute('aria-label',/0/);
 special.remainingPercent=null;monthly.remainingPercent=null;expect(await receive(send('display',{data}))).toBe(true);await expect(cell('other').locator('.qvalue')).toHaveText('--');
 five.validUntil='2026-11-03T11:59:00Z';expect(await receive(send('display',{data}))).toBe(true);await expect(cell('first').locator('.qvalue')).toHaveText('--');await expect(cell('second').locator('.qvalue')).toHaveText('60');
});

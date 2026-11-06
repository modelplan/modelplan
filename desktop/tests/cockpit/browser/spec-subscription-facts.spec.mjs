// SPDX-License-Identifier: MIT
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';

test('CKP-MFD-10 subscription page shows admitted header and window facts',async({page})=>{
 const now=Date.now(),data=visualFixture().data,row=data.projection.rows[0],account=row.accounts[0];
 row.name.en='Synthetic Provider';account.plan.name={en:'Synthetic Plan',zh:'合成方案'};
 account.observedAt=new Date(now-5*60000).toISOString();account.freshUntil=new Date(now+86400000).toISOString();
 for(const w of account.windows){w.observedAt=account.observedAt;w.validUntil=account.freshUntil;w.resetsAt=new Date(now+138*60000).toISOString();}
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 for(const raw of [send('load',{appearance,shell}),send('visibility',{visible:true,occluded:false,key:true}),send('display',{data}),send('tick',{nowUnixMs:String(now),reason:'clockChange'})])expect(await receive(raw)).toBe(true);
 const click=async locator=>{await expect(locator).toBeVisible();const r=await locator.boundingBox();expect(r).not.toBeNull();await page.mouse.click(r.x+r.width/2,r.y+r.height/2);};
 await click(page.getByRole('button',{name:'Subscription',exact:true}));await click(page.locator('.eng-keys .ek[data-sub]').first());
 const view=page.locator('.pg-sub');await expect(view.locator('.sp-h b')).toHaveText('Synthetic Provider');await expect(view.locator('.sp-h .mg')).toBeVisible();
 await expect(view.locator('.sp-sub .pl')).toHaveText('Synthetic Plan');await expect(view.locator('.sp-sub .src')).toHaveText('modelplan · 5 min ago');
 const windows=view.locator('.sp-w');await expect(windows).toHaveCount(2);
 for(let i=0;i<2;i++){const w=windows.nth(i);await expect(w.locator('.mb10 i')).toHaveCount(10);await expect(w.locator('.v')).toHaveText(i===0?'75%':'40%');await expect(w.locator('em')).toContainText('2h18');}
});

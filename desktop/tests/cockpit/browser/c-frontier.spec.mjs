// SPDX-License-Identifier: MIT
// The frontier on the Effort page, from published public data through the normal bridge (owner D39/D-B). Synthetic data.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';

const effort=(key,ability,cost,star=false)=>({effort:key,label:key,star,ability,cost,time:30});
const model=(id,efforts)=>({id,name:'Synthetic '+id,developerId:'openai',recommended:'high',efforts});
const models=[model('leader',[effort('low',30,.1),effort('high',50,.4,true)]),model('behind',[effort('high',35,.9,true)])];
async function open(page,published) {
 const {data}=visualFixture();if(published)data.details.publishedModels=published;
 await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance,shell,redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data}))).toBe(true);
 await page.getByRole('button',{name:'Models',exact:true}).click();
}
test('D-B the frontier plots published points, stars each model and dims the dominated one',async({page})=>{
 await open(page,models);
 await expect(page.locator('.fc-star')).toHaveCount(2);await expect(page.locator('.fc-star.dim')).toHaveCount(1);
 expect((await page.locator('.fc-front').getAttribute('points')).trim().split(/\s+/).length).toBe(2);
 await expect(page.locator('.fc-l',{hasText:'Synthetic leader'})).toHaveCount(1);
 await expect(page.locator('.fc-inspect')).toHaveCount(3);
});
test('D-B an effort without a published cost is not plotted',async({page})=>{
 await open(page,[model('a',[effort('low',30,null),effort('high',50,.4,true)])]);
 await expect(page.locator('.fc-inspect')).toHaveCount(1);
});
test('D-B an older engine shows no chart and says so',async({page})=>{
 await open(page,null);
 await expect(page.locator('.fc')).toHaveCount(0);await expect(page.locator('.mfd-page .mp-empty')).toHaveText('Data unavailable');
});

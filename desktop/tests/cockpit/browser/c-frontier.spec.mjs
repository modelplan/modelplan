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
 await page.getByRole('button',{name:'Models',exact:true}).click(); await page.locator('.ok[data-opt="models"] b[data-choice="chart"]').click();
}
test('D-B the frontier plots published points, stars each model and dims the dominated one',async({page})=>{
 await open(page,models);
 await expect(page.locator('.fc-star')).toHaveCount(2);await expect(page.locator('.fc-star.dim')).toHaveCount(1);
 // D386: only the leader's recommended effort is on the shared frontier;
 // its lower effort remains inspectable but no longer extends the line.
 expect((await page.locator('.fc-front').getAttribute('points')).trim().split(/\s+/).length).toBe(1);
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

test('D386 HUD and enlarged chart use the same recommended-effort frontier',async({page})=>{
 const fleet=[model('A',[effort('high',60,.4,true)]),model('B',[effort('low',65,.3),effort('high',70,.7,true)]),model('C',[effort('low',40,.1),effort('high',45,.6,true)])];
 await open(page,fleet);
 const hud=await page.locator('.hud .hp').evaluateAll(rows=>rows.map(r=>r.dataset.hudModel));
 expect(hud).toEqual(['B','A']);
 await expect(page.locator('.fc-l',{hasText:'Synthetic A'})).not.toHaveClass(/\bdim\b/);
 await expect(page.locator('.fc-l',{hasText:'Synthetic B'})).not.toHaveClass(/\bdim\b/);
 await expect(page.locator('.fc-l',{hasText:'Synthetic C'})).toHaveClass(/\bdim\b/);
 await expect(page.locator('.fc-inspect')).toHaveCount(5);
});

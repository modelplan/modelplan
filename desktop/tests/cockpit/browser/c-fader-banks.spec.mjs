// SPDX-License-Identifier: MIT
// QA 11-08 / owner: one fader per model, three per bank, paged with ◀ ▶ and [ ] (CKP-FAD-01, CKP-FAD-02, CKP-FAD-15).
// The built page through its normal bridge; synthetic data only.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell,excludePortholeFlicker} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';

test.beforeEach(async({page})=>excludePortholeFlicker(page));
const model=(id,developerId)=>({id,name:'Synthetic '+id,developerId,recommended:'medium',efforts:[{effort:'low',label:'Low',star:false,ability:30,cost:1,time:null},{effort:'medium',label:'Med',star:true,ability:40,cost:2,time:null}]});
// The engine's publication: three models, the one in use first. Published: those three, four more OpenAI models,
// one from a developer with no subscription here (xAI) and one Anthropic model in use beyond the engine's three.
function fixture(){
 const data=visualFixture().data;
 const publication=[model('used','openai'),model('lineup-1','openai'),model('lineup-2','anthropic')];
 data.details.publication={contractVersion:1,publicationId:'0123456789abcdef01234567',publishedAt:'2026-10-24T12:00:00Z',source:'client',truncated:true,models:publication};
 data.details.publishedModels=[...publication,model('more-1','openai'),model('xai-1','xai'),model('more-2','openai'),model('also-used','anthropic'),model('more-3','openai')];
 data.details.sessions=[{sessionRef:'00000000000000a1',source:'codex',subscriptionRef:null,model:'used',effort:'medium',projectLabel:null,lastObservedAt:new Date().toISOString(),state:'running',rate:null},
  {sessionRef:'00000000000000a2',source:'claude',subscriptionRef:null,model:'also-used',effort:'medium',projectLabel:null,lastObservedAt:new Date().toISOString(),state:'idle',rate:null}];
 return data;
}
async function open(page,data){
 await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance,shell,redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data}))).toBe(true);
}
const names=page=>page.locator('.fd-ch:not(.empty) .fd-strip').evaluateAll(list=>list.map(e=>e.getAttribute('aria-label').split(':')[0]));

test('CKP-FAD-01 one fader per model beyond the engine three, three per bank, models in use first',async({page})=>{
 await open(page,fixture());
 await expect(page.locator('.bank-lcd')).toHaveText('Bank 1/3');
 expect(await names(page)).toEqual(['Synthetic used','Synthetic also-used','Synthetic lineup-1']);
 await page.locator('[data-bank="1"]').click();await expect(page.locator('.bank-lcd')).toHaveText('Bank 2/3');
 expect(await names(page)).toEqual(['Synthetic lineup-2','Synthetic more-1','Synthetic more-2']);
 await page.locator('[data-bank="1"]').click();await expect(page.locator('.bank-lcd')).toHaveText('Bank 3/3');
 expect(await names(page)).toEqual(['Synthetic more-3']);
 // A developer without a subscription here gets no fader.
 for(const label of await page.locator('.fd-strip[aria-label]').evaluateAll(l=>l.map(e=>e.getAttribute('aria-label'))))expect(label).not.toContain('xai-1');
});

test('CKP-FAD-15 [ and ] page the banks like ◀ ▶',async({page})=>{
 await open(page,fixture());
 await page.keyboard.press(']');await expect(page.locator('.bank-lcd')).toHaveText('Bank 2/3');
 await page.keyboard.press(']');await expect(page.locator('.bank-lcd')).toHaveText('Bank 3/3');
 await page.keyboard.press('[');await expect(page.locator('.bank-lcd')).toHaveText('Bank 2/3');
 await page.locator('[data-bank="-1"]').click();await expect(page.locator('.bank-lcd')).toHaveText('Bank 1/3');
});

test('CKP-FAD-01 three models or fewer keep one bank and no pager',async({page})=>{
 const data=fixture();data.details.publishedModels=data.details.publication.models;
 await open(page,data);
 await expect(page.locator('.fd-ch:not(.empty)')).toHaveCount(3);await expect(page.locator('.bank-lcd')).toHaveCount(0);
});

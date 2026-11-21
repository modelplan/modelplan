// SPDX-License-Identifier: MIT
// Post-merge sampling #930 (2026-11-14), with Settings' "show all models" off (D123):
// (1) a model used earlier this week is "in use" through the recorded sessions (details.recentSessions), not only the
//     live ones, so it stays (D135) and leads the set;
// (2) a stale reading does not remove a subscription's published models: the plan is still the user's.
// The built page through its normal bridge; synthetic data only.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell,excludePortholeFlicker} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';

test.beforeEach(async({page})=>excludePortholeFlicker(page));
const model=(id,developerId)=>({id,name:'Synthetic '+id,developerId,recommended:'medium',efforts:[{effort:'low',label:'Low',star:false,ability:30,cost:1,time:null},{effort:'medium',label:'Med',star:true,ability:40,cost:2,time:null}]});
const CLAUDE='0000000000000002';
function fixture(){
 const data=visualFixture().data;
 const publication=[model('gpt-a','openai'),model('gpt-b','openai'),model('claude-a','anthropic')];
 data.details.publication={contractVersion:1,publicationId:'0123456789abcdef01234567',publishedAt:'2026-10-24T12:00:00Z',source:'client',truncated:true,models:publication};
 data.details.publishedModels=[...publication,model('claude-b','anthropic'),model('gemini-a','google'),model('gpt-c','openai'),model('grok-a','xai')];
 data.details.sessions=[];
 return data;
}
async function open(page,data){
 await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance,shell,redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data}))).toBe(true);
 return {send,receive};
}
const names=page=>page.locator('.fd-ch:not(.empty) .fd-strip').evaluateAll(list=>list.map(e=>e.getAttribute('aria-label').split(':')[0]));
const allNames=async page=>{const out=[];const lcd=page.locator('.bank-lcd');const total=await lcd.count()?Number((await lcd.textContent()).match(/\/(\d+)/)[1]):1;
 for(let i=0;i<total;i++){out.push(...await names(page));if(i<total-1)await page.locator('[data-bank="1"]').click();}return out;};

test('sampling-930 a model of no own plan recorded two days ago (no live session) stays and leads the in-use order',async({page})=>{
 const data=fixture();
 data.details.recentSessions=[{sessionRef:'00000000000000b1',source:'grok',subscriptionRef:null,model:'grok-a',effort:'medium',projectLabel:null,lastObservedAt:new Date(Date.now()-2*86_400_000).toISOString()}];
 await open(page,data);
 const all=await allNames(page);
 // No subscription runs xAI's models: only the recorded session keeps grok-a (D135), and it leads the set (D123).
 expect(all[0]).toBe('Synthetic grok-a');
});

test('sampling-930 a stale reading keeps the subscription\'s published models',async({page})=>{
 const data=fixture();
 for(const row of data.projection.rows)if(row.id==='claude')for(const account of row.accounts)account.valueState='retained';
 for(const s of data.subscriptions)for(const a of s.accounts)if(a.tool==='claude')a.account.valueState='retained';
 const {send,receive}=await open(page,data);
 expect([...await allNames(page)].sort()).toEqual(['Synthetic claude-a','Synthetic claude-b','Synthetic gemini-a','Synthetic gpt-a','Synthetic gpt-b','Synthetic gpt-c']);
 expect(await receive(send('shell',{...shell,scope:CLAUDE}))).toBe(true);
 expect([...await allNames(page)].sort()).toEqual(['Synthetic claude-a','Synthetic claude-b']);
});

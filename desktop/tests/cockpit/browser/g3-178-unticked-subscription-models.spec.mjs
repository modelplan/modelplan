// SPDX-License-Identifier: MIT
// D391 (owner 11-22) through the normal bridge: a subscription unticked in Settings has no card (its row keeps the
// menu/settings surfaces only), so its models never show in any cockpit model view — fader banks, model cards, the
// porthole HUD — even when local sessions use them. This replaces the D123/D135 live-use inclusion (the G3-176
// report: a live ZCode session on GLM-5.3). The session tape still names the session; it is a session view, not a
// model view.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell,excludePortholeFlicker} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';

test.beforeEach(async({page})=>excludePortholeFlicker(page));
const model=(id,developerId)=>({id,name:'Synthetic '+id,developerId,recommended:'medium',efforts:[{effort:'low',label:'Low',star:false,ability:30,cost:1,time:null},{effort:'medium',label:'Med',star:true,ability:40,cost:2,time:null}]});
function fixture(){
 const {data}=visualFixture();
 // Codex ticked; ZCode unticked in Settings: its row keeps no dock surface, so it has no subscription card.
 const codex=data.projection.rows[0],seed=structuredClone(codex);
 codex.surfaces=['dock','menu','settings'];
 const zai=seed;zai.id='zai';zai.name={en:'ZCode',zh:'ZCode'};zai.surfaces=['menu','settings'];zai.accounts.forEach(a=>{a.subscriptionRef=null;a.accountLocator=null;});
 data.projection.rows=[codex,zai];
 const publication=[model('used','openai')];
 data.details.publication={contractVersion:1,publicationId:'0123456789abcdef01234567',publishedAt:'2026-10-24T12:00:00Z',source:'client',truncated:true,models:publication};
 data.details.publishedModels=[...publication,model('glm-live','zhipuai'),model('glm-rest','zhipuai')];
 const at=new Date().toISOString();
 data.details.sessions=[
  {sessionRef:'00000000000000a1',source:'codex',subscriptionRef:null,model:'used',effort:'medium',projectLabel:null,lastObservedAt:at,state:'running',rate:null},
  {sessionRef:'00000000000000a2',source:'zcode',subscriptionRef:null,model:'glm-live',effort:'medium',projectLabel:null,lastObservedAt:at,state:'running',rate:null},
  {sessionRef:'00000000000000a3',source:'zcode',subscriptionRef:null,model:'unknown',modelDisplay:'GLM-5.3 live',effort:null,projectLabel:null,lastObservedAt:at,state:'running',rate:null},
 ];
 // ghglm-1171-1: usage recorded before unticking still ranks the GLM model in the (unattributed) history.
 const ranking=measure=>({measure,attribution:'unattributed',recent7d:{entities:1,totalObservedOutputTokens:404000,top:[{name:'glm-live',observedOutputTokens:404000,observedRequests:80,share:1}]},recent30d:{entities:0,totalObservedOutputTokens:0,top:[]}});
 data.history={version:1,sources:['local-history'],coverage:'local-history',recordingSince:null,dailyFrom:null,subscriptions:[],models:ranking('observed-output-tokens'),tools:ranking('observed-output-tokens'),daily:[],hourly:[],projects:{recent7d:[],recent30d:[]},cycles:[]};
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

test('D391 an unticked subscription\'s models show in no cockpit model view, live sessions and history included',async({page})=>{
 await open(page,fixture());
 // Fader banks: only the ticked subscription's in-use model; no GLM fader, no unlisted "GLM-5.3 live" card,
 // and the history ranking (ghglm-1171-1) adds no GLM fader either.
 await expect(page.locator('.fd-ch:not(.empty)')).toHaveCount(1);
 await expect(page.locator('.fd-ch:not(.empty) .fd-strip')).toHaveAttribute('aria-label',/^Synthetic used:/);
 // Porthole HUD: no GLM row (the list is the members' own models; the unticked tool adds none).
 for(const row of await page.locator('.hud .hp').all())await expect(row).not.toContainText('GLM');
 // Models page (ghglm-1171-2): its list is the same member set; the unticked developer's model has no row.
 await page.locator('[data-mfd="page:tune"]').click();
 await expect(page.locator('.pg-tune .md-row')).toBeVisible();
 for(const row of await page.locator('.pg-tune .md-row').all())await expect(row).not.toContainText('GLM');
 await expect(page.locator('.pg-tune .md-row .md-n').first()).toHaveText('Synthetic used');
 // Outside the session tape no text names the unticked subscription's models.
 const texts=await page.locator('#cockpit').evaluate(root=>[...root.querySelectorAll('*')].filter(e=>!e.closest('.ck-tape')&&e.children.length===0).map(e=>e.textContent).filter(t=>t&&t.includes('GLM')));
 expect(texts).toEqual([]);
});

test('D391 a ticked subscription keeps its sessions\' models (the filter is the subscription, not the live-use rule)',async({page})=>{
 const data=fixture();
 data.details.publishedModels=[...data.details.publishedModels,model('claude-used','anthropic')];
 const claude=structuredClone(data.projection.rows[0]);claude.id='claude';claude.name={en:'Claude Code',zh:'Claude Code'};claude.surfaces=['dock','menu','settings'];
 claude.accounts.forEach((a,i)=>{a.subscriptionRef='00000000000000b'+(i+1);a.accountLocator=a.subscriptionRef;});
 data.projection.rows.push(claude);
 data.details.sessions.push({sessionRef:'00000000000000a4',source:'claude',subscriptionRef:null,model:'claude-used',effort:'medium',projectLabel:null,lastObservedAt:new Date().toISOString(),state:'running',rate:null});
 await open(page,data);
 const labels=await page.locator('.fd-ch:not(.empty) .fd-strip').evaluateAll(list=>list.map(e=>e.getAttribute('aria-label').split(':')[0]));
 expect(labels).toContain('Synthetic claude-used');
 expect(labels.some(l=>l.includes('GLM'))).toBe(false);
});

test('D391 a Settings visibility update removes model cards but preserves the session tape',async({page})=>{
 const data=fixture(),zai=data.projection.rows[1],ref='1122334455667788';
 zai.surfaces=['dock','menu','settings'];zai.accounts[0].subscriptionRef=ref;zai.accounts[0].accountLocator=ref;
 data.subscriptions.push({subscriptionRef:ref,accounts:[{tool:'zai',account:structuredClone(zai.accounts[0])}]});
 const {send,receive}=await open(page,data);
 await expect(page.locator('.fd-ch:not(.empty) .fd-strip[aria-label^="Synthetic glm-live:"]')).toHaveCount(1);
 await expect(page.locator('.ck-tape [data-session="00000000000000a2"]')).toHaveCount(1);
 expect(await receive(send('shell',{...shell,scope:ref}))).toBe(true);
 await expect(page.locator('#cockpit')).toHaveAttribute('data-scope','subscription');
 expect(await receive(send('appearance',{...appearance,hiddenMembers:[ref]}))).toBe(true);
 await expect(page.locator('.fd-ch:not(.empty) .fd-strip[aria-label^="Synthetic glm-live:"]')).toHaveCount(0);
 await expect(page.locator('.ck-tape [data-session="00000000000000a2"]')).toHaveCount(1);
 await expect(page.locator('#cockpit')).toHaveAttribute('data-scope','all');
 expect(await receive(send('appearance',{...appearance}))).toBe(true);
 await expect(page.locator('.fd-ch:not(.empty) .fd-strip[aria-label^="Synthetic glm-live:"]')).toHaveCount(1);
 const codexRef=data.projection.rows[0].accounts[0].subscriptionRef;
 expect(await receive(send('appearance',{...appearance,hiddenMembers:[ref,codexRef]}))).toBe(true);
 await expect(page.locator('.fd-ch:not(.empty)')).toHaveCount(0);
 await expect(page.locator('.ck-tape [data-session="00000000000000a2"]')).toHaveCount(1);
});

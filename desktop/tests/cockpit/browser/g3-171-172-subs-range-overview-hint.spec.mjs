// SPDX-License-Identifier: MIT
// G3-171 / G3-172 (owner test build 3): the Subscriptions page always draws from the header's range and shows a loading
// state, never an empty page, before the first reply; the Overview's bottom keys follow the chart mode.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell,excludePortholeFlicker} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';

test.beforeEach(async({page})=>excludePortholeFlicker(page));
const NOW=new Date(2026,10,4,12).getTime();
const localDay=back=>{const d=new Date(2026,10,4-back);return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`;};
const sums=out=>({inputTokens:null,outputTokens:out,cacheReadTokens:null,cacheWriteTokens:null,cacheHitRatio:null,generationTps:null,observedRequests:1,eligibleRequests:1});
const ranking={measure:'observed-output-tokens',attribution:'unattributed',recent7d:{entities:0,totalObservedOutputTokens:0,top:[]},recent30d:{entities:0,totalObservedOutputTokens:0,top:[]}};
function history(){
 const data=visualFixture().data,ref=data.projection.rows[0].accounts[0].subscriptionRef;
 data.history={version:1,sources:['local-history'],coverage:'local-history',recordingSince:null,dailyFrom:localDay(39),
  subscriptions:[{subscriptionRef:ref,sources:[{source:'codex',bindingBasis:'source-wide-current-binding',recent7d:sums(1),recent30d:sums(1)}]}],
  models:ranking,tools:ranking,daily:[[0,200],[1,1000],[3,4000],[8,20000]].map(([back,n])=>({at:localDay(back),source:'codex',origin:'live',observedOutputTokens:n})),hourly:[],
  projects:{recent7d:[],recent30d:[]},cycles:[]};
 return data;
}
async function open(page,{display=true}={}){
 await page.addInitScript(()=>{window.__msgs=[];window.webkit={messageHandlers:{cockpit:{postMessage(raw){window.__msgs.push(JSON.parse(raw));}}}};});
 await page.clock.setFixedTime(new Date(NOW));
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance,shell:{...shell,range:'7d'},redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 if(display)expect(await receive(send('display',{data:history()}))).toBe(true);
 return {send,receive};
}
const header=page=>page.locator('[data-range-key][aria-checked="true"]');
const pageKey=page=>page.locator('[data-opt="range"] b.on');
const plans=async page=>{await page.keyboard.press('1');await page.getByRole('button',{name:'Plans',exact:true}).click();};

test('G3-171 a range chosen in the header while another tab is open is the range the Subscriptions page draws',async({page})=>{
 await open(page);
 await page.locator('[data-range-key="30d"]').click();
 await plans(page);
 await expect(page.locator('.sp-stats')).toHaveAttribute('data-days','30');
 await expect(pageKey(page)).toHaveText('30d');
 await expect(header(page)).toHaveAttribute('data-range-key','30d');
 await page.locator('[data-range-key="today"]').click();
 await expect(page.locator('.sp-stats')).toHaveAttribute('data-days','today');
 await expect(pageKey(page)).toHaveText('Today');
 await expect(header(page)).toHaveAttribute('data-range-key','today');
});

test('G3-171 a host echo of an older range never splits the header from the Subscriptions page',async({page})=>{
 const {send,receive}=await open(page);
 await plans(page);
 await page.locator('[data-range-key="30d"]').click();
 const scope=await page.evaluate(()=>window.__msgs.filter(m=>m.action==='scopeSelect').at(-1)?.key??'all');
 expect(await receive(send('shell',{...shell,scope,range:'today'}))).toBe(true);
 await expect(header(page)).toHaveAttribute('data-range-key','today');
 await expect(pageKey(page)).toHaveText('Today');
 await expect(page.locator('.sp-stats')).toHaveAttribute('data-days','today');
});

test('G3-171 opening Subscriptions before the first reply shows a loading state, then the data in the header range',async({page})=>{
 const {send,receive}=await open(page,{display:false});
 await page.locator('[data-range-key="30d"]').click();
 await plans(page);
 await expect(page.locator('.mfd-page')).toHaveAttribute('aria-busy','true');
 await expect(page.locator('.mfd-page .mp-loading')).toHaveText('Reading');
 await expect(page.locator('.mfd-page')).not.toContainText('No subscriptions found');
 expect(await receive(send('display',{data:history()}))).toBe(true);
 await expect(page.locator('.mfd-page')).not.toHaveAttribute('aria-busy','true');
 await page.keyboard.press('1');
 await expect(page.locator('.sp-stats')).toHaveAttribute('data-days','30');
 await expect(header(page)).toHaveAttribute('data-range-key','30d');
});

test('G3-171 an empty accepted reply ends loading on Overview and Plans',async({page})=>{
 const {send,receive}=await open(page,{display:false});
 await expect(page.locator('.mfd-page')).toHaveAttribute('aria-busy','true');
 await expect(page.locator('.mfd-page .mp-loading')).toHaveText('Reading');
 const data=history();data.projection.rows=[];data.subscriptions=[];data.details=null;
 expect(await receive(send('display',{data}))).toBe(true);
 await expect(page.locator('.mfd-page')).not.toHaveAttribute('aria-busy','true');
 await expect(page.locator('.mfd-page .mp-loading')).toHaveCount(0);
 await expect(page.locator('.mfd-page .mp-empty')).toContainText('No subscriptions found');
 await plans(page);
 await expect(page.locator('.mfd-page')).not.toHaveAttribute('aria-busy','true');
 await expect(page.locator('.mfd-page .mp-loading')).toHaveCount(0);
 await expect(page.locator('.mfd-page .mp-empty')).toContainText('No subscriptions found');
});

test('G3-172 the Overview bottom keys always name the chart mode that is drawn',async({page})=>{
 await open(page);
 const chart=page.locator('[data-opt="chart"]');
 await expect(chart.locator('b.on')).toHaveText('Bars');
 // A press on the key's edge (not on a label) toggles the mode (D390); the lit label and the drawn chart always agree.
 await chart.locator('.ok-sep').click({force:true});
 await expect(chart.locator('b.on')).toHaveText('Grid');
 await expect(page.locator('.ov-chart')).toHaveCount(0);
 await expect(chart).toHaveAttribute('aria-label','Bars | Grid: Grid');
 await chart.locator('.ok-sep').click({force:true});
 await expect(chart.locator('b.on')).toHaveText('Bars');
 await expect(page.locator('.ov-heat')).toHaveCount(0);
 await expect(chart).toHaveAttribute('aria-label','Bars | Grid: Bars');
});

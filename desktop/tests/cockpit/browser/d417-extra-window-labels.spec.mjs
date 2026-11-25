// SPDX-License-Identifier: MIT
// D417: an extra window is named by what it is (MCP, Opus, Fable), never "其他"/"Other", and the name shows in full
// even in the narrowest engine table (six columns). Synthetic data only.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell,excludePortholeFlicker} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';

test.beforeEach(async({page})=>excludePortholeFlicker(page));
const NOW=new Date('2026-11-24T12:30:00Z');
const win=(id,role,seconds,label,limitKey,remaining,modelScope)=>({source:'saved_login',id,role,durationSeconds:seconds,label:{en:label,zh:label},limitKey,poolKey:'main',resetMode:'fixed',remainingPercent:remaining,resetsAt:'2026-11-26T12:00:00Z',observedAt:'2026-11-24T12:00:00Z',current:true,validUntil:'2030-01-01T00:00:00Z',...(modelScope?{modelScope:{models:modelScope}}:{})});
function fixture(){
 const data=visualFixture().data,rows=data.projection.rows,base=rows[0];
 const clone=(id,name,windows)=>{const row=structuredClone(base);row.id=id;row.name={en:name,zh:name};row.vendorKey=null;for(const a of row.accounts){a.subscriptionRef=null;a.accountLocator=null;delete a.resetCards;delete a.today;delete a.activity;a.windows=windows;}return row;};
 const five=()=>win('session:18000:five_hour:main','session',18000,'Session','five_hour',80),week=()=>win('weekly:604800:weekly:main','weekly',604800,'Weekly','weekly',55);
 rows.splice(0,rows.length,
  clone('zcode','ZCode',[five(),week(),win('monthly:2592000:mcp:main','monthly',2592000,'MCP','mcp',42)]),
  clone('claude','Claude Code',[five(),week(),win('weekly:604800:other:main','weekly',604800,'Opus','other',31,['opus'])]),
  clone('sonnet','Claude Max',[five(),week(),win('weekly:604800:other:main','weekly',604800,'Sonnet','other',64,['sonnet'])]),
  clone('s1','Spare 1',[five(),week()]),clone('s2','Spare 2',[five(),week()]),clone('s3','Spare 3',[five(),week()]));
 data.subscriptions=[];
 return data;
}
async function open(page,locale){
 await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};});
 await page.clock.setFixedTime(NOW);
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance:{...appearance,locale},shell,redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data:fixture()}))).toBe(true);
}

for(const locale of ['zh-CN','en'])test(`D417 extra windows are named in full, never Other (${locale})`,async({page})=>{
 await open(page,locale);
 const table=page.locator('.u11-engine-table');
 await expect(table.locator('.eng-cols > .ec[data-col]')).toHaveCount(6);
 // The heading never reads the bare 其他/Other; three different names make it the neutral 额外/Extra.
 await expect(table.locator('.lb-other')).toHaveText(locale==='en'?'Extra':'额外');
 const cells=await table.locator('.qcell[data-kind="extra"]').evaluateAll(list=>list.map(e=>{const col=e.closest('.ec').getBoundingClientRect(),t=e.querySelector('.qtxt'),r=t.getBoundingClientRect();
  return {text:t.textContent,tag:e.dataset.tag,fits:t.scrollWidth<=t.clientWidth+1,inside:r.left>=col.left-1&&r.right<=col.right+1};}));
 expect(cells.length).toBe(3);
 const joined=cells.map(c=>c.text).join('|');
 for(const name of ['MCP','Opus'])expect(joined,name).toContain(name);
 expect(joined,'Sonnet or its short form Snt').toMatch(/Sonnet|Snt/);
 for(const c of cells){expect(c,JSON.stringify(c)).toMatchObject({fits:true,inside:true});expect(c.text).not.toMatch(/其他|Other/);}
});

// SPDX-License-Identifier: MIT
// macrev2-1286-3: ZCode's saved sign-in has no subscription reference, so its reserve (extra resets) comes from the
// account's own reset-card facts (source zcode-account). Normal entry: the built page receives the data through the
// host command, the engine table's reserve row shows the live count and, under 48 h, the warning. A non-ZCode account
// with no reference (its facts from another source) shows no reserve, as before. Synthetic data only.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell,excludePortholeFlicker} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';

test.beforeEach(async({page})=>excludePortholeFlicker(page));
const NOW=new Date('2026-11-21T12:00:00Z');
const hours=h=>new Date(NOW.getTime()+h*3600e3).toISOString();
const id=c=>c.repeat(64);
function facts(source,items){
 return {state:'complete',count:items.length,earliestExpiresAt:items.map(i=>i.expiresAt).sort()[0],items,truncated:false,sources:[{source,observedAt:hours(-0.1)}]};
}
function fixture(){
 const data=visualFixture().data,rows=data.projection.rows,base=rows[0];
 const clone=(rid,name,source,items)=>{const row=structuredClone(base);row.id=rid;row.name={en:name,zh:name};row.vendorKey=null;
  for(const a of row.accounts){a.subscriptionRef=null;a.accountLocator=null;delete a.today;delete a.activity;a.credits=null;a.resetCards=facts(source,items);}return row;};
 rows.push(
  clone('zcode','ZCode','zcode-account',[{id:id('a'),expiresAt:hours(20)},{id:id('b'),expiresAt:hours(20)},{id:id('c'),expiresAt:hours(100)}]),
  clone('other','Other tool','codex-account',[{id:id('d'),expiresAt:hours(20)}]));
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
const reserve=(page,col)=>page.locator(`.u11-engine-table .ec[data-col^="${col}#"] .qrow-r`);

for(const [locale,text] of [['en',/^3 resets · expires in 20h/],['zh-CN',/^重置 3 次 · 20h 后到期/]])
 test(`ZCode reserve row shows its own live count and the under-48 h warning (${locale})`,async({page})=>{
  await open(page,locale);
  const row=reserve(page,'zcode');
  await expect(row.locator('.qrv-c')).toHaveAttribute('data-full',text);
  await expect(row.locator('.qrv-c')).toHaveClass(/warn/);
 });

test('a non-ZCode account with no reference shows no reserve from foreign facts',async({page})=>{
 await open(page,'en');
 await expect(page.locator('.u11-engine-table .ec[data-col^="other#"]')).toHaveCount(1);
 await expect(reserve(page,'other').locator('.qrv-c')).toHaveCount(0);
 await expect(reserve(page,'other').locator('.qrv-p')).toHaveCount(0);
});

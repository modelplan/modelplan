// SPDX-License-Identifier: MIT
// SET-9-38 / SET-9-40: a pseudo-long locale (English padded by about 40 %) must not push key labels out of their boxes.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';
import {usePseudoLong} from '../pseudo-long.mjs';

async function open(page,{pseudo}) {
 if(pseudo)await usePseudoLong(page);
 await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};});
 await page.clock.setFixedTime(new Date('2026-11-04T12:00:00Z'));
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance,shell,redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data:visualFixture().data}))).toBe(true);
 return {send,receive};
}
// Every visible leaf of the cockpit whose text is wider or taller than its own box (clipped or ellipsised).
const clipped=page=>page.locator('#cockpit').evaluate(root=>{
 const path=e=>{const parts=[];for(let n=e;n&&n!==root;n=n.parentElement)parts.unshift(n.tagName.toLowerCase()+(n.classList[0]?'.'+n.classList[0]:'')+':'+[...n.parentElement.children].indexOf(n));return parts.join('>');};
 return [...root.querySelectorAll('*')].filter(e=>!e.children.length&&e.textContent.trim()&&e.getClientRects().length&&(e.scrollWidth>e.clientWidth+1||e.scrollHeight>e.clientHeight+1)).map(e=>({path:path(e),text:e.textContent.trim()}));
});
// Gaps the pseudo-long check found in the first run (v1.1, SET-9-40 owns the layout work): the page-key labels and the
// record strip's status word are sized for today's two languages. The test fails on any other clipped label, and also when
// one of these stops clipping, so the list can only shrink.
const known=['section.ck-deck:4>div.dk-mfd:1>div.mfd-pk:0>button.pk:1>span:0','section.ck-deck:4>div.dk-mfd:1>div.mfd-pk:0>button.pk:3>span:0','section.ck-tape:5>div.t-lines:0>button.tl:2>span.t-time:6'];
for(const tier of ['tall','compact'])
test(`pseudo-long English keeps key labels inside their boxes (${tier})`,async({page})=>{
 const found={};
 for(const pseudo of [false,true]){
  const context=await page.context().browser().newContext({viewport:{width:636,height:890}}),p=await context.newPage();
  const {send,receive}=await open(p,{pseudo});
  expect(await receive(send('shell',{...shell,tier}))).toBe(true);
  const seen=[];
  for(const scope of ['all','member']){
   if(scope==='member')await p.locator('.eng-keys .ek[data-sub]').first().click();else await p.locator('.ek-all').click();
   for(let i=0;i<4;i++){await p.locator('.mfd-pk .pk').nth(i).click();seen.push(...(await clipped(p)).map(x=>({...x,view:scope+':'+i})));}
  }
  found[pseudo?'pseudo':'plain']=seen;await context.close();
 }
 const base=new Set(found.plain.map(x=>x.view+'|'+x.path));
 const fresh=found.pseudo.filter(x=>!base.has(x.view+'|'+x.path));
 expect(fresh.filter(x=>!known.includes(x.path)).map(x=>[x.view,x.path,x.text]),'a key label no longer fits the pseudo-long locale').toEqual([]);
 expect(known.filter(path=>!fresh.some(x=>x.path===path)),'a known gap is fixed: remove it from the list').toEqual([]);
});

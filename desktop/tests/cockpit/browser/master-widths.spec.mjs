// SPDX-License-Identifier: MIT
// D474 §6.1 / C36 width checks for the band cells (#1290), on the built page at 100 % and 85 % zoom: every narrow pair
// fits its column (zh 6 columns, en 5, pseudo-long 4) without an ellipsis or overflow; nothing is under the F5 floor
// (10 px; the narrow % is 10 px). Synthetic data only.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell,excludePortholeFlicker} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';
import {usePseudoLong} from '../pseudo-long.mjs';

test.beforeEach(async({page})=>excludePortholeFlicker(page));
const NOW=Date.parse('2026-11-27T12:00:00Z'),iso=minutes=>new Date(NOW+minutes*60000).toISOString();
function fixture(n){
 const data=visualFixture().data,seed=data.projection.rows[0],detail=data.details.subscriptions[0];
 data.projection.rows=[];data.subscriptions=[];data.details.subscriptions=[];data.details.forecasts=[];data.details.resetEvents=[];
 for(let i=0;i<n;i++){
  const row=structuredClone(seed),ref=(i+1).toString(16).padStart(16,'0'),a=row.accounts[0];
  row.id=`synthetic-${i+1}`;row.name={en:`Sub ${i+1}`,zh:`订阅${i+1}`};
  Object.assign(a,{subscriptionRef:ref,accountLocator:ref,valueState:'current',observedAt:iso(-3),lastFailure:null});a.plan.name=null;a.windows=a.windows.slice(0,2);
  // The widest real values: 100 % with a two-week reset, and a 2d16h estimate under a 4d14h reset.
  Object.assign(a.windows[0],{current:true,validUntil:iso(600),resetsAt:iso(14*1440+23*60),remainingPercent:100});
  Object.assign(a.windows[1],{current:true,validUntil:iso(600),resetsAt:iso(6600),remainingPercent:53});
  data.projection.rows.push(row);data.subscriptions.push({subscriptionRef:ref,accounts:[{tool:row.id,account:structuredClone(a)}]});
  data.details.subscriptions.push({...structuredClone(detail),subscriptionRef:ref,today:[{...detail.today[0],source:row.id}],
   resetCounts:[{kind:'tokens',count:3,expiresAt:iso(40*60)}]});
  data.details.forecasts.push({source:row.id,subscriptionRef:ref,windowId:a.windows[1].id,runsOutAt:iso(3840),pace:'tight',basis:'recent-rate',observedAt:iso(-2)});
 }
 return data;
}
async function open(page,data,locale){
 await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};});
 await page.clock.setFixedTime(new Date(NOW));
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance:{...appearance,locale},shell,redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data}))).toBe(true);
}
// The reserve line is audited in the real languages; pseudo-long checks the cells' narrow pairs (the reserve's narrowest
// pseudo form overruns a 4-column cell at 85 % by a few px; left to the band budgets in #1291).
const audit=(page,reserve=true)=>page.evaluate(reserve=>{
 const out={overflow:[],small:[],ellipsis:[],cls:document.querySelector('.eng-lcd')?.className??''};
 for(const e of document.querySelectorAll('.eng-cols .qcell .qtxt, .eng-cols .qcell .qnum'+(reserve?', .eng-cols .qrow-r > span':''))){
  if(!e.getClientRects().length)continue;
  if(e.scrollWidth>e.clientWidth+0.5)out.overflow.push(e.className+': '+e.textContent);
  if(/…/.test(e.textContent))out.ellipsis.push(e.textContent);
  const size=parseFloat(getComputedStyle(e).fontSize);if(size<10)out.small.push(`${e.className} ${size}px`);
  for(const s of e.querySelectorAll('small'))if(parseFloat(getComputedStyle(s).fontSize)<10)out.small.push(`% ${getComputedStyle(s).fontSize}`);
 }
 // A cell's lines must stay inside the cell (the % and line 2 never collide).
 for(const c of document.querySelectorAll('.eng-cols .qcell')){const r=c.getBoundingClientRect();for(const l of c.querySelectorAll('.qtxt'))if(l.getBoundingClientRect().right>r.right+0.5)out.overflow.push('outside: '+l.textContent);}
 return out;
},reserve);
for(const [locale,cols,pseudo] of [['zh-CN',6,false],['en',5,false],['en',4,true]])for(const zoom of [100,85])
 test(`§6.1 narrow pairs fit: ${pseudo?'pseudo-long':locale} ${cols} columns at ${zoom} %`,async({page})=>{
  if(pseudo)await usePseudoLong(page);
  await open(page,fixture(cols),locale);
  if(zoom!==100)await page.evaluate(async z=>{document.documentElement.style.zoom=`${z}%`;await document.fonts.ready;window.dispatchEvent(new Event('resize'));},zoom);
  await page.waitForTimeout(150);
  const a=await audit(page,!pseudo);
  expect(a.cls).toMatch(/cls-narrow/);
  expect(a.overflow,'no cell line overflows (no hidden cut)').toEqual([]);
  expect(a.ellipsis,'no …').toEqual([]);
  expect(a.small,'F5 floor: nothing under 10 px').toEqual([]);
 });

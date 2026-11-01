// SPDX-License-Identifier: MIT
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {commands,pageId,appearance,shell} from '../fixture.mjs';

for(const locale of ['en','zh-CN'])for(const tier of ['tall','compact']){
 test(`fader labels and caps share the prototype scale in ${locale}, ${tier}`,async({page})=>{
  await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
  const send=commands();expect(await page.evaluate(raw=>window.modelPlanCockpit.receive(raw),send('load',{appearance:{...appearance,locale},shell:{...shell,tier}}))).toBe(true);
  await page.evaluate(async(locale)=>{
   const {mountPrototypeDeck}=await import('/src/prototype-deck.js');
   const levels=['Low','Med','High','XHigh','Max'];
   const faders=levels.map((level,i)=>({id:'synthetic-'+i,name:'Synthetic '+level,short:'S'+i,rec:level,e:levels.map((l,n)=>[l,n+1,n+1,n+1]),accounts:[],sessions:[]}));
   const deck=mountPrototypeDeck(document.querySelector('#cockpit'),undefined,{publication:{accounts:[],faders},liveSessions:[],resetEvents:null,history:null});deck.locale(locale);
  },locale);
  const expected=['Max','XHigh','High','Med','Low'],seen=[];
  for(let bank=0;bank<2;bank++){
   const actual=await page.evaluate(()=>{
    const labels=[...document.querySelectorAll('.fd-scale .sc-l')].map(e=>({text:e.textContent.trim(),y:e.getBoundingClientRect().y+e.getBoundingClientRect().height/2})).sort((a,b)=>a.y-b.y);
    const caps=[...document.querySelectorAll('.fd-ch:not(.empty)')].map(ch=>{const cap=ch.querySelector('.fd-cap').getBoundingClientRect();return {level:ch.querySelector('.fd-travel').getAttribute('aria-valuetext'),y:cap.y+cap.height/2};});
    return {labels,caps};
   });
   expect(actual.labels.map(x=>x.text)).toEqual(expected);
   for(const cap of actual.caps){const label=actual.labels.find(x=>x.text===cap.level);expect(label,`missing label for ${cap.level}`).toBeTruthy();expect(Math.abs(cap.y-label.y),`${cap.level} cap should align with its label`).toBeLessThan(1);seen.push(cap.level);}
   if(bank===0)await page.locator('.fd-bank [data-bank="1"]').click();
  }
  expect(seen.sort()).toEqual([...expected].sort());
 });
}

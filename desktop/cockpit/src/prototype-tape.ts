// SPDX-License-Identifier: MIT
// Study record-strip empty state, adapted to the authenticated cockpit bridge.
// No titles, paths, synthetic sessions or inferred ended states are produced.
import {unavailablePrototypeDetailsFixture} from './prototype-details-fixture-adapter.js';
type Locale='en'|'zh-CN';
export function mountPrototypeTape(root:HTMLElement){
 const host=root.querySelector<HTMLElement>('.ck-tape')!;
 const lines=document.createElement('div');lines.className='t-lines';host.replaceChildren(lines);
 const details=unavailablePrototypeDetailsFixture();let locale:Locale='en',count=5;
 function paint(){
  host.setAttribute('aria-label',locale==='en'?'Live session coverage unavailable':'实时会话覆盖情况不可用');
  host.dataset.sessionsAvailable=String(details.liveSessions!==null);
  const blanks=Array.from({length:count},()=>{const item=document.createElement('span');item.className='tl t-blank';item.setAttribute('aria-hidden','true');return item;});
  lines.replaceChildren(...blanks);
 }
 paint();return {locale(value:Locale){locale=value;paint();},layout(value:number){count=value===5?5:3;root.style.setProperty('--tape-lines',String(count));paint();},clear(){paint();}};
}

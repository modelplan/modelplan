// SPDX-License-Identifier: MIT
// Copyright (c) 2026 ModelPlan.
// WP-10: the header's date keys (Today / 7d / 30d). Each key is one radio whose hit area covers its label, its cap and
// the halves of the gaps beside it (see strip header.css). The page only shows the range and reports a request; the
// owner of the range is the app (WP-09), so the caller decides what a request does. With no usage source the keys look dim (data-nosource)
// but still accept and remember a choice (R3 section 5).
import {ht} from './host-text.js';

export type HeaderRange='today'|'7d'|'30d';
export const headerRanges:readonly HeaderRange[]=['today','7d','30d'];
const labelKey:Record<HeaderRange,string>={today:'host.rangeToday','7d':'host.range7d','30d':'host.range30d'};

export function headerRangeMarkup():string {
  return `<span class="ck-range" data-range role="radiogroup" aria-label="Time range">${headerRanges.map(k=>`<button type="button" class="rk" data-range-key="${k}" data-mat="part" role="radio" aria-checked="false" tabindex="-1"><i class="rk-cap" aria-hidden="true"></i><span class="rk-label"></span></button>`).join('')}</span>`;
}

export function mountHeaderRange(root:HTMLElement,request:(range:HeaderRange)=>void,initial:HeaderRange='7d') {
  const group=root.querySelector<HTMLElement>('[data-range]')!,keys=[...group.querySelectorAll<HTMLButtonElement>('[data-range-key]')];
  let current=initial,locale='en',dim=false;
  const paint=()=>{for(const key of keys){const on=key.dataset.rangeKey===current;key.setAttribute('aria-checked',String(on));key.tabIndex=on?0:-1;key.querySelector('.rk-label')!.textContent=ht(locale,labelKey[key.dataset.rangeKey as HeaderRange]);}group.setAttribute('aria-label',ht(locale,'host.rangeAria'));for(const key of keys){if(dim)key.dataset.nosource='true';else delete key.dataset.nosource;}};
  const choose=(range:HeaderRange)=>{if(range!==current){current=range;paint();}request(range);};
  for(const key of keys){
    key.onclick=e=>{if(e.isTrusted)choose(key.dataset.rangeKey as HeaderRange);};
    key.onkeydown=e=>{
      if(!e.isTrusted||e.altKey||e.ctrlKey||e.metaKey)return;
      const step=e.key==='ArrowRight'||e.key==='ArrowDown'?1:e.key==='ArrowLeft'||e.key==='ArrowUp'?-1:0;if(!step)return;
      e.preventDefault();const next=headerRanges[(headerRanges.indexOf(current)+step+headerRanges.length)%headerRanges.length];
      choose(next);keys.find(k=>k.dataset.rangeKey===next)!.focus();
    };
  }
  paint();
  return {dim(value:boolean){if(value!==dim){dim=value;paint();}},set(range:HeaderRange){if(range!==current){current=range;paint();}},locale(value:string){locale=value;paint();},current:()=>current};
}

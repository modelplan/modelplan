// SPDX-License-Identifier: MIT
// Study fader/MFD hierarchy, adapted for the v2 page without HTML interpolation.
// Current bridge has no cockpitDetailsV1 or publication payload: no study
// fixture readings, rankings or invented session controls are displayed.
import {unavailablePrototypeDetailsFixture} from './prototype-details-fixture-adapter.js';
type Locale='en'|'zh-CN';
const node=<K extends keyof HTMLElementTagNameMap>(tag:K,cls?:string,text?:string):HTMLElementTagNameMap[K]=>{const e=document.createElement(tag);if(cls)e.className=cls;if(text!==undefined)e.textContent=text;return e;};
const pages=[{id:'overview',en:'Overview',zh:'总览'},{id:'plans',en:'Plans',zh:'订阅'},{id:'tune',en:'Tune',zh:'档位'},{id:'where',en:'Where',zh:'去向'}] as const;
export function mountPrototypeDeck(root:HTMLElement){
 const scale=root.querySelector<HTMLElement>('.fd-scale')!,channels=root.querySelector<HTMLElement>('.fd-chs')!,mfd=root.querySelector<HTMLElement>('.dk-mfd')!;
 const details=unavailablePrototypeDetailsFixture();
 let locale:Locale='en',selected=0;root.dataset.detailsAvailable=String(details.liveSessions!==null);
 const label=node('span','silk sc-led'),lcd=node('span','sc-lcd'),travel=node('span','sc-travel');
 const levels=['Max','XHigh','High','Med','Low'];for(const [i,level] of levels.entries()){const b=node('button','silk sc-l',level);b.type='button';b.disabled=true;b.tabIndex=-1;b.style.setProperty('--k',String(i/4));travel.append(b);}scale.replaceChildren(label,lcd,travel);
 for(let i=0;i<3;i++){
  const channel=node('div','fd-ch empty');channel.dataset.slot=String(i);
  const leds=node('div','fd-leds'),strip=node('button','fd-strip'),track=node('div','fd-travel');strip.type='button';strip.disabled=true;strip.tabIndex=-1;track.setAttribute('aria-hidden','true');
  for(const cls of ['fd-slot','fd-marks','fd-peek','fd-ghost','fd-cap']){const item=node('span',cls);if(cls==='fd-ghost'||cls==='fd-cap')item.hidden=true;track.append(item);}
  channel.append(leds,strip,track);channels.append(channel);
 }
 const bar=node('div','mfd-pk'),screen=node('div','mfd-screen'),page=node('div','mfd-page pg-overview'),footer=node('div','mfd-ok');bar.setAttribute('role','toolbar');screen.dataset.mat='well';screen.append(page);
 const buttons=pages.map((item,i)=>{const b=node('button','pk'),caption=node('span'),led=node('i','pk-led');b.type='button';b.dataset.mfd='page:'+item.id;b.append(caption,led);b.onclick=e=>{if(!e.isTrusted)return;selected=i;paint();};bar.append(b);return {b,caption};});
 for(let i=0;i<3;i++){const empty=node('span','ok soft off');empty.setAttribute('aria-hidden','true');footer.append(empty);}
 mfd.replaceChildren(bar,screen,footer);
 function paint(){
  label.textContent=locale==='en'?'Status':'状态';bar.setAttribute('aria-label',locale==='en'?'Cockpit pages':'驾驶舱页面');
  buttons.forEach(({b,caption},i)=>{caption.textContent=locale==='en'?pages[i].en:pages[i].zh;b.classList.toggle('on',i===selected);b.setAttribute('aria-pressed',String(i===selected));});
  page.className='mfd-page pg-'+pages[selected].id;page.replaceChildren(node('p','mfd-empty',locale==='en'?'No data available':'暂无数据'));
 }
 paint();return {locale(value:Locale){locale=value;paint();},clear(){selected=0;paint();},dispose(){for(const {b} of buttons)b.onclick=null;}};
}

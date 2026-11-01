// SPDX-License-Identifier: MIT
// P6 record-strip hierarchy. The v1 producer supplies a coverage-labelled
// last-seen list, not a complete session history or evidence of endings.
import type {WireCockpitData,WireCockpitSession} from '../generated/wire.js';
import {prototypeEngineSupplement} from './prototype-data-adapter.js';
type Locale='en'|'zh-CN';
const esc=(v:unknown)=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]!));
export function mountPrototypeTape(root:HTMLElement){
 const host=root.querySelector<HTMLElement>('.ck-tape')!;let locale:Locale='en',count=5,data:WireCockpitData|null=null;
 function speed(s:WireCockpitSession):number|null {
  if(!data||!s.subscriptionRef||!data.subscriptions.some(x=>x.subscriptionRef===s.subscriptionRef))return null;
  const matches=data.details?.subscriptions.filter(x=>x.subscriptionRef===s.subscriptionRef)??[];
  const entries=matches.length===1?matches[0].today:[];
  if(entries.length!==1||entries[0].source!==s.source||entries[0].bindingBasis!=='source-wide-current-binding')return null;
  const member=data.projection.rows.flatMap(r=>r.accounts).find(a=>a.subscriptionRef===s.subscriptionRef);
  return member?prototypeEngineSupplement(member,data).todayAverageGenerationTps:null;
 }
 function paint(){
  const detail=data?.details,coverage=detail?.sessionCoverage??'unavailable';
  host.dataset.sessionsAvailable=String(!!detail&&coverage==='local-last-seen');
  const title=locale==='en'?'Local sessions, last observed':'本机会话，最近观测';
  const unavailable=coverage==='recording-off'?(locale==='en'?'Session recording off':'会话记录已关闭'):(locale==='en'?'Live session coverage unavailable':'实时会话覆盖情况不可用');
  host.setAttribute('aria-label',coverage==='local-last-seen'?title:unavailable);
  const sessions=coverage==='local-last-seen'?detail?.sessions??[]:[];
  const shown=sessions.length>count?sessions.slice(0,count-1):sessions.slice(0,count);
  const rows=shown.map(s=>{
   const rate=speed(s),when=new Date(s.lastObservedAt).toLocaleTimeString(locale,{hour:'2-digit',minute:'2-digit'});
   const observed=(locale==='en'?'Last observed ':'最近观测 ')+s.lastObservedAt;
   const rateLabel=rate===null?'':(locale==='en'?'Today average ':'今日平均 ')+rate+' t/s';
   return `<button class="tl t-observed" type="button" aria-disabled="true" tabindex="-1" aria-label="${esc([s.source,s.model,s.effort??'--',s.projectLabel??'--',observed,rateLabel].filter(Boolean).join(' · '))}">
   <i class="chip"></i><span class="t-tool">${esc(s.source)}</span><span class="t-model">${esc(s.model)}</span><span class="t-eff">${esc(s.effort??'--')}</span>
   <span class="t-proj">${esc(s.projectLabel??'--')}</span><span class="t-live" aria-label="${esc(rateLabel)}">${rate===null?'--':`${esc(Math.round(rate))}<em class="t-unit"> t/s</em>`}</span><span class="t-time">${esc(when)}</span></button>`;
  });
  if(sessions.length>shown.length){const n=sessions.length-shown.length;rows.push(`<span class="tl t-overflow">${locale==='en'?`${n} more observed`:`另有 ${n} 条观测`}</span>`);}
  while(rows.length<count)rows.push('<span class="tl t-blank" aria-hidden="true"></span>');
  host.innerHTML=`<div class="t-lines">${rows.join('')}</div>`;
  for(const chip of host.querySelectorAll<HTMLElement>('.chip'))chip.style.setProperty('--v','#c6ccd4');
 }
 paint();return {locale(value:Locale){locale=value;paint();},layout(value:number){count=value===5?5:3;root.style.setProperty('--tape-lines',String(count));paint();},render(value:WireCockpitData){data=value;paint();},clear(){data=null;paint();}};
}

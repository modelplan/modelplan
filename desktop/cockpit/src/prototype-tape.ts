// SPDX-License-Identifier: MIT
// The record strip shows only producer-reported running sessions. The source
// publishes last-seen evidence, not a complete session history or start time.
import type {WireCockpitData} from '../generated/wire.js';
type Locale='en'|'zh-CN';
const esc=(v:unknown)=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]!));
export function mountPrototypeTape(root:HTMLElement){
 const host=root.querySelector<HTMLElement>('.ck-tape')!;let locale:Locale='en',count=5,data:WireCockpitData|null=null;
 function paint(){
  const detail=data?.details,coverage=detail?.sessionCoverage??'unavailable';
  host.dataset.sessionsAvailable=String(!!detail&&coverage==='local-last-seen');
  const title=locale==='en'?'Running sessions':'运行中的会话';
  const unavailable=coverage==='recording-off'?(locale==='en'?'Session recording off':'会话记录已关闭'):(locale==='en'?'Session data unavailable':'暂无会话数据');
  host.setAttribute('aria-label',coverage==='local-last-seen'?title:unavailable);
  const sessions=coverage==='local-last-seen'?(detail?.sessions??[]).filter(s=>s.state==='running'):[];
  const shown=sessions.length>count?sessions.slice(0,count-1):sessions.slice(0,count);
  const rows=shown.map(s=>{
   const rate=s.rate!==null&&Number.isFinite(s.rate)&&s.rate>=0?s.rate:null;
   const running=locale==='en'?'Running':'运行中',rateLabel=rate===null?'':(locale==='en'?'Session rate ':'会话速率 ')+rate+' t/s';
   return `<button class="tl t-observed" type="button" aria-disabled="true" tabindex="-1" aria-label="${esc([s.source,s.model,s.effort??'--',s.projectLabel??'--',running,rateLabel].filter(Boolean).join(' · '))}">
   <i class="chip"></i><span class="t-tool">${esc(s.source)}</span><span class="t-model">${esc(s.model)}</span><span class="t-eff">${esc(s.effort??'--')}</span>
   <span class="t-proj">${esc(s.projectLabel??'--')}</span><span class="t-live" aria-label="${esc(rateLabel)}">${rate===null?'--':`${esc(Math.round(rate))}<em class="t-unit"> t/s</em>`}</span><span class="t-time">${esc(running)}</span></button>`;
  });
  if(sessions.length>shown.length){const n=sessions.length-shown.length;rows.push(`<span class="tl t-overflow">${locale==='en'?`${n} more running`:`另有 ${n} 个会话运行中`}</span>`);}
  while(rows.length<count)rows.push('<span class="tl t-blank" aria-hidden="true"></span>');
  host.innerHTML=`<div class="t-lines">${rows.join('')}</div>`;
  for(const chip of host.querySelectorAll<HTMLElement>('.chip'))chip.style.setProperty('--v','#c6ccd4');
 }
 paint();return {locale(value:Locale){locale=value;paint();},layout(value:number){count=value===5?5:3;root.style.setProperty('--tape-lines',String(count));paint();},render(value:WireCockpitData){data=value;paint();},clear(){data=null;paint();}};
}

// SPDX-License-Identifier: MIT
// The record strip shows producer-reported running and last-seen (CLI state "idle") sessions.
// Last-seen evidence does not establish an end time or a complete history.
import type {WireCockpitData} from '../generated/wire.js';
type Locale='en'|'zh-CN';
const esc=(v:unknown)=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]!));
type TapeSession=NonNullable<WireCockpitData['details']>['sessions'][number];
// CKP-STRIP-15: the frame owns what a line links to; the tape only reports which line.
export interface TapeLink {knows(ref:string):boolean;hover(session:TapeSession|null):void;select(session:TapeSession):void;}
export function mountPrototypeTape(root:HTMLElement,link?:TapeLink){
 const host=root.querySelector<HTMLElement>('.ck-tape')!;let locale:Locale='en',count=5,data:WireCockpitData|null=null;
 function paint(){
  const detail=data?.details,coverage=detail?.sessionCoverage??'unavailable';
  host.dataset.sessionsAvailable=String(!!detail&&coverage==='local-last-seen');
  const title=locale==='en'?'Last-seen sessions':'最近读数的会话';
  const unavailable=coverage==='recording-off'?(locale==='en'?'Session recording off':'会话记录已关闭'):(locale==='en'?'Session data unavailable':'暂无会话数据');
  host.setAttribute('aria-label',coverage==='local-last-seen'?title:unavailable);
  const sessions=coverage==='local-last-seen'?(detail?.sessions??[]).filter(s=>s.state==='running'||s.state==='idle').slice().sort((a,b)=>Number(b.state==='running')-Number(a.state==='running')):[];
  const shown=sessions.length>count?sessions.slice(0,count-1):sessions.slice(0,count);
  const rows=shown.map(s=>{
   const rate=s.state==='running'&&s.rate!==null&&Number.isFinite(s.rate)&&s.rate>=0?s.rate:null;
   const running=s.state==='running'?(locale==='en'?'Running':'运行中'):(locale==='en'?'Last seen':'最近读数'),rateLabel=rate===null?'':(locale==='en'?'Session rate ':'会话速率 ')+rate+' t/s';
   const linked=!!link&&(!!s.subscriptionRef||link.knows(s.sessionRef));
   return `<button class="tl t-observed" type="button"${linked?'':' aria-disabled="true" tabindex="-1"'} data-session="${esc(s.sessionRef)}" aria-label="${esc([s.source,s.model,s.effort??'--',s.projectLabel??'--',running,rateLabel].filter(Boolean).join(' · '))}">
   <i class="chip"></i><span class="t-tool">${esc(s.source)}</span><span class="t-model">${esc(s.model)}</span><span class="t-eff">${esc(s.effort??'--')}</span>
   <span class="t-proj">${esc(s.projectLabel??'--')}</span><span class="t-live" aria-label="${esc(rateLabel)}">${rate===null?'--':`${esc(Math.round(rate))}<em class="t-unit"> t/s</em>`}</span><span class="t-time">${esc(running)}${s.state==='running'?'<i class="t-cur" aria-hidden="true"></i>':''}</span></button>`;
  });
  if(sessions.length>shown.length){const hidden=sessions.slice(shown.length),n=hidden.length,running=hidden.every(s=>s.state==='running');rows.push(`<span class="tl t-overflow">${locale==='en'?(running?`${n} more running`:`${n} more sessions`):(running?`另有 ${n} 个会话运行中`:`另有 ${n} 个会话`)}</span>`);}
  while(rows.length<count)rows.push('<span class="tl t-blank" aria-hidden="true"></span>');
  host.innerHTML=`<div class="t-lines">${rows.join('')}</div>`;
  for(const chip of host.querySelectorAll<HTMLElement>('.chip'))chip.style.setProperty('--v','#c6ccd4');
 }
 const sessionAt=(target:EventTarget|null)=>{const row=target instanceof Element?target.closest<HTMLElement>('.t-observed'):null;if(!row||row.getAttribute('aria-disabled')==='true')return null;return data?.details?.sessions.find(s=>s.sessionRef===row.dataset.session)??null;};
 if(link){
  host.addEventListener('pointerover',e=>link.hover(sessionAt(e.target)));host.addEventListener('pointerleave',()=>link.hover(null));
  host.addEventListener('focusin',e=>link.hover(sessionAt(e.target)));host.addEventListener('focusout',()=>link.hover(null));
  host.addEventListener('click',e=>{const session=sessionAt(e.target);if(e.isTrusted&&session)link.select(session);});
 }
 paint();return {locale(value:Locale){locale=value;paint();},layout(value:number){count=value===5?5:3;root.style.setProperty('--tape-lines',String(count));paint();},render(value:WireCockpitData){data=value;paint();},clear(){data=null;paint();}};
}

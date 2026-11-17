// SPDX-License-Identifier: MIT
// The record strip shows producer-reported running and last-seen (CLI state "idle") sessions.
// Last-seen evidence does not establish an end time or a complete history.
// Owner decision D277 (2026-11-16, CKP-STRIP-09/16/17): chip · tool · project · model + effort · elapsed · tokens · right
// end, where the right end is "● 58 t/s" with the cursor while running and "6m ago" when idle. The strip is "now": it
// follows the render clock and the minute ticks, never the global time range.
import {ht} from './host-text.js';
import type {WireCockpitData} from '../generated/wire.js';
import {cockpitMembers} from './members.js';
import {sessionMember,memberColours,NEUTRAL} from './session-binding.js';
import {shortLabel} from '../study/rocket-r1/short-label.js';
import {sessionLine} from '../study/rocket-r1/session-line.js';
// The producer's label for a project that has a reference but no name the tool stores (cockpit_details.go).
const UNNAMED='Unnamed project';
type Locale='en'|'zh-CN';
const esc=(v:unknown)=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]!));
type TapeSession=NonNullable<WireCockpitData['details']>['sessions'][number];
// CKP-STRIP-15: the frame owns what a line links to; the tape only reports which line.
export interface TapeLink {knows(ref:string):boolean;hover(session:TapeSession|null):void;select(session:TapeSession):void;}
export function mountPrototypeTape(root:HTMLElement,link?:TapeLink){
 const host=root.querySelector<HTMLElement>('.ck-tape')!;let locale:Locale='en',count=5,data:WireCockpitData|null=null,named=true,now=0;
 function paint(){
  const detail=data?.details,coverage=detail?.sessionCoverage??'unavailable';
  host.dataset.sessionsAvailable=String(!!detail&&coverage==='local-last-seen');
  const title=ht(locale,'host.lastSeenSessions');
  const unavailable=coverage==='recording-off'?(ht(locale,'host.sessionRecordingOff')):(ht(locale,'host.sessionDataUnavailable'));
  host.setAttribute('aria-label',coverage==='local-last-seen'?title:unavailable);
  const sessions=coverage==='local-last-seen'?(detail?.sessions??[]).filter(s=>s.state==='running'||s.state==='idle').slice().sort((a,b)=>Number(b.state==='running')-Number(a.state==='running')):[];
  const shown=sessions.length>count?sessions.slice(0,count-1):sessions.slice(0,count),members=data?cockpitMembers(data):[];
  // The chip is the session's subscription colour (study tape.js); an unbound session stays neutral.
  // A published model reads by its short name, as on the faders and the HUD; anything else as reported.
  const names=new Map((detail?.publishedModels??[]).map(m=>[m.id,shortLabel(m.name)])),modelName=(id:string)=>names.get(id)??id;
  const palette=memberColours(members),colours=shown.map(s=>{const m=sessionMember(members,s);return m?palette.get(m.key)??NEUTRAL:NEUTRAL;});
  const rows=shown.map(s=>{
   const line=sessionLine(s,now,locale,modelName);
   const running=line.running?(ht(locale,'host.running')):(ht(locale,'host.lastSeen')),rateLabel=line.rate===null?'':(ht(locale,'host.sessionRate'))+Math.round(line.rate)+' t/s';
   // G3-100: no project in the tool's own definition reads "No project"; with names turned off the label stays hidden ("--").
   // glm-909-1: the producer's state decides, so a name hidden by `project-labels off` never reads "No project".
   const state=s.projectState??(s.projectLabel===UNNAMED?'unnamed':s.projectLabel===null?'none':'named');
   const project=!named||state==='hidden'?'--':state==='unnamed'?(ht(locale,'host.projectUnnamed')):state==='none'?(ht(locale,'host.projectNone')):s.projectLabel??'--';
   const linked=!!link&&(!!s.subscriptionRef||link.knows(s.sessionRef));
   const model=line.unknownModel?ht(locale,'host.unknownModel'):line.model,elapsed=ht(locale,'host.sessionElapsed',{d:line.elapsed}),tokens=ht(locale,'host.sessionTokens',{n:line.tokens});
   const right=line.running?`● ${line.rate===null?'--':esc(Math.round(line.rate))}<em class="t-unit"> t/s</em><i class="t-cur" aria-hidden="true"></i>`:esc(line.ago);
   return `<button class="tl t-observed" type="button"${linked?'':' aria-disabled="true" tabindex="-1"'} data-session="${esc(s.sessionRef)}" data-state="${line.running?'running':'idle'}" aria-label="${esc([line.tool,project,[model,line.effort].filter(Boolean).join(' '),elapsed,tokens,running,line.running?rateLabel:line.ago].filter(Boolean).join(' · '))}">
   <i class="chip"></i><span class="t-tool" title="${esc(s.source)}">${esc(line.tool)}</span><span class="t-proj">${esc(project)}</span>
   <span class="t-me"><span class="t-model${line.unknownModel?' t-unknown':''}" title="${esc(s.model)}">${esc(model)}</span>${line.effort?` <span class="t-eff">${esc(line.effort)}</span>`:''}</span>
   <span class="t-elapsed">${esc(line.elapsed)}</span><span class="t-tok">${esc(line.tokens)}</span><span class="t-live">${right}</span></button>`;
  });
  if(sessions.length>shown.length){const hidden=sessions.slice(shown.length),n=hidden.length,running=hidden.every(s=>s.state==='running');rows.push(`<span class="tl t-overflow">${ht(locale,running?'host.moreRunning':'host.moreSessions',{n})}</span>`);}
  while(rows.length<count)rows.push('<span class="tl t-blank" aria-hidden="true"></span>');
  host.innerHTML=`<div class="t-lines">${rows.join('')}</div>`;
  for(const [i,chip] of [...host.querySelectorAll<HTMLElement>('.t-observed .chip')].entries())chip.style.setProperty('--v',colours[i]??NEUTRAL);
 }
 const sessionAt=(target:EventTarget|null)=>{const row=target instanceof Element?target.closest<HTMLElement>('.t-observed'):null;if(!row||row.getAttribute('aria-disabled')==='true')return null;return data?.details?.sessions.find(s=>s.sessionRef===row.dataset.session)??null;};
 if(link){
  host.addEventListener('pointerover',e=>link.hover(sessionAt(e.target)));host.addEventListener('pointerleave',()=>link.hover(null));
  host.addEventListener('focusin',e=>link.hover(sessionAt(e.target)));host.addEventListener('focusout',()=>link.hover(null));
  host.addEventListener('click',e=>{const session=sessionAt(e.target);if(e.isTrusted&&session)link.select(session);});
 }
 paint();return {
  /** Recovery contract: the tape's own render state, restored with the view after a refused render (glm-990-1). */
  checkpoint(){const saved={data,named,now};return ()=>{({data,named,now}=saved);};},
  locale(value:Locale){locale=value;paint();},layout(value:number){count=value===5?5:3;root.style.setProperty('--tape-lines',String(count));paint();},render(value:WireCockpitData,namesShown=true,at=Date.now()){data=value;named=namesShown;now=at;paint();},
  /** A minute tick: elapsed time and age move with the clock, not only with a new reading. */
  refresh(at:number){now=at;paint();},clear(){data=null;paint();}};
}

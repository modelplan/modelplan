// SPDX-License-Identifier: MIT
// Study fader/MFD hierarchy, with escaped renderer fields and bounded identifiers.
// Publication and session facts come from admitted cockpit details; unknown
// inputs stay unavailable, with synthetic values confined to test fixtures.
import {ht} from './host-text.js';
import {accountLabel,footerState,updatedCopy,agoKey} from './account-line.js';
import {unavailablePrototypeDetailsFixture,type PrototypeDetailsFixture} from './prototype-details-fixture-adapter.js';
import {effectiveRedBelow} from './threshold.js';
import {beginFaderPress,endFaderPress} from './fader-press.js';
import {publicationFaders,scopedFaders,historyUsage,moreFaderModels as moreModels,FADER_SET_LIMIT,type FaderSubscription} from './publication-faders.js';
import {positionalRemap,refreshComparison,comparisonInput} from './fader-identity.js';
import type {WireCockpitData,WireAccount,WireRow} from '../generated/wire.js';
import {cockpitMembers} from './members.js';
import {INITIAL_RANGE,isCockpitRange,nextCockpitRange,type CockpitRange} from './range.js';
import {sessionMember,sessionMembers,sessionAdmittedBy,memberColours,toolDevelopers,vendorPalette} from './session-binding.js';
import {cautionItems} from './caution.js';
import {prototypeEngineSupplement,currentWindow,displayWindow,scopedWindow,runOutMinutes,runOutFields,forecastOf,moneyText} from './prototype-data-adapter.js';
import {historyView,resetHistory,usageStats} from './prototype-history.js';
import {publishedFleet} from './prototype-hud.js';
import {cardUsage,currentEffort,type CardUse} from './model-card.js';
import {approxCost} from '../study/rocket-r1/mfd-pages/fmt.js';
import {scaleView,levelK,bankView,faderModel,lcdView,indicatorView,marksView,stripAria} from '../study/rocket-r1/fader-view.js';
import {setLanguage,t,formatCredits} from '../study/rocket-r1/i18n.js';
import {overview} from '../study/rocket-r1/mfd-pages/overview.js';
import {plans,subjectOf} from '../study/rocket-r1/mfd-pages/plans.js';
import {relativeMoment,tok,until,md} from '../study/rocket-r1/mfd-pages/fmt.js';
import {tune} from '../study/rocket-r1/mfd-pages/tune.js';
import {where} from '../study/rocket-r1/mfd-pages/where.js';
import {alertsPage} from '../study/rocket-r1/mfd-pages/alerts.js';
import {shortLabel} from '../study/rocket-r1/short-label.js';
import {compareSpeedTiers} from './speed-tiers.js';
import {comparison,compareKeys,compareView,type CompareArgs} from '../study/rocket-r1/mfd-pages/views.js';
import '../study/rocket-r1/strings/mfd.js';
type Locale='en'|'zh-CN';
const node=<K extends keyof HTMLElementTagNameMap>(tag:K,cls?:string,text?:string):HTMLElementTagNameMap[K]=>{const e=document.createElement(tag);if(cls)e.className=cls;if(text!==undefined)e.textContent=text;return e;};
const cockpitPageRegistry=Object.freeze([Object.freeze({module:overview,key:'host.pageOverview'}),Object.freeze({module:plans,key:'host.pageSubscription'}),Object.freeze({module:tune,key:'host.pageEffort'}),Object.freeze({module:where,key:'host.pageBreakdown'})]);
export const cockpitPageIds=Object.freeze(cockpitPageRegistry.map(p=>p.module.id));
export function mountPrototypeDeck(root:HTMLElement,onScope?:(key:string)=>boolean,fixture:PrototypeDetailsFixture=unavailablePrototypeDetailsFixture(),redBelow:()=>number=()=>effectiveRedBelow(undefined),reportPins:(ids:string[])=>void=()=>{},onSettings:()=>boolean=()=>false,onRange?:(range:CockpitRange)=>boolean,onRefresh:(key:string)=>boolean=()=>false,appRange?:()=>CockpitRange,onOpenCompare:()=>void=()=>{}){
 const scale=root.querySelector<HTMLElement>('.fd-scale')!,channels=root.querySelector<HTMLElement>('.fd-chs')!,mfd=root.querySelector<HTMLElement>('.dk-mfd')!;
 let details=fixture;const fixturePublication=fixture.publication!==null;fixture=unavailablePrototypeDetailsFixture();
 let publicationKey:string|null=null;
 let locale:Locale='en',selected=0,scope='all',data:WireCockpitData|null=null,renderedNow=0;
 // Prototype mfd.js:39-58,75 (openMfdView/closeMfdView): the full alert list is a view over the current page, opened by the
 // ALERT lamp or the overview's "+N" line, closed by "‹ Back to <page>", Esc, a page key or a second lamp press.
 let pageFill:{w:number;h:number}|null=null,alertsView:{from:'caution'|'mfd';mark?:string|null;flash?:boolean}|null=null,returnPage:number|null=null,tuneModel:string|null=null;
 // The study's comparison view (mfd.js openComparison, views.js round D1): a fader trial shows "Compare · <model>" over
 // the current page, whose key goes dark; ‹ back, Esc, a page key or the same source again returns. One trial at a time.
 let compare:{modelId:string;current:string|null;trial?:string;fast?:boolean;currentFast:boolean}|null=null,cmpFill:{w:number;h:number}|null=null,cmpWatch:ResizeObserver|null=null;root.dataset.detailsAvailable=String(details.liveSessions!==null);
 // The study controller's fixed three-channel skeleton. No fixture data is
 // bundled; absent publication and session capabilities leave all bays empty, and the bank row says so.
 const skeleton=(i:number)=>`<div class="fd-ch empty" data-slot="${i}"><div class="fd-leds"></div><button class="fd-strip" data-mat="well" tabindex="-1"></button>
  <div class="fd-travel" role="slider" aria-orientation="vertical" aria-valuemin="0" aria-valuemax="4" tabindex="-1"><span class="fd-slot"></span><span class="fd-marks"></span><span class="fd-tline" hidden></span><span class="fd-peek"></span><span class="fd-ghost" data-mat="part" hidden></span><span class="fd-cap" data-mat="part" hidden></span></div></div>`;
 channels.innerHTML=Array.from({length:3},(_,i)=>skeleton(i)).join('');
 for(const b of channels.querySelectorAll<HTMLButtonElement>('.fd-strip'))b.disabled=true;
 const bank=root.querySelector<HTMLElement>('.fd-bank')!;bank.innerHTML=bankView({bank:0,banks:1});
 // CKP-FAD-54 / V1-FINAL §15: a click on empty fader space deselects the model and closes its effort page.
 const fadPanel=root.querySelector<HTMLElement>('.dk-fad'),emptyClick=(e:MouseEvent)=>{if(!e.isTrusted||!compare)return;
  // The event path, not target.closest: a card click repaints the card, so its target is detached by the time it bubbles here.
  if(e.composedPath().some(n=>n instanceof Element&&n.matches('.fd-strip,.fd-travel,button,a,input')))return;closeCompare();};fadPanel?.addEventListener('click',emptyClick);
 const ladder=['Low','Med','High','XHigh','Max'] as const,BANK_SIZE=3;let bankIndex=0,selectedModel:string|null=null,previews:Record<string,string>={};
 // WP-08 / WP-09: cards follow the app's time range (rangeNow(), from shell.range; V1-FINAL §0: use, ≈cost and shares follow it).
 // heldCurrent keeps each model's current effort for the hysteresis (CKP-FAD-53).
 const heldCurrent=new Map<string,string>();
 let showAllModels=false,pins:string[]=[],unpinned=new Set<string>(),press:{pointer:number;started:number;sourceId:string;pinned:boolean}|null=null,suppressClick=false;
 // CKP-FAD-24/-17 (D115, D122): a drag moves only the trial ghost, continuously; the release snaps it to the nearest effort
 // the model has (back on the real lever = no trial). The real lever shows one of 33 baked frames (Low 0 .. Max 32) and
 // glides through them when its effort changes (CKP-FAD-12); the community edition draws the same state flat.
 let drag:{pointer:number;model:string;k:number;prior:string|undefined}|null=null;
 // --fd-frame is a registered integer in the official throttle sheet, so its CSS transition steps through the frames.
 const FRAMES=32,frameOf=(k:number)=>Math.round((1-k)*FRAMES);
 function setLever(cap:HTMLElement,k:number){const frame=String(frameOf(k));cap.dataset.frame=frame;cap.style.setProperty('--fd-frame',frame);}
 // The trial ghost and the thin blue slot line from the real lever to it (D122); k is continuous while dragging.
 function placeGhost(ch:HTMLElement,leverK:number,k:number|null,dragging:boolean){
  const ghost=ch.querySelector<HTMLElement>('.fd-ghost')!,line=ch.querySelector<HTMLElement>('.fd-tline')!;
  // CKP-FAD-54 step 5: a cancelled trial's ghost glides back onto the real lever in 280 ms (CSS .back), then hides.
  const owner=ch.dataset.model??'',same=!!owner&&ghost.dataset.for===owner;
  if(k==null&&same&&!ghost.hidden&&!dragging&&ghost.style.getPropertyValue('--k')!==''&&!ghost.classList.contains('back')){
   line.hidden=true;ghost.classList.remove('drag');ghost.classList.add('back');ghost.style.setProperty('--k',String(leverK));
   // It ends with its fade (opacity, the last transition, also under Reduce Motion); no timers in the page (bundle test).
   const end=(e:TransitionEvent)=>{if(e.target!==ghost||e.propertyName!=='opacity')return;ghost.removeEventListener('transitionend',end);ghost.removeEventListener('transitioncancel',end);if(!ghost.classList.contains('back'))return;ghost.classList.remove('back');ghost.hidden=true;ghost.style.removeProperty('--k');delete ghost.dataset.for;};
   ghost.addEventListener('transitionend',end);ghost.addEventListener('transitioncancel',end);return;
  }
  if(k!=null||!same)ghost.classList.remove('back');else if(ghost.classList.contains('back'))return;
  if(k!=null)ghost.dataset.for=owner;else delete ghost.dataset.for;
  ghost.hidden=k==null;line.hidden=k==null||Math.abs(k-.5)<.001;ghost.classList.toggle('drag',dragging);
  if(k==null){ghost.style.removeProperty('--k');return;}ghost.style.setProperty('--k',String(k));line.style.setProperty('--k0','.5');line.style.setProperty('--k1',String(k));
 }
 // The travel position under the pointer: 0 = Max .. 1 = Low, on the same rows as the level labels (pad at both ends).
 function travelK(travel:HTMLElement,clientY:number){
  const r=travel.getBoundingClientRect(),zoom=r.height/Math.max(1,travel.offsetHeight),pad=(parseFloat(getComputedStyle(travel).getPropertyValue('--fd-pad'))||8)*zoom;
  return Math.max(0,Math.min(1,(clientY-r.top-pad)/Math.max(1,r.height-2*pad)));
 }
 const record=(v:unknown):Record<string,unknown>|null=>v!==null&&typeof v==='object'&&!Array.isArray(v)?v as Record<string,unknown>:null;
 const safeText=(v:unknown)=>typeof v==='string'?v.slice(0,200):'';
 const effort=(v:unknown):string|null=>{if(typeof v!=='string')return null;const aliases:Readonly<Record<string,string>>={low:'Low',med:'Med',medium:'Med',high:'High',xhigh:'XHigh',max:'Max'};return aliases[v.toLowerCase()]??null;};
 const number=(v:unknown)=>typeof v==='number'&&Number.isFinite(v)&&v>=0&&v<=1e12?v:null;
 // Only a supplied publication and observed live-session input can populate
 // channels; this adapter never creates models or fills unknown readings.
 function faderInput(){
  const input=record(details.publication);if(!input||!Array.isArray(input.faders)||!Array.isArray(input.accounts))return {accounts:[],faders:[]};
  const accountIds=new Map<string,string>(),scopeBindings=new Map<string,string[]>();const accounts=input.accounts.slice(0,100).flatMap((v,i)=>{const a=record(v);if(!a||typeof a.id!=='string')return [];const id='a'+i;accountIds.set(a.id,id);return [{id,colour:typeof a.colour==='string'&&/^#[a-f0-9]{6}$/i.test(a.colour)?a.colour:null}];});
  const faders=input.faders.slice(0,100).flatMap((v,i)=>{const f=record(v),unlisted=f?.unlisted===true,rec=unlisted?'':effort(f?.rec);if(!f||(!rec&&!unlisted)||!Array.isArray(f.e))return [];const rows=f.e.slice(0,5).flatMap(v=>{if(!Array.isArray(v))return [];const label=effort(v[0]),ability=number(v[1]),cost=number(v[2]),aa=number(v[4]);return !label?[]:[aa!==null&&aa>0?[label,ability,cost,number(v[3]),aa]:[label,ability,cost,number(v[3])]];});if(!unlisted&&!rows.some(r=>r[0]===rec))return [];
   const live=Array.isArray(details.liveSessions)?details.liveSessions.slice(0,500).flatMap(v=>{const x=record(v),ref=x&&(typeof x.sessionRef==='string'?x.sessionRef:typeof x.ref==='string'?x.ref:null);return x&&ref?[{ref,value:x}]:[]}):[];
   // One session's verified binding: the publication's subscription, confirmed by the observed live session.
   const binding=(v:unknown)=>{const x=record(v),match=x&&typeof x.ref==='string'?live.find(y=>y.ref===x.ref):null;if(!x||!match)return null;const observed=match.value,bound=typeof x.sub==='string'&&typeof observed.subscriptionRef==='string'&&x.sub===observed.subscriptionRef&&accountIds.has(x.sub);return {x,observed,bound};};
   // macrevb-930-1: scope membership reads every bound session, not only the six the fader displays.
   const boundAccounts=Array.isArray(f.sessions)?[...new Set(f.sessions.slice(0,500).flatMap(v=>{const b=binding(v);return b?.bound?[accountIds.get(b.x.sub as string)!]:[];}))]:[];
   // macrevb-1052-2: the session lamp reads every verified session (not the six the tooltip lists); a session is bound only when its subscription is confirmed.
   const lamps=Array.isArray(f.sessions)?f.sessions.slice(0,500).flatMap(v=>{const b=binding(v);return b?[{sub:b.bound?accountIds.get(b.x.sub as string)??'':'',active:b.observed.state==='running'}]:[];}):[];
   const sessions=Array.isArray(f.sessions)?f.sessions.slice(0,6).flatMap(v=>{const b=binding(v);if(!b)return [];const {x,observed,bound}=b;return [{sub:bound?accountIds.get(x.sub as string)??'':'',account:bound?safeText(x.account):'',tool:safeText(observed.tool||observed.source),project:safeText(observed.projectLabel||observed.project),effort:effort(observed.effort),fast:typeof observed.fast==='boolean'?observed.fast:null,lastObservedAt:typeof observed.lastObservedAt==='string'?observed.lastObservedAt:typeof observed.lastAt==='string'?observed.lastAt:null,running:false,active:observed.state==='running',startedMin:null,endedMin:null}];}):[];
   // CKP-FAD-53: the current effort from every bound live session of the last 15 minutes (hysteresis held per model).
   const samples=Array.isArray(f.sessions)?f.sessions.slice(0,500).flatMap(v=>{const b=binding(v);if(!b)return [];const o=b.observed,at=Date.parse(safeText(o.lastObservedAt||o.lastAt));return [{effort:effort(o.effort),at,weight:number(o.rate)}];}):[];
   const sourceId=safeText(f.id),now=renderedNow||Date.now(),picked=samples.length?currentEffort(samples,now,heldCurrent.get(sourceId)??null):{current:null,notable:[] as string[]};if(picked.current)heldCurrent.set(sourceId,picked.current);
   const current=picked.current,fast=(sessions.find(x=>x.effort===current)??sessions[0])?.fast??null,tier=record(f.tier),speed=number(tier?.speed),cost=number(tier?.cost),harness=safeText(tier?.harness),otherEntries:Record<string,number>={};for(const x of sessions.slice(1))if(x.effort)otherEntries[x.effort]=(otherEntries[x.effort]??0)+1;
   const links=Array.isArray(f.accounts)?f.accounts.flatMap(v=>typeof v==='string'&&accountIds.has(v)?[accountIds.get(v)!]:[]):[];
   scopeBindings.set('model'+i,boundAccounts);
   return [{id:'model'+i,unlisted,sourceId:safeText(f.id),...use7(safeText(f.id)),name:safeText(f.name)||safeText(f.short),short:safeText(f.name)?shortLabel(safeText(f.name)):safeText(f.short),rec:rec??'',e:rows,pinned:pins.includes(safeText(f.id))||(f.pinned===true&&!unpinned.has(safeText(f.id))),live:sessions.length>0,lamps,current,currentFast:fast===true,others:otherEntries,notable:picked.notable,...cardInput(sourceId,f.use),tier:speed!==null&&harness?{harness,speed,cost,...(tier?.taskTimeUnknown===true?{taskTimeUnknown:true as const}:{})}:null,accounts:links,sessions}];});
  // G3-110: a subscription scope keeps that subscription's faders (study core.js faders()/scopePools); before the D123 cap.
  const scopeMember=scope==='all'||!data?null:cockpitMembers(data).find(m=>m.key===scope)??null,scopeAccount=scopeMember?accountIds.get(scopeMember.key)??null:null;
  const members=new Set(scopedFaders(faders.map(f=>({id:f.id,accounts:f.accounts,sessions:(scopeBindings.get(f.id)??[]).map(sub=>({sub}))})),scopeAccount,!!scopeMember&&Object.hasOwn(toolDevelopers,scopeMember.row.id)).map(f=>f.id));
  const shown=faders.filter(f=>members.has(f.id));
  const rank=new Map(pins.map((id,i)=>[id,i]));shown.sort((a,b)=>(rank.get(a.sourceId)??Infinity)-(rank.get(b.sourceId)??Infinity));return {accounts,faders:showAllModels?shown:shown.slice(0,FADER_SET_LIMIT)};
 }
 // CKP-MFD-50: a model's own 7-day use for the effort page title: its tokens and its share of everything recorded in those
 // seven days (local history only). Absent when the history does not rank the model. ≈$ joins with estimated cost (WP-06).
 function use7(id:string):{u7?:{tokens:number;share:number;cost?:string}}{
  const u=cardUsage(data?.history,'7d').get(id);
  return u?{u7:{tokens:u.tokens,share:u.share,...(u.cost!==undefined?{cost:approxCost(u.cost)}:{})}}:{};
 }
 // WP-08 (V1-FINAL §7): what a model card shows beyond the publication, for the cockpit's time range. A test fixture may
 // carry its own `use` on a fader; the normal entry reads the local history ranking. `recorded` = a recorded session of
 // this model in the range (the 7-day ledger), so a model in use without token history reads "no usage record".
 function cardInput(id:string,fixtureUse:unknown):{use:CardUse|null;recorded:boolean}{
  const u=cardUsage(data?.history,rangeNow()).get(id)??null,fx=record(fixtureUse),tokens=number(fx?.tokens),share=number(fx?.share),cost=number(fx?.cost);
  const use=u??(tokens!==null&&share!==null&&share<=1?{tokens,share,...(cost!==null?{cost}:{})}:null);
  const span=rangeNow()==='today'?86_400_000:rangeNow()==='7d'?7*86_400_000:30*86_400_000,now=renderedNow||Date.now();
  const recorded=(data?.details?.recentSessions??[]).some(x=>x.model===id&&now-Date.parse(x.lastObservedAt)<=span);
  return {use,recorded};
 }
 type Channel={id:string;current:string|null;base:string;currentFast:boolean};
 function openCompare(c:Channel,trial?:string,fast?:boolean){
  onOpenCompare();
  for(const id of Object.keys(previews))if(id!==c.id)delete previews[id];
  compare={modelId:c.id,current:c.current??null,...(trial?{trial}:{}),...(fast!==undefined?{fast}:{}),currentFast:!!c.currentFast};
  if(trial&&trial!==c.base)previews[c.id]=trial;else delete previews[c.id];
  selectedModel=c.id;alertsView=null;paint();
 }
 // CKP-FAD-54: closing the effort page deselects the model (the frame goes with it); the page underneath comes back.
 function closeCompare(){if(!compare)return false;delete previews[compare.modelId];compare=null;selectedModel=null;paint();return true;}
 // CKP-FAD-54 step 5 / §15: Esc first cancels a trial and stays on the effort page; the next Esc returns.
 function cancelTrial(){if(!compare||(previews[compare.modelId]===undefined&&(compare.fast===undefined||compare.fast===compare.currentFast)))return false;
  const {trial:_t,fast:_f,...rest}=compare;delete previews[compare.modelId];compare=rest;paint();return true;}
 // faders.js tryEffort / pressLevel / pressStrip. G3-87: the ghost (a trial) is kept only off the real cap (current, or ★
 // when current is unreported); pressing the LCD opens the comparison for the model without one.
 function tryEffort(c:Channel,level:string){openCompare(c,level,compare?.modelId===c.id?compare.fast:undefined);}
// CKP-FAD-54 step 3 (macrevb-1052-4): while the pointer is down the card shows the tentative effort ("Try XHigh / Now High")
 // and the ghost follows; the preview is the same one a release keeps. Only the card's own lines are repainted, never the
 // channel, so the captured pointer and the drag stay alive. Moving back onto the real cap shows the normal card.
 function dragCard(c:Channel&{label?:string},level:string){
  const ch=channels.querySelector<HTMLElement>(`.fd-ch[data-model="${c.id}"]`),strip=ch?.querySelector<HTMLElement>('.fd-strip');if(!ch||!strip)return;
  if(level===c.base)delete previews[c.id];else previews[c.id]=level;
  const model=faderModel(faderInput(),{bank:bankIndex,bankSize:BANK_SIZE,compact:root.dataset.layout==='640',selModel:selectedModel,previews,view:compare?{modelId:compare.modelId,trial:compare.modelId===c.id?level:compare.trial,fast:compare.fast??null,from:'fader',key:compare.modelId}:null,phase:'open',reduced:true}),next=model.all.find((x:{id:string})=>x.id===c.id);
  if(!next)return;strip.innerHTML=lcdView(next);strip.dataset.card=next.card.state;strip.setAttribute('aria-label',stripAria(next));ch.classList.toggle('trying',!!next.trial);
  const shareBar=strip.querySelector<HTMLElement>('.cd-bar');if(shareBar&&next.card.bar!=null){shareBar.style.setProperty('--s',(next.card.bar*100).toFixed(1)+'%');if(next.segments[0])shareBar.style.setProperty('--v',next.segments[0]);}
  for(const [j,el] of [...strip.querySelectorAll<HTMLElement>('.st-vend b')].entries())el.style.setProperty('--v',next.segments[j]);
 }
 function pressLevel(c:Channel,level:string){if(compare?.modelId===c.id&&level===(previews[c.id]??c.base))closeCompare();else tryEffort(c,level);}
 function pressStrip(c:Channel){if(compare?.modelId===c.id)closeCompare();else openCompare(c,previews[c.id]??c.current??undefined);}
 function paintScale(){setLanguage(locale);scale.innerHTML=scaleView();for(const b of scale.querySelectorAll<HTMLButtonElement>('.sc-l')){b.disabled=true;b.classList.add('na');b.style.setProperty('--k',String(levelK(b.dataset.level??'')));}}
 function paintFaders(){
  const data=faderInput(),input=record(details.publication),requested=selectedModel??safeText(input?.selectedModel),target=data.faders.find(f=>f.id===requested||f.sourceId===requested)?.id??null,ui={bank:bankIndex,bankSize:BANK_SIZE,compact:root.dataset.layout==='640',selModel:target,previews,view:compare?{modelId:compare.modelId,trial:compare.trial,fast:compare.fast??null,from:'fader',key:compare.modelId}:null,phase:'open',reduced:true},model=faderModel(data,ui);bankIndex=model.bank;
  const targetChannel=model.all.find((c:{id:string})=>c.id===model.target);
  // The one selected model, by published id, for the surfaces that light with it (session line, rocket ring: WP-04, WP-12).
  const selSource=compare?data.faders.find(f=>f.id===compare!.modelId)?.sourceId:null;if(selSource)root.dataset.selModel=selSource;else delete root.dataset.selModel;
  for(const b of scale.querySelectorAll<HTMLButtonElement>('.sc-l')){const level=b.dataset.level??'',allowed=!!targetChannel&&targetChannel.levels.includes(level);b.disabled=false;b.classList.toggle('na',!allowed);b.onclick=e=>{if(!e.isTrusted||!allowed)return;pressLevel(targetChannel,level);};}
  for(const [i,ch] of [...channels.querySelectorAll<HTMLElement>('.fd-ch')].entries()){
   const c=model.channels[i],strip=ch.querySelector<HTMLButtonElement>('.fd-strip')!,leds=ch.querySelector<HTMLElement>('.fd-leds')!,travel=ch.querySelector<HTMLElement>('.fd-travel')!,marks=ch.querySelector<HTMLElement>('.fd-marks')!,cap=ch.querySelector<HTMLElement>('.fd-cap')!;
   ch.className='fd-ch'+(c?'':' empty');ch.dataset.model=c?.id??'';if(c){ch.classList.toggle('sel',!!c.sel);ch.classList.toggle('trying',!!c.trial);ch.classList.toggle('src',c.src==='fader');}strip.disabled=!c;strip.tabIndex=c?0:-1;travel.tabIndex=c&&!c.unlisted?0:-1;
   leds.innerHTML=c?indicatorView(c):'';if(c?.leds.length){const indicator=leds.querySelector<HTMLElement>('.fd-indicator'),times=c.leds.map((x:{lastObservedAt:string|null})=>x.lastObservedAt?Date.parse(x.lastObservedAt):NaN).filter(Number.isFinite),latest=times.length?new Date(Math.max(...times)).toLocaleString(locale):'';indicator?.setAttribute('aria-label',c.name+' · '+ht(locale,'host.lastReading')+(latest?' '+latest:''));}strip.innerHTML=c?lcdView(c):'';if(c)strip.dataset.card=c.card.state;else delete strip.dataset.card;marks.innerHTML=c?marksView(c):'';cap.hidden=!c||c.unlisted;cap.classList.toggle('unused',!!c&&c.card.state==='unused');if(!c)placeGhost(ch,0,null,false);
   if(!c){strip.removeAttribute('aria-label');strip.removeAttribute('data-strip');travel.removeAttribute('data-travel');strip.onclick=null;strip.onpointerdown=null;strip.onpointerup=null;strip.onpointercancel=null;strip.onlostpointercapture=null;travel.onkeydown=null;travel.onpointerdown=null;travel.onpointermove=null;travel.onpointerup=null;travel.onpointercancel=null;travel.removeAttribute('aria-valuenow');travel.removeAttribute('aria-valuetext');continue;}strip.dataset.strip=c.id;travel.dataset.travel=c.id;const shown=c.tEff||c.base;if(c.unlisted){/* no efforts, no lever: not a slider, not focusable, hidden from assistive tech (macrevb-1052-5) */travel.hidden=true;travel.setAttribute('aria-hidden','true');travel.removeAttribute('role');travel.removeAttribute('aria-label');travel.removeAttribute('aria-valuenow');travel.removeAttribute('aria-valuetext');travel.removeAttribute('aria-valuemin');travel.removeAttribute('aria-valuemax');}else{travel.hidden=false;travel.removeAttribute('aria-hidden');travel.setAttribute('role','slider');travel.setAttribute('aria-valuemin','0');travel.setAttribute('aria-valuemax','4');travel.setAttribute('aria-label',c.name);travel.setAttribute('aria-valuenow',String(ladder.indexOf(shown)));travel.setAttribute('aria-valuetext',shown);}const dragging=drag?.model===c.id;placeGhost(ch,c.capK,dragging?drag!.k:c.ghostK,dragging);travel.dataset.lever=c.base;travel.dataset.trial=c.tEff??'';setLever(cap,c.capK);travel.onkeydown=e=>{if(!e.isTrusted||!['ArrowUp','ArrowDown'].includes(e.key))return;e.preventDefault();const at=ladder.indexOf(shown),step=e.key==='ArrowUp'?1:-1;for(let n=at+step;n>=0&&n<ladder.length;n+=step)if(c.levels.includes(ladder[n])){selectedModel=c.id;tryEffort(c,ladder[n]);break;}};const nearest=(k:number)=>{const levels=c.levels as string[];let best=levels[0],delta=Infinity;for(const level of levels){const d=Math.abs((4-ladder.indexOf(level as typeof ladder[number]))/4-k);if(d<delta){delta=d;best=level;}}return best;};
   travel.onpointerdown=e=>{if(!e.isTrusted||e.button!==0||drag||!c.levels.length)return;e.preventDefault();drag={pointer:e.pointerId,model:c.id,k:travelK(travel,e.clientY),prior:previews[c.id]};try{travel.setPointerCapture(e.pointerId);}catch{}travel.focus({preventScroll:true});placeGhost(ch,c.capK,drag.k,true);dragCard(c,nearest(drag.k));};
   // CKP-FAD-14: hovering the travel shows the blue dashed what-if box at the nearest offered level (not a trial: nothing is chosen).
   const peek=ch.querySelector<HTMLElement>('.fd-peek')!,hidePeek=()=>peek.classList.remove('on');
   travel.onpointerleave=hidePeek;
   travel.onpointermove=e=>{if(drag){if(drag.pointer!==e.pointerId||drag.model!==c.id)return;hidePeek();drag.k=travelK(travel,e.clientY);placeGhost(ch,c.capK,drag.k,true);dragCard(c,nearest(drag.k));return;}if(e.pointerType==='touch'||!c.levels.length){hidePeek();return;}const at=nearest(travelK(travel,e.clientY));peek.style.setProperty('--k',String((4-ladder.indexOf(at as typeof ladder[number]))/4));peek.classList.toggle('on',at!==c.base);};
   travel.onpointerup=e=>{if(!drag||drag.pointer!==e.pointerId)return;const k=drag.model===c.id?travelK(travel,e.clientY):drag.k;drag=null;selectedModel=c.id;tryEffort(c,nearest(k));};
   travel.onpointercancel=e=>{if(!drag||drag.pointer!==e.pointerId)return;if(drag.prior===undefined)delete previews[drag.model];else previews[drag.model]=drag.prior;drag=null;paintFaders();};strip.onpointerdown=e=>{const sourceId=data.faders.find(f=>f.id===c.id)?.sourceId;if(!e.isTrusted||!e.isPrimary||e.button!==0||!sourceId||press||c.unlisted)return;suppressClick=false;press=beginFaderPress(press,{pointer:e.pointerId,started:e.timeStamp,sourceId,pinned:!!c.pinned});strip.setPointerCapture(e.pointerId);};const release=(e:PointerEvent)=>{if(!e.isTrusted)return;const result=endFaderPress(press,e.pointerId,e.timeStamp,'up');press=result.active;const held=result.commit;if(!held)return;if(held.pinned){pins=pins.filter(id=>id!==held.sourceId);unpinned.add(held.sourceId);}else{pins=[held.sourceId,...pins.filter(id=>id!==held.sourceId)];unpinned.delete(held.sourceId);}reportPins(pins.slice(0,64));suppressClick=true;bankIndex=0;paintFaders();};strip.onpointerup=release;strip.onpointercancel=e=>{if(!e.isTrusted)return;press=endFaderPress(press,e.pointerId,e.timeStamp,'cancel').active;};strip.onlostpointercapture=e=>{if(press?.pointer===e.pointerId)press=null;};strip.onclick=e=>{if(!e.isTrusted)return;if(suppressClick&&e.detail!==0){suppressClick=false;return;}suppressClick=false;if(c.unlisted)return;selectedModel=c.id;pressStrip(c);};strip.setAttribute('aria-label',stripAria(c));cap.style.setProperty('--k',String(c.capK));
   for(const [j,el] of [...marks.querySelectorAll<HTMLElement>('.fd-tick')].entries())el.style.setProperty('--k',String(c.ticks[j]));const rec=marks.querySelector<HTMLElement>('.fd-rec');rec?.style.setProperty('--k',String(c.recK));for(const [j,el] of [...marks.querySelectorAll<HTMLElement>('.fd-dot')].entries())el.style.setProperty('--k',String(c.dots[j].k));
   // CSP (style-src 'self') drops inline styles: the share bar's length and colour and the lamp colour go through CSSOM.
   const shareBar=strip.querySelector<HTMLElement>('.cd-bar');if(shareBar&&c.card.bar!=null){shareBar.style.setProperty('--s',(c.card.bar*100).toFixed(1)+'%');if(c.segments[0])shareBar.style.setProperty('--v',c.segments[0]);}
   const lamp=leds.querySelector<HTMLElement>('.fd-indicator');if(lamp&&c.lampColour)lamp.style.setProperty('--lamp',c.lampColour);for(const [j,el] of [...strip.querySelectorAll<HTMLElement>('.st-vend b')].entries())el.style.setProperty('--v',c.segments[j]);
  }
  bank.innerHTML=bankView(model);if(!model.all.length)bank.append(node('p','mp-empty sm',ht(locale,'host.dataUnavailable')));for(const b of bank.querySelectorAll<HTMLButtonElement>('[data-bank]'))b.onclick=e=>{if(!e.isTrusted)return;bankIndex+=b.dataset.bank==='1'?1:-1;paintFaders();};
 }

 const bar=node('div','mfd-pk'),screen=node('div','mfd-screen'),page=node('div','mfd-page pg-overview'),footer=node('div','mfd-ok');bar.setAttribute('role','toolbar');screen.dataset.mat='well';page.dataset.fill='page';screen.append(page);
 // A change of the screen's size (compact / tall) redraws the overview, whose alert budget follows it.
 if(typeof ResizeObserver!=='undefined')new ResizeObserver(()=>{if(selected===0&&pageFill&&page.clientHeight>0&&page.clientHeight!==pageFill.h)paint(true);}).observe(page);
 // G3-171: one source for the range. The app's (the header's) range is read at every paint; the copy below is only the
 // fallback of a deck mounted without an app (tests).
 const rangeNow=():CockpitRange=>appRange?.()??uiRangeLocal;const pages=cockpitPageRegistry,modules=pages.map(p=>p.module);let uiWhere='proj',uiRangeLocal:CockpitRange=INITIAL_RANGE,painted:CockpitRange|null=null,uiChart='bars',uiStack=true,uiModels:'list'|'chart'='list',listPick:string|null=null,uiSubTab='now',uiCycle:string|null=null,gridFill:{w:number;h:number}|null=null;
 const buttons=pages.map((item,i)=>{const b=node('button','pk'),caption=node('span'),led=node('i','pk-led');b.type='button';b.dataset.mfd='page:'+modules[i].id;b.dataset.mat='part';b.append(caption,led);b.onclick=e=>{if(!e.isTrusted)return;alertsView=null;if(compare){delete previews[compare.modelId];compare=null;}returnPage=null;tuneModel=null;selected=i;paint();};bar.append(b);return {b,caption};});
 mfd.replaceChildren(bar,screen,footer);
 // The study's floating LCD tooltip (mfd.css .mfd-tip) for chart cells and buckets: hover shows a [data-tip]'s lines,
 // the first as its heading. Text only; it never takes pointer events.
 const tip=node('div','mfd-tip');tip.hidden=true;tip.setAttribute('role','tooltip');screen.append(tip);
 const hideTip=()=>{tip.hidden=true;tip.replaceChildren();};
 screen.onpointerover=e=>{const source=(e.target as Element).closest?.('[data-tip]');if(!source||!page.contains(source)){hideTip();return;}
  const lines=(source.getAttribute('data-tip')??'').split('\n').filter(Boolean);if(!lines.length){hideTip();return;}
  tip.replaceChildren(...lines.map((line,i)=>node('span',i?'':'h',line)));tip.hidden=false;
  const box=screen.getBoundingClientRect(),r=source.getBoundingClientRect(),w=tip.offsetWidth,h=tip.offsetHeight;
  const left=r.right-box.left+6+w<=box.width?r.right-box.left+6:Math.max(0,r.left-box.left-6-w),top=Math.min(Math.max(0,r.top-box.top),Math.max(0,box.height-h));
  tip.style.left=left+'px';tip.style.top=top+'px';};
 screen.onpointerleave=hideTip;
 // Public projection only: v1.1 charts, rankings and full session lists are
 // absent, not populated with the prototype's fixture numbers.
 // 时间 list from the admitted last-seen sessions only (CKP-MFD-23, bounded v1 part). The producer reports
 // running or idle and the last observation; it is never an end time, and per-session tokens are not reported.
 function lastSeen(members:ReturnType<typeof cockpitMembers>,ids:Map<string,string>){
  const detail=data?.details;if(!detail||detail.sessionCoverage!=='local-last-seen')return [];
  return detail.sessions.slice(0,64).flatMap(x=>{const at=Date.parse(x.lastObservedAt);if(!Number.isFinite(at)||(x.state!=='running'&&x.state!=='idle'))return [];
   const member=sessionMember(members,x);
   return [{ref:x.sessionRef,sub:member?ids.get(member.key)??null:null,tool:x.source,model:x.model,effort:x.effort,fast:false,project:x.projectLabel??'--',running:x.state==='running',startedAt:null,endedAt:null,lastAt:at,tokens:null}];});
 }
 // D63: the 7-day time view adds the recorded sessions (cockpitSessionsV1) that are not live now. Each shows its last
 // sighting only: no end time, title or token count.
 function recentSeen(members:ReturnType<typeof cockpitMembers>,ids:Map<string,string>,live:ReadonlySet<string>){
  const detail=data?.details;if(!detail?.recentSessions||detail.sessionCoverage!=='local-last-seen')return [];
  return detail.recentSessions.slice(0,200).flatMap(x=>{const at=Date.parse(x.lastObservedAt);if(!Number.isFinite(at)||live.has(x.sessionRef))return [];
   const member=x.subscriptionRef?members.find(m=>m.key===x.subscriptionRef):undefined;
   return [{ref:x.sessionRef,sub:member?ids.get(member.key)??null:null,tool:x.source,model:x.model,effort:x.effort,fast:false,project:x.projectLabel??'--',running:false,startedAt:null,endedAt:null,lastAt:at,tokens:null}];});
 }
 // The balance text of a current reading with a balance and no usage percentage; null otherwise.
 function balanceOnly(account:WireAccount):string|null{
  const c=account.credits,value=c?.balance;
  if(account.valueState!=='current'||!c||typeof value!=='number'||!Number.isFinite(value)||account.windows.some(w=>w.remainingPercent!==null))return null;
  return moneyText(c,locale)??formatCredits(value,locale);
 }
 function publicData(now=renderedNow){
  const members=data?cockpitMembers(data):[],ids=new Map(members.map((m,i)=>[m.key,'member'+i]));
  // Owner build 13 / study fixtures: the Subscription page names the subscription ("ChatGPT Pro"), not the tool, and
  // shows its vendor mark; the reading age is whole minutes, "just now" under one.
  // Marks the bundle ships under assets/brands (build.mjs); a vendor without one shows no mark.
  const subscriptionMarks:Readonly<Record<string,string>>={openai:'openai-white.svg',claude:'claude-rounded.svg',glm:'zhipu.svg',kimi:'kimi-white.svg'};
  const product:Readonly<Record<string,string>>={openai:'ChatGPT',claude:'Claude'},planOf=(account:WireAccount)=>account.plan.name?(locale==='en'?account.plan.name.en:account.plan.name.zh):'';
  const titleOf=(row:WireRow,account:WireAccount)=>{const brand=row.vendorKey?product[row.vendorKey]:undefined,plan=planOf(account);return brand?[brand,plan].filter(Boolean).join(' '):locale==='en'?row.name.en:row.name.zh;};
  const ageOf=(account:WireAccount)=>{const at=account.observedAt?Date.parse(account.observedAt):NaN;if(!Number.isFinite(at))return null;const m=Math.round(Math.max(0,now-at)/60000);return m<1?null:m;};
  const colours=memberColours(members);
  const accounts=members.map(({key,row,account})=>({id:ids.get(key)!,name:titleOf(row,account),short:locale==='en'?row.name.en:row.name.zh,plan:planOf(account),vendor:row.vendorKey&&Object.hasOwn(vendorPalette,row.vendorKey)?row.vendorKey:'unknown',colour:colours.get(key)!,logo:row.vendorKey&&Object.hasOwn(subscriptionMarks,row.vendorKey)?subscriptionMarks[row.vendorKey]!:'',source:'native',state:account.valueState==='current'?'ok':account.valueState==='retained'?'stale':'loading',ageMin:ageOf(account),support:'quota-only',pool:null,windows:account.valueState==='none'?[]:account.windows.filter(w=>!scopedWindow(w)).map(w=>({kind:w.role==='session'?'5h':w.role==='weekly'?'week':w.role==='monthly'?'month':w.role==='daily'?'day':'other',label:locale==='en'?w.label.en:w.label.zh,remaining:displayWindow(account,w,now)?w.remainingPercent:null,resetIn:displayWindow(account,w,now)&&w.resetsAt&&Number.isFinite(Date.parse(w.resetsAt))&&Date.parse(w.resetsAt)>=now?(Date.parse(w.resetsAt)-now)/60000:null,resetAt:displayWindow(account,w,now)&&w.resetsAt&&Number.isFinite(Date.parse(w.resetsAt))?Date.parse(w.resetsAt):null,...runOutFields(runOutMinutes(data,row.id,account,w,now)),elapsed:null})),extras:account.valueState==='none'?[]:account.windows.filter(scopedWindow).map(w=>({kind:'other',label:locale==='en'?w.label.en:w.label.zh,remaining:displayWindow(account,w,now)?w.remainingPercent:null,resetIn:displayWindow(account,w,now)&&w.resetsAt&&Number.isFinite(Date.parse(w.resetsAt))&&Date.parse(w.resetsAt)>=now?(Date.parse(w.resetsAt)-now)/60000:null,resetAt:displayWindow(account,w,now)&&w.resetsAt&&Number.isFinite(Date.parse(w.resetsAt))?Date.parse(w.resetsAt):null,...runOutFields(runOutMinutes(data,row.id,account,w,now)),elapsed:null})),cards:[],credits:scope==='all'&&prototypeEngineSupplement(account,data??undefined).reserveCredits?.balance!=null&&['credits','points'].includes(prototypeEngineSupplement(account,data??undefined).reserveCredits?.unit??'')?{balance:prototypeEngineSupplement(account,data??undefined).reserveCredits!.balance,drawing:null}:null,todayTokens:prototypeEngineSupplement(account,data??undefined).todayTokens,forecast:forecastOf(account.windows.filter(w=>!scopedWindow(w)).map(w=>runOutFields(runOutMinutes(data,row.id,account,w,now)))),peak:null,resets:resetHistory(data,account.subscriptionRef,row.id,now),usageStats:usageStats(data,account.subscriptionRef)}));
  // Owner D38: urgency order, subscription and time left; resets and stale readings are list-only (blue).
  // The overview follows the selected scope; the full list (the global lamp's destination) never does.
  const allAlerts=data?cautionItems(data,now,redBelow()).map(x=>({member:x.member,level:x.level,stable:x.stable,text:locale==='en'?x.text.en:x.text.zh,detail:x.detail?locale==='en'?x.detail.en:x.detail.zh:null,settings:x.settings===true,kind:x.kind})):[];
  const alerts=allAlerts.filter(x=>scope==='all'||x.member===scope).map(({level,text,kind})=>({level,text,kind}));
  // Public model data for the frontier (owner D39/D-B): the shared selection for this scope, ten at most.
  const published=publishedFleet(data,scope,now);
  // macrevc-1058-4: the Models list also shows an eligible model the history ranks as used even when it falls outside the ten-model field.
  const listModels=publishedFleet(data,scope,now,Infinity);
  return {now,accounts,alerts,allAlerts,events:[],...historyView(data,ids,now,locale),recordStart:recordStart(),sessionRanking:(()=>{const live=lastSeen(members,ids);return [...live,...recentSeen(members,ids,new Set(live.map(x=>x.ref)))];})(),models:published,listModels,lineup:[],selection:{scope:scope==='all'?null:ids.get(scope)??null,field:published},empty:accounts.length===0,ids,members};
 }
 // The first local day of the recorded history (cockpitHistoryV1 dailyFrom), as a local midnight.
 function recordStart(){const from=data?.history?.coverage==='local-history'?data.history.dailyFrom:null;if(!from||!/^\d{4}-\d{2}-\d{2}$/.test(from))return null;const [y,m,day]=from.split('-').map(Number),at=new Date(y!,m!-1,day!);if(at.getFullYear()!==y||at.getMonth()!==m!-1||at.getDate()!==day)return null;return at.getTime();}
 const dayStart=(now:number,back:number)=>{const at=new Date(now);return new Date(at.getFullYear(),at.getMonth(),at.getDate()-back).getTime();};
 // Beyond the engine's three (moreFaderModels): published models in use, live or recorded (D391: only sessions of
 // ticked subscriptions arrive here), then those of a developer one of the user's subscriptions runs, in publication
 // order. Banks of three page through them.
 function moreFaderModels(value:WireCockpitData,subscriptions:readonly FaderSubscription[],live:readonly {readonly model:string}[]=[],recorded:readonly {readonly model:string}[]=[]){
  const published=value.details?.publishedModels??[];
  // D123 "show all models": every published model, not only those of the user's own plans.
  if(showAllModels)return published;
  return moreModels(published,live,recorded,subscriptions,new Set(historyUsage(value.history).keys()));
 }
 function paint(keepFaders=false,now?:number){
  if(now!==undefined)renderedNow=now;
  painted=rangeNow();
  hideTip();if(!keepFaders){paintScale();paintFaders();}bar.setAttribute('aria-label',t('mfd.keysAria'));
  buttons.forEach(({b,caption},i)=>{caption.textContent=t(modules[i].title);b.setAttribute('aria-label',ht(locale,pages[i].key));b.classList.toggle('on',i===selected);b.setAttribute('aria-pressed',String(i===selected));});
  // The page's own measured size (the screen is absolute, so it does not depend on the content): the overview's alert budget reads it (V1-FINAL §13).
 if(page.clientHeight>0)pageFill={w:page.clientWidth,h:page.clientHeight};
  const d=publicData(),selectedId=scope==='all'?null:d.ids.get(scope)??null,subId=selectedId??subjectOf(d,{scope:null})?.id??null,ui={page:modules[selected].id,view:null,days:rangeNow()==='today'?24:rangeNow()==='7d'?7:30,range:rangeNow(),stack:uiStack,chart:uiChart,where:uiWhere,models:uiModels,time:rangeNow()==='today'?'today':'7d',subTab:uiSubTab,subDays:rangeNow()==='30d'?30:7,cycle:uiCycle,older:false,scope:selectedId,selModel:listPick??tuneModel,trials:{},now:d.now,lang:locale,fill:{...(selected===0&&uiChart==='grid'&&gridFill?{ov:gridFill}:{}),...(pageFill?{page:pageFill}:{})},redAt:redBelow()};
  root.querySelector('[data-caution]')?.classList.toggle('mfd-src',alertsView?.from==='caution');
  bar.classList.remove('dark');footer.className='mfd-ok';footer.onclick=null;
  // G3-171: before the first reply there is nothing to show yet; say so (busy) on every view the page carries, so a restored alerts list does not keep a stale busy flag.
  if(data)page.removeAttribute('aria-busy');else page.setAttribute('aria-busy','true');
  if(compare&&!alertsView&&paintCompare(d,ui))return;
  if(alertsView){
   // CKP-MFD-55/56 (WP-11): the list view (mfd-pages/alerts.js). A row selects its subscription and returns to the
   // page the list was opened from, now scoped; a grey (unreadable) row opens Settings › Subscriptions instead.
   const back=t(pages[selected].module.title),mark=alertsView.from==='caution'?alertsView.mark??null:null,flashRow=alertsView.flash===true;alertsView.flash=false;
   page.className='mfd-page pg-alerts is-view';
   page.innerHTML=alertsPage(d.allAlerts,{back:{label:t('mfd.back',{p:back}),aria:t('mfd.backAria',{p:back})},mark,flash:flashRow,ack:alertsView.from==='caution'});
   footer.replaceChildren(...Array.from({length:3},()=>{const e=node('span','ok soft off');e.dataset.mat='part';e.setAttribute('aria-hidden','true');return e;}));
   page.onclick=e=>{
    if(!e.isTrusted)return;const target=e.target as HTMLElement;
    if(target.closest('[data-mfd="back"]')){closeAlerts();return;}
    const row=target.closest<HTMLElement>('[data-al]'),x=row?d.allAlerts.find(a=>a.stable===row.dataset.alId):undefined;if(!x)return;
    if(x.settings){onSettings();return;}
    if(d.members.some(m=>m.key===x.member)&&onScope?.(x.member)){setScope(x.member);closeAlerts();}
   };
   return;
  }
  page.className='mfd-page pg-'+modules[selected].id;
  // G3-171: before the first reply there is nothing to show yet; say so (loading) instead of the empty-subscriptions text.
  page.innerHTML=!data?`<p class="mp-empty mp-loading" role="status">${t('eng.loading')}</p>`:d.empty?`<p class="mp-empty">${t('eng.empty')}</p>`:modules[selected].render(d,ui);
  // The study's measured chart area (mfd.js): the heatmap takes the largest cells its area allows, so it is drawn at the
  // measured size, again once if that size changed.
  if(!d.empty&&selected===0&&uiChart==='grid'){const area=page.querySelector<HTMLElement>('[data-fill="ov"]'),size=area?{w:Math.floor(area.clientWidth),h:Math.floor(area.clientHeight)}:null;if(size&&size.w>0&&size.h>0&&(gridFill?.w!==size.w||gridFill?.h!==size.h)){gridFill=size;page.innerHTML=modules[selected].render(d,{...ui,fill:{ov:size}});}}
  // The page CSP (style-src 'self') drops the study markup's inline style attributes. The heatmap's placement and its
  // vendor colour (--hv) live there, so they are applied again through CSSOM, which the policy allows.
  // The vendor mark (plans.js glyph): a monochrome mask in the vendor ink; an unknown vendor has no mark.
  for(const e of page.querySelectorAll<HTMLElement>('i.mg[style]')){const css=e.getAttribute('style')??'',ink=/--v:(#[0-9a-f]{6})/i.exec(css)?.[1],url=/url\('assets\/brands\/([a-z-]+\.svg)'\)/.exec(css)?.[1];e.removeAttribute('style');if(!url){e.remove();continue;}if(ink)e.style.setProperty('--v',ink);e.style.setProperty('-webkit-mask-image',`url('assets/brands/${url}')`);e.style.setProperty('mask-image',`url('assets/brands/${url}')`);}
  for(const e of page.querySelectorAll<SVGElement|HTMLElement>('svg.ov-heat[style],.hm-since[style]')){const css=e.getAttribute('style')??'';e.removeAttribute('style');for(const decl of css.split(';')){const at=decl.indexOf(':');if(at<0)continue;const name=decl.slice(0,at).trim(),value=decl.slice(at+1).trim();if(/^(left|top|--hv)$/.test(name)&&/^(-?\d+(\.\d+)?px|#[0-9a-f]{3,8})$/i.test(value))e.style.setProperty(name,value);}}
  // Opened from the HUD: the same return rule as the alerts view.
  if(returnPage!==null){const back=node('button','mfd-back',t('mfd.back',{p:t(pages[returnPage]!.module.title)}));back.type='button';back.dataset.mfd='back';page.prepend(back);}
  // D376 (CKP-ENG-27/55): the update time and refresh are the overview's bottom line, in every overview state. 全部 shows the
  // oldest reading and rereads everything; a selected subscription shows its own and rereads only it. Reads that keep
  // failing turn the line amber ("12 分钟前 · 重试", the full sentence on hover). The existing note sits on the same line.
  if(selected===0&&!d.empty){
   const own=selectedId?d.members[Number(selectedId.slice('member'.length))]:undefined,shown=own?[own]:d.members,state=footerState(shown.map(m=>m.account));
   const foot=node('div','ov-foot'),note=page.querySelector('.ov-note');if(note)foot.append(note);
   const line=node('div','eng-upd'),copy=state.at!==null?updatedCopy(state.at,d.now):null;line.dataset.failing=String(state.failing);
   if(copy){const text=node('span','eng-upd-t',state.failing?ht(locale,agoKey(copy.key),{n:copy.n}):ht(locale,copy.key,{n:copy.n}));line.append(text);}
   if(copy||state.failing){line.append(node('i','eng-upd-sep',' · '));}
   const button=node('button','eng-upd-r',ht(locale,state.failing?'host.retry':'host.refresh'));button.type='button';button.dataset.refresh=own?.key??'all';
   button.setAttribute('aria-label',own?ht(locale,'host.refreshOne',{name:accountLabel(locale==='en'?own.row.name.en:own.row.name.zh,own.account,locale)}):ht(locale,'host.refreshAll'));
   if(state.failing)line.dataset.tip=[copy?ht(locale,copy.key,{n:copy.n}):'',ht(locale,'host.noNewData'),ht(locale,'host.retryTip')].filter(Boolean).join(' · ');
   line.append(button);foot.append(line);page.append(foot);
  }
  // The overview draws its own totals row, "since" label and empty state (WP-12); the deck adds nothing to them.
  // D-D: the totals are this device's records; the totals row carries that as its hover note (it has no room for a label).
  if(selected===0&&d.daily.length){const top=page.querySelector<HTMLElement>('.ov-top');if(top)top.dataset.tip=ht(locale,'host.onThisMac');}
  // D63: the subscription usage block says where a shorter local record starts.
  const since=recordStart();
  if(since!==null&&selected===1)for(const stats of page.querySelectorAll<HTMLElement>('.sp-stats[data-days]')){const days=Number(stats.dataset.days),head=stats.querySelector('.stat-h');if(head&&Number.isFinite(days)&&since>dayStart(d.now,days-1))head.textContent+=' · '+t('mfd.since',{d:md(since,{lang:locale})});}
  // G3-109: a subscription with a balance but no usage percentage (Grok Build on the X Subscription, D228) has no
  // chart; its Overview shows the balance and why there is no percentage instead of an empty "Quota only". Recorded
  // token history (macrev2-925-1) keeps its totals and chart: the balance then follows the totals instead of the empty state.
  if(selected===0&&selectedId){const entry=d.members[Number(selectedId.slice('member'.length))],balance=entry?balanceOnly(entry.account):null;
   if(entry&&balance!==null){const block=node('div','ov-bal'),note=node('p','ov-bal-note',t(entry.row.id==='grok'?'mfd.balanceOnlyX':'mfd.balanceOnly'));block.append(node('span','lbl',t('mfd.balance')),node('b','',balance));
    const empty=page.querySelector('.mp-empty'),anchor=page.querySelector('.ov-top')??page.querySelector('.mfd-alerts')??page.querySelector('.mfd-back');
    if(empty)empty.replaceWith(block,note);else if(anchor)anchor.after(block,note);else page.prepend(block,note);}}
  // Study list IDs are positional; attach the originating member identity for focus restoration.
  for(const el of page.querySelectorAll<HTMLElement>('[data-mfd^="scope:member"]')){const match=/^scope:member(\d+)$/.exec(el.dataset.mfd??'');const member=match?d.members[Number(match[1])]:null;if(member){el.dataset.focusMember=member.key;}}
  // 30-day history and the full session list are unavailable, not zero.
  if(selected===1&&uiSubTab==='hist')for(const e of page.querySelectorAll<HTMLElement>('.mp-empty.sm'))e.textContent=ht(locale,'host.dataUnavailable');
  if(selected===1&&!subId)for(const [i,e] of [...page.querySelectorAll<HTMLElement>('.sa-list .sa')].entries())if(d.members[i]?.account.valueState==='retained')e.append(node('span','mfd-stale',ht(locale,'host.lastKnownReading')));
  if(selected===2)for(const e of page.querySelectorAll<HTMLElement>('.mp-empty:not(.period)'))e.textContent=ht(locale,'host.dataUnavailable');
  // Projects are not reported yet; the 时间 list is empty for a period only when last-seen sessions are admitted.
  if(selected===3&&!(uiWhere==='time'?data?.details?.sessionCoverage==='local-last-seen':data?.history?.coverage==='local-history'))for(const e of page.querySelectorAll<HTMLElement>('.mp-empty'))e.textContent=ht(locale,'host.dataUnavailable');
  // WP-13: the Models and Breakdown rows' share bars and colour chips; the page CSP drops inline style attributes, so they are set through CSSOM.
  for(const e of page.querySelectorAll<HTMLElement>('[data-p]'))e.style.setProperty('--p',e.dataset.p+'%');for(const e of page.querySelectorAll<HTMLElement>('i.chip[data-v]'))e.style.setProperty('--v',e.dataset.v!);
  if(selected===3)for(const b of page.querySelectorAll<HTMLElement>('.ws[data-mfd^="session:"]')){const x=d.sessionRanking.find((s:{ref:string})=>'session:'+s.ref===b.dataset.mfd) as {sub:string|null}|undefined,a=x?.sub?d.accounts.find(a=>a.id===x.sub):null;b.querySelector<HTMLElement>('.chip')?.style.setProperty('--v',a?.colour??'#c6ccd4');}
  if(selected===1&&subId){const index=Number(subId.slice('member'.length)),entry=d.members[index];if(!entry?.account.observedAt){const source=page.querySelector<HTMLElement>('.sp-sub .src');if(source)source.textContent=ht(locale,'host.readingTimeUnknown');}}
  // The cycle chart's vendor colour (--cv) sits in an inline style the page CSP drops; apply it through CSSOM.
  for(const e of page.querySelectorAll<SVGElement>('svg.cy-chart[style]')){const m=/--cv:\s*(#[0-9a-f]{3,8})/i.exec(e.getAttribute('style')??'');e.removeAttribute('style');if(m)e.style.setProperty('--cv',m[1]!);}
  // Reset-card facts are personal observations, joined only by a verified reference.
  if(selected===1&&subId&&uiSubTab==='now'){const index=Number(subId.slice('member'.length)),entry=d.members[index],ref=entry?.account.subscriptionRef,verified=ref!=null&&data?.subscriptions.some(s=>s.subscriptionRef===ref),matches=verified?data?.details?.subscriptions.filter(s=>s.subscriptionRef===ref)??[]:[],cards=matches.length===1?matches[0].resetCards:null;if(cards&&cards.state!=='unknown'){const items=(cards.items??[]).flatMap(item=>item.expiresAt&&Number.isFinite(Date.parse(item.expiresAt))?[Date.parse(item.expiresAt)]:[]).sort((a,b)=>a-b),line=node('div','rc'),expiries=node('span','rc-exp');line.append(node('span','lbl',t('mfd.cards')),node('b','',cards.count===null?'--':t('mfd.cardsN',{n:cards.count})));for(const [i,time] of items.slice(0,4).entries()){if(i)expiries.append(node('s','','·'));expiries.append(node('i','',until(time,{now:d.now,lang:locale})));}if(items.length>4)expiries.append(node('i','more','+'+(items.length-4)));line.append(expiries);if(items.length)line.title=items.map(time=>relativeMoment(time,{now:d.now,lang:locale},true)).join('\n');page.append(line);}}
  // The prototype's credits chart assumes 30-day history. Show only an
  // actual reported balance instead of fabricating that history or a zero.
  if(selected===1&&subId&&uiSubTab==='now'){const index=Number(subId.slice('member'.length)),entry=d.members[index],credits=entry?prototypeEngineSupplement(entry.account,data??undefined).reserveCredits:null;if(credits?.balance!==null&&credits?.balance!==undefined&&['credits','points'].includes(credits.unit)){const line=node('div','cr-l');line.append(node('span','lbl',ht(locale,'host.creditsLabel')),node('b','cr-bal',formatCredits(credits.balance,locale)));const ref=entry?.account.subscriptionRef,verified=ref!=null&&data?.subscriptions.some(s=>s.subscriptionRef===ref),matches=verified?data?.details?.subscriptions.filter(s=>s.subscriptionRef===ref)??[]:[],observed=matches.length===1?matches[0].credits?.observedAt:null;line.append(node('em','',observed&&Number.isFinite(Date.parse(observed))?t('mfd.creditsRead',{t:relativeMoment(Date.parse(observed),{now:d.now,lang:locale})}):ht(locale,'host.readingTimeUnknown')));page.append(line);
   // The study's 30 daily credit bars need a daily credits history no reader reports yet: the total stays unknown, never a zero or a drawn bar.
   const daily=node('div','cr-l sub cr-30-unknown');daily.append(node('span','lbl'),node('em','',t('mfd.credits30',{n:'--'})));page.append(daily);}}
  footer.replaceChildren();const raw=d.empty?[]:(modules[selected].optionKeys?.(ui,d)??[]);for(let i=0;i<3;i++){const item=raw[i] as {id:string;items?:{value:string|number;text:string;on:boolean}[];a?:{value:string|number;text:string;on:boolean};b?:{value:string|number;text:string;on:boolean}}|null|undefined;if(!item){const e=node('span','ok soft off');e.dataset.mat='part';e.setAttribute('aria-hidden','true');footer.append(e);continue;}const b=node('button','ok soft'),label=node('span','ok-l'),choices=item.items??[item.a!,item.b!];b.type='button';b.dataset.mfd='opt:'+item.id;b.dataset.opt=item.id;b.dataset.mat='part';b.setAttribute('aria-label',choices.map(x=>x.text).join(' | ')+': '+(choices.find(x=>x.on)?.text??''));choices.forEach((x,j)=>{if(j){const sep=node('i','ok-sep');sep.setAttribute('aria-hidden','true');label.append(sep);}const choice=node('b',x.on?'on':'',x.text);choice.dataset.choice=String(x.value);label.append(choice);});b.append(label);b.onclick=e=>{if(!e.isTrusted)return;const v=(e.target as HTMLElement).closest<HTMLElement>('[data-choice]')?.dataset.choice;if(item.id==='where')uiWhere=v??(uiWhere==='time'?'proj':'time');else if(item.id==='models')uiModels=v==='chart'?'chart':v==='list'?'list':uiModels==='chart'?'list':'chart';else if(item.id==='range'){/* CKP-SHELL-50: the app owns the range; the key asks for it (onRange shows it at once). */const next=isCockpitRange(v)?v:nextCockpitRange(rangeNow());if(onRange?onRange(next):true)uiRangeLocal=next;}else if(item.id==='chart')uiChart=v==='grid'?'grid':'bars';else if(item.id==='stack')uiStack=v?v==='stack':!uiStack;else if(item.id==='tab')uiSubTab=v??(uiSubTab==='hist'?'now':'hist');else if(item.id==='cycle'){const other=choices.find(x=>!x.on);uiCycle=v??(other?String(other.value):uiCycle);}paint();};footer.append(b);}
  page.onclick=e=>{const target=e.target as HTMLElement;if(target.closest('a')){e.preventDefault();return;}{const refresh=target.closest<HTMLButtonElement>('button[data-refresh]');if(refresh){if(e.isTrusted)onRefresh(refresh.dataset.refresh||'all');return;}}if(e.isTrusted&&target.closest('[data-mfd="back"]')){closeTune();return;}if(e.isTrusted&&target.closest('[data-mfd="alerts"]')){alertsView={from:'mfd'};paint();return;}const row=target.closest<HTMLElement>('[data-mfd^="model:"]');if(e.isTrusted&&row?.dataset.model){listPick=row.dataset.model;selectedModel=listPick;paint();return;}const b=target.closest<HTMLElement>('[data-mfd^="scope:"]');if(!e.isTrusted||!b)return;const index=Number((b.dataset.mfd??'').slice('scope:member'.length));const m=d.members[index];if(m&&onScope?.(m.key)){setScope(m.key);paint();}};
 }
 // The comparison card on the screen and its own bottom keys (mfd.js screen/renderMfd with VIEWS.compare).
 function paintCompare(d:ReturnType<typeof publicData>,ui:Record<string,unknown>){
  const f=faderInput().faders.find(x=>x.id===compare!.modelId);if(!f){compare=null;return false;}
  // Audit F 2/5: current and Fast are the session's as reported in this delivery (only the trial is the user's), and the
  // website link names the published model, not the fader's position.
  compare=refreshComparison(compare!,f);
  const fast=compareSpeedTiers(f,f.tier),{model,args:input}=comparisonInput(f,compare,fast.pool),view={models:[model],speedTiers:fast.speedTiers,sessionRanking:[],accounts:[],now:d.now};
  const args:CompareArgs=input;
  const back=t(pages[selected]!.module.title),draw=()=>{page.innerHTML=comparison(view,{...ui,scope:null,trialNote:true,compact:root.dataset.layout==='640',starMode:root.dataset.starMode||undefined,laneMode:root.dataset.laneMode||undefined,fill:cmpFill?{cmp:cmpFill}:{}},args);};
  bar.classList.add('dark');for(const {b} of buttons){b.classList.remove('on');b.setAttribute('aria-pressed','false');}
  // CSP (style-src 'self') drops the key block's inline geometry (the ladder and the numbers under it inherit it); apply it through CSSOM after every draw.
  const ladder=()=>{for(const e of page.querySelectorAll<HTMLElement>('.cmp-keys[style]')){const css=e.getAttribute('style')??'';e.removeAttribute('style');for(const m of css.matchAll(/(--c[lr]):(\d+(?:\.\d+)?px)/g))e.style.setProperty(m[1]!,m[2]!);}};
  page.className='mfd-page pg-compare is-view own-title';draw();
  // The chart is drawn at its measured size (mfd.js renderMfd), again once if that size changed.
  const measure=()=>{const area=page.querySelector<HTMLElement>('[data-fill="cmp"]');return area?{w:Math.floor(area.clientWidth),h:Math.floor(area.clientHeight)}:null;};
  let size=measure();
  if(size&&size.w>0&&size.h>0&&(cmpFill?.w!==size.w||cmpFill?.h!==size.h)){cmpFill=size;draw();}
  ladder();
  // Build 14c: a fill measured at zero (the screen not laid out yet, e.g. the first paint after a fader trial) left the
  // chart out for good. Watch the page's size (no timers: bundle rule) and draw the chart once the fill has a size, if
  // the same comparison is still shown.
  cmpWatch?.disconnect();cmpWatch=null;
  if((!size||!size.w||!size.h)&&typeof ResizeObserver!=='undefined'){const shown=compare,watch=new ResizeObserver(()=>{
    if(compare!==shown||!page.classList.contains('pg-compare')){watch.disconnect();if(cmpWatch===watch)cmpWatch=null;return;}
    const next=measure();if(!next||!next.w||!next.h)return;watch.disconnect();if(cmpWatch===watch)cmpWatch=null;
    if(cmpFill?.w!==next.w||cmpFill?.h!==next.h){cmpFill=next;draw();ladder();}});
   cmpWatch=watch;watch.observe(page);}
  const keys=document.createElement('template');keys.innerHTML=compareKeys(view,ui,args,{back});
  footer.className='mfd-ok mfd-vk';footer.replaceChildren(...(keys.content.firstElementChild?.childNodes??[]));
  footer.onclick=e=>{if(!e.isTrusted)return;const key=(e.target as Element).closest<HTMLElement>('[data-mfd]');if(!key)return;
   if(key.dataset.mfd==='back'){closeCompare();return;}
   const next=compareView.onClick('fast','',ui,view,args);if(next&&compare){compare={...compare,fast:next.trial.fast!};paint();}};
  // The bars, the chart and the effort keys are linked: the pointer on an effort (data-hover) previews it everywhere; on an
  // Ability / Cost row (data-hk) it sets that chart line apart. Pure marking: nothing is tried, the page is not redrawn.
  const hover=(effort:string|null,row:string|null)=>{if(row)page.dataset.hk=row;else delete page.dataset.hk;for(const el of page.querySelectorAll<SVGElement>('.pc-preview,.pc-band-hover'))el.classList.toggle('hot',effort!==null&&el.dataset.effort===effort);};
  page.onpointerover=e=>{if(e.pointerType==='touch')return;const target=e.target as Element;hover(target.closest<HTMLElement>('[data-hover]')?.dataset.hover??null,target.closest<HTMLElement>('[data-hk]')?.dataset.hk??null);};
  page.onpointerleave=e=>{if(e.pointerType!=='touch')hover(null,null);};
  page.onclick=e=>{const target=e.target as HTMLElement;if(target.closest('a')){e.preventDefault();return;}const key=target.closest<HTMLElement>('[data-mfd^="try:"]');if(!e.isTrusted||!key||!compare)return;
   const level=(key.dataset.mfd??'').slice(4),c={id:compare.modelId,current:compare.current,base:compare.current??f.rec,currentFast:compare.currentFast};tryEffort(c,level);};
  return true;
 }
 function closeTune(){if(returnPage===null)return false;selected=returnPage;returnPage=null;tuneModel=null;paint();return true;}
 function closeAlerts(){if(!alertsView)return false;const focus=mfd.contains(document.activeElement);alertsView=null;paint();if(focus)buttons[selected]?.b.focus({preventScroll:true});return true;}
 const escape=(e:KeyboardEvent)=>{if(e.isTrusted&&e.key==='Escape'&&!e.altKey&&(alertsView?closeAlerts():compare?cancelTrial()||closeCompare():closeTune()))e.preventDefault();};window.addEventListener('keydown',escape);
 // CKP-FAD-15: [ and ] page the fader banks, as the ◀ ▶ keys do.
 const bankKeys=(e:KeyboardEvent)=>{if(!e.isTrusted||e.altKey||e.ctrlKey||e.metaKey||e.repeat||(e.key!=='['&&e.key!==']'))return;const target=e.target;if(target instanceof Element&&target.closest('input,textarea,select,[contenteditable]:not([contenteditable="false"])'))return;if(!bank.querySelector('[data-bank]'))return;e.preventDefault();bankIndex+=e.key===']'?1:-1;paintFaders();};window.addEventListener('keydown',bankKeys);
 // Audit F 1: fader ids are positions in the adapter's order, which a delivery can change (models in use lead). The
 // selection, the open comparison and the trial's ghost follow the published model they named, or end with it.
 // macrevb-1062-3 r2/r3: an explicit selection from the enlarged field shows the selected fader's bank, because the
 // renderer resolves the shared effort controls on the visible bank only. Only that event moves the bank: data refreshes,
 // local trials, record lines and manual paging never do (CKP-FAD-09). A clear, or a model without a fader here, keeps it.
 function showSelectedBank(){const at=selectedModel===null?-1:faderInput().faders.findIndex(f=>f.id===selectedModel);if(at>=0)bankIndex=Math.floor(at/BANK_SIZE);}
 function publishedOrder(){const input=record(details.publication);return Array.isArray(input?.faders)?input.faders.slice(0,100).map(v=>safeText(record(v)?.id)):[];}
 function carryOver(before:readonly string[]){
  const move=positionalRemap(before,publishedOrder()),moved:Record<string,string>={};
  for(const [id,level] of Object.entries(previews)){const to=move(id);if(to)moved[to]=level;}previews=moved;
  if(selectedModel!==null)selectedModel=move(selectedModel);
  if(compare){const to=move(compare.modelId);compare=to?{...compare,modelId:to}:null;}
 }
 // G3-110 / study cockpit.js setScope: a new scope starts at bank 1 and ends a comparison whose fader left the scope.
 function setScope(value:string){if(value===scope)return;scope=value;bankIndex=0;if(compare&&!faderInput().faders.some(f=>f.id===compare!.modelId)){delete previews[compare.modelId];compare=null;}}
 // CKP-STRIP-15: a record line names a session; the publication says which fader carries it.
 function sessionModel(ref:string){const input=record(details.publication);if(!input||!Array.isArray(input.faders))return null;const i=input.faders.slice(0,100).findIndex(v=>{const sessions=record(v)?.sessions;return Array.isArray(sessions)&&sessions.some(x=>record(x)?.ref===ref);});if(i<0)return null;const id='model'+i;/* D123 cap: a model dropped from the row has no fader to select */return faderInput().faders.some(f=>f.id===id)?id:null;}
 paint();return {
  /** Recovery contract: the deck's own render state, restored with the view after a refused render (glm-990-1). */
  checkpoint(){const held=new Map(heldCurrent),saved={details,publicationKey,scope,data,renderedNow,compare,bankIndex,selectedModel,selected,alertsView,returnPage,tuneModel,previews:{...previews},press};return ()=>{({details,publicationKey,scope,data,renderedNow,compare,bankIndex,selectedModel,selected,alertsView,returnPage,tuneModel,press}=saved);previews={...saved.previews};heldCurrent.clear();for(const [k,v] of held)heldCurrent.set(k,v);};},
  restorePins(ids:readonly string[]){pins=[...new Set(ids)].slice(0,64);unpinned.clear();if(data)this.render(data,renderedNow);},showAllModels(value:boolean){if(showAllModels===value)return;showAllModels=value;if(data)this.render(data,renderedNow);},/** WP-22 (macrevb-1062-3): the enlarged field's selection, by public model id; a model without a fader here, or null, selects none. */selectModel(id:string|null){selectedModel=id===null?null:faderInput().faders.find(f=>f.sourceId===id)?.id??null;showSelectedBank();paint();},showTune(id:string){const tune=modules.findIndex(m=>m.id==='tune');if(tune<0)return;if(compare){delete previews[compare.modelId];compare=null;}alertsView=null;if(returnPage===null)returnPage=selected;selected=tune;tuneModel=id;listPick=null;uiModels='chart';paint();},knowsSession(ref:string){return sessionModel(ref)!==null;},highlightSession(ref:string|null){const id=ref?sessionModel(ref):null;for(const ch of channels.querySelectorAll<HTMLElement>('.fd-ch'))ch.classList.toggle('xhl',!!id&&ch.dataset.model===id);},showWhere(){const at=modules.findIndex(m=>m.id==='where');if(at<0)return;if(compare){delete previews[compare.modelId];compare=null;}selected=at;alertsView=null;paint();},sessionSelected(ref:string){const id=sessionModel(ref);return id!==null&&selectedModel===id;},clearSession(){selectedModel=null;if(compare){delete previews[compare.modelId];compare=null;}paint();},selectSession(ref:string){const id=sessionModel(ref);if(compare){delete previews[compare.modelId];compare=null;}if(id)selectedModel=id;const at=modules.findIndex(m=>m.id==='where');if(at>=0){selected=at;uiWhere='time';}alertsView=null;paint();},alertsOpen:()=>alertsView?.from==='caution',showAlerts(mark?:string|null){if(alertsView?.from==='caution'){closeAlerts();return false;}alertsView={from:'caution',mark:mark??null,flash:mark!=null};paint();return true;},refresh(now?:number){paint(true,now);},locale(value:Locale,now?:number){locale=value;paint(false,now);},render(value:WireCockpitData,now:number){press=null;
 // D391 (owner 11-22): a subscription unticked in Settings has no card, so its sessions add no models to any view
 // (faders, cards, All) — the D123/D135 live-use inclusion is gone. The unfiltered sessions still feed the record strip.
 const admitted=(x:{readonly source:string;readonly subscriptionRef:string|null})=>sessionAdmittedBy(cockpitMembers(value),x),binding=sessionMembers(value),bound=(value.details?.sessions??[]).filter(admitted).map(x=>({...x,subscriptionRef:binding.get(x.sessionRef)??null})),recorded=(value.details?.recentSessions??[]).filter(admitted);renderedNow=now;data=value;const publication=value.details?.publication;const nextKey=publication?JSON.stringify([publication.publicationId,publication.models.map(m=>m.id)]):null,before=publishedOrder();if(!fixturePublication&&nextKey!==publicationKey){previews={};selectedModel=null;bankIndex=0;compare=null;}publicationKey=nextKey;details={...details,publication:fixturePublication?details.publication:publication==null?null:(subscriptions=>publicationFaders(publication,bound,moreFaderModels(value,subscriptions,bound,recorded),subscriptions,{now,ownPlansOnly:!showAllModels,recorded,usage:historyUsage(value.history)}))((members=>{const palette=memberColours(members);return members.map(m=>({key:m.key,developer:toolDevelopers[m.row.id]??null,colour:palette.get(m.key)!}));})(cockpitMembers(value))),liveSessions:value.details?bound:null,resetEvents:value.details?.resetEvents??null};carryOver(before);root.dataset.detailsAvailable=String(value.details!=null);paint();},scope(value:string){setScope(value);paint();},range(value:CockpitRange){uiRangeLocal=value;if(painted===rangeNow()&&painted===value)return;paint();},cancelPress(){press=null;suppressClick=false;},clear(){hideTip();listPick=null;publicationKey=null;press=null;drag=null;unpinned.clear();suppressClick=false;data=null;root.dataset.detailsAvailable='false';details=unavailablePrototypeDetailsFixture();bankIndex=0;selectedModel=null;previews={};scope='all';selected=0;alertsView=null;returnPage=null;tuneModel=null;compare=null;paint();},dispose(){publicationKey=null;press=null;drag=null;pins=[];unpinned.clear();suppressClick=false;window.removeEventListener('keydown',escape);window.removeEventListener('keydown',bankKeys);alertsView=null;compare=null;returnPage=null;tuneModel=null;data=null;root.dataset.detailsAvailable='false';details=unavailablePrototypeDetailsFixture();bankIndex=0;selectedModel=null;previews={};scope='all';selected=0;paint();for(const {b} of buttons)b.onclick=null;page.onclick=null;screen.onpointerover=null;screen.onpointerleave=null;hideTip();}};
}

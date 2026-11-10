// SPDX-License-Identifier: MIT
// Study fader/MFD hierarchy, with escaped renderer fields and bounded identifiers.
// Publication and session facts come from admitted cockpit details; unknown
// inputs stay unavailable, with synthetic values confined to test fixtures.
import {unavailablePrototypeDetailsFixture,type PrototypeDetailsFixture} from './prototype-details-fixture-adapter.js';
import {effectiveRedBelow} from './threshold.js';
import {beginFaderPress,endFaderPress} from './fader-press.js';
import {publicationFaders} from './publication-faders.js';
import type {WireCockpitData,WireAccount,WireRow} from '../generated/wire.js';
import {cockpitMembers} from './members.js';
import {sessionMember,sessionMembers,memberColour,toolDevelopers,vendorPalette} from './session-binding.js';
import {cautionItems} from './caution.js';
import {prototypeEngineSupplement,currentWindow,displayWindow,scopedWindow,runOutMinutes,runOutFields,forecastOf} from './prototype-data-adapter.js';
import {historyView,resetHistory,usageStats} from './prototype-history.js';
import {publishedFleet} from './prototype-hud.js';
import {scaleView,levelK,bankView,faderModel,lcdView,indicatorView,marksView,stripAria} from '../study/rocket-r1/fader-view.js';
import {setLanguage,t,formatCredits} from '../study/rocket-r1/i18n.js';
import {overview} from '../study/rocket-r1/mfd-pages/overview.js';
import {plans} from '../study/rocket-r1/mfd-pages/plans.js';
import {relativeMoment,tok,until,md} from '../study/rocket-r1/mfd-pages/fmt.js';
import {tune} from '../study/rocket-r1/mfd-pages/tune.js';
import {where} from '../study/rocket-r1/mfd-pages/where.js';
import {shortLabel} from '../study/rocket-r1/short-label.js';
import {compareSpeedTiers} from './speed-tiers.js';
import {comparison,compareKeys,compareView,type CompareArgs} from '../study/rocket-r1/mfd-pages/views.js';
import '../study/rocket-r1/strings/mfd.js';
type Locale='en'|'zh-CN';
const node=<K extends keyof HTMLElementTagNameMap>(tag:K,cls?:string,text?:string):HTMLElementTagNameMap[K]=>{const e=document.createElement(tag);if(cls)e.className=cls;if(text!==undefined)e.textContent=text;return e;};
const cockpitPageRegistry=Object.freeze([Object.freeze({module:overview,en:'Overview',zh:'总览'}),Object.freeze({module:plans,en:'Subscription',zh:'订阅'}),Object.freeze({module:tune,en:'Effort',zh:'档位'}),Object.freeze({module:where,en:'Breakdown',zh:'去向'})]);
export const cockpitPageIds=Object.freeze(cockpitPageRegistry.map(p=>p.module.id));
export function mountPrototypeDeck(root:HTMLElement,onScope?:(key:string)=>boolean,fixture:PrototypeDetailsFixture=unavailablePrototypeDetailsFixture(),redBelow:()=>number=()=>effectiveRedBelow(undefined)){
 const scale=root.querySelector<HTMLElement>('.fd-scale')!,channels=root.querySelector<HTMLElement>('.fd-chs')!,mfd=root.querySelector<HTMLElement>('.dk-mfd')!;
 let details=fixture;const fixturePublication=fixture.publication!==null;fixture=unavailablePrototypeDetailsFixture();
 let publicationKey:string|null=null;
 let locale:Locale='en',selected=0,scope='all',data:WireCockpitData|null=null,renderedNow=0;
 // Prototype mfd.js:39-58,75 (openMfdView/closeMfdView): the full alert list is a view over the current page, opened by the
 // ALERT lamp or the overview's "+N" line, closed by "‹ Back to <page>", Esc, a page key or a second lamp press.
 let alertsView:{from:'caution'|'mfd';mark?:string|null;flash?:boolean}|null=null,returnPage:number|null=null,tuneModel:string|null=null;
 // The study's comparison view (mfd.js openComparison, views.js round D1): a fader trial shows "Compare · <model>" over
 // the current page, whose key goes dark; ‹ back, Esc, a page key or the same source again returns. One trial at a time.
 let compare:{modelId:string;current:string|null;trial?:string;fast?:boolean;currentFast:boolean}|null=null,cmpFill:{w:number;h:number}|null=null;root.dataset.detailsAvailable=String(details.liveSessions!==null);
 // The study controller's fixed three-channel skeleton. No fixture data is
 // bundled; absent publication and session capabilities leave all bays empty, and the bank row says so.
 const skeleton=(i:number)=>`<div class="fd-ch empty" data-slot="${i}"><div class="fd-leds"></div><button class="fd-strip" data-mat="well" tabindex="-1"></button>
  <div class="fd-travel" role="slider" aria-orientation="vertical" aria-valuemin="0" aria-valuemax="4" tabindex="-1"><span class="fd-slot"></span><span class="fd-marks"></span><span class="fd-peek"></span><span class="fd-ghost" data-mat="part" hidden></span><span class="fd-cap" data-mat="part" hidden></span></div></div>`;
 channels.innerHTML=Array.from({length:3},(_,i)=>skeleton(i)).join('');
 for(const b of channels.querySelectorAll<HTMLButtonElement>('.fd-strip'))b.disabled=true;
 const bank=root.querySelector<HTMLElement>('.fd-bank')!;bank.innerHTML=bankView({bank:0,banks:1});
 const ladder=['Low','Med','High','XHigh','Max'] as const;let bankIndex=0,selectedModel:string|null=null,previews:Record<string,string>={};
 let pins:string[]=[],unpinned=new Set<string>(),press:{pointer:number;started:number;sourceId:string;pinned:boolean}|null=null,suppressClick=false;
 const record=(v:unknown):Record<string,unknown>|null=>v!==null&&typeof v==='object'&&!Array.isArray(v)?v as Record<string,unknown>:null;
 const safeText=(v:unknown)=>typeof v==='string'?v.slice(0,200):'';
 const effort=(v:unknown):string|null=>{if(typeof v!=='string')return null;const aliases:Readonly<Record<string,string>>={low:'Low',med:'Med',medium:'Med',high:'High',xhigh:'XHigh',max:'Max'};return aliases[v.toLowerCase()]??null;};
 const number=(v:unknown)=>typeof v==='number'&&Number.isFinite(v)&&v>=0&&v<=1e12?v:null;
 // Only a supplied publication and observed live-session input can populate
 // channels; this adapter never creates models or fills unknown readings.
 function faderInput(){
  const input=record(details.publication);if(!input||!Array.isArray(input.faders)||!Array.isArray(input.accounts))return {accounts:[],faders:[]};
  const accountIds=new Map<string,string>();const accounts=input.accounts.slice(0,100).flatMap((v,i)=>{const a=record(v);if(!a||typeof a.id!=='string')return [];const id='a'+i;accountIds.set(a.id,id);return [{id,colour:typeof a.colour==='string'&&/^#[a-f0-9]{6}$/i.test(a.colour)?a.colour:null}];});
  const faders=input.faders.slice(0,100).flatMap((v,i)=>{const f=record(v),rec=effort(f?.rec);if(!f||!rec||!Array.isArray(f.e))return [];const rows=f.e.slice(0,5).flatMap(v=>{if(!Array.isArray(v))return [];const label=effort(v[0]),ability=number(v[1]),cost=number(v[2]);return !label?[]:[[label,ability,cost,number(v[3])]];});if(!rows.some(r=>r[0]===rec))return [];
   const live=Array.isArray(details.liveSessions)?details.liveSessions.slice(0,500).flatMap(v=>{const x=record(v),ref=x&&(typeof x.sessionRef==='string'?x.sessionRef:typeof x.ref==='string'?x.ref:null);return x&&ref?[{ref,value:x}]:[]}):[];
   const sessions=Array.isArray(f.sessions)?f.sessions.slice(0,6).flatMap(v=>{const x=record(v),match=x&&typeof x.ref==='string'?live.find(y=>y.ref===x.ref):null;if(!x||!match)return [];const observed=match.value,bound=typeof x.sub==='string'&&typeof observed.subscriptionRef==='string'&&x.sub===observed.subscriptionRef&&accountIds.has(x.sub);return [{sub:bound?accountIds.get(x.sub as string)??'':'',account:bound?safeText(x.account):'',tool:safeText(observed.tool||observed.source),project:safeText(observed.projectLabel||observed.project),effort:effort(observed.effort),fast:typeof observed.fast==='boolean'?observed.fast:null,lastObservedAt:typeof observed.lastObservedAt==='string'?observed.lastObservedAt:typeof observed.lastAt==='string'?observed.lastAt:null,running:false,startedMin:null,endedMin:null}];}):[];
   const current=sessions[0]?.effort??null,fast=sessions[0]?.fast??null,tier=record(f.tier),speed=number(tier?.speed),cost=number(tier?.cost),harness=safeText(tier?.harness),otherEntries:Record<string,number>={};for(const x of sessions.slice(1))if(x.effort)otherEntries[x.effort]=(otherEntries[x.effort]??0)+1;
   const links=Array.isArray(f.accounts)?f.accounts.flatMap(v=>typeof v==='string'&&accountIds.has(v)?[accountIds.get(v)!]:[]):[];
   return [{id:'model'+i,sourceId:safeText(f.id),name:safeText(f.name)||safeText(f.short),short:safeText(f.name)?shortLabel(safeText(f.name)):safeText(f.short),rec,e:rows,pinned:pins.includes(safeText(f.id))||(f.pinned===true&&!unpinned.has(safeText(f.id))),live:sessions.length>0,current,currentFast:fast===true,others:otherEntries,tier:speed!==null&&harness?{harness,speed,cost,...(tier?.taskTimeUnknown===true?{taskTimeUnknown:true as const}:{})}:null,accounts:links,sessions}];});const rank=new Map(pins.map((id,i)=>[id,i]));faders.sort((a,b)=>(rank.get(a.sourceId)??Infinity)-(rank.get(b.sourceId)??Infinity));return {accounts,faders};
 }
 type Channel={id:string;current:string|null;base:string;currentFast:boolean};
 function openCompare(c:Channel,trial?:string,fast?:boolean){
  for(const id of Object.keys(previews))if(id!==c.id)delete previews[id];
  compare={modelId:c.id,current:c.current??null,...(trial?{trial}:{}),...(fast!==undefined?{fast}:{}),currentFast:!!c.currentFast};
  if(trial&&trial!==c.current)previews[c.id]=trial;else delete previews[c.id];
  selectedModel=c.id;alertsView=null;paint();
 }
 function closeCompare(){if(!compare)return false;delete previews[compare.modelId];compare=null;paint();return true;}
 // faders.js tryEffort / pressLevel / pressStrip.
 function tryEffort(c:Channel,level:string){openCompare(c,level,compare?.modelId===c.id?compare.fast:undefined);}
 function pressLevel(c:Channel,level:string){if(compare?.modelId===c.id&&level===(previews[c.id]??c.base))closeCompare();else tryEffort(c,level);}
 function pressStrip(c:Channel){if(compare?.modelId===c.id)closeCompare();else openCompare(c,previews[c.id]??c.current??undefined);}
 function paintScale(){setLanguage(locale);scale.innerHTML=scaleView();for(const b of scale.querySelectorAll<HTMLButtonElement>('.sc-l')){b.disabled=true;b.classList.add('na');b.style.setProperty('--k',String(levelK(b.dataset.level??'')));}}
 function paintFaders(){
  const data=faderInput(),input=record(details.publication),requested=selectedModel??safeText(input?.selectedModel),target=data.faders.find(f=>f.id===requested||f.sourceId===requested)?.id??null,ui={bank:bankIndex,bankSize:3,selModel:target,previews,view:compare?{modelId:compare.modelId,trial:compare.trial,fast:compare.fast??null,from:'fader',key:compare.modelId}:null,phase:'open',reduced:true},model=faderModel(data,ui);bankIndex=model.bank;
  const targetChannel=model.all.find((c:{id:string})=>c.id===model.target);
  for(const b of scale.querySelectorAll<HTMLButtonElement>('.sc-l')){const level=b.dataset.level??'',allowed=!!targetChannel&&targetChannel.levels.includes(level);b.disabled=false;b.classList.toggle('na',!allowed);b.onclick=e=>{if(!e.isTrusted||!allowed)return;pressLevel(targetChannel,level);};}
  for(const [i,ch] of [...channels.querySelectorAll<HTMLElement>('.fd-ch')].entries()){
   const c=model.channels[i],strip=ch.querySelector<HTMLButtonElement>('.fd-strip')!,leds=ch.querySelector<HTMLElement>('.fd-leds')!,travel=ch.querySelector<HTMLElement>('.fd-travel')!,marks=ch.querySelector<HTMLElement>('.fd-marks')!,cap=ch.querySelector<HTMLElement>('.fd-cap')!;
   ch.className='fd-ch'+(c?'':' empty');ch.dataset.model=c?.id??'';if(c){ch.classList.toggle('sel',!!c.sel);ch.classList.toggle('trying',!!c.trial);ch.classList.toggle('src',c.src==='fader');}strip.disabled=!c;strip.tabIndex=c?0:-1;travel.tabIndex=c?0:-1;
   leds.innerHTML=c?indicatorView(c):'';if(c?.leds.length){const indicator=leds.querySelector<HTMLElement>('.fd-indicator'),times=c.leds.map((x:{lastObservedAt:string|null})=>x.lastObservedAt?Date.parse(x.lastObservedAt):NaN).filter(Number.isFinite),latest=times.length?new Date(Math.max(...times)).toLocaleString(locale):'';indicator?.setAttribute('aria-label',c.name+' · '+(locale==='en'?'Last reading':'最近读数')+(latest?' '+latest:''));}strip.innerHTML=c?lcdView(c):'';marks.innerHTML=c?marksView(c):'';cap.hidden=!c;
   if(!c){strip.removeAttribute('aria-label');strip.removeAttribute('data-strip');travel.removeAttribute('data-travel');strip.onclick=null;strip.onpointerdown=null;strip.onpointerup=null;strip.onpointercancel=null;strip.onlostpointercapture=null;travel.onkeydown=null;travel.onpointerdown=null;travel.removeAttribute('aria-valuenow');travel.removeAttribute('aria-valuetext');continue;}strip.dataset.strip=c.id;travel.dataset.travel=c.id;const shown=c.tEff||c.base;travel.setAttribute('aria-label',c.name);travel.setAttribute('aria-valuenow',String(ladder.indexOf(shown)));travel.setAttribute('aria-valuetext',shown);const ghost=ch.querySelector<HTMLElement>('.fd-ghost')!;ghost.hidden=c.ghostK==null;if(c.ghostK!=null)ghost.style.setProperty('--k',String(c.ghostK));travel.onkeydown=e=>{if(!e.isTrusted||!['ArrowUp','ArrowDown'].includes(e.key))return;e.preventDefault();const at=ladder.indexOf(shown),step=e.key==='ArrowUp'?1:-1;for(let n=at+step;n>=0&&n<ladder.length;n+=step)if(c.levels.includes(ladder[n])){selectedModel=c.id;tryEffort(c,ladder[n]);break;}};travel.onpointerdown=e=>{if(!e.isTrusted||e.button!==0)return;const r=travel.getBoundingClientRect(),k=Math.max(0,Math.min(1,(e.clientY-r.top)/Math.max(1,r.height))),levels=c.levels as string[];let best=levels[0],delta=Infinity;for(const level of levels){const d=Math.abs((4-ladder.indexOf(level as typeof ladder[number]))/4-k);if(d<delta){delta=d;best=level;}}selectedModel=c.id;tryEffort(c,best);};strip.onpointerdown=e=>{const sourceId=data.faders.find(f=>f.id===c.id)?.sourceId;if(!e.isTrusted||!e.isPrimary||e.button!==0||!sourceId||press)return;suppressClick=false;press=beginFaderPress(press,{pointer:e.pointerId,started:e.timeStamp,sourceId,pinned:!!c.pinned});strip.setPointerCapture(e.pointerId);};const release=(e:PointerEvent)=>{if(!e.isTrusted)return;const result=endFaderPress(press,e.pointerId,e.timeStamp,'up');press=result.active;const held=result.commit;if(!held)return;if(held.pinned){pins=pins.filter(id=>id!==held.sourceId);unpinned.add(held.sourceId);}else{pins=[held.sourceId,...pins.filter(id=>id!==held.sourceId)];unpinned.delete(held.sourceId);}suppressClick=true;bankIndex=0;paintFaders();};strip.onpointerup=release;strip.onpointercancel=e=>{if(!e.isTrusted)return;press=endFaderPress(press,e.pointerId,e.timeStamp,'cancel').active;};strip.onlostpointercapture=e=>{if(press?.pointer===e.pointerId)press=null;};strip.onclick=e=>{if(!e.isTrusted)return;if(suppressClick&&e.detail!==0){suppressClick=false;return;}suppressClick=false;selectedModel=c.id;pressStrip(c);};strip.setAttribute('aria-label',stripAria(c));cap.style.setProperty('--k',String(c.capK));
   for(const [j,el] of [...marks.querySelectorAll<HTMLElement>('.fd-tick')].entries())el.style.setProperty('--k',String(c.ticks[j]));const rec=marks.querySelector<HTMLElement>('.fd-rec');rec?.style.setProperty('--k',String(c.recK));for(const [j,el] of [...marks.querySelectorAll<HTMLElement>('.fd-dot')].entries())el.style.setProperty('--k',String(c.dots[j].k));
   for(const [j,el] of [...strip.querySelectorAll<HTMLElement>('.eb')].entries()){const b=c.bars[j];if(!b.none)el.style.setProperty('--h',(3+b.h*8).toFixed(1)+'px');}for(const [j,el] of [...strip.querySelectorAll<HTMLElement>('.st-vend b')].entries())el.style.setProperty('--v',c.segments[j]);
  }
  bank.innerHTML=bankView(model);if(!model.all.length)bank.append(node('p','mp-empty sm',locale==='en'?'Data unavailable':'暂无数据'));for(const b of bank.querySelectorAll<HTMLButtonElement>('[data-bank]'))b.onclick=e=>{if(!e.isTrusted)return;bankIndex+=b.dataset.bank==='1'?1:-1;paintFaders();};
 }

 const bar=node('div','mfd-pk'),screen=node('div','mfd-screen'),page=node('div','mfd-page pg-overview'),footer=node('div','mfd-ok');bar.setAttribute('role','toolbar');screen.dataset.mat='well';page.dataset.fill='page';screen.append(page);
 const pages=cockpitPageRegistry,modules=pages.map(p=>p.module);let uiWhere='proj',uiTime='today',uiDays=30,uiChart='bars',uiStack=true,uiSubTab='now',uiSubDays:7|30=7,uiCycle:string|null=null,gridFill:{w:number;h:number}|null=null;
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
 function publicData(now=renderedNow){
  const members=data?cockpitMembers(data):[],ids=new Map(members.map((m,i)=>[m.key,'member'+i]));
  // Owner build 13 / study fixtures: the Subscription page names the subscription ("ChatGPT Pro"), not the tool, and
  // shows its vendor mark; the reading age is whole minutes, "just now" under one.
  // Marks the bundle ships under assets/brands (build.mjs); a vendor without one shows no mark.
  const subscriptionMarks:Readonly<Record<string,string>>={openai:'openai-white.svg',claude:'claude-rounded.svg',glm:'zhipu.svg',kimi:'kimi-white.svg'};
  const product:Readonly<Record<string,string>>={openai:'ChatGPT',claude:'Claude'},planOf=(account:WireAccount)=>account.plan.name?(locale==='en'?account.plan.name.en:account.plan.name.zh):'';
  const titleOf=(row:WireRow,account:WireAccount)=>{const brand=row.vendorKey?product[row.vendorKey]:undefined,plan=planOf(account);return brand?[brand,plan].filter(Boolean).join(' '):locale==='en'?row.name.en:row.name.zh;};
  const ageOf=(account:WireAccount)=>{const at=account.observedAt?Date.parse(account.observedAt):NaN;if(!Number.isFinite(at))return null;const m=Math.round(Math.max(0,now-at)/60000);return m<1?null:m;};
  const accounts=members.map(({key,row,account})=>({id:ids.get(key)!,name:titleOf(row,account),short:locale==='en'?row.name.en:row.name.zh,plan:planOf(account),vendor:row.vendorKey&&Object.hasOwn(vendorPalette,row.vendorKey)?row.vendorKey:'unknown',colour:memberColour({row}),logo:row.vendorKey&&Object.hasOwn(subscriptionMarks,row.vendorKey)?subscriptionMarks[row.vendorKey]!:'',source:'native',state:account.valueState==='current'?'ok':account.valueState==='retained'?'stale':'loading',ageMin:ageOf(account),support:'quota-only',pool:null,windows:account.valueState==='none'?[]:account.windows.filter(w=>!scopedWindow(w)).map(w=>({kind:w.role==='session'?'5h':w.role==='weekly'?'week':w.role==='monthly'?'month':w.role==='daily'?'day':'other',label:locale==='en'?w.label.en:w.label.zh,remaining:displayWindow(account,w,now)?w.remainingPercent:null,resetIn:displayWindow(account,w,now)&&w.resetsAt&&Number.isFinite(Date.parse(w.resetsAt))&&Date.parse(w.resetsAt)>=now?(Date.parse(w.resetsAt)-now)/60000:null,resetAt:displayWindow(account,w,now)&&w.resetsAt&&Number.isFinite(Date.parse(w.resetsAt))?Date.parse(w.resetsAt):null,...runOutFields(runOutMinutes(data,row.id,account,w,now)),elapsed:null})),extras:account.valueState==='none'?[]:account.windows.filter(scopedWindow).map(w=>({kind:'other',label:locale==='en'?w.label.en:w.label.zh,remaining:displayWindow(account,w,now)?w.remainingPercent:null,resetIn:displayWindow(account,w,now)&&w.resetsAt&&Number.isFinite(Date.parse(w.resetsAt))&&Date.parse(w.resetsAt)>=now?(Date.parse(w.resetsAt)-now)/60000:null,resetAt:displayWindow(account,w,now)&&w.resetsAt&&Number.isFinite(Date.parse(w.resetsAt))?Date.parse(w.resetsAt):null,...runOutFields(runOutMinutes(data,row.id,account,w,now)),elapsed:null})),cards:[],credits:scope==='all'&&prototypeEngineSupplement(account,data??undefined).reserveCredits?.balance!=null&&['credits','points'].includes(prototypeEngineSupplement(account,data??undefined).reserveCredits?.unit??'')?{balance:prototypeEngineSupplement(account,data??undefined).reserveCredits!.balance,drawing:null}:null,todayTokens:prototypeEngineSupplement(account,data??undefined).todayTokens,forecast:forecastOf(account.windows.filter(w=>!scopedWindow(w)).map(w=>runOutFields(runOutMinutes(data,row.id,account,w,now)))),peak:null,resets:resetHistory(data,account.subscriptionRef,row.id,now),usageStats:usageStats(data,account.subscriptionRef)}));
  // Owner D38: urgency order, subscription and time left; resets and stale readings are list-only (blue).
  // The overview follows the selected scope; the full list (the global lamp's destination) never does.
  const allAlerts=data?cautionItems(data,now,redBelow()).map(x=>({member:x.member,level:x.level,stable:x.stable,text:locale==='en'?x.text.en:x.text.zh})):[];
  const alerts=allAlerts.filter(x=>scope==='all'||x.member===scope).map(({level,text})=>({level,text}));
  // Public model data for the frontier (owner D39/D-B): the shared selection for this scope, ten at most.
  const published=publishedFleet(data,scope,now);
  return {now,accounts,alerts,allAlerts,events:[],...historyView(data,ids,now,locale),sessionRanking:lastSeen(members,ids),models:published,lineup:[],selection:{scope:scope==='all'?null:ids.get(scope)??null,field:published},empty:accounts.length===0,ids,members};
 }
 // The first local day of the recorded history (cockpitHistoryV1 dailyFrom), as a local midnight.
 function recordStart(){const from=data?.history?.coverage==='local-history'?data.history.dailyFrom:null;if(!from||!/^\d{4}-\d{2}-\d{2}$/.test(from))return null;const [y,m,day]=from.split('-').map(Number),at=new Date(y!,m!-1,day!);if(at.getFullYear()!==y||at.getMonth()!==m!-1||at.getDate()!==day)return null;return at.getTime();}
 const dayStart=(now:number,back:number)=>{const at=new Date(now);return new Date(at.getFullYear(),at.getMonth(),at.getDate()-back).getTime();};
 // Beyond the engine's three: published models in use, then those of a developer whose tool has a current reading
 // (the engine's eligibleCockpitVendors rule), in publication order. Banks of three page through them.
 function moreFaderModels(value:WireCockpitData){
  const published=value.details?.publishedModels??[],used=new Set((value.details?.sessions??[]).map(s=>s.model));
  const developers=toolDevelopers;
  const vendors=new Set(cockpitMembers(value).flatMap(m=>m.account.valueState==='current'&&Object.hasOwn(developers,m.row.id)?[developers[m.row.id]!]:[]));
  return [...published.filter(m=>used.has(m.id)),...published.filter(m=>!used.has(m.id)&&vendors.has(m.developerId))];
 }
 function paint(keepFaders=false,now?:number){
  if(now!==undefined)renderedNow=now;
  hideTip();if(!keepFaders){paintScale();paintFaders();}bar.setAttribute('aria-label',t('mfd.keysAria'));
  buttons.forEach(({b,caption},i)=>{caption.textContent=t(modules[i].title);b.setAttribute('aria-label',locale==='en'?pages[i].en:pages[i].zh);b.classList.toggle('on',i===selected);b.setAttribute('aria-pressed',String(i===selected));});
  const d=publicData(),selectedId=scope==='all'?null:d.ids.get(scope)??null,ui={page:modules[selected].id,view:null,days:uiDays,stack:uiStack,chart:uiChart,where:uiWhere,time:uiTime,subTab:uiSubTab,subDays:uiSubDays,cycle:uiCycle,older:false,scope:selectedId,selModel:tuneModel,trials:{},now:d.now,lang:locale,fill:selected===0&&uiChart==='grid'&&gridFill?{ov:gridFill}:{},redAt:redBelow()};
  root.querySelector('[data-caution]')?.classList.toggle('mfd-src',alertsView?.from==='caution');
  bar.classList.remove('dark');footer.className='mfd-ok';footer.onclick=null;
  if(compare&&!alertsView&&paintCompare(d,ui))return;
  if(alertsView){
   const back=t(pages[selected].module.title),list=node('ul','mfd-alerts all'+(alertsView.from==='caution'?' ack':'')),button=node('button','mfd-back',t('mfd.back',{p:back}));
   button.type='button';button.dataset.mfd='back';button.setAttribute('aria-label',t('mfd.backAria',{p:back}));
   const mark=alertsView.from==='caution'?alertsView.mark??null:null,flashRow=alertsView.flash===true;alertsView.flash=false;
   for(const x of d.allAlerts){const li=node('li','al-'+x.level+(mark!==null&&x.stable===mark?' al-mark'+(flashRow?' al-flash':''):''));li.append(node('i','','●'),node('span','',x.text));list.append(li);}
   if(!d.allAlerts.length)list.append(node('li','al-none',t('mfd.noAlerts')));
   page.className='mfd-page pg-alerts is-view';page.replaceChildren(button,list);
   footer.replaceChildren(...Array.from({length:3},()=>{const e=node('span','ok soft off');e.dataset.mat='part';e.setAttribute('aria-hidden','true');return e;}));
   page.onclick=e=>{if(e.isTrusted&&(e.target as HTMLElement).closest('[data-mfd="back"]'))closeAlerts();};
   return;
  }
  page.className='mfd-page pg-'+modules[selected].id;
  page.innerHTML=d.empty?`<p class="mp-empty">${t('eng.empty')}</p>`:modules[selected].render(d,ui);
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
  // v1 has today facts but no daily history; never turn a partial aggregate into a complete total.
  if(selected===0&&d.daily.length){const top=page.querySelector('.ov-top');if(top)top.append(node('span','lbl ov-local',locale==='en'?'On this Mac':'本机记录'));}
  // D63: a total over a period longer than the local record says where the record starts, not "30 days".
  const since=recordStart();
  if(since!==null&&selected===0&&d.daily.length){const sum=page.querySelector('.ov-top .ov-sum'),label=sum?.previousElementSibling;if(label&&since>dayStart(d.now,29))label.textContent=t('mfd.since',{d:md(since,{lang:locale})});}
  if(since!==null&&selected===1)for(const stats of page.querySelectorAll<HTMLElement>('.sp-stats[data-days]')){const days=Number(stats.dataset.days),head=stats.querySelector('.stat-h');if(head&&Number.isFinite(days)&&since>dayStart(d.now,days-1))head.textContent+=' · '+t('mfd.since',{d:md(since,{lang:locale})});}
  if(selected===0&&!d.daily.length){const members=scope==='all'?d.members:d.members.filter(m=>m.key===scope),values=members.map(m=>prototypeEngineSupplement(m.account,data??undefined).todayTokens);if(values.length&&values.every((v):v is number=>v!==null)){const sum=values.reduce((a,v)=>a+v,0);if(Number.isSafeInteger(sum)){const total=node('div','ov-top');total.append(node('span','lbl',t('mfd.today')),node('b','ov-total',tok(sum)));const alerts=page.querySelector('.mfd-alerts');if(alerts)alerts.after(total);else page.prepend(total);}}}
  // Study list IDs are positional; attach the originating member identity for focus restoration.
  for(const el of page.querySelectorAll<HTMLElement>('[data-mfd^="scope:member"]')){const match=/^scope:member(\d+)$/.exec(el.dataset.mfd??'');const member=match?d.members[Number(match[1])]:null;if(member){el.dataset.focusMember=member.key;}}
  // 30-day history and the full session list are unavailable, not zero.
  if(selected===1&&uiSubTab==='hist')for(const e of page.querySelectorAll<HTMLElement>('.mp-empty.sm'))e.textContent=locale==='en'?'Data unavailable':'暂无数据';
  if(selected===1&&!selectedId)for(const [i,e] of [...page.querySelectorAll<HTMLElement>('.sa-list .sa')].entries())if(d.members[i]?.account.valueState==='retained')e.append(node('span','mfd-stale',locale==='en'?'Last known reading':'上次读数'));
  if(selected===2)for(const e of page.querySelectorAll<HTMLElement>('.mp-empty'))e.textContent=locale==='en'?'Data unavailable':'暂无数据';
  // Projects are not reported yet; the 时间 list is empty for a period only when last-seen sessions are admitted.
  if(selected===3&&!(uiWhere==='time'&&data?.details?.sessionCoverage==='local-last-seen'))for(const e of page.querySelectorAll<HTMLElement>('.mp-empty'))e.textContent=locale==='en'?'Data unavailable':'暂无数据';
  if(selected===3)for(const b of page.querySelectorAll<HTMLElement>('.ws[data-mfd^="session:"]')){const x=d.sessionRanking.find((s:{ref:string})=>'session:'+s.ref===b.dataset.mfd) as {sub:string|null}|undefined,a=x?.sub?d.accounts.find(a=>a.id===x.sub):null;b.querySelector<HTMLElement>('.chip')?.style.setProperty('--v',a?.colour??'#c6ccd4');}
  if(selected===1&&selectedId){const index=Number(selectedId.slice('member'.length)),entry=d.members[index];if(!entry?.account.observedAt){const source=page.querySelector<HTMLElement>('.sp-sub .src');if(source)source.textContent=locale==='en'?'Reading time unknown':'读数时间未知';}}
  // The cycle chart's vendor colour (--cv) sits in an inline style the page CSP drops; apply it through CSSOM.
  for(const e of page.querySelectorAll<SVGElement>('svg.cy-chart[style]')){const m=/--cv:\s*(#[0-9a-f]{3,8})/i.exec(e.getAttribute('style')??'');e.removeAttribute('style');if(m)e.style.setProperty('--cv',m[1]!);}
  // Reset-card facts are personal observations, joined only by a verified reference.
  if(selected===1&&selectedId&&uiSubTab==='now'){const index=Number(selectedId.slice('member'.length)),entry=d.members[index],ref=entry?.account.subscriptionRef,verified=ref!=null&&data?.subscriptions.some(s=>s.subscriptionRef===ref),matches=verified?data?.details?.subscriptions.filter(s=>s.subscriptionRef===ref)??[]:[],cards=matches.length===1?matches[0].resetCards:null;if(cards&&cards.state!=='unknown'){const items=(cards.items??[]).flatMap(item=>item.expiresAt&&Number.isFinite(Date.parse(item.expiresAt))?[Date.parse(item.expiresAt)]:[]).sort((a,b)=>a-b),line=node('div','rc'),expiries=node('span','rc-exp');line.append(node('span','lbl',t('mfd.cards')),node('b','',cards.count===null?'--':t('mfd.cardsN',{n:cards.count})));for(const [i,time] of items.slice(0,4).entries()){if(i)expiries.append(node('s','','·'));expiries.append(node('i','',until(time,{now:d.now,lang:locale})));}if(items.length>4)expiries.append(node('i','more','+'+(items.length-4)));line.append(expiries);if(items.length)line.title=items.map(time=>relativeMoment(time,{now:d.now,lang:locale},true)).join('\n');page.append(line);}}
  // The prototype's credits chart assumes 30-day history. Show only an
  // actual reported balance instead of fabricating that history or a zero.
  if(selected===1&&selectedId&&uiSubTab==='now'){const index=Number(selectedId.slice('member'.length)),entry=d.members[index],credits=entry?prototypeEngineSupplement(entry.account,data??undefined).reserveCredits:null;if(credits?.balance!==null&&credits?.balance!==undefined&&['credits','points'].includes(credits.unit)){const line=node('div','cr-l');line.append(node('span','lbl',locale==='en'?'Credits':'点数'),node('b','cr-bal',formatCredits(credits.balance,locale)));const ref=entry?.account.subscriptionRef,verified=ref!=null&&data?.subscriptions.some(s=>s.subscriptionRef===ref),matches=verified?data?.details?.subscriptions.filter(s=>s.subscriptionRef===ref)??[]:[],observed=matches.length===1?matches[0].credits?.observedAt:null;line.append(node('em','',observed&&Number.isFinite(Date.parse(observed))?t('mfd.creditsRead',{t:relativeMoment(Date.parse(observed),{now:d.now,lang:locale})}):locale==='en'?'Reading time unknown':'读数时间未知'));page.append(line);
   // The study's 30 daily credit bars need a daily credits history no reader reports yet: the total stays unknown, never a zero or a drawn bar.
   const daily=node('div','cr-l sub cr-30-unknown');daily.append(node('span','lbl'),node('em','',t('mfd.credits30',{n:'--'})));page.append(daily);}}
  footer.replaceChildren();const raw=d.empty?[]:(modules[selected].optionKeys?.(ui,d)??[]);for(let i=0;i<3;i++){const item=raw[i] as {id:string;items?:{value:string|number;text:string;on:boolean}[];a?:{value:string|number;text:string;on:boolean};b?:{value:string|number;text:string;on:boolean}}|null|undefined;if(!item){const e=node('span','ok soft off');e.dataset.mat='part';e.setAttribute('aria-hidden','true');footer.append(e);continue;}const b=node('button','ok soft'),label=node('span','ok-l'),choices=item.items??[item.a!,item.b!];b.type='button';b.dataset.mfd='opt:'+item.id;b.dataset.opt=item.id;b.dataset.mat='part';b.setAttribute('aria-label',choices.map(x=>x.text).join(' | ')+': '+(choices.find(x=>x.on)?.text??''));choices.forEach((x,j)=>{if(j){const sep=node('i','ok-sep');sep.setAttribute('aria-hidden','true');label.append(sep);}const choice=node('b',x.on?'on':'',x.text);choice.dataset.choice=String(x.value);label.append(choice);});b.append(label);b.onclick=e=>{if(!e.isTrusted)return;const v=(e.target as HTMLElement).closest<HTMLElement>('[data-choice]')?.dataset.choice;if(item.id==='where')uiWhere=v??(uiWhere==='time'?'proj':'time');else if(item.id==='time')uiTime=v??(uiTime==='7d'?'today':'7d');else if(item.id==='days')uiDays=v?Number(v):uiDays===30?7:30;else if(item.id==='chart')uiChart=v??(uiChart==='grid'?'bars':'grid');else if(item.id==='stack')uiStack=v?v==='stack':!uiStack;else if(item.id==='tab')uiSubTab=v??(uiSubTab==='hist'?'now':'hist');else if(item.id==='usage')uiSubDays=v?Number(v)===30?30:7:uiSubDays===30?7:30;else if(item.id==='cycle'){const other=choices.find(x=>!x.on);uiCycle=v??(other?String(other.value):uiCycle);}paint();};footer.append(b);}
  page.onclick=e=>{const target=e.target as HTMLElement;if(target.closest('a')){e.preventDefault();return;}if(e.isTrusted&&target.closest('[data-mfd="back"]')){closeTune();return;}if(e.isTrusted&&target.closest('[data-mfd="alerts"]')){alertsView={from:'mfd'};paint();return;}const b=target.closest<HTMLElement>('[data-mfd^="scope:"]');if(!e.isTrusted||!b)return;const index=Number((b.dataset.mfd??'').slice('scope:member'.length));const m=d.members[index];if(m&&onScope?.(m.key)){scope=m.key;paint();}};
 }
 // The comparison card on the screen and its own bottom keys (mfd.js screen/renderMfd with VIEWS.compare).
 function paintCompare(d:ReturnType<typeof publicData>,ui:Record<string,unknown>){
  const f=faderInput().faders.find(x=>x.id===compare!.modelId);if(!f){compare=null;return false;}
  const fast=compareSpeedTiers(f,f.tier),model={id:f.id,name:f.name,short:f.short||f.name,rec:f.rec,e:f.e,pool:fast.pool},view={models:[model],speedTiers:fast.speedTiers,sessionRanking:[],accounts:[],now:d.now};
  const args:CompareArgs={modelId:f.id,current:compare!.current,...(compare!.trial?{trial:compare!.trial}:{}),...(compare!.fast!==undefined?{fast:compare!.fast}:{}),currentFast:compare!.currentFast};
  const back=t(pages[selected]!.module.title),draw=()=>{page.innerHTML=comparison(view,{...ui,scope:null,fill:cmpFill?{cmp:cmpFill}:{}},args);};
  bar.classList.add('dark');for(const {b} of buttons){b.classList.remove('on');b.setAttribute('aria-pressed','false');}
  page.className='mfd-page pg-compare is-view own-title';draw();
  // The chart is drawn at its measured size (mfd.js renderMfd), again once if that size changed.
  const area=page.querySelector<HTMLElement>('[data-fill="cmp"]'),size=area?{w:Math.floor(area.clientWidth),h:Math.floor(area.clientHeight)}:null;
  if(size&&size.w>0&&size.h>0&&(cmpFill?.w!==size.w||cmpFill?.h!==size.h)){cmpFill=size;draw();}
  // CSP (style-src 'self') drops the ladder's inline geometry; apply it through CSSOM.
  for(const e of page.querySelectorAll<HTMLElement>('.cmp-lad[style]')){const css=e.getAttribute('style')??'';e.removeAttribute('style');for(const m of css.matchAll(/(--c[lr]):(\d+(?:\.\d+)?px)/g))e.style.setProperty(m[1]!,m[2]!);}
  const keys=document.createElement('template');keys.innerHTML=compareKeys(view,ui,args,{back});
  footer.className='mfd-ok mfd-vk';footer.replaceChildren(...(keys.content.firstElementChild?.childNodes??[]));
  footer.onclick=e=>{if(!e.isTrusted)return;const key=(e.target as Element).closest<HTMLElement>('[data-mfd]');if(!key)return;
   if(key.dataset.mfd==='back'){closeCompare();return;}
   const next=compareView.onClick('fast','',ui,view,args);if(next&&compare){compare={...compare,fast:next.trial.fast!};paint();}};
  page.onclick=e=>{const target=e.target as HTMLElement;if(target.closest('a')){e.preventDefault();return;}const key=target.closest<HTMLElement>('[data-mfd^="try:"]');if(!e.isTrusted||!key||!compare)return;
   const level=(key.dataset.mfd??'').slice(4),c={id:compare.modelId,current:compare.current,base:compare.current??f.rec,currentFast:compare.currentFast};tryEffort(c,level);};
  return true;
 }
 function closeTune(){if(returnPage===null)return false;selected=returnPage;returnPage=null;tuneModel=null;paint();return true;}
 function closeAlerts(){if(!alertsView)return false;const focus=mfd.contains(document.activeElement);alertsView=null;paint();if(focus)buttons[selected]?.b.focus({preventScroll:true});return true;}
 const escape=(e:KeyboardEvent)=>{if(e.isTrusted&&e.key==='Escape'&&!e.altKey&&(alertsView?closeAlerts():compare?closeCompare():closeTune()))e.preventDefault();};window.addEventListener('keydown',escape);
 // CKP-FAD-15: [ and ] page the fader banks, as the ◀ ▶ keys do.
 const bankKeys=(e:KeyboardEvent)=>{if(!e.isTrusted||e.altKey||e.ctrlKey||e.metaKey||e.repeat||(e.key!=='['&&e.key!==']'))return;const target=e.target;if(target instanceof Element&&target.closest('input,textarea,select,[contenteditable]:not([contenteditable="false"])'))return;if(!bank.querySelector('[data-bank]'))return;e.preventDefault();bankIndex+=e.key===']'?1:-1;paintFaders();};window.addEventListener('keydown',bankKeys);
 // CKP-STRIP-15: a record line names a session; the publication says which fader carries it.
 function sessionModel(ref:string){const input=record(details.publication);if(!input||!Array.isArray(input.faders))return null;const i=input.faders.slice(0,100).findIndex(v=>{const sessions=record(v)?.sessions;return Array.isArray(sessions)&&sessions.some(x=>record(x)?.ref===ref);});return i<0?null:'model'+i;}
 paint();return {showTune(id:string){const tune=modules.findIndex(m=>m.id==='tune');if(tune<0)return;if(compare){delete previews[compare.modelId];compare=null;}alertsView=null;if(returnPage===null)returnPage=selected;selected=tune;tuneModel=id;paint();},knowsSession(ref:string){return sessionModel(ref)!==null;},highlightSession(ref:string|null){const id=ref?sessionModel(ref):null;for(const ch of channels.querySelectorAll<HTMLElement>('.fd-ch'))ch.classList.toggle('xhl',!!id&&ch.dataset.model===id);},selectSession(ref:string){const id=sessionModel(ref);if(compare){delete previews[compare.modelId];compare=null;}if(id)selectedModel=id;const at=modules.findIndex(m=>m.id==='where');if(at>=0){selected=at;uiWhere='time';uiTime='today';}alertsView=null;paint();},alertsOpen:()=>alertsView?.from==='caution',showAlerts(mark?:string|null){if(alertsView?.from==='caution'){closeAlerts();return false;}alertsView={from:'caution',mark:mark??null,flash:mark!=null};paint();return true;},refresh(now?:number){paint(true,now);},locale(value:Locale,now?:number){locale=value;paint(false,now);},render(value:WireCockpitData,now:number){press=null;const binding=sessionMembers(value),bound=(value.details?.sessions??[]).map(x=>({...x,subscriptionRef:binding.get(x.sessionRef)??null}));renderedNow=now;data=value;const publication=value.details?.publication;const nextKey=publication?JSON.stringify([publication.publicationId,publication.models.map(m=>m.id)]):null;if(!fixturePublication&&nextKey!==publicationKey){previews={};selectedModel=null;bankIndex=0;compare=null;}publicationKey=nextKey;details={...details,publication:fixturePublication?details.publication:publication==null?null:publicationFaders(publication,bound,moreFaderModels(value),cockpitMembers(value).map(m=>({key:m.key,developer:toolDevelopers[m.row.id]??null,colour:memberColour(m)}))),liveSessions:value.details?bound:null,resetEvents:value.details?.resetEvents??null};root.dataset.detailsAvailable=String(value.details!=null);paint();},scope(value:string){scope=value;paint();},cancelPress(){press=null;suppressClick=false;},clear(){publicationKey=null;press=null;pins=[];unpinned.clear();suppressClick=false;data=null;root.dataset.detailsAvailable='false';details=unavailablePrototypeDetailsFixture();bankIndex=0;selectedModel=null;previews={};scope='all';selected=0;alertsView=null;returnPage=null;tuneModel=null;compare=null;paint();},dispose(){publicationKey=null;press=null;pins=[];unpinned.clear();suppressClick=false;window.removeEventListener('keydown',escape);window.removeEventListener('keydown',bankKeys);alertsView=null;compare=null;returnPage=null;tuneModel=null;data=null;root.dataset.detailsAvailable='false';details=unavailablePrototypeDetailsFixture();bankIndex=0;selectedModel=null;previews={};scope='all';selected=0;paint();for(const {b} of buttons)b.onclick=null;page.onclick=null;screen.onpointerover=null;screen.onpointerleave=null;hideTip();}};
}

// SPDX-License-Identifier: MIT
// Study fader/MFD hierarchy, with escaped renderer fields and bounded identifiers.
// Current bridge has no cockpitDetailsV1 or publication payload: no study
// fixture readings, rankings or invented session controls are displayed.
import {unavailablePrototypeDetailsFixture,type PrototypeDetailsFixture} from './prototype-details-fixture-adapter.js';
import {effectiveRedBelow} from './threshold.js';
import type {WireCockpitData} from '../generated/wire.js';
import {cockpitMembers} from './members.js';
import {cautionItems} from './caution.js';
import {prototypeEngineSupplement,currentWindow,displayWindow,scopedWindow,runOutMinutes,runOutFields,forecastOf} from './prototype-data-adapter.js';
import {historyView,usageStats} from './prototype-history.js';
import {scaleView,levelK,bankView,faderModel,lcdView,indicatorView,marksView,stripAria} from '../study/rocket-r1/fader-view.js';
import {setLanguage,t,formatCredits} from '../study/rocket-r1/i18n.js';
import {overview} from '../study/rocket-r1/mfd-pages/overview.js';
import {plans} from '../study/rocket-r1/mfd-pages/plans.js';
import {relativeMoment,tok,until} from '../study/rocket-r1/mfd-pages/fmt.js';
import {tune} from '../study/rocket-r1/mfd-pages/tune.js';
import {where} from '../study/rocket-r1/mfd-pages/where.js';
import '../study/rocket-r1/strings/mfd.js';
type Locale='en'|'zh-CN';
const node=<K extends keyof HTMLElementTagNameMap>(tag:K,cls?:string,text?:string):HTMLElementTagNameMap[K]=>{const e=document.createElement(tag);if(cls)e.className=cls;if(text!==undefined)e.textContent=text;return e;};
const cockpitPageRegistry=Object.freeze([Object.freeze({module:overview,en:'Overview',zh:'总览'}),Object.freeze({module:plans,en:'Subscription',zh:'订阅'}),Object.freeze({module:tune,en:'Effort',zh:'档位'}),Object.freeze({module:where,en:'Breakdown',zh:'去向'})]);
export const cockpitPageIds=Object.freeze(cockpitPageRegistry.map(p=>p.module.id));
export function mountPrototypeDeck(root:HTMLElement,onScope?:(key:string)=>boolean,fixture:PrototypeDetailsFixture=unavailablePrototypeDetailsFixture(),redBelow:()=>number=()=>effectiveRedBelow(undefined)){
 const scale=root.querySelector<HTMLElement>('.fd-scale')!,channels=root.querySelector<HTMLElement>('.fd-chs')!,mfd=root.querySelector<HTMLElement>('.dk-mfd')!;
 let details=fixture;fixture=unavailablePrototypeDetailsFixture();
 let locale:Locale='en',selected=0,scope='all',data:WireCockpitData|null=null,renderedNow=0;
 // Prototype mfd.js:39-58,75 (openMfdView/closeMfdView): the full alert list is a view over the current page, opened by the
 // ALERT lamp or the overview's "+N" line, closed by "‹ Back to <page>", Esc, a page key or a second lamp press.
 let alertsView:{from:'caution'|'mfd'}|null=null;root.dataset.detailsAvailable=String(details.liveSessions!==null);
 // The study controller's fixed three-channel skeleton. No fixture data is
 // bundled; absent publication and session capabilities leave all bays empty.
 const skeleton=(i:number)=>`<div class="fd-ch empty" data-slot="${i}"><div class="fd-leds"></div><button class="fd-strip" data-mat="well" tabindex="-1"></button>
  <div class="fd-travel" role="slider" aria-orientation="vertical" aria-valuemin="0" aria-valuemax="4" tabindex="-1"><span class="fd-slot"></span><span class="fd-marks"></span><span class="fd-peek"></span><span class="fd-ghost" data-mat="part" hidden></span><span class="fd-cap" data-mat="part" hidden></span></div></div>`;
 channels.innerHTML=Array.from({length:3},(_,i)=>skeleton(i)).join('');
 for(const b of channels.querySelectorAll<HTMLButtonElement>('.fd-strip'))b.disabled=true;
 const bank=root.querySelector<HTMLElement>('.fd-bank')!;bank.innerHTML=bankView({bank:0,banks:1});
 const ladder=['Low','Med','High','XHigh','Max'] as const;let bankIndex=0,selectedModel:string|null=null,previews:Record<string,string>={};
 const record=(v:unknown):Record<string,unknown>|null=>v!==null&&typeof v==='object'&&!Array.isArray(v)?v as Record<string,unknown>:null;
 const safeText=(v:unknown)=>typeof v==='string'?v.slice(0,200):'';
 const effort=(v:unknown):string|null=>{if(typeof v!=='string')return null;const aliases:Readonly<Record<string,string>>={low:'Low',med:'Med',medium:'Med',high:'High',xhigh:'XHigh',max:'Max'};return aliases[v.toLowerCase()]??null;};
 const number=(v:unknown)=>typeof v==='number'&&Number.isFinite(v)&&v>=0&&v<=1e12?v:null;
 // Only a supplied publication and observed live-session input can populate
 // channels; this adapter never creates models or fills unknown readings.
 function faderInput(){
  const input=record(details.publication);if(!input||!Array.isArray(input.faders)||!Array.isArray(input.accounts))return {accounts:[],faders:[]};
  const accountIds=new Map<string,string>();const accounts=input.accounts.slice(0,100).flatMap((v,i)=>{const a=record(v);if(!a||typeof a.id!=='string')return [];const id='a'+i;accountIds.set(a.id,id);return [{id,colour:typeof a.colour==='string'&&/^#[a-f0-9]{6}$/i.test(a.colour)?a.colour:null}];});
  const faders=input.faders.slice(0,100).flatMap((v,i)=>{const f=record(v),rec=effort(f?.rec);if(!f||!rec||!Array.isArray(f.e))return [];const rows=f.e.slice(0,5).flatMap(v=>{if(!Array.isArray(v))return [];const label=effort(v[0]),ability=number(v[1]),cost=number(v[2]);return !label||ability===null||cost===null?[]:[[label,ability,cost,number(v[3])]];});if(!rows.some(r=>r[0]===rec))return [];
   const live=Array.isArray(details.liveSessions)?details.liveSessions.slice(0,500).flatMap(v=>{const x=record(v),ref=x&&(typeof x.sessionRef==='string'?x.sessionRef:typeof x.ref==='string'?x.ref:null);return x&&ref?[{ref,value:x}]:[]}):[];
   const sessions=Array.isArray(f.sessions)?f.sessions.slice(0,6).flatMap(v=>{const x=record(v),match=x&&typeof x.ref==='string'?live.find(y=>y.ref===x.ref):null;if(!x||!match)return [];const observed=match.value,bound=typeof x.sub==='string'&&typeof observed.subscriptionRef==='string'&&x.sub===observed.subscriptionRef&&accountIds.has(x.sub);return [{sub:bound?accountIds.get(x.sub as string)??'':'',account:bound?safeText(x.account):'',tool:safeText(observed.tool||observed.source),project:safeText(observed.projectLabel||observed.project),effort:effort(observed.effort),fast:typeof observed.fast==='boolean'?observed.fast:null,lastObservedAt:typeof observed.lastObservedAt==='string'?observed.lastObservedAt:typeof observed.lastAt==='string'?observed.lastAt:null,running:false,startedMin:null,endedMin:null}];}):[];
   const current=sessions[0]?.effort??null,fast=sessions[0]?.fast??null,tier=record(f.tier),speed=number(tier?.speed),cost=number(tier?.cost),otherEntries:Record<string,number>={};for(const x of sessions.slice(1))if(x.effort)otherEntries[x.effort]=(otherEntries[x.effort]??0)+1;
   const links=Array.isArray(f.accounts)?f.accounts.flatMap(v=>typeof v==='string'&&accountIds.has(v)?[accountIds.get(v)!]:[]):[];
   return [{id:'model'+i,sourceId:safeText(f.id),name:safeText(f.name)||safeText(f.short),short:safeText(f.short),rec,e:rows,pinned:f.pinned===true,live:sessions.length>0,current,currentFast:fast===true,others:otherEntries,tier:fast!==null&&speed!==null&&cost!==null?{speed,cost}:null,accounts:links,sessions}];});return {accounts,faders};
 }
 function paintScale(){setLanguage(locale);scale.innerHTML=scaleView();for(const b of scale.querySelectorAll<HTMLButtonElement>('.sc-l')){b.disabled=true;b.classList.add('na');b.style.setProperty('--k',String(levelK(b.dataset.level??'')));}}
 function paintFaders(){
  const data=faderInput(),input=record(details.publication),requested=selectedModel??safeText(input?.selectedModel),target=data.faders.find(f=>f.id===requested||f.sourceId===requested)?.id??null,ui={bank:bankIndex,bankSize:3,selModel:target,previews,view:null,phase:'open',reduced:true},model=faderModel(data,ui);bankIndex=model.bank;
  const targetChannel=model.all.find((c:{id:string})=>c.id===model.target);
  for(const b of scale.querySelectorAll<HTMLButtonElement>('.sc-l')){const level=b.dataset.level??'',allowed=!!targetChannel&&targetChannel.levels.includes(level);b.disabled=false;b.classList.toggle('na',!allowed);b.onclick=e=>{if(!e.isTrusted||!allowed)return;previews[targetChannel.id]=level;paintFaders();};}
  for(const [i,ch] of [...channels.querySelectorAll<HTMLElement>('.fd-ch')].entries()){
   const c=model.channels[i],strip=ch.querySelector<HTMLButtonElement>('.fd-strip')!,leds=ch.querySelector<HTMLElement>('.fd-leds')!,travel=ch.querySelector<HTMLElement>('.fd-travel')!,marks=ch.querySelector<HTMLElement>('.fd-marks')!,cap=ch.querySelector<HTMLElement>('.fd-cap')!;
   ch.className='fd-ch'+(c?'':' empty');ch.dataset.model=c?.id??'';if(c){ch.classList.toggle('sel',!!c.sel);ch.classList.toggle('trying',!!c.trial);ch.classList.toggle('src',c.src==='fader');}strip.disabled=!c;strip.tabIndex=c?0:-1;travel.tabIndex=c?0:-1;
   leds.innerHTML=c?indicatorView(c):'';if(c?.leds.length){const indicator=leds.querySelector<HTMLElement>('.fd-indicator'),times=c.leds.map((x:{lastObservedAt:string|null})=>x.lastObservedAt?Date.parse(x.lastObservedAt):NaN).filter(Number.isFinite),latest=times.length?new Date(Math.max(...times)).toLocaleString(locale):'';indicator?.setAttribute('aria-label',c.name+' · '+(locale==='en'?'Last reading':'最近读数')+(latest?' '+latest:''));}strip.innerHTML=c?lcdView(c):'';marks.innerHTML=c?marksView(c):'';cap.hidden=!c;
   if(!c){strip.removeAttribute('aria-label');strip.removeAttribute('data-strip');travel.removeAttribute('data-travel');strip.onclick=null;travel.onkeydown=null;travel.onpointerdown=null;travel.removeAttribute('aria-valuenow');travel.removeAttribute('aria-valuetext');continue;}strip.dataset.strip=c.id;travel.dataset.travel=c.id;const shown=c.tEff||c.base;travel.setAttribute('aria-label',c.name);travel.setAttribute('aria-valuenow',String(ladder.indexOf(shown)));travel.setAttribute('aria-valuetext',shown);const ghost=ch.querySelector<HTMLElement>('.fd-ghost')!;ghost.hidden=c.ghostK==null;if(c.ghostK!=null)ghost.style.setProperty('--k',String(c.ghostK));travel.onkeydown=e=>{if(!e.isTrusted||!['ArrowUp','ArrowDown'].includes(e.key))return;e.preventDefault();const at=ladder.indexOf(shown),step=e.key==='ArrowUp'?1:-1;for(let n=at+step;n>=0&&n<ladder.length;n+=step)if(c.levels.includes(ladder[n])){selectedModel=c.id;previews[c.id]=ladder[n];paintFaders();break;}};travel.onpointerdown=e=>{if(!e.isTrusted||e.button!==0)return;const r=travel.getBoundingClientRect(),k=Math.max(0,Math.min(1,(e.clientY-r.top)/Math.max(1,r.height))),levels=c.levels as string[];let best=levels[0],delta=Infinity;for(const level of levels){const d=Math.abs((4-ladder.indexOf(level as typeof ladder[number]))/4-k);if(d<delta){delta=d;best=level;}}selectedModel=c.id;previews[c.id]=best;paintFaders();};strip.onclick=e=>{if(!e.isTrusted)return;selectedModel=c.id;paintFaders();};strip.setAttribute('aria-label',stripAria(c));cap.style.setProperty('--k',String(c.capK));
   for(const [j,el] of [...marks.querySelectorAll<HTMLElement>('.fd-tick')].entries())el.style.setProperty('--k',String(c.ticks[j]));const rec=marks.querySelector<HTMLElement>('.fd-rec');rec?.style.setProperty('--k',String(c.recK));for(const [j,el] of [...marks.querySelectorAll<HTMLElement>('.fd-dot')].entries())el.style.setProperty('--k',String(c.dots[j].k));
   for(const [j,el] of [...strip.querySelectorAll<HTMLElement>('.eb')].entries()){const b=c.bars[j];if(!b.none)el.style.setProperty('--h',(3+b.h*8).toFixed(1)+'px');}for(const [j,el] of [...strip.querySelectorAll<HTMLElement>('.st-vend b')].entries())el.style.setProperty('--v',c.segments[j]);
  }
  bank.innerHTML=bankView(model);for(const b of bank.querySelectorAll<HTMLButtonElement>('[data-bank]'))b.onclick=e=>{if(!e.isTrusted)return;bankIndex+=b.dataset.bank==='1'?1:-1;paintFaders();};
 }

 const bar=node('div','mfd-pk'),screen=node('div','mfd-screen'),page=node('div','mfd-page pg-overview'),footer=node('div','mfd-ok');bar.setAttribute('role','toolbar');screen.dataset.mat='well';page.dataset.fill='page';screen.append(page);
 const pages=cockpitPageRegistry,modules=pages.map(p=>p.module);let uiWhere='proj',uiTime='today',uiDays=30,uiChart='bars',uiStack=true,uiSubTab='now';
 const buttons=pages.map((item,i)=>{const b=node('button','pk'),caption=node('span'),led=node('i','pk-led');b.type='button';b.dataset.mfd='page:'+modules[i].id;b.dataset.mat='part';b.append(caption,led);b.onclick=e=>{if(!e.isTrusted)return;alertsView=null;selected=i;paint();};bar.append(b);return {b,caption};});
 mfd.replaceChildren(bar,screen,footer);
 // Public projection only: v1.1 charts, rankings and full session lists are
 // absent, not populated with the prototype's fixture numbers.
 // 时间 list from the admitted last-seen sessions only (CKP-MFD-23, bounded v1 part). The producer reports
 // running or idle and the last observation; it is never an end time, and per-session tokens are not reported.
 function lastSeen(members:ReturnType<typeof cockpitMembers>,ids:Map<string,string>){
  const detail=data?.details;if(!detail||detail.sessionCoverage!=='local-last-seen')return [];
  return detail.sessions.slice(0,64).flatMap(x=>{const at=Date.parse(x.lastObservedAt);if(!Number.isFinite(at)||(x.state!=='running'&&x.state!=='idle'))return [];
   const member=x.subscriptionRef?members.find(m=>m.key===x.subscriptionRef):undefined;
   return [{ref:x.sessionRef,sub:member?ids.get(member.key)??null:null,tool:x.source,model:x.model,effort:x.effort,fast:false,project:x.projectLabel??'--',running:x.state==='running',startedAt:null,endedAt:null,lastAt:at,tokens:null}];});
 }
 function publicData(now=renderedNow){
  const members=data?cockpitMembers(data):[],ids=new Map(members.map((m,i)=>[m.key,'member'+i]));
  const colours:Readonly<Record<string,string>>={openai:'#6aa8ff',claude:'#ff9a6a',cursor:'#eef2f6',copilot:'#c08cff',kimi:'#ff8fcf',glm:'#8f7dff',opencode:'#b5d65a'};
  const accounts=members.map(({key,row,account})=>({id:ids.get(key)!,name:locale==='en'?row.name.en:row.name.zh,short:locale==='en'?row.name.en:row.name.zh,plan:account.plan.name?(locale==='en'?account.plan.name.en:account.plan.name.zh):'',vendor:row.vendorKey&&Object.hasOwn(colours,row.vendorKey)?row.vendorKey:'unknown',colour:row.vendorKey&&Object.hasOwn(colours,row.vendorKey)?colours[row.vendorKey]:'#c6ccd4',logo:'../../neutral.png',source:'native',state:account.valueState==='current'?'ok':account.valueState==='retained'?'stale':'loading',ageMin:account.observedAt&&Number.isFinite(Date.parse(account.observedAt))?Math.max(0,(now-Date.parse(account.observedAt))/60000):null,support:'quota-only',pool:null,windows:account.valueState==='none'?[]:account.windows.filter(w=>!scopedWindow(w)).map(w=>({kind:w.role==='session'?'5h':w.role==='weekly'?'week':w.role==='monthly'?'month':w.role==='daily'?'day':'other',label:locale==='en'?w.label.en:w.label.zh,remaining:displayWindow(account,w,now)?w.remainingPercent:null,resetIn:displayWindow(account,w,now)&&w.resetsAt&&Number.isFinite(Date.parse(w.resetsAt))&&Date.parse(w.resetsAt)>=now?(Date.parse(w.resetsAt)-now)/60000:null,resetAt:displayWindow(account,w,now)&&w.resetsAt&&Number.isFinite(Date.parse(w.resetsAt))?Date.parse(w.resetsAt):null,...runOutFields(runOutMinutes(data,row.id,account,w,now)),elapsed:null})),extras:account.valueState==='none'?[]:account.windows.filter(scopedWindow).map(w=>({kind:'other',label:locale==='en'?w.label.en:w.label.zh,remaining:displayWindow(account,w,now)?w.remainingPercent:null,resetIn:displayWindow(account,w,now)&&w.resetsAt&&Number.isFinite(Date.parse(w.resetsAt))&&Date.parse(w.resetsAt)>=now?(Date.parse(w.resetsAt)-now)/60000:null,resetAt:displayWindow(account,w,now)&&w.resetsAt&&Number.isFinite(Date.parse(w.resetsAt))?Date.parse(w.resetsAt):null,...runOutFields(runOutMinutes(data,row.id,account,w,now)),elapsed:null})),cards:[],credits:scope==='all'&&prototypeEngineSupplement(account,data??undefined).reserveCredits?.balance!=null&&['credits','points'].includes(prototypeEngineSupplement(account,data??undefined).reserveCredits?.unit??'')?{balance:prototypeEngineSupplement(account,data??undefined).reserveCredits!.balance,drawing:null}:null,todayTokens:prototypeEngineSupplement(account,data??undefined).todayTokens,forecast:forecastOf(account.windows.filter(w=>!scopedWindow(w)).map(w=>runOutFields(runOutMinutes(data,row.id,account,w,now)))),peak:null,resets:[],usageStats:usageStats(data,account.subscriptionRef)}));
  // Owner D38: urgency order, subscription and time left; resets and stale readings are list-only (blue).
  // The overview follows the selected scope; the full list (the global lamp's destination) never does.
  const allAlerts=data?cautionItems(data,now,redBelow()).map(x=>({member:x.member,level:x.level,text:locale==='en'?x.text.en:x.text.zh})):[];
  const alerts=allAlerts.filter(x=>scope==='all'||x.member===scope).map(({level,text})=>({level,text}));
  return {now,accounts,alerts,allAlerts,events:[],...historyView(data,ids,now,locale),paceHistory:{},sessionRanking:lastSeen(members,ids),models:[],lineup:[],selection:{scope:scope==='all'?null:ids.get(scope)??null,field:[]},empty:accounts.length===0,ids,members};
 }
 function paint(keepFaders=false,now?:number){
  if(now!==undefined)renderedNow=now;
  if(!keepFaders){paintScale();paintFaders();}bar.setAttribute('aria-label',t('mfd.keysAria'));
  buttons.forEach(({b,caption},i)=>{caption.textContent=t(modules[i].title);b.setAttribute('aria-label',locale==='en'?pages[i].en:pages[i].zh);b.classList.toggle('on',i===selected);b.setAttribute('aria-pressed',String(i===selected));});
  const d=publicData(),selectedId=scope==='all'?null:d.ids.get(scope)??null,ui={page:modules[selected].id,view:null,days:uiDays,stack:uiStack,chart:uiChart,where:uiWhere,time:uiTime,subTab:uiSubTab,subDays:7,cycle:null,older:false,scope:selectedId,selModel:null,trials:{},now:d.now,lang:locale,fill:{},redAt:redBelow()};
  root.querySelector('[data-caution]')?.classList.toggle('mfd-src',alertsView?.from==='caution');
  if(alertsView){
   const back=t(pages[selected].module.title),list=node('ul','mfd-alerts all'+(alertsView.from==='caution'?' ack':'')),button=node('button','mfd-back',t('mfd.back',{p:back}));
   button.type='button';button.dataset.mfd='back';button.setAttribute('aria-label',t('mfd.backAria',{p:back}));
   for(const x of d.allAlerts){const li=node('li','al-'+x.level);li.append(node('i','','●'),node('span','',x.text));list.append(li);}
   if(!d.allAlerts.length)list.append(node('li','al-none',t('mfd.noAlerts')));
   page.className='mfd-page pg-alerts is-view';page.replaceChildren(button,list);
   footer.replaceChildren(...Array.from({length:3},()=>{const e=node('span','ok soft off');e.dataset.mat='part';e.setAttribute('aria-hidden','true');return e;}));
   page.onclick=e=>{if(e.isTrusted&&(e.target as HTMLElement).closest('[data-mfd="back"]'))closeAlerts();};
   return;
  }
  page.className='mfd-page pg-'+modules[selected].id;
  page.innerHTML=d.empty?`<p class="mp-empty">${t('eng.empty')}</p>`:modules[selected].render(d,ui);
  // v1 has today facts but no daily history; never turn a partial aggregate into a complete total.
  if(selected===0&&d.daily.length){const top=page.querySelector('.ov-top');if(top)top.append(node('span','lbl ov-local',locale==='en'?'On this Mac':'本机记录'));}
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
  // Reset-card facts are personal observations, joined only by a verified reference.
  if(selected===1&&selectedId&&uiSubTab==='now'){const index=Number(selectedId.slice('member'.length)),entry=d.members[index],ref=entry?.account.subscriptionRef,verified=ref!=null&&data?.subscriptions.some(s=>s.subscriptionRef===ref),matches=verified?data?.details?.subscriptions.filter(s=>s.subscriptionRef===ref)??[]:[],cards=matches.length===1?matches[0].resetCards:null;if(cards&&cards.state!=='unknown'){const items=(cards.items??[]).flatMap(item=>item.expiresAt&&Number.isFinite(Date.parse(item.expiresAt))?[Date.parse(item.expiresAt)]:[]).sort((a,b)=>a-b),line=node('div','rc'),expiries=node('span','rc-exp');line.append(node('span','lbl',t('mfd.cards')),node('b','',cards.count===null?'--':t('mfd.cardsN',{n:cards.count})));for(const [i,time] of items.slice(0,4).entries()){if(i)expiries.append(node('s','','·'));expiries.append(node('i','',until(time,{now:d.now,lang:locale})));}if(items.length>4)expiries.append(node('i','more','+'+(items.length-4)));line.append(expiries);if(items.length)line.title=items.map(time=>relativeMoment(time,{now:d.now,lang:locale},true)).join('\n');page.append(line);}}
  // The prototype's credits chart assumes 30-day history. Show only an
  // actual reported balance instead of fabricating that history or a zero.
  if(selected===1&&selectedId){const index=Number(selectedId.slice('member'.length)),entry=d.members[index],credits=entry?prototypeEngineSupplement(entry.account,data??undefined).reserveCredits:null;if(credits?.balance!==null&&credits?.balance!==undefined&&['credits','points'].includes(credits.unit)){const line=node('div','cr-l');line.append(node('span','lbl',locale==='en'?'Credits':'点数'),node('b','cr-bal',formatCredits(credits.balance,locale)));const ref=entry?.account.subscriptionRef,verified=ref!=null&&data?.subscriptions.some(s=>s.subscriptionRef===ref),matches=verified?data?.details?.subscriptions.filter(s=>s.subscriptionRef===ref)??[]:[],observed=matches.length===1?matches[0].credits?.observedAt:null;line.append(node('em','',observed&&Number.isFinite(Date.parse(observed))?t('mfd.creditsRead',{t:relativeMoment(Date.parse(observed),{now:d.now,lang:locale})}):locale==='en'?'Reading time unknown':'读数时间未知'));page.append(line);}}
  footer.replaceChildren();const raw=d.empty?[]:(modules[selected].optionKeys?.(ui,d)??[]);for(let i=0;i<3;i++){const item=raw[i] as {id:string;items?:{value:string|number;text:string;on:boolean}[];a?:{value:string|number;text:string;on:boolean};b?:{value:string|number;text:string;on:boolean}}|null|undefined;if(!item){const e=node('span','ok soft off');e.dataset.mat='part';e.setAttribute('aria-hidden','true');footer.append(e);continue;}const b=node('button','ok soft'),label=node('span','ok-l'),choices=item.items??[item.a!,item.b!];b.type='button';b.dataset.mfd='opt:'+item.id;b.dataset.opt=item.id;b.dataset.mat='part';b.setAttribute('aria-label',choices.map(x=>x.text).join(' | ')+': '+(choices.find(x=>x.on)?.text??''));choices.forEach((x,j)=>{if(j){const sep=node('i','ok-sep');sep.setAttribute('aria-hidden','true');label.append(sep);}const choice=node('b',x.on?'on':'',x.text);choice.dataset.choice=String(x.value);label.append(choice);});b.append(label);b.onclick=e=>{if(!e.isTrusted)return;const v=(e.target as HTMLElement).closest<HTMLElement>('[data-choice]')?.dataset.choice;if(item.id==='where')uiWhere=v??(uiWhere==='time'?'proj':'time');else if(item.id==='time')uiTime=v??(uiTime==='7d'?'today':'7d');else if(item.id==='days')uiDays=v?Number(v):uiDays===30?7:30;else if(item.id==='chart')uiChart=v??(uiChart==='grid'?'bars':'grid');else if(item.id==='stack')uiStack=v?v==='stack':!uiStack;else if(item.id==='tab')uiSubTab=v??(uiSubTab==='hist'?'now':'hist');paint();};footer.append(b);}
  page.onclick=e=>{const target=e.target as HTMLElement;if(target.closest('a')){e.preventDefault();return;}if(e.isTrusted&&target.closest('[data-mfd="alerts"]')){alertsView={from:'mfd'};paint();return;}const b=target.closest<HTMLElement>('[data-mfd^="scope:"]');if(!e.isTrusted||!b)return;const index=Number((b.dataset.mfd??'').slice('scope:member'.length));const m=d.members[index];if(m&&onScope?.(m.key)){scope=m.key;paint();}};
 }
 function closeAlerts(){if(!alertsView)return false;const focus=mfd.contains(document.activeElement);alertsView=null;paint();if(focus)buttons[selected]?.b.focus({preventScroll:true});return true;}
 const escape=(e:KeyboardEvent)=>{if(e.isTrusted&&e.key==='Escape'&&!e.altKey&&alertsView&&closeAlerts())e.preventDefault();};window.addEventListener('keydown',escape);
 paint();return {alertsOpen:()=>alertsView?.from==='caution',showAlerts(){if(alertsView?.from==='caution'){closeAlerts();return false;}alertsView={from:'caution'};paint();return true;},refresh(now?:number){paint(true,now);},locale(value:Locale,now?:number){locale=value;paint(false,now);},render(value:WireCockpitData,now:number){renderedNow=now;data=value;details={...details,liveSessions:value.details?.sessions??null,resetEvents:value.details?.resetEvents??null};root.dataset.detailsAvailable=String(value.details!=null);paint();},scope(value:string){scope=value;paint();},clear(){data=null;root.dataset.detailsAvailable='false';details=unavailablePrototypeDetailsFixture();bankIndex=0;selectedModel=null;previews={};scope='all';selected=0;alertsView=null;paint();},dispose(){window.removeEventListener('keydown',escape);alertsView=null;data=null;root.dataset.detailsAvailable='false';details=unavailablePrototypeDetailsFixture();bankIndex=0;selectedModel=null;previews={};scope='all';selected=0;paint();for(const {b} of buttons)b.onclick=null;page.onclick=null;}};
}

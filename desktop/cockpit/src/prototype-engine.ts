// SPDX-License-Identifier: MIT
// Adapter around the released study engine model/view. Every wire string is
// escaped once before the prototype's trusted HTML renderer; its fmt wrapper
// does not escape again. All non-text substitutions use closed vocabularies.
import {ht} from './host-text.js';
import {accountLabel,updatedCopy,accountState} from './account-line.js';
import {effectiveRedBelow} from './threshold.js';
import type {WireCockpitData,WireWindow,WireAccount} from '../generated/wire.js';
import type {Appearance} from './bridge.js';
import {INITIAL_RANGE,type CockpitRange} from './range.js';
import {cockpitMembers,unavailableZCodeMember} from './members.js';
import {memberColours} from './session-binding.js';
import {bandUsage} from './prototype-cost.js';
import {NEUTRAL} from './livery.js';
import {cautionItems,cautionLevel,lights} from './caution.js';
import {prototypeEngineSupplement,currentWindow,displayWindow,runOutMinutes,runOutFields,forecastOf,forecastLasts,moneyText} from './prototype-data-adapter.js';
import {engineModel,statusBySub,widthClass} from '../study/rocket-r1/engine-model.js';
import {pluginHostOf} from './plugin-host.js';
import {newsLive,newsMark} from './news-clock.js';
import {calendarModel,type CalModel} from './calendar-model.js';
import {paintStrip,stripCard} from './calendar-page.js';
import {mountHoverCards} from './hover-card.js';
import {pageOfSubscription,type LayoutPage} from './plugin-layout.js';
import {engineView,rowsTemplate} from '../study/rocket-r1/engine-view.js';
import {setLanguage,t} from '../study/rocket-r1/i18n.js';
const esc=(value:unknown)=>String(value??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]!));
// Vendor marks are the bundled official-edition files under assets/brands/ (third-party marks, SOURCES.md).
const logos:Readonly<Record<string,string>>={openai:'openai-white.svg',claude:'claude-rounded.svg',cursor:'cursor.svg',copilot:'copilot.svg',kimi:'kimi-white.svg',glm:'zai-white.svg',opencode:'opencode.svg'};
const finite=(v:number|null)=>v!==null&&Number.isFinite(v)?v:null;
const role=(w:WireWindow)=>w.role==='session'&&w.durationSeconds===18000?'5h':w.role==='weekly'&&w.durationSeconds===604800?'week':w.role==='daily'?'day':w.role==='monthly'?'month':'other';
const general=(w:WireWindow)=>!w.modelScope&&w.poolKey==='main'&&(w.role==='session'?(w.limitKey==='main'||w.limitKey==='five_hour'):w.role==='weekly'?(w.limitKey==='main'||w.limitKey==='weekly'):false);
// CKP-ENG-53 / WP-06 (#1050): the range row's ≈cost reads the supplement's optional estCost for today when it is
// present; absent (no price, or WP-06 not merged) means no ≈$, never a guess.
const rangeCost=(detail:object):number|null=>{const usd=(detail as {estCost?:{today?:{usd?:unknown}|null}|null}).estCost?.today?.usd;return typeof usd==='number'&&Number.isFinite(usd)&&usd>0?usd:null;};
// CKP-ENG-53 (G3-156): the column's range row follows the header range. Today: the supplement's today row (tokens, average
// speed) and its ≈cost; 7d / 30d: the subscription's history sums over its bound sources (tokens summed, speed only when one
// source stands alone since averages need their denominators) and the ≈cost of its priced days. History read but nothing
// recorded in the range is "no usage", never "quota only" (which is for a subscription with no usage record at all).
const dayKeyOf=(at:number)=>{const d=new Date(at);return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`;};
function rangeFields(account:WireAccount,data:WireCockpitData,detail:ReturnType<typeof prototypeEngineSupplement>,range:CockpitRange,now:number){
 const ref=account.subscriptionRef,sub=ref===null?undefined:data.history?.subscriptions.find(h=>h.subscriptionRef===ref);
 const sources=new Set((sub?.sources??[]).map(x=>x.source)),readHistory=sources.size>0;
 const days=range==='today'?1:range==='7d'?7:30,clock=new Date(now),keys=new Set(Array.from({length:days},(_,i)=>dayKeyOf(new Date(clock.getFullYear(),clock.getMonth(),clock.getDate()-i).getTime())));
 let usd:number|null=null;
 if(readHistory&&data.history?.cost?.basis==='api-list-price'){let sum=0;for(const b of data.history.cost.daily)if(sources.has(b.source)&&keys.has(b.at)&&b.pricedTokens>0)sum+=b.estimatedUsd;if(sum>0)usd=sum;}
 // D474 §2.5, G-a: the figure is total tokens from cost.* (today) or the subscription's own history sums (7d / 30d); a source
 // shared with another subscription cannot be split, so that column's 今天 cell is "—" with its explanation in the hover.
 const band=bandUsage(data,ref??null,range,now),own=range==='today'?band.from==='cost'||band.shared!==null:false;
 let tokens:number|null=band.tokens,speed:number|null=null;
 if(range==='today'){
  // Speed and the ≈cost stay the supplement's; without prices (no cost.*) the supplement's output reading is the fallback.
  if(!own&&band.from===null)tokens=detail.todayTokens;
  speed=detail.todayAverageGenerationTps;usd=rangeCost(detail)??usd;
 }
 else if(sub&&tokens!==null&&sub.sources.length===1){const g=(range==='7d'?sub.sources[0]!.recent7d:sub.sources[0]!.recent30d).generationTps;speed=g!==null&&g>=0?g:null;}
 const noUsage=readHistory&&tokens===null&&usd===null;
 return {support:tokens!==null||usd!==null||band.shared!==null?'observed':'quota-only',noUsage:noUsage&&band.shared===null,todayAverageGenerationTps:speed,todayTokens:tokens,rangeCost:usd,shared:band.shared,unpricedShare:band.unpricedShare,kinds:band.kinds};
}
// D474 §3.4: a kept reading whose later attempt failed is 失败·2h (error-lastgood): numbers kept, line 1 says how old.
// Only a failure newer than the reading counts (CKP-ENG-55 uses the same comparison for the 全部 key).
const failedAt=(account:WireAccount)=>{const at=account.lastFailure?Date.parse(account.lastFailure.at):NaN;return Number.isFinite(at)?at:null;};
const attemptAt=(account:WireAccount)=>account.valueState==='retained'?failedAt(account):null;
function cellState(account:WireAccount,rowState?:Parameters<typeof accountState>[1]){
 const state=accountState(account,rowState);if(state!=='stale')return state;
 const failed=failedAt(account),observed=account.observedAt?Date.parse(account.observedAt):NaN;
 return failed!==null&&(!Number.isFinite(observed)||failed>observed)?'error-lastgood':state;
}
const updatedText=(at:number,now:number,locale:Appearance['locale'])=>{const c=updatedCopy(at,now);return ht(locale,c.key,{n:c.n});};
export function renderPrototypeEngine(data:WireCockpitData,locale:Appearance['locale'],root:HTMLElement,priorScope:string,onSelect:(key:string)=>boolean,onAdd:()=>boolean,priorPage=0,initialNow=0,redBelow:()=>number=()=>effectiveRedBelow(undefined),showUsed:()=>boolean=()=>false,onRefresh:(key:string)=>boolean=()=>false,range:()=>CockpitRange=()=>INITIAL_RANGE):{table:HTMLElement;applyScope:(scope:string)=>void;pageBy:(step:number)=>boolean;detachHover:()=>void;setRange:()=>void;refresh:(now?:number)=>void;setLocale:(value:Appearance['locale'],now:number)=>void;focusIdentity:(element:HTMLElement)=>string|null;fit:()=>void}|null {
 const members=cockpitMembers(data);if(!members.length)return null;
 const seen=new Map(members.map(x=>[x.key,x]));// D474 §3.1: a page holds as many columns as the language's labels allow (zh 6, en 5; the pseudo-long test locale 4), a
 // string-table number so a language owns its own capacity.
 const perPage=()=>{setLanguage(locale);const n=Number(t('eng.perPage'));return Number.isInteger(n)&&n>=3&&n<=6?n:6;};
 let scope=seen.has(priorScope)?priorScope:'',page=Number.isSafeInteger(priorPage)?Math.max(0,Math.min(priorPage,Math.ceil(members.length/perPage())-1)):0;
 const host=document.createElement('div');host.className='u11-engine-table s6-page';const focusIdentities=new WeakMap<HTMLElement,string>();
 // Producer ordinals can change when a sibling appears; only unique structural meaning proves identity.
 const base=(w:WireWindow)=>`${w.role}:${w.durationSeconds??'unknown'}:${w.limitKey}:${w.poolKey}`;
 const semantic=(w:WireWindow)=>JSON.stringify([w.role,w.durationSeconds,w.limitKey,w.poolKey,w.modelScope?.models?[...w.modelScope.models].sort():null]);
 function sourceAt(now:number){
 const colours=memberColours(members);
 // D466 (band round 1, reverses the plan-name part of D277): a key shows the logo and the short tool name ("Codex",
 // "ZCode" for "ZCode / GLM"); the plan tier is added only (the wire carries no user alias yet) when two shown subscriptions share
 // that short name. The full "Codex Pro 100" stays in the key's tooltip and accessible name.
 const shortOf=(row:typeof members[number]['row'])=>{const name=locale==='en'?row.name.en:row.name.zh;return name.split(' / ')[0]!.trim()||name;};
 const shortCount=new Map<string,number>();for(const m of members)shortCount.set(shortOf(m.row),(shortCount.get(shortOf(m.row))??0)+1);
 const keyNames=new Map<string,string>();
 for(const m of members){const s=shortOf(m.row);keyNames.set(m.key,(shortCount.get(s)??0)>1?accountLabel(s,m.account,locale):s);}
 const accounts=members.map(({key,row,account})=>{
  const brand=row.vendorKey&&Object.hasOwn(logos,row.vendorKey)?{colour:colours.get(key)!,logo:logos[row.vendorKey]!}:null;
  const name=locale==='en'?row.name.en:row.name.zh,label=accountLabel(name,account,locale);
  const ids=new Map<string,number>(),bases=new Map<string,number>(),meanings=new Map<string,number>(),semantics=new Map<WireWindow,string>();
  for(const w of account.windows){const meaning=semantic(w),key=base(w);semantics.set(w,meaning);ids.set(w.id,(ids.get(w.id)??0)+1);bases.set(key,(bases.get(key)??0)+1);meanings.set(meaning,(meanings.get(meaning)??0)+1);}
  const validId=(w:WireWindow)=>{const key=base(w),count=bases.get(key)??0;if(count===1)return w.id===key;const suffix=w.id.startsWith(key+':')?w.id.slice(key.length+1):'';return /^[1-9]\d*$/.test(suffix)&&Number.isSafeInteger(Number(suffix))&&Number(suffix)<=count;};
  const runOut=(w:WireWindow)=>runOutMinutes(data,row.id,account,w,now,true);// CKP-ENG-26: an unknown reset does not hide a forecast run-out
  const convert=(w:WireWindow)=>({focusIdentity:validId(w)&&ids.get(w.id)===1&&meanings.get(semantics.get(w)!)===1?semantics.get(w)!:null,kind:role(w),remaining:displayWindow(account,w,now)?finite(w.remainingPercent):null,resetIn:displayWindow(account,w,now)&&w.resetsAt&&Number.isFinite(Date.parse(w.resetsAt))?Math.max(0,(Date.parse(w.resetsAt)-now)/60000):null,resetAt:null,resetText:null,elapsed:null,...runOutFields(runOut(w)),lasts:forecastLasts(data,row.id,account,w,now),resetPassed:!!w.resetsAt&&Number.isFinite(Date.parse(w.resetsAt))&&Date.parse(w.resetsAt)<=now,durationMinutes:w.durationSeconds===null?null:w.durationSeconds/60});
  const windows=account.windows.filter(general).map(convert);
  const extras=account.windows.filter(w=>!general(w)).map(w=>({...convert(w),period:role(w),named:!!w.modelScope||w.limitKey==='mcp',name:esc(locale==='en'?w.label.en:w.label.zh),label:esc(locale==='en'?w.label.en:w.label.zh),scope:{label:esc(locale==='en'?w.label.en:w.label.zh)}}));
  // D466: a reset announcement is news on the key (one blue dot) and, once a banked reset is confirmed, a "+1" in the
  // reserve, both for its news clock only (DOCK-3.7-05). It never reaches a quota cell.
  const news=(data.details?.resetEvents??[]).filter(e=>e.rowId===row.id&&(!e.planIds?.length||e.planIds.includes(account.plan.id))&&newsLive(e,data,now));
  const plus=news.filter(e=>e.status==='confirmed'&&e.kind==='reset_credit').length;
  // G3-109: a money balance (Grok Build) has no credits/points; the reserve row shows it in its reported currency.
  const money=moneyText(account.credits,locale);
  const detail=prototypeEngineSupplement(account,data), cards=detail.resetCards?.map(c=>({count:c.count,expiresAt:c.expiresAt?Date.parse(c.expiresAt):null}))??[];
  return {id:esc(key),name:esc(label),short:esc(keyNames.get(key)??label),plan:esc((account.plan.name?(locale==='en'?account.plan.name.en:account.plan.name.zh):'').trim()),updated:esc(account.observedAt&&Number.isFinite(Date.parse(account.observedAt))?updatedText(Date.parse(account.observedAt),now,locale):''),alias:esc(keyNames.get(key)??name),colour:brand?.colour??NEUTRAL,logo:brand?brand.logo:'../../neutral.png',state:cellState(account,unavailableZCodeMember(row,account)?row.state:undefined),attemptAt:attemptAt(account),ageMin:(()=>{const at=account.observedAt?Date.parse(account.observedAt):NaN;return Number.isFinite(at)?Math.max(0,Math.floor((now-at)/60000)):null;})(),...rangeFields(account,data,detail,range(),now),tool:esc(shortOf(row)),usage7:null,windows,extras,forecast:forecastOf(windows),news:news.some(e=>e.status==='confirmed')?'confirmed':news.length?'announced':null,newsMarks:news.map(newsMark).join(' '),plus,plusMarks:news.filter(e=>e.status==='confirmed'&&e.kind==='reset_credit').map(newsMark).join(' '),cards,credits:detail.reserveCredits&&['credits','points'].includes(detail.reserveCredits.unit)&&finite(detail.reserveCredits.balance)!==null?{balance:detail.reserveCredits.balance,drawing:false}:money!==null?{balance:account.credits!.balance,drawing:false,money:esc(money)}:null};
 });
 // Owner D38: only red (at or below T) and forecast amber conditions wash a column or light the lamp.
 const items=cautionItems(data,now,redBelow());
 const alerts=items.flatMap(x=>lights(x)?[{level:x.level,sub:esc(x.member)}]:[]);
 const level=cautionLevel(items);
 const caution=root.querySelector<HTMLElement>('.ck-lamp .caution');if(caution){caution.classList.toggle('lit',!!level);caution.classList.toggle('red',level==='red');caution.classList.toggle('amber',level==='amber');caution.setAttribute('aria-label',level?(ht(locale,'host.alertActive')):(ht(locale,'host.alertInactive')));}
 return {now,accounts,alerts,caution:{level,key:''}};
 }
 // Plugin columns (D124, D293): with a plugin host, pages and widths follow the plugin layout; the study model still
 // draws each page's subscriptions, and the host turns the page's first empty slots into its plugin columns.
 const plugins=pluginHostOf(root);
 const pageCount=()=>plugins?plugins.layout(members.length,perPage()).pages.length:Math.ceil(members.length/perPage());
 const pageOf=(index:number)=>plugins?pageOfSubscription(plugins.layout(members.length,perPage()),index):Math.floor(index/perPage());
 const pagedModel=(source:ReturnType<typeof sourceAt>,ui:{page:number;colWidth:number|null}):{model:any;plugins:LayoutPage|null}=>{
  if(!plugins)return {model:engineModel(source,ui),plugins:null};
  const layout=plugins.layout(members.length,perPage()),p=Math.max(0,Math.min(ui.page,layout.pages.length-1)),shown=layout.pages[p];
  const model=engineModel({...source,accounts:source.accounts.slice(shown.from,shown.to)},{...ui,page:0,few:'c3'});
  const status=statusBySub(source.alerts),grey=new Set(['stale','error','error-lastgood']),rank=(l:string|null)=>l==='red'?2:l==='amber'?1:0;
  model.leds=layout.pages.map((x,i)=>{const list=source.accounts.slice(x.from,x.to),levels=list.map(a=>grey.has(a.state)?null:status.get(a.id)??null);
   return {page:i,current:i===p,accounts:list.map((a,j)=>({name:a.name,status:levels[j]})),level:levels.reduce<string|null>((l,v)=>rank(v)>rank(l)?v:l,null)};});
  Object.assign(model,{pages:layout.pages.length,page:p,slots:shown.slots,cls:widthClass(shown.slots,ui.colWidth)});
  return {model,plugins:shown};
 };
 let renderedNow=initialNow;
 const firstShown=()=>plugins?plugins.layout(members.length,perPage()).pages[Math.min(page,pageCount()-1)]?.from??0:page*perPage();
 // D474 §6.1, one threshold: the width class follows the measured column width ((band − label column) / slots), so a
 // narrower window or a longer label column changes the cell forms, not the column count. Unmeasured: by slots.
 let colWidth:number|null=null;
 const measuredColumn=()=>{const cols=host.querySelector<HTMLElement>('.eng-cols'),n=Number(host.querySelector<HTMLElement>('.eng-keys')?.dataset.slots);return cols&&cols.isConnected&&cols.clientWidth>0&&n>0?cols.clientWidth/n:null;};
 let calendar:CalModel|null=null;
 const paint=(time?:number)=>{
  if(time!==undefined)renderedNow=time;const now=renderedNow,source=sourceAt(now);setLanguage(locale);const per=perPage(),ui={per,few:members.length<=per?'c3':'a',page,scope:scope?esc(scope):null,range:range(),tint:true,pctMode:showUsed()?'used':'left',redAt:redBelow(),ack:null,lang:locale,now,colWidth};
  const {model,plugins:pluginPage}=pagedModel(source,ui);page=model.page;host.dataset.cls=model.cls;host.style.setProperty('--n',String(model.slots));// Unknown vendors have no mark: drop the study's neutral placeholder before parsing so nothing is requested.
  hideCard();
  plugins?.hold();// D323: a focused drawn plugin control is taken back by its new column
  host.innerHTML=engineView(model,{changed:new Set(),lang:locale,now}).replace(/ style="/g,' data-study-style="').replaceAll('<img class="lamp" src="assets/brands/../../neutral.png" alt="">','');
  if(plugins&&pluginPage)plugins.decorate(host,pluginPage,locale);
  // D466: every subscription column carries its 24 h strip at the right edge (always, even when empty: it is the way
  // into the calendar). A click opens the big screen's 日历 tab for that subscription.
  calendar=calendarModel(data,now);
  for(const column of host.querySelectorAll<HTMLElement>('.eng-cols > .ec[data-col]:not(.pl-col)')){
   const sub=calendar.subs.findIndex(x=>esc(x.key)===column.dataset.col);if(sub>=0)paintStrip(column,calendar,sub,locale);
  }
  // Keep the selected source-window identity in memory, never in rendered HTML.
  for(const [index,column] of [...host.querySelectorAll<HTMLElement>('.eng-cols > .ec[data-col]')].entries()){const rendered=model.cols[index];for(const cell of column.querySelectorAll<HTMLElement>('.qcell[data-row]')){const identity=rendered?.cells?.[cell.dataset.row??'']?.focusIdentity;if(typeof identity==='string')focusIdentities.set(cell,identity);}}
  // Inline style attributes from the study HTML are blocked by the host CSP.
  // Apply only validated model-derived layout and fixed palette values through
  // CSSOM; wire text is never interpreted as CSS.
  for(const el of host.querySelectorAll<HTMLElement>('.eng-keys,.eng-lcd'))el.style.setProperty('--n',String(model.slots));
  host.querySelector<HTMLElement>('.eng-lcd')?.style.setProperty('--rows',rowsTemplate(model));
  const keys=host.querySelector<HTMLElement>('.eng-keys');if(keys)keys.dataset.slots=String(model.slots);
  for(const [index,el] of [...host.querySelectorAll<HTMLElement>('.eng-keys .ek[data-sub] .bl')].entries()){
   const colour=model.cols[index]?.colour;if(typeof colour==='string'&&/^#[0-9a-f]{6}$/i.test(colour))el.style.setProperty('--v',colour);
  }
  for(const cell of host.querySelectorAll<HTMLElement>('.qcell')){
   const state=['ok','mid','low'].find(x=>cell.classList.contains('lv-'+x));
   if(state){cell.style.setProperty('--qf',`var(--st-${state})`);if(state!=='ok')cell.style.setProperty('--qn',`var(--st-${state})`);}
  }
  // These bridge rows have no today metrics until the details capability supplies them.
  for(const row of host.querySelectorAll<HTMLElement>('.qrow-t'))row.dataset.available=String(!!row.querySelector('.qtokens,.qaverage'));
  // Native supplies only allowlisted marks; retain the established accessibility hook.
  for(const image of host.querySelectorAll<HTMLImageElement>('.ek img.lamp'))image.classList.add('vendor-mark');
  // Unknown vendors have no mark; never turn their input into an image URL.
  for(const image of host.querySelectorAll<HTMLImageElement>('img[src="assets/brands/../../neutral.png"]'))image.remove();
  for(const b of host.querySelectorAll<HTMLButtonElement>('.ek[data-sub]')){const member=seen.get(b.dataset.sub??'');if(member){b.dataset.scope=member.key;b.dataset.unstable=String(member.unstable);const name=locale==='en'?member.row.name.en:member.row.name.zh;const digit=b.querySelector('.ki')?.textContent??'';const shortcut=ht(locale,'host.shortcutKey',{digit});// The key's accessible NAME stays "name · shortcut" (stable for assistive tech and the native host); the card's facts ride as its description.
   b.setAttribute('aria-description',[b.dataset.hcFacts?.split('\n').join(' · '),b.dataset.hcBasis].filter(Boolean).join(' · '));b.setAttribute('aria-label',`${name} · ${shortcut}`);b.dataset.hcFacts=[b.dataset.hcFacts,shortcut].filter(Boolean).join('\n');const label=b.querySelector<HTMLElement>('.ek-name');label?.removeAttribute('title');/* the shared hover card replaces the native tooltip */}}
  const all=host.querySelector<HTMLButtonElement>('.ek[data-all]');if(all){all.dataset.scope='';const shortcut=ht(locale,'host.shortcutKey',{digit:0});all.setAttribute('aria-label',`${ht(locale,'host.allScope')} · ${shortcut}`);all.title=shortcut;}
  root.dataset.scope=scope?'subscription':'all';
  // C27 (D474): the 全部 key carries no stale dot; failing reads say so in their own column (失败·2h) and the grey line.
  fit();
  hover.refresh();
 };
 // G3-109: a cell line that does not fit its column takes the view's shorter forms (data-short, then data-small);
 // CSS ellipsis is the last resort. Measured again whenever the table's width changes (not laid out yet: skipped).
 let watch:ResizeObserver|null=null;
 // The width watch starts once the table is in the page: WebKit reports nothing for a target observed while detached.
 function fit(){
  if(!watch&&host.isConnected&&typeof ResizeObserver!=='undefined'){watch=new ResizeObserver(fit);watch.observe(host);}
  const measured=measuredColumn(),slots=Number(host.querySelector<HTMLElement>('.eng-keys')?.dataset.slots);
  if(measured!==null&&Math.abs(measured-(colWidth??-1))>0.5){colWidth=measured;if(widthClass(slots,measured)!==host.dataset.cls){paint();return;}}
  const entries=[...host.querySelectorAll<HTMLElement>('.qtxt[data-full],.qrv-p[data-full],.ek-name[data-full],.qrv-c[data-full],.qrv-x[data-full],.pl-fit[data-full]')]
   .filter(e=>e.isConnected&&e.clientWidth>0).map(e=>({e,forms:[e.dataset.full,e.dataset.short,e.dataset.small].filter((v):v is string=>!!v)}));
  // Batch writes and width reads: interleaving them forces a full layout for each label on a page switch.
  const setText=(e:HTMLElement,text:string)=>{if(e.textContent!==text)e.textContent=text;};
  for(const {e,forms} of entries)setText(e,forms[0]??'');
  for(let i=1;i<=2;i++){
   const shorten=entries.filter(({e,forms})=>i<forms.length&&e.scrollWidth>e.clientWidth);
   for(const {e,forms} of shorten)setText(e,forms[i]);
  }
  // D474 §3.1: a narrow reserve line whose short forms still do not fit drops its count, so the expiry clause stays whole.
  const reserves=[...host.querySelectorAll<HTMLElement>('.qrow-r')].filter(row=>row.isConnected&&row.clientWidth>0);
  for(const row of reserves)for(const d of row.querySelectorAll<HTMLElement>('[data-drop]'))d.classList.remove('drop');
  const tight=reserves.filter(row=>[...row.children].some(c=>c.scrollWidth>c.clientWidth));
  for(const row of tight)for(const d of row.querySelectorAll<HTMLElement>('[data-drop]'))d.classList.add('drop');
  const hidden=entries.filter(({e})=>e.classList.contains('pl-side')&&e.scrollWidth>e.clientWidth);
  for(const {e} of hidden)setText(e,''); // D371 Q5: an unfit plugin side value is hidden, never cut.
  // D464 (§14 order reversed): drop speed first, then ≈cost; tokens always stay.
  const rows=[...host.querySelectorAll<HTMLElement>('.qrow-t')].filter(row=>row.isConnected&&row.clientWidth>0)
   .map(row=>({row,parts:[row.querySelector<HTMLElement>('.qaverage'),row.querySelector<HTMLElement>('.qtokens')?row.querySelector<HTMLElement>('.qcost'):null]}));
  for(const {parts} of rows)for(const part of parts)part?.classList.remove('drop');
  for(let i=0;i<2;i++){
   const overflow=rows.filter(({row})=>row.scrollWidth>row.clientWidth);
   for(const {parts} of overflow)parts[i]?.classList.add('drop');
  }
  hover.refresh();
 }

 // Owner D76: the Reserve label's hint (and, macrevb-1020-2, a quota cell's own details: its unknown reset time), in the MFD's floating LCD tip style (study mfd.css .mfd-tip), on hover or focus.
 // Text only and never takes pointer events; the label also carries it as its accessible name.
 const hint=document.createElement('div');hint.className='mfd-tip eng-hint';hint.setAttribute('role','tooltip');hint.hidden=true;
 const hideHint=()=>{hint.hidden=true;hint.replaceChildren();hint.remove();};
 const showHint=(target:EventTarget|null)=>{const label=target instanceof Element?target.closest<HTMLElement>('.lb-r[data-tip],.qcell[data-tip]'):null;if(!label||!host.contains(label)){hideHint();return;}
  hint.replaceChildren(...(label.dataset.tip??'').split('\n').filter(Boolean).map((line,i)=>{const e=document.createElement('span');if(!i)e.className='h';e.textContent=line;return e;}));
  (root.querySelector('#cockpit')??document.body).append(hint);hint.hidden=false;const r=label.getBoundingClientRect(),w=hint.offsetWidth,h=hint.offsetHeight;
  // Above the label, so it never covers the reserve values beside it.
  hint.style.left=Math.max(4,Math.min(window.innerWidth-w-4,r.left))+'px';hint.style.top=Math.max(4,r.top-h-4)+'px';};
 // D466: the strip's hover card ("接下来 24 小时") opens to the left of the strip; it stays while the pointer is on the
 // strip or on the card (its "7 天日历 ›" link), and on keyboard focus.
 const cockpit=()=>root.querySelector<HTMLElement>('#cockpit')??root;
 const openCalendar=(key:string)=>{hideCard();root.dispatchEvent(new CustomEvent('cockpit-calendar',{detail:{scope:key,range:'7d'}}));};
 // D474 §7.1: one shared hover card for the cells, the range row, the reserve row and the keys (400 ms, Esc, same text in
 // aria-label). It never covers the HUD, and a redraw of the cells keeps an open card (refresh below).
 const hover=mountHoverCards(host,{owner:'engine',container:cockpit,avoid:()=>root.querySelector<HTMLElement>('.hud')?.getBoundingClientRect()??null});
 let card:HTMLElement|null=null;
 const hideCard=()=>{card?.remove();card=null;};
 const showCard=(hit:HTMLElement)=>{const sub=Number(hit.dataset.strip),key=calendar?.subs[sub]?.key;if(!calendar||key===undefined)return;hideHint();
  card=stripCard(cockpit(),hit,calendar,sub,locale,()=>openCalendar(key));
  card.addEventListener('pointerleave',e=>{if(!(e.relatedTarget instanceof Element&&e.relatedTarget.closest('.ec-strip')))hideCard();});};
 host.addEventListener('pointerover',e=>{const hit=e.target instanceof Element?e.target.closest<HTMLElement>('.ec-strip'):null;if(hit&&host.contains(hit)){if(card?.dataset.strip!==hit.dataset.strip){showCard(hit);if(card)card.dataset.strip=hit.dataset.strip??'';}}});
 host.addEventListener('pointerout',e=>{const from=e.target instanceof Element?e.target.closest('.ec-strip'):null,to=e.relatedTarget instanceof Element?e.relatedTarget:null;if(from&&!(to&&(to.closest('.ec-next')||from.contains(to))))hideCard();});
 host.addEventListener('focusin',e=>{const hit=e.target instanceof Element?e.target.closest<HTMLElement>('.ec-strip'):null;if(hit){showCard(hit);if(card)card.dataset.strip=hit.dataset.strip??'';}});
 host.addEventListener('focusout',e=>{const to=e.relatedTarget instanceof Element?e.relatedTarget:null;if(!(to&&to.closest('.ec-next')))hideCard();});
 host.addEventListener('click',e=>{if(!e.isTrusted)return;const hit=e.target instanceof Element?e.target.closest<HTMLElement>('.ec-strip'):null;const key=hit?calendar?.subs[Number(hit.dataset.strip)]?.key:undefined;if(key!==undefined)openCalendar(key);});
 // D474 §7.2: a band cell scopes to its subscription and opens 订阅 on it; the reserve row opens 订阅 at the reserve (the
 // scoped page lists it). The strip has its own click (日历), and a key its own scope.
 host.addEventListener('click',e=>{
  if(!e.isTrusted)return;const el=e.target instanceof Element?e.target.closest<HTMLElement>('.qcell[data-hc-key],.qrow[data-hc-key]'):null;
  if(!el||!host.contains(el)||el.closest('.ec-strip'))return;
  const key=el.closest<HTMLElement>('.ec[data-col]')?.dataset.col??'';if(!key||!seen.has(key))return;
  if(plugins?.dismissScreen())paint();
  if(key!==scope){if(!onSelect(key))return;scope=key;paint();}
  root.dispatchEvent(new CustomEvent('cockpit-open-subscription',{detail:{reserve:el.classList.contains('qrow-r')}}));
 });
 // D474 §7.3 (G-d): Tab walks the band column by column (each column's cells top to bottom, then its strip: the DOM order);
 // the arrow keys move across rows and columns, to the cell with the same row in the neighbouring column.
 const ROW_ORDER=['first','second','other','range','reserve'];
 const rowKey=(e:HTMLElement)=>e.dataset.row??(e.classList.contains('qrow-t')?'range':'reserve');
 host.addEventListener('keydown',e=>{
  if(!e.isTrusted||e.altKey||e.ctrlKey||e.metaKey||e.shiftKey)return;
  const dir=e.key==='ArrowLeft'?[-1,0]:e.key==='ArrowRight'?[1,0]:e.key==='ArrowUp'?[0,-1]:e.key==='ArrowDown'?[0,1]:null;if(!dir)return;
  const from=e.target instanceof Element?e.target.closest<HTMLElement>('.qcell[tabindex],.qrow[tabindex]'):null;if(!from||!host.contains(from))return;
  const cols=[...host.querySelectorAll<HTMLElement>('.eng-cols > .ec[data-col]:not(.pl-col)')].map(c=>[...c.querySelectorAll<HTMLElement>(':scope > .qcell[tabindex],:scope > .qrow[tabindex]')]);
  const ci=cols.findIndex(c=>c.includes(from));if(ci<0)return;
  let to:HTMLElement|undefined;
  if(dir[0]!==0){
   const next=cols[ci+dir[0]!];if(!next?.length)return;
   const at=ROW_ORDER.indexOf(rowKey(from));
   to=next.reduce((best,x)=>Math.abs(ROW_ORDER.indexOf(rowKey(x))-at)<Math.abs(ROW_ORDER.indexOf(rowKey(best))-at)?x:best,next[0]!);
  }else to=cols[ci]![cols[ci]!.indexOf(from)+dir[1]!];
  if(!to)return;e.preventDefault();to.focus();
 });
 host.addEventListener('pointerover',e=>showHint(e.target));host.addEventListener('pointerleave',hideHint);
 host.addEventListener('focusin',e=>showHint(e.target));host.addEventListener('focusout',hideHint);
 host.onclick=e=>{if(!e.isTrusted)return;const b=(e.target as Element).closest<HTMLButtonElement>('button');if(!b||!host.contains(b))return;
    if(b.hasAttribute('data-add-subscription')){if(plugins){plugins.openMenu(b,{data,locale,mark:vendorKey=>vendorKey&&Object.hasOwn(logos,vendorKey)?'assets/brands/'+logos[vendorKey]:null,connect:onAdd});return;}onAdd();return;}
  // D401: a screen covering the panel hides the selection (not changes it); the first press ends the screen, and the key of the remembered selection only brings it back.
  const covered=(b.hasAttribute('data-all')||b.hasAttribute('data-sub'))&&(plugins?.dismissScreen()??false);
  if(b.hasAttribute('data-all')){if(covered&&scope===''){paint();return;}if(onSelect('all')){scope='';paint();}return;}
  if(b.hasAttribute('data-sub')){const key=b.dataset.sub??'';if(!seen.has(key))return;if(key===scope){if(covered){paint();return;}if(onSelect('all')){scope='';paint();}return;}if(onSelect(key)){scope=key;paint();}return;}
  if(b.hasAttribute('data-bpage')){const step=b.dataset.bpage==='1'?1:b.dataset.bpage==='-1'?-1:0;page=Math.max(0,Math.min(pageCount()-1,page+step));paint();}
 };
 const applyScope=(next:string)=>{scope=next!=='all'&&seen.has(next)?next:'';if(scope){const index=members.findIndex(m=>m.key===scope);page=pageOf(index);}paint();};
 plugins?.bindEngine(()=>paint());paint();const pageBy=(step:number)=>{const next=Math.max(0,Math.min(pageCount()-1,page+step));if(next===page)return false;page=next;paint();return true;};
 return {table:host,applyScope,pageBy,detachHover:hover.detach,setRange(){paint();},refresh:paint,setLocale(value,now){const before=perPage(),first=firstShown();locale=value;// A language switch that changes the page capacity keeps the scoped subscription on screen (when it was), else the first column on screen; one that does not leaves the page alone.
  if(perPage()!==before){const at=scope?members.findIndex(m=>m.key===scope):-1,shown=at>=first&&at<first+before;page=pageOf(Math.max(0,shown?at:first));}paint(now);},focusIdentity(element){return focusIdentities.get(element)??null;},fit};
}

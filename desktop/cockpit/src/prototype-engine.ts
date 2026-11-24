// SPDX-License-Identifier: MIT
// Adapter around the released study engine model/view. Every wire string is
// escaped once before the prototype's trusted HTML renderer; its fmt wrapper
// does not escape again. All non-text substitutions use closed vocabularies.
import {ht} from './host-text.js';
import {accountLabel,updatedCopy,accountState,footerState} from './account-line.js';
import {effectiveRedBelow} from './threshold.js';
import type {WireCockpitData,WireWindow} from '../generated/wire.js';
import type {Appearance} from './bridge.js';
import {cockpitMembers} from './members.js';
import {memberColours} from './session-binding.js';
import {NEUTRAL} from './livery.js';
import {cautionItems,cautionLevel,lights} from './caution.js';
import {prototypeEngineSupplement,currentWindow,displayWindow,runOutMinutes,runOutFields,forecastOf,moneyText} from './prototype-data-adapter.js';
import {engineModel,statusBySub,widthClass} from '../study/rocket-r1/engine-model.js';
import {pluginHostOf} from './plugin-host.js';
import {pageOfSubscription,type LayoutPage} from './plugin-layout.js';
import {engineView,rowsTemplate} from '../study/rocket-r1/engine-view.js';
import {setLanguage} from '../study/rocket-r1/i18n.js';
const esc=(value:unknown)=>String(value??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]!));
// Vendor marks are the bundled official-edition files under assets/brands/ (third-party marks, SOURCES.md).
const logos:Readonly<Record<string,string>>={openai:'openai-white.svg',claude:'claude-rounded.svg',cursor:'cursor.svg',copilot:'copilot.svg',kimi:'kimi-white.svg',glm:'zai-white.svg',opencode:'opencode.svg'};
const finite=(v:number|null)=>v!==null&&Number.isFinite(v)?v:null;
const role=(w:WireWindow)=>w.role==='session'&&w.durationSeconds===18000?'5h':w.role==='weekly'&&w.durationSeconds===604800?'week':w.role==='daily'?'day':w.role==='monthly'?'month':'other';
const general=(w:WireWindow)=>!w.modelScope&&w.poolKey==='main'&&(w.role==='session'?(w.limitKey==='main'||w.limitKey==='five_hour'):w.role==='weekly'?(w.limitKey==='main'||w.limitKey==='weekly'):false);
// CKP-ENG-53 / WP-06 (#1050): the range row's ≈cost reads the supplement's optional estCost for today when it is
// present; absent (no price, or WP-06 not merged) means no ≈$, never a guess.
const rangeCost=(detail:object):number|null=>{const usd=(detail as {estCost?:{today?:{usd?:unknown}|null}|null}).estCost?.today?.usd;return typeof usd==='number'&&Number.isFinite(usd)&&usd>0?usd:null;};
const updatedText=(at:number,now:number,locale:Appearance['locale'])=>{const c=updatedCopy(at,now);return ht(locale,c.key,{n:c.n});};
export function renderPrototypeEngine(data:WireCockpitData,locale:Appearance['locale'],root:HTMLElement,priorScope:string,onSelect:(key:string)=>boolean,onAdd:()=>boolean,priorPage=0,initialNow=0,redBelow:()=>number=()=>effectiveRedBelow(undefined),showUsed:()=>boolean=()=>false,onRefresh:(key:string)=>boolean=()=>false):{table:HTMLElement;applyScope:(scope:string)=>void;refresh:(now?:number)=>void;setLocale:(value:Appearance['locale'],now:number)=>void;focusIdentity:(element:HTMLElement)=>string|null;fit:()=>void}|null {
 const members=cockpitMembers(data);if(!members.length)return null;
 const seen=new Map(members.map(x=>[x.key,x]));let scope=seen.has(priorScope)?priorScope:'',page=Number.isSafeInteger(priorPage)?Math.max(0,Math.min(priorPage,Math.ceil(members.length/6)-1)):0;
 const host=document.createElement('div');host.className='u11-engine-table s6-page';const focusIdentities=new WeakMap<HTMLElement,string>();
 // Producer ordinals can change when a sibling appears; only unique structural meaning proves identity.
 const base=(w:WireWindow)=>`${w.role}:${w.durationSeconds??'unknown'}:${w.limitKey}:${w.poolKey}`;
 const semantic=(w:WireWindow)=>JSON.stringify([w.role,w.durationSeconds,w.limitKey,w.poolKey,w.modelScope?.models?[...w.modelScope.models].sort():null]);
 function sourceAt(now:number){
 const colours=memberColours(members);
 const accounts=members.map(({key,row,account})=>{
  const brand=row.vendorKey&&Object.hasOwn(logos,row.vendorKey)?{colour:colours.get(key)!,logo:logos[row.vendorKey]!}:null;
  const name=locale==='en'?row.name.en:row.name.zh,label=accountLabel(name,account,locale);
  const ids=new Map<string,number>(),bases=new Map<string,number>(),meanings=new Map<string,number>(),semantics=new Map<WireWindow,string>();
  for(const w of account.windows){const meaning=semantic(w),key=base(w);semantics.set(w,meaning);ids.set(w.id,(ids.get(w.id)??0)+1);bases.set(key,(bases.get(key)??0)+1);meanings.set(meaning,(meanings.get(meaning)??0)+1);}
  const validId=(w:WireWindow)=>{const key=base(w),count=bases.get(key)??0;if(count===1)return w.id===key;const suffix=w.id.startsWith(key+':')?w.id.slice(key.length+1):'';return /^[1-9]\d*$/.test(suffix)&&Number.isSafeInteger(Number(suffix))&&Number(suffix)<=count;};
  const runOut=(w:WireWindow)=>runOutMinutes(data,row.id,account,w,now,true);// CKP-ENG-26: an unknown reset does not hide a forecast run-out
  const convert=(w:WireWindow)=>({focusIdentity:validId(w)&&ids.get(w.id)===1&&meanings.get(semantics.get(w)!)===1?semantics.get(w)!:null,kind:role(w),remaining:displayWindow(account,w,now)?finite(w.remainingPercent):null,resetIn:displayWindow(account,w,now)&&w.resetsAt&&Number.isFinite(Date.parse(w.resetsAt))?Math.max(0,(Date.parse(w.resetsAt)-now)/60000):null,resetAt:null,resetText:null,elapsed:null,...runOutFields(runOut(w)),durationMinutes:w.durationSeconds===null?null:w.durationSeconds/60});
  const windows=account.windows.filter(general).map(convert);
  const extras=account.windows.filter(w=>!general(w)).map(w=>({...convert(w),period:role(w),name:esc(locale==='en'?w.label.en:w.label.zh),label:esc(locale==='en'?w.label.en:w.label.zh),scope:{label:esc(locale==='en'?w.label.en:w.label.zh)}}));
  const notice=data.details?.resetEvents.find(e=>e.rowId===row.id&&Date.parse(e.expiresAt)>now&&(!e.planIds?.length||e.planIds.includes(account.plan.id)));
  // G3-109: a money balance (Grok Build) has no credits/points; the reserve row shows it in its reported currency.
  const money=moneyText(account.credits,locale);
  const detail=prototypeEngineSupplement(account,data), cards=detail.resetCards?.map(c=>({count:c.count,expiresAt:c.expiresAt?Date.parse(c.expiresAt):null}))??[];
  return {id:esc(key),name:esc(label),short:esc(label),alias:esc(name),colour:brand?.colour??NEUTRAL,logo:brand?brand.logo:'../../neutral.png',state:accountState(account),ageMin:(()=>{const at=account.observedAt?Date.parse(account.observedAt):NaN;return Number.isFinite(at)?Math.max(0,Math.floor((now-at)/60000)):null;})(),support:detail.todayTokens!==null?'observed':'quota-only',todayAverageGenerationTps:detail.todayAverageGenerationTps,todayTokens:detail.todayTokens,rangeCost:rangeCost(detail),usage7:null,windows,extras,forecast:forecastOf(windows),event:notice?{status:notice.status,at:null}:null,cards,credits:detail.reserveCredits&&['credits','points'].includes(detail.reserveCredits.unit)&&finite(detail.reserveCredits.balance)!==null?{balance:detail.reserveCredits.balance,drawing:false}:money!==null?{balance:account.credits!.balance,drawing:false,money:esc(money)}:null};
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
 const pageCount=()=>plugins?plugins.layout(members.length).pages.length:Math.ceil(members.length/6);
 const pageOf=(index:number)=>plugins?pageOfSubscription(plugins.layout(members.length),index):Math.floor(index/6);
 const pagedModel=(source:ReturnType<typeof sourceAt>,ui:{page:number}):{model:any;plugins:LayoutPage|null}=>{
  if(!plugins)return {model:engineModel(source,ui),plugins:null};
  const layout=plugins.layout(members.length),p=Math.max(0,Math.min(ui.page,layout.pages.length-1)),shown=layout.pages[p];
  const model=engineModel({...source,accounts:source.accounts.slice(shown.from,shown.to)},{...ui,page:0,few:'c3'});
  const status=statusBySub(source.alerts),grey=new Set(['stale','error','error-lastgood']),rank=(l:string|null)=>l==='red'?2:l==='amber'?1:0;
  model.leds=layout.pages.map((x,i)=>{const list=source.accounts.slice(x.from,x.to),levels=list.map(a=>grey.has(a.state)?null:status.get(a.id)??null);
   return {page:i,current:i===p,accounts:list.map((a,j)=>({name:a.name,status:levels[j]})),level:levels.reduce<string|null>((l,v)=>rank(v)>rank(l)?v:l,null)};});
  Object.assign(model,{pages:layout.pages.length,page:p,slots:shown.slots,cls:widthClass(shown.slots)});
  return {model,plugins:shown};
 };
 let renderedNow=initialNow;
 const paint=(time?:number)=>{
  if(time!==undefined)renderedNow=time;const now=renderedNow,source=sourceAt(now);setLanguage(locale);const ui={few:members.length<=6?'c3':'a',page,scope:scope?esc(scope):null,tint:true,pctMode:showUsed()?'used':'left',redAt:redBelow(),ack:null,lang:locale,now};
  const {model,plugins:pluginPage}=pagedModel(source,ui);page=model.page;host.dataset.cls=model.cls;host.style.setProperty('--n',String(model.slots));// Unknown vendors have no mark: drop the study's neutral placeholder before parsing so nothing is requested.
  plugins?.hold();// D323: a focused drawn plugin control is taken back by its new column
  host.innerHTML=engineView(model,{changed:new Set(),lang:locale,now}).replaceAll('<img class="lamp" src="assets/brands/../../neutral.png" alt="">','');
  if(plugins&&pluginPage)plugins.decorate(host,pluginPage,locale);
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
  for(const b of host.querySelectorAll<HTMLButtonElement>('.ek[data-sub]')){const member=seen.get(b.dataset.sub??'');if(member){b.dataset.scope=member.key;b.dataset.unstable=String(member.unstable);const name=locale==='en'?member.row.name.en:member.row.name.zh;const digit=b.querySelector('.ki')?.textContent??'';const shortcut=ht(locale,'host.shortcutKey',{digit});b.setAttribute('aria-label',`${name} · ${shortcut}`);b.title=`${name} · ${shortcut}`;const label=b.querySelector<HTMLElement>('.ek-name');if(label)label.title=b.title;}}
  const all=host.querySelector<HTMLButtonElement>('.ek[data-all]');if(all){all.dataset.scope='';const shortcut=ht(locale,'host.shortcutKey',{digit:0});all.setAttribute('aria-label',`${ht(locale,'host.allScope')} · ${shortcut}`);all.title=shortcut;}
  root.dataset.scope=scope?'subscription':'all';
  // D376: no strip under the table (the update line moved to the overview's bottom line). Reads that keep failing
  // (CKP-ENG-55) stay visible as an amber dot on the 全部 key, whichever MFD page is showing.
  if(all&&footerState(members.map(m=>m.account)).failing){const dot=document.createElement('i');dot.className='ek-stale';dot.setAttribute('aria-hidden','true');all.append(dot);all.title=ht(locale,'host.staleDot');all.setAttribute('aria-label',`${ht(locale,'host.allScope')} · ${ht(locale,'host.staleDot')}`);}
  fit();
 };
 // G3-109: a cell line that does not fit its column takes the view's shorter forms (data-short, then data-small);
 // CSS ellipsis is the last resort. Measured again whenever the table's width changes (not laid out yet: skipped).
 let watch:ResizeObserver|null=null;
 // The width watch starts once the table is in the page: WebKit reports nothing for a target observed while detached.
 function fit(){if(!watch&&host.isConnected&&typeof ResizeObserver!=='undefined'){watch=new ResizeObserver(fit);watch.observe(host);}for(const e of host.querySelectorAll<HTMLElement>('.qtxt[data-full],.qrv-p[data-full],.ek-name[data-full],.qrv-c[data-full],.pl-fit[data-full]')){if(!e.isConnected||e.clientWidth<=0)continue;const forms=[e.dataset.full,e.dataset.short,e.dataset.small].filter((v):v is string=>!!v);e.textContent=forms[0]??'';for(const form of forms.slice(1)){if(e.scrollWidth<=e.clientWidth)break;e.textContent=form;}if(e.classList.contains('pl-side')&&e.scrollWidth>e.clientWidth)e.textContent='';}// D371 Q5: a plugin side value that does not fit even short is hidden, never cut
  // CKP-ENG-53 (§14): a range row that does not fit drops its speed first, then its tokens; ≈cost always stays.
  for(const row of host.querySelectorAll<HTMLElement>('.qrow-t')){if(!row.isConnected||row.clientWidth<=0)continue;const parts=[row.querySelector<HTMLElement>('.qaverage'),row.querySelector<HTMLElement>('.qtokens')];
   for(const part of parts)part?.classList.remove('drop');for(const part of parts){if(row.scrollWidth<=row.clientWidth)break;part?.classList.add('drop');}}}

 // Owner D76: the Reserve label's hint (and, macrevb-1020-2, a quota cell's own details: its unknown reset time), in the MFD's floating LCD tip style (study mfd.css .mfd-tip), on hover or focus.
 // Text only and never takes pointer events; the label also carries it as its accessible name.
 const hint=document.createElement('div');hint.className='mfd-tip eng-hint';hint.setAttribute('role','tooltip');hint.hidden=true;
 const hideHint=()=>{hint.hidden=true;hint.replaceChildren();hint.remove();};
 const showHint=(target:EventTarget|null)=>{const label=target instanceof Element?target.closest<HTMLElement>('.lb-r[data-tip],.qcell[data-tip]'):null;if(!label||!host.contains(label)){hideHint();return;}
  hint.replaceChildren(...(label.dataset.tip??'').split('\n').filter(Boolean).map((line,i)=>{const e=document.createElement('span');if(!i)e.className='h';e.textContent=line;return e;}));
  (root.querySelector('#cockpit')??document.body).append(hint);hint.hidden=false;const r=label.getBoundingClientRect(),w=hint.offsetWidth,h=hint.offsetHeight;
  // Above the label, so it never covers the reserve values beside it.
  hint.style.left=Math.max(4,Math.min(window.innerWidth-w-4,r.left))+'px';hint.style.top=Math.max(4,r.top-h-4)+'px';};
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
 plugins?.bindEngine(()=>paint());paint();return {table:host,applyScope,refresh:paint,setLocale(value,now){locale=value;paint(now);},focusIdentity(element){return focusIdentities.get(element)??null;},fit};
}

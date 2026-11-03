// SPDX-License-Identifier: MIT
// Adapter around the released study engine model/view. Every wire string is
// escaped once before the prototype's trusted HTML renderer; its fmt wrapper
// does not escape again. All non-text substitutions use closed vocabularies.
import type {WireCockpitData,WireWindow} from '../generated/wire.js';
import type {Appearance} from './bridge.js';
import {cockpitMembers} from './members.js';
import {prototypeEngineSupplement,currentWindow,displayWindow} from './prototype-data-adapter.js';
import {engineModel} from '../study/rocket-r1/engine-model.js';
import {engineView,rowsTemplate} from '../study/rocket-r1/engine-view.js';
import {setLanguage} from '../study/rocket-r1/i18n.js';
const esc=(value:unknown)=>String(value??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]!));
const palette:Readonly<Record<string,{colour:string;logo:string}>>={openai:{colour:'#6aa8ff',logo:'openai'},claude:{colour:'#ff9a6a',logo:'claude'},cursor:{colour:'#eef2f6',logo:'cursor'},copilot:{colour:'#c08cff',logo:'copilot'},kimi:{colour:'#ff8fcf',logo:'kimi'},glm:{colour:'#8f7dff',logo:'zai-white'},opencode:{colour:'#b5d65a',logo:'opencode'}};
const finite=(v:number|null)=>v!==null&&Number.isFinite(v)?v:null;
const role=(w:WireWindow)=>w.role==='session'&&w.durationSeconds===18000?'5h':w.role==='weekly'&&w.durationSeconds===604800?'week':w.role==='daily'?'day':w.role==='monthly'?'month':'other';
const general=(w:WireWindow)=>!w.modelScope&&w.poolKey==='main'&&(w.role==='session'?(w.limitKey==='main'||w.limitKey==='five_hour'):w.role==='weekly'?(w.limitKey==='main'||w.limitKey==='weekly'):false);
export function renderPrototypeEngine(data:WireCockpitData,locale:Appearance['locale'],root:HTMLElement,priorScope:string,_cell:(w:WireWindow|undefined,other?:boolean)=>HTMLElement,onSelect:(key:string)=>boolean,onAdd:()=>boolean,priorPage=0):{table:HTMLElement;applyScope:(scope:string)=>void;refresh:(now?:number)=>void;setLocale:(value:Appearance['locale'],now:number)=>void;focusIdentity:(element:HTMLElement)=>string|null}|null {
 const members=cockpitMembers(data);if(!members.length)return null;
 const seen=new Map(members.map(x=>[x.key,x]));let scope=seen.has(priorScope)?priorScope:'',page=Number.isSafeInteger(priorPage)?Math.max(0,Math.min(priorPage,Math.ceil(members.length/6)-1)):0;
 const host=document.createElement('div');host.className='u11-engine-table s6-page';const focusIdentities=new WeakMap<HTMLElement,string>();
 // Producer ordinals can change when a sibling appears; only unique structural meaning proves identity.
 const base=(w:WireWindow)=>`${w.role}:${w.durationSeconds??'unknown'}:${w.limitKey}:${w.poolKey}`;
 const semantic=(w:WireWindow)=>JSON.stringify([w.role,w.durationSeconds,w.limitKey,w.poolKey,w.modelScope?.models?[...w.modelScope.models].sort():null]);
 function sourceAt(now:number){
 const accounts=members.map(({key,row,account})=>{
  const brand=row.vendorKey&&Object.hasOwn(palette,row.vendorKey)?palette[row.vendorKey]:null;
  const name=locale==='en'?row.name.en:row.name.zh;
  const ids=new Map<string,number>(),bases=new Map<string,number>(),meanings=new Map<string,number>(),semantics=new Map<WireWindow,string>();
  for(const w of account.windows){const meaning=semantic(w),key=base(w);semantics.set(w,meaning);ids.set(w.id,(ids.get(w.id)??0)+1);bases.set(key,(bases.get(key)??0)+1);meanings.set(meaning,(meanings.get(meaning)??0)+1);}
  const validId=(w:WireWindow)=>{const key=base(w),count=bases.get(key)??0;if(count===1)return w.id===key;const suffix=w.id.startsWith(key+':')?w.id.slice(key.length+1):'';return /^[1-9]\d*$/.test(suffix)&&Number.isSafeInteger(Number(suffix))&&Number(suffix)<=count;};
  const convert=(w:WireWindow)=>({focusIdentity:validId(w)&&ids.get(w.id)===1&&meanings.get(semantics.get(w)!)===1?semantics.get(w)!:null,kind:role(w),remaining:displayWindow(account,w,now)?finite(w.remainingPercent):null,resetIn:displayWindow(account,w,now)&&w.resetsAt&&Number.isFinite(Date.parse(w.resetsAt))?Math.max(0,(Date.parse(w.resetsAt)-now)/60000):null,resetAt:null,resetText:null,elapsed:null,trend:null,durationMinutes:w.durationSeconds===null?null:w.durationSeconds/60});
  const windows=account.windows.filter(general).map(convert);
  const extras=account.windows.filter(w=>!general(w)).map(w=>({...convert(w),period:role(w),name:esc(locale==='en'?w.label.en:w.label.zh),label:esc(locale==='en'?w.label.en:w.label.zh),scope:{label:esc(locale==='en'?w.label.en:w.label.zh)},runOutMin:null}));
  const notice=data.details?.resetEvents.find(e=>e.rowId===row.id&&Date.parse(e.expiresAt)>now&&(!e.planIds?.length||e.planIds.includes(account.plan.id)));
  const detail=prototypeEngineSupplement(account,data), cards=detail.resetCards?.map(c=>({count:c.count,expiresAt:c.expiresAt?Date.parse(c.expiresAt):null}))??[];
  return {id:esc(key),name:esc(name),short:esc(name),alias:esc(name),colour:brand?.colour??'#c6ccd4',logo:brand?'../../vendor-marks/'+brand.logo+'.svg':'../../neutral.png',state:account.valueState==='current'?'ok':account.valueState==='retained'?'stale':'loading',ageMin:null,support:detail.todayTokens!==null?'observed':'quota-only',todayAverageGenerationTps:detail.todayAverageGenerationTps,todayTokens:detail.todayTokens,usage7:null,windows,extras,forecast:null,event:notice?{status:notice.status,at:null}:null,cards,credits:detail.reserveCredits&&['credits','points'].includes(detail.reserveCredits.unit)&&finite(detail.reserveCredits.balance)!==null?{balance:detail.reserveCredits.balance,drawing:false}:null};
 });
 const alerts=data.details?data.details.alerts.flatMap(a=>{const m=members.find(m=>m.key===a.subscriptionRef&&m.row.id===a.source);return m&&m.account.windows.some(w=>w.id===a.windowId&&currentWindow(m.account,w,now))&&['critical','warning'].includes(a.severity)?[{level:a.severity==='critical'?'red':'amber',sub:esc(m.key)}]:[];}):members.flatMap(({key,account})=>account.valueState!=='current'?[]:account.windows.filter(w=>currentWindow(account,w,now)&&w.remainingPercent!==null&&w.remainingPercent<=40).map(w=>({level:w.remainingPercent!<=25?'red':'amber',sub:esc(key)})));
 const hasReset=!!data.details?.resetEvents.some(e=>Date.parse(e.expiresAt)>now&&members.some(m=>m.row.id===e.rowId));
 const level=alerts.some(a=>a.level==='red')?'red':alerts.some(a=>a.level==='amber')||hasReset?'amber':null;
 const caution=root.querySelector<HTMLElement>('.ck-lamp .caution');if(caution){caution.classList.toggle('lit',!!level);caution.classList.toggle('red',level==='red');caution.classList.toggle('amber',level==='amber');caution.setAttribute('aria-label',level?(locale==='en'?'Alert active':'告警激活'):(locale==='en'?'Alert inactive':'告警未激活'));}
 return {now,accounts,alerts,caution:{level,key:''}};
 }
 const paint=(time?:number)=>{
  const now=time??Date.now(),source=sourceAt(now);setLanguage(locale);const ui={few:members.length<=6?'c3':'a',page,scope:scope?esc(scope):null,tint:true,pctMode:'left',redAt:25,ack:null,lang:locale,now};
  const model=engineModel(source,ui);page=model.page;host.dataset.cls=model.cls;host.style.setProperty('--n',String(model.slots));host.innerHTML=engineView(model,{changed:new Set(),lang:locale,now});
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
  for(const led of host.querySelectorAll<HTMLElement>('.eng-led[data-page]')){const n=Number(led.dataset.page);led.setAttribute('role','button');led.setAttribute('aria-label',locale==='en'?`Page ${n+1}`:`第 ${n+1} 页`);led.setAttribute('aria-current',String(n===page));}
  // Unknown vendors have no mark; never turn their input into an image URL.
  for(const image of host.querySelectorAll<HTMLImageElement>('img[src="assets/brands/../../neutral.png"]'))image.remove();
  for(const b of host.querySelectorAll<HTMLButtonElement>('.ek[data-sub]')){const member=seen.get(b.dataset.sub??'');if(member){b.dataset.scope=member.key;b.dataset.unstable=String(member.unstable);b.setAttribute('aria-label',locale==='en'?member.row.name.en:member.row.name.zh);}}
  const all=host.querySelector<HTMLButtonElement>('.ek[data-all]');if(all){all.dataset.scope='';all.setAttribute('aria-label',locale==='en'?'All':'全部');}
  root.dataset.scope=scope?'subscription':'all';
 };
 const choosePage=(element:Element)=>{const led=element.closest<HTMLElement>('.eng-led[data-page]');if(!led||!host.contains(led))return false;const requested=Number(led.dataset.page);if(Number.isInteger(requested)&&requested>=0&&requested<Math.ceil(members.length/6)){page=requested;paint();}return true;};
 host.onkeydown=e=>{if(e.isTrusted&&(e.key==='Enter'||e.key===' ')&&choosePage(e.target as Element))e.preventDefault();};
 host.onclick=e=>{if(!e.isTrusted)return;if(choosePage(e.target as Element))return;const b=(e.target as Element).closest<HTMLButtonElement>('button');if(!b||!host.contains(b))return;
  if(b.hasAttribute('data-add-subscription')){onAdd();return;}
  if(b.hasAttribute('data-all')){if(onSelect('all')){scope='';paint();}return;}
  if(b.hasAttribute('data-sub')){const key=b.dataset.sub??'';if(seen.has(key)&&onSelect(key)){scope=key;paint();}return;}
  if(b.hasAttribute('data-bpage')){const step=b.dataset.bpage==='1'?1:b.dataset.bpage==='-1'?-1:0;page=Math.max(0,Math.min(Math.ceil(members.length/6)-1,page+step));paint();}
 };
 const applyScope=(next:string)=>{scope=next!=='all'&&seen.has(next)?next:'';if(scope){const index=members.findIndex(m=>m.key===scope);page=Math.floor(index/6);}paint();};
 paint();return {table:host,applyScope,refresh:paint,setLocale(value,now){locale=value;paint(now);},focusIdentity(element){return focusIdentities.get(element)??null;}};
}

// SPDX-License-Identifier: MIT
// Adapter around the released study engine model/view. Every wire string is
// escaped once before the prototype's trusted HTML renderer; its fmt wrapper
// does not escape again. All non-text substitutions use closed vocabularies.
import type {WireCockpitData,WireWindow} from '../generated/wire.js';
import type {Appearance} from './bridge.js';
import {cockpitMembers} from './members.js';
import {engineModel} from '../study/rocket-r1/engine-model.js';
import {engineView} from '../study/rocket-r1/engine-view.js';
import {setLanguage} from '../study/rocket-r1/i18n.js';
const esc=(value:unknown)=>String(value??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]!));
const palette:Readonly<Record<string,{colour:string;logo:string}>>={openai:{colour:'#6aa8ff',logo:'openai'},claude:{colour:'#ff9a6a',logo:'claude'},cursor:{colour:'#eef2f6',logo:'cursor'},copilot:{colour:'#c08cff',logo:'copilot'},kimi:{colour:'#ff8fcf',logo:'kimi'},glm:{colour:'#8f7dff',logo:'zai-white'},opencode:{colour:'#b5d65a',logo:'opencode'}};
const finite=(v:number|null)=>v!==null&&Number.isFinite(v)?v:null;
const role=(w:WireWindow)=>w.role==='session'&&w.durationSeconds===18000?'5h':w.role==='weekly'&&w.durationSeconds===604800?'week':w.role==='daily'?'day':w.role==='monthly'?'month':'other';
const general=(w:WireWindow)=>!w.modelScope&&w.poolKey==='main'&&(w.role==='session'?(w.limitKey==='main'||w.limitKey==='five_hour'):w.role==='weekly'?(w.limitKey==='main'||w.limitKey==='weekly'):false);
export function renderPrototypeEngine(data:WireCockpitData,locale:Appearance['locale'],root:HTMLElement,priorScope:string,_cell:(w:WireWindow|undefined,other?:boolean)=>HTMLElement,onSelect:(key:string)=>boolean,onAdd:()=>boolean):{table:HTMLElement;applyScope:(scope:string)=>void}|null {
 const members=cockpitMembers(data);if(!members.length)return null;
 const seen=new Map(members.map(x=>[x.key,x]));let scope=seen.has(priorScope)?priorScope:'',page=0;
 const host=document.createElement('div');host.className='u11-engine-table s6-page';
 const now=Date.now();
 const accounts=members.map(({key,row,account})=>{
  const brand=row.vendorKey&&Object.hasOwn(palette,row.vendorKey)?palette[row.vendorKey]:null;
  const name=locale==='en'?row.name.en:row.name.zh;
  const convert=(w:WireWindow)=>({kind:role(w),remaining:finite(w.remainingPercent),resetIn:w.resetsAt&&Number.isFinite(Date.parse(w.resetsAt))?Math.max(0,(Date.parse(w.resetsAt)-now)/60000):null,resetAt:null,resetText:null,elapsed:null,trend:null,durationMinutes:w.durationSeconds===null?null:w.durationSeconds/60});
  const windows=account.windows.filter(general).map(convert);
  const extras=account.windows.filter(w=>!general(w)).map(w=>({...convert(w),period:role(w),name:esc(locale==='en'?w.label.en:w.label.zh),label:esc(locale==='en'?w.label.en:w.label.zh),scope:{label:esc(locale==='en'?w.label.en:w.label.zh)},runOutMin:null}));
  return {id:esc(key),name:esc(name),short:esc(name),alias:esc(name),colour:brand?.colour??'#c6ccd4',logo:brand?'../../vendor-marks/'+brand.logo+'.png':'../../neutral.png',state:account.valueState==='current'?'ok':account.valueState==='retained'?'stale':'loading',ageMin:null,support:'quota-only',todayAverageGenerationTps:null,todayTokens:null,usage7:null,windows,extras,forecast:null,event:null,cards:[],credits:account.credits&&['credits','points'].includes(account.credits.unit)&&finite(account.credits.balance)!==null?{balance:account.credits.balance,drawing:false}:null};
 });
 const alerts=members.flatMap(({key,account})=>account.valueState!=='current'?[]:account.windows.filter(w=>w.remainingPercent!==null&&w.remainingPercent<=40).map(w=>({level:w.remainingPercent!<=25?'red':'amber',sub:esc(key)})));
 const source={now,accounts,alerts,caution:{level:null,key:''}};
 const paint=()=>{
  setLanguage(locale);const ui={few:members.length<=6?'c3':'a',page,scope:scope?esc(scope):null,tint:true,pctMode:'left',redAt:25,ack:null,lang:locale,now};
  const model=engineModel(source,ui);page=model.page;host.dataset.cls=model.cls;host.innerHTML=engineView(model,{changed:new Set(),lang:locale,now});
  // Unknown vendors have no mark; never turn their input into an image URL.
  for(const image of host.querySelectorAll<HTMLImageElement>('img[src="assets/brands/../../neutral.png"]'))image.remove();
  for(const b of host.querySelectorAll<HTMLButtonElement>('.ek[data-sub]')){const member=seen.get(b.dataset.sub??'');if(member){b.dataset.scope=member.key;b.dataset.unstable=String(member.unstable);b.setAttribute('aria-label',locale==='en'?member.row.name.en:member.row.name.zh);}}
  const all=host.querySelector<HTMLButtonElement>('.ek[data-all]');if(all){all.dataset.scope='';all.setAttribute('aria-label',locale==='en'?'All':'全部');}
  root.dataset.scope=scope?'subscription':'all';
 };
 host.onclick=e=>{if(!e.isTrusted)return;const b=(e.target as Element).closest<HTMLButtonElement>('button');if(!b||!host.contains(b))return;
  if(b.hasAttribute('data-add-subscription')){onAdd();return;}
  if(b.hasAttribute('data-all')){if(onSelect('all')){scope='';paint();}return;}
  if(b.hasAttribute('data-sub')){const key=b.dataset.sub??'';if(seen.has(key)&&onSelect(key)){scope=key;paint();}return;}
  if(b.hasAttribute('data-bpage')){const step=b.dataset.bpage==='1'?1:b.dataset.bpage==='-1'?-1:0;page=Math.max(0,Math.min(Math.ceil(members.length/6)-1,page+step));paint();}
 };
 const applyScope=(next:string)=>{scope=next!=='all'&&seen.has(next)?next:'';if(scope){const index=members.findIndex(m=>m.key===scope);page=Math.floor(index/6);}paint();};
 paint();return {table:host,applyScope};
}

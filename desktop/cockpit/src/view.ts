// SPDX-License-Identifier: MIT
import type { WireCockpitData } from '../generated/wire.js';
import {websiteAction} from './website-link.js';
import type { Appearance,CockpitView,LiveAppearance,ShellState,PageAction } from './bridge.js';
import {effectiveRedBelow} from './threshold.js';
import { mountPrototypeHelp } from './prototype-help.js';
import { prototypeFrame } from './prototype-frame.js';
import { cockpitLayout } from './prototype-layout.js';
import { renderPrototypeEngine } from './prototype-engine.js';
import { mountPrototypeDeck } from './prototype-deck.js';
import { paintHud,wireHud } from './prototype-hud.js';
import { mountPrototypeTape } from './prototype-tape.js';
import { cockpitMembers } from './members.js';
import { mountPrototypeBase } from './prototype-base.js';
import { cautionItems,readWindows } from './caution.js';
import { createCautionMemory } from './caution-ack.js';
import {currentWindow,withoutProjectNames} from './prototype-data-adapter.js';
const words={en:{all:'All',settings:'Settings',waiting:'Waiting for readings',cleared:'Readings cleared',empty:'No subscriptions',rows:['5h','Weekly','Other'],page:'Page',resets:'resets in',now:'now'},'zh-CN':{all:'全部',settings:'设置',waiting:'等待读数',cleared:'读数已清除',empty:'无订阅',rows:['5小时','每周','其他'],page:'第',resets:'后重置',now:'现在'}};
const element=<K extends keyof HTMLElementTagNameMap>(tag:K,text?:string,className?:string):HTMLElementTagNameMap[K]=>{const e=document.createElement(tag);if(text!==undefined)e.textContent=text;if(className)e.className=className;return e;};
export function mountCockpit(root:HTMLElement,action:(kind:PageAction,tool?:string)=>void,reportAcked:(ids:string[])=>void=()=>{}):CockpitView {
 let locale:Appearance['locale']='en',disposed=false,active=false,reduceMotion=false;
 let nativeShell:ShellState|null=null,tier:ShellState['tier']='tall';
 let applyScope:((scope:string)=>void)|null=null,refreshEngine:((now?:number)=>void)|null=null,localiseEngine:((value:Appearance['locale'],now:number)=>void)|null=null,quotaFocusIdentity:((element:HTMLElement)=>string|null)|null=null,lastData:WireCockpitData|null=null;
 let lastRenderedAt=0;const retiredUnstableScopes=new Set<string>();
 let hudSelected:string|null=null;const hudOptions=()=>({scope:nativeShell?.scope??'all',now:lastRenderedAt,selected:hudSelected,closed:nativeShell?.profile==='closed'});
 let selectedRedBelow=effectiveRedBelow(undefined);const redBelow=()=>selectedRedBelow;
 const frame=prototypeFrame(root);const help=mountPrototypeHelp(root,()=>locale,()=>active,()=>nativeShell?.attached??true);const deck=mountPrototypeDeck(root,key=>{if(!active)return false;retiredUnstableScopes.delete(key);action('scopeSelect',key);if(nativeShell)nativeShell={...nativeShell,scope:key};applyScope?.(key);return true;},undefined,redBelow);const tape=mountPrototypeTape(root,{knows:ref=>deck.knowsSession(ref),hover(session){deck.highlightSession(session?.sessionRef??null);const key=session?.subscriptionRef??null;for(const el of root.querySelectorAll<HTMLElement>('[data-col]'))el.classList.toggle('xhl',!!key&&el.dataset.col===key);},select(session){if(!active)return;const key=session.subscriptionRef;if(key&&[...root.querySelectorAll<HTMLElement>('.ek[data-sub]')].some(el=>el.dataset.sub===key)){retiredUnstableScopes.delete(key);action('scopeSelect',key);if(nativeShell)nativeShell={...nativeShell,scope:key};applyScope?.(key);deck.scope(key);}deck.selectSession(session.sessionRef);}});
 // G3-47: base bells under the engine columns; repainted from the drawn engine table.
 const base=mountPrototypeBase(root,()=>lastData,z=>{
  const member=lastData?cockpitMembers(lastData).find(m=>m.key===z.key):undefined,name=member?(locale==='en'?member.row.name.en:member.row.name.zh):'';
  const what=z.state==='work'?(locale==='en'?'working now':'正在用')+(z.rate===null?'':` · ${Math.round(z.rate)} t/s`):z.state==='stale'?(locale==='en'?'reading is not current':'读数不是最新'):(locale==='en'?'idle':'空闲');
  return name?`${name} · ${what}`:what;});
 const scopeShortcut=(event:KeyboardEvent)=>{if(!event.isTrusted||!active||disposed||!nativeShell||nativeShell.profile!=='open'||nativeShell.forcedClosed||event.altKey||event.ctrlKey||event.metaKey||event.shiftKey||event.repeat||!/^[0-6]$/.test(event.key))return;const target=event.target;if(target instanceof Element&&(target.closest('input,textarea,select,[contenteditable]:not([contenteditable="false"])')))return;const button=event.key==='0'?frame.engine.querySelector<HTMLButtonElement>('.ek[data-all]'):[...frame.engine.querySelectorAll<HTMLButtonElement>('.eng-keys .ek[data-sub]')][Number(event.key)-1];if(!button||!applyScope)return;const key=button.dataset.scope;if(key===undefined)return;const scope=key||'all';event.preventDefault();retiredUnstableScopes.delete(scope);action('scopeSelect',scope);nativeShell={...nativeShell,scope};deck.scope(scope);applyScope(scope);};
 window.addEventListener('keydown',scopeShortcut);
 const caution=root.querySelector<HTMLButtonElement>('[data-caution]')!;const cautions=createCautionMemory(reportAcked);const motionQuery=matchMedia('(prefers-reduced-motion: reduce)');const finishCaution=(e:AnimationEvent)=>{if(e.animationName==='cockpit-caution-blink')caution.classList.remove('flash');};const syncReduced=()=>document.body.classList.toggle('reduced',reduceMotion||motionQuery.matches);/* body.reduced is the carried prototype CSS's Reduce Motion switch: app setting or OS preference. */const motionChanged=()=>{syncReduced();if(motionQuery.matches)caution.classList.remove('flash');};caution.addEventListener('animationend',finishCaution);motionQuery.addEventListener('change',motionChanged);
 function syncCaution(data:WireCockpitData,now:number){const items=cautionItems(data,now,redBelow()),fresh=cautions.update(items,readWindows(data,now));if(!items.some(x=>x.level!=='blue'))caution.classList.remove('flash');else if(fresh&&active&&nativeShell?.profile==='open'&&!reduceMotion&&!motionQuery.matches){caution.classList.remove('flash');void caution.offsetWidth;caution.classList.add('flash');}}
 caution.onclick=e=>{if(!e.isTrusted||!active||(!caution.classList.contains('lit')&&!deck.alertsOpen()))return;caution.classList.remove('flash');deck.showAlerts(deck.alertsOpen()?undefined:cautions.acknowledge());};
 const head=root.querySelector<HTMLElement>('.ck-head')!;head.style.pointerEvents='auto';
 const shutter=root.querySelector<HTMLButtonElement>('[data-shutter]')!;
 let drag:{id:number;x:number;start:number;scale:number;moved:boolean}|null=null,suppressClick=false;
 const requestShutter=(closed:boolean)=>{if(active&&nativeShell&&!nativeShell.forcedClosed&&(nativeShell.profile==='closed')!==closed)action('shutterToggle');};
 shutter.onclick=e=>{if(!e.isTrusted)return;if(suppressClick&&e.detail!==0){suppressClick=false;return;}suppressClick=false;requestShutter(nativeShell?.profile!=='closed');};
 shutter.onpointerdown=e=>{if(!e.isTrusted||!active||!nativeShell||nativeShell.forcedClosed||!e.isPrimary||e.button!==0)return;drag={id:e.pointerId,x:e.clientX,start:nativeShell.profile==='closed'?100:0,scale:shutter.getBoundingClientRect().width/shutter.offsetWidth||1,moved:false};shutter.setPointerCapture(e.pointerId);};
 shutter.onpointermove=e=>{if(!drag||drag.id!==e.pointerId)return;const dx=(e.clientX-drag.x)/drag.scale;if(Math.abs(dx)>3)drag.moved=true;if(drag.moved)shutter.style.setProperty('--shutter-travel',Math.max(0,Math.min(100,drag.start+dx))+'px');};
 shutter.onpointerup=e=>{if(!drag||drag.id!==e.pointerId)return;const d=drag;drag=null;shutter.style.removeProperty('--shutter-travel');if(d.moved){suppressClick=true;requestShutter(d.start+(e.clientX-d.x)/d.scale>=50);}};
 const cancelDrag=()=>{drag=null;shutter.style.removeProperty('--shutter-travel');};shutter.onpointercancel=cancelDrag;shutter.onlostpointercapture=cancelDrag;
 shutter.onkeydown=e=>{const target=e.key==='ArrowRight'||e.key==='End'?true:e.key==='ArrowLeft'||e.key==='Home'?false:null;if(target!==null&&e.isTrusted){e.preventDefault();requestShutter(target);}};
 const attach=root.querySelector<HTMLButtonElement>('[data-detach]')!,close=root.querySelector<HTMLButtonElement>('[data-close]')!;
 const noMenu=(e:Event)=>e.preventDefault();document.addEventListener('contextmenu',noMenu);
 frame.settings.classList.add('s6-strip-key');attach.classList.add('s6-strip-key');close.classList.add('s6-strip-key');
 const cap=element('section',undefined,'s6-closed-cap');cap.hidden=true;
 cap.style.pointerEvents='auto';cap.style.gridRow='1';cap.style.gridColumn='1';cap.style.alignSelf='end';cap.style.padding='12px';cap.style.background='var(--port-bg)';cap.style.borderRadius='8px';
 const reason=element('span');reason.id='s6-closed-reason';reason.setAttribute('role','status');cap.append(reason);root.append(cap);
 attach.onclick=e=>{if(e.isTrusted&&nativeShell)action(nativeShell.attached?'detach':'putBack');};
 close.onclick=e=>{if(e.isTrusted)action('close');};
 const unwireHud=wireHud(frame.hud,id=>{hudSelected=id;deck.showTune(id);if(lastData)paintHud(frame.hud,lastData,tier!=='tall',locale,hudOptions());});
 let showProjectNames=true;
 const paintRecords=(data:WireCockpitData,at:number)=>{const shown=showProjectNames?data:withoutProjectNames(data);deck.render(shown,at);tape.render(shown);};
 function shellControls(){
  const zh=locale==='zh-CN', closed=nativeShell?.profile==='closed', forced=!!nativeShell?.forcedClosed;
  const alert=root.querySelector<HTMLElement>('.s6-alert')!;alert.setAttribute('aria-label',alert.classList.contains('lit')?(zh?'告警激活':'Alert active'):(zh?'告警未激活':'Alert inactive'));
  attach.setAttribute('aria-pressed',String(!nativeShell?.attached));attach.setAttribute('aria-label',nativeShell?.attached?(zh?'分离':'Detach'):(zh?'放回':'Put back'));close.setAttribute('aria-label',zh?'关闭':'Close');
  reason.textContent=forced?(zh?'窗口高度不足，无法打开':'Not enough window height to open'):'';
  shutter.setAttribute('aria-label',zh?'舷窗快门':'Porthole shutter');shutter.setAttribute('aria-pressed',String(closed));shutter.setAttribute('aria-describedby',reason.id);shutter.title=reason.textContent;shutter.disabled=!active||!nativeShell||forced;
  attach.hidden=!nativeShell;close.hidden=!nativeShell;
  attach.disabled=!active||!nativeShell;close.disabled=!active||!nativeShell;
  cap.hidden=!closed;cap.style.display=closed?'block':'none';
  root.querySelector<HTMLElement>('.ck-portrow')!.style.visibility=closed?'hidden':'';
  root.dataset.shell=closed?'closed':'open';root.style.setProperty('--body-h',(closed?(tier==='tall'?691:609):(tier==='tall'?877:627))+'px');
  if(closed){stop();caution.classList.remove('flash');}
 }
 function localise(now?:number){
  document.documentElement.lang=locale;deck.locale(locale,now);tape.locale(locale);frame.settings.setAttribute('aria-label',words[locale].settings);
  for(const e of root.querySelectorAll<HTMLElement>('[data-en][data-zh]')){e.textContent=locale==='en'?e.dataset.en!:e.dataset.zh!;if(e.tagName==='BUTTON')e.setAttribute('aria-label',e.textContent);else if(e.classList.contains('ek-name'))e.parentElement?.setAttribute('aria-label',e.textContent);}
  for(const e of root.querySelectorAll<HTMLButtonElement>('.eng-led[data-page]')){const n=Number(e.dataset.page)+1;e.setAttribute('aria-label',locale==='en'?`Page ${n}`:`第 ${n} 页`);}
  shellControls();help.refresh();
 }
 const bilingual=(e:HTMLElement,en:string,zh:string)=>{e.dataset.en=en;e.dataset.zh=zh;return e;};
 frame.settings.onclick=e=>{if(e.isTrusted)action('openSettings');};
 // A website link never navigates the page: native opens the typed page it names, on a real press only.
 root.addEventListener('click',e=>{const link=(e.target as Element).closest?.<HTMLAnchorElement>('a.website-link');if(!link)return;e.preventDefault();const target=websiteAction(link.href);if(e.isTrusted&&target)action('openWebsite',target);});
 const stop=()=>frame.lamp.classList.remove('state-pulse');
 const settled=()=>{if(!frame.lamp.getAnimations().some(a=>a.playState==='running'))stop();};
 frame.lamp.addEventListener('animationend',settled);frame.lamp.addEventListener('animationcancel',settled);
 const displayedState=()=>[frame.engine.innerHTML,frame.hud.innerHTML,frame.mfd.innerHTML].join('\0');
 const pulse=()=>{stop();if(!active||nativeShell?.profile==='closed'||reduceMotion||matchMedia('(prefers-reduced-motion: reduce)').matches)return;void frame.lamp.offsetWidth;frame.lamp.classList.add('state-pulse');};
 const setEmpty=(key:'waiting'|'cleared'|'empty')=>{base.clear();frame.hud.replaceChildren();frame.hud.hidden=true;hudSelected=null;caution.classList.remove('flash');refreshEngine=null;localiseEngine=null;quotaFocusIdentity=null;const alert=root.querySelector<HTMLElement>('.s6-alert')!;alert.classList.remove('lit','red','amber');alert.setAttribute('aria-label',locale==='en'?'Alert inactive':'告警未激活');applyScope=null;frame.engine.replaceChildren(bilingual(element('p',words[locale][key],'ec-empty'),words.en[key],words['zh-CN'][key]));frame.hud.replaceChildren();deck.clear();tape.clear();};
 function nextDeadline(data:WireCockpitData,now:number):number|null {
  let next=Infinity;
  for(const row of data.projection.rows)for(const account of row.accounts)if(account.valueState==='current')for(const w of account.windows){
   if(!w.current||w.remainingPercent===null||w.validUntil===null)continue;
   const at=Date.parse(w.validUntil);if(Number.isFinite(at)&&at>now)next=Math.min(next,at);
  }
  for(const event of data.details?.resetEvents??[]){const at=Date.parse(event.expiresAt);if(Number.isFinite(at)&&at>now)next=Math.min(next,at);}
  // A run-out stops being a forecast when it passes; the amber lamp, row and cell must clear then, with no new reading.
  for(const forecast of data.details?.forecasts??[]){const at=forecast.runsOutAt?Date.parse(forecast.runsOutAt):NaN;if(Number.isFinite(at)&&at>now)next=Math.min(next,at);}
  return Number.isFinite(next)?next:null;
 }
 function preserveFocus(update:()=>void,replacing=false){
  const focused=document.activeElement instanceof HTMLElement?document.activeElement:null;
  const area=focused&&(frame.engine.contains(focused)?frame.engine:frame.mfd.contains(focused)?frame.mfd:null);
  const quota=focused?.classList.contains('qcell')?focused:null;const quotaColumn=quota?.closest<HTMLElement>('.ec[data-col]');
  const memberKey=quotaColumn?.dataset.col??focused?.dataset.focusMember??(focused?.dataset.scope||undefined);
  const previousMember=memberKey&&lastData?cockpitMembers(lastData).find(m=>m.key===memberKey):undefined;
  const verified=(m:typeof previousMember,d:WireCockpitData|null)=>!!m?.account.subscriptionRef&&m.account.subscriptionRef===m.key&&!!d?.subscriptions.some(s=>s.subscriptionRef===m.key);
  const quotaIdentity=quota?quotaFocusIdentity?.(quota)??null:null;const previousData=lastData;
  let path:number[]|null=null;const keys=['data-focus-member','data-scope','data-page','data-mfd','data-opt','data-row','data-col','data-bpage','data-add-subscription','aria-label'];
  const key=focused&&area?keys.find(k=>focused.hasAttribute(k)):undefined;
  const keyValue=key&&focused?focused.getAttribute(key):null;
  const priorPage=key==='data-add-subscription'?frame.engine.querySelector('[data-page][aria-current="true"]')?.getAttribute('data-page')??null:null;
  if(focused&&area){path=[];for(let n:Element|null=focused;n&&n!==area;n=n.parentElement)path.unshift(Array.prototype.indexOf.call(n.parentElement?.children,n));}
  update();
  if(!focused||!area||focused.isConnected||!active||document.hidden)return;
  const current=document.activeElement;if(current&&current!==document.body&&current!==document.documentElement&&current!==focused)return;
  if(key==='data-add-subscription'&&priorPage!==(frame.engine.querySelector('[data-page][aria-current="true"]')?.getAttribute('data-page')??null))return;
  if(memberKey&&!previousMember)return;
  if(memberKey&&previousMember){
   const member=lastData?cockpitMembers(lastData).find(m=>m.key===memberKey):undefined;
   if(!member||member.row.id!==previousMember.row.id||replacing&&(!verified(previousMember,previousData)||!verified(member,lastData)))return;
   if(quota){
    if(!quotaIdentity)return;
    const columns=[...frame.engine.querySelectorAll<HTMLElement>('.ec[data-col]')].filter(e=>e.dataset.col===memberKey);
    const cells=columns.flatMap(e=>[...e.querySelectorAll<HTMLElement>('.qcell[data-row]')]).filter(e=>e.dataset.row===quota.dataset.row&&quotaFocusIdentity?.(e)===quotaIdentity);
    if(cells.length===1)cells[0].focus({preventScroll:true});return;
   }
  }
  let target:HTMLElement|null=null;
  if(key&&key!=='data-add-subscription'&&keyValue!==null){const matches=[...area.querySelectorAll<HTMLElement>(focused.tagName)].filter(e=>e.getAttribute(key)===keyValue);if(matches.length===1)target=matches[0];}
  if(!target&&path){let e:Element|null=area;for(const i of path)e=e?.children.item(i)??null;if(e instanceof HTMLElement&&e.tagName===focused.tagName&&(key?e.getAttribute(key)===keyValue:e.className===focused.className))target=e;}
  target?.focus({preventScroll:true});
 }
 function refreshDeadlines(now:number){if(!lastData||disposed)return;lastRenderedAt=now;preserveFocus(()=>{refreshEngine?.(now);deck.refresh(now);syncCaution(lastData!,now);});}
 function renderData(data:WireCockpitData,now:number){
  preserveFocus(()=>{
   const previousData=lastData;lastData=data;lastRenderedAt=now;
   if(disposed)throw Error('closed');const before=displayedState();const priorPage=Number(frame.engine.querySelector('[data-page][aria-current="true"]')?.getAttribute('data-page')??0);const priorButton=frame.engine.querySelector<HTMLButtonElement>('.ek[aria-pressed="true"]');const selectedScope=nativeShell?.scope??priorButton?.dataset.scope??'all';const unstable=(previousData?cockpitMembers(previousData):[]).some(m=>m.key===selectedScope&&m.unstable)||cockpitMembers(data).some(m=>m.key===selectedScope&&m.unstable);const priorScope=unstable?'':selectedScope==='all'?'':selectedScope;if(unstable){retiredUnstableScopes.add(selectedScope);if(nativeShell)nativeShell={...nativeShell,scope:'all'};}applyScope=null;frame.engine.replaceChildren();
   const engine=renderPrototypeEngine(data,locale,root,priorScope,key=>{if(!active)return false;retiredUnstableScopes.delete(key);action('scopeSelect',key);if(nativeShell)nativeShell={...nativeShell,scope:key};deck.scope(key);return true;},()=>{if(!active)return false;action('openSettings');return true;},priorPage,lastRenderedAt,redBelow);
   if(!engine){setEmpty('empty');return;}frame.engine.append(engine.table);applyScope=engine.applyScope;refreshEngine=engine.refresh;localiseEngine=engine.setLocale;quotaFocusIdentity=engine.focusIdentity;deck.scope(nativeShell?.scope??'all');paintRecords(data,lastRenderedAt);paintHud(frame.hud,data,tier!=='tall',locale,hudOptions());syncCaution(data,now);help.refresh();
   if(before!==displayedState())pulse();
  },true);
 }
 setEmpty('waiting');
 return {
  restoreAcked(ids){cautions.restore(ids);},
  forgetAcked(){cautions.forget();},
  configure(value,threshold){selectedRedBelow=threshold;locale=value.locale;showProjectNames=value.showProjectNames;reduceMotion=value.reduceMotion;syncReduced();document.documentElement.lang=locale;document.documentElement.dataset.theme=value.theme;document.documentElement.dataset.reduceMotion=String(value.reduceMotion);document.documentElement.dataset.reduceTransparency=String(value.reduceTransparency);frame.hud.classList.toggle('solid',value.reduceTransparency);deck.locale(locale);tape.locale(locale);frame.settings.setAttribute('aria-label',words[locale].settings);setEmpty('waiting');},
  updateAppearance(value:LiveAppearance,now:number,threshold){const namesChanged=showProjectNames!==value.showProjectNames;showProjectNames=value.showProjectNames;selectedRedBelow=threshold;locale=value.locale;reduceMotion=value.reduceMotion;syncReduced();document.documentElement.dataset.theme=value.theme;document.documentElement.dataset.reduceMotion=String(value.reduceMotion);document.documentElement.dataset.reduceTransparency=String(value.reduceTransparency);frame.hud.classList.toggle('solid',value.reduceTransparency);if(reduceMotion){stop();caution.classList.remove('flash');}if(lastData){lastRenderedAt=now;preserveFocus(()=>{localise(lastRenderedAt);localiseEngine?.(locale,lastRenderedAt);paintHud(frame.hud,lastData!,tier!=='tall',locale,hudOptions());if(namesChanged)paintRecords(lastData!,lastRenderedAt);syncCaution(lastData!,lastRenderedAt);});}else localise();},
  shell(value:ShellState){if(retiredUnstableScopes.has(value.scope))value={...value,scope:'all'};const changed=(nativeShell?.scope??'all')!==value.scope;nativeShell=value;preserveFocus(()=>{tier=value.tier;const h=tier==='tall'?890:640,layout=cockpitLayout(h);document.documentElement.dataset.profile=tier==='tall'?'full':'compact';root.dataset.layout=String(h);root.style.setProperty('--console-h',layout.console+'px');root.style.setProperty('--tape-h',layout.tapeH+'px');root.style.setProperty('--eng-h',layout.eng+'px');tape.layout(layout.tapeLines);shellControls();if(lastData)paintHud(frame.hud,lastData,tier!=='tall',locale,hudOptions());if(changed){applyScope?.(value.scope);deck.scope(value.scope);}});},
  render:renderData,
  nextDeadline(){return lastData?nextDeadline(lastData,lastRenderedAt):null;},
  tick(now){refreshDeadlines(now);},
  clear(){retiredUnstableScopes.clear();caution.classList.remove('flash');lastData=null;stop();setEmpty('cleared');if(nativeShell)nativeShell={...nativeShell,scope:'all'};delete root.dataset.scope;},
  active(value){active=value;root.dataset.active=String(value);frame.settings.disabled=!value;shellControls();if(!value){deck.cancelPress();stop();caution.classList.remove('flash');help.hide();}},
  dispose(){if(disposed)return;disposed=true;base.dispose();unwireHud();document.removeEventListener('contextmenu',noMenu);window.removeEventListener('keydown',scopeShortcut);caution.onclick=null;caution.removeEventListener('animationend',finishCaution);motionQuery.removeEventListener('change',motionChanged);applyScope=null;refreshEngine=null;localiseEngine=null;quotaFocusIdentity=null;lastData=null;nativeShell=null;deck.dispose();help.dispose();stop();frame.lamp.removeEventListener('animationend',settled);frame.lamp.removeEventListener('animationcancel',settled);frame.settings.onclick=null;attach.onclick=null;shutter.onclick=null;shutter.onpointerdown=null;shutter.onpointermove=null;shutter.onpointerup=null;shutter.onpointercancel=null;shutter.onlostpointercapture=null;shutter.onkeydown=null;close.onclick=null;root.replaceChildren();root.removeAttribute('data-active');delete root.dataset.scope;},
 };
}

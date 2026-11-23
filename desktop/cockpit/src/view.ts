// SPDX-License-Identifier: MIT
import {ht} from './host-text.js';
import {mountHeaderRange} from './header-range.js';
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
import { cockpitMembers,setMemberOrder } from './members.js';
import { mountPrototypeBase } from './prototype-base.js';
import { cautionItems,lights,readWindows } from './caution.js';
import { createCautionMemory } from './caution-ack.js';
import {currentWindow,withoutProjectNames} from './prototype-data-adapter.js';
import {INITIAL_RANGE,nextCockpitRange,type CockpitRange} from './range.js';
import {mountPluginHost,pluginHostOf,type PluginReports} from './plugin-host.js';
const element=<K extends keyof HTMLElementTagNameMap>(tag:K,text?:string,className?:string):HTMLElementTagNameMap[K]=>{const e=document.createElement(tag);if(text!==undefined)e.textContent=text;if(className)e.className=className;return e;};
/** Controls focusable through their own tabindex that a pointer presses (B1): buttons, radios and sliders. */
export const POINTER_UNFOCUSED='button,[role="radio"],[role="slider"]';
/** B1: how long a page keeps its last local history across replies whose history read was unavailable. */
export const HISTORY_HOLD_MS=10*60*1000;
export function mountCockpit(root:HTMLElement,action:(kind:PageAction,tool?:string)=>void,reportAcked:(ids:string[])=>void=()=>{},reportPins:(ids:string[])=>void=()=>{},reportPlugins:PluginReports={state:()=>{},running:()=>{}}):CockpitView {
 let locale:Appearance['locale']='en',disposed=false,active=false,reduceMotion=false;
 let nativeShell:ShellState|null=null,tier:ShellState['tier']='tall';
 // CKP-SHELL-50 / MENU-52: the range is the app's. A key or T asks for it and mirrors it at once, as a scope key does; the
 // host's shell echo is the same value, so nothing repaints twice.
 const requestRange=(range:CockpitRange):boolean=>{if(!active||disposed||!nativeShell)return false;action('rangeSelect',range);nativeShell={...nativeShell,range};return true;};
 let applyScope:((scope:string)=>void)|null=null,refreshEngine:((now?:number)=>void)|null=null,localiseEngine:((value:Appearance['locale'],now:number)=>void)|null=null,quotaFocusIdentity:((element:HTMLElement)=>string|null)|null=null,lastData:WireCockpitData|null=null;
 let heldHistory:{history:NonNullable<WireCockpitData['history']>;at:number}|null=null;
 let lastRenderedAt=0;const retiredUnstableScopes=new Set<string>();
 let hudSelected:string|null=null;const hudOptions=()=>({scope:nativeShell?.scope??'all',now:lastRenderedAt,selected:hudSelected,closed:nativeShell?.profile==='closed'});
 let selectedRedBelow=effectiveRedBelow(undefined);const redBelow=()=>selectedRedBelow;let showUsedPercent=false;const showUsed=()=>showUsedPercent;
 let stripSelected:string|null=null;
 const frame=prototypeFrame(root);const help=mountPrototypeHelp(root,()=>locale,()=>active,()=>nativeShell?.attached??true);const deck=mountPrototypeDeck(root,key=>{if(!active)return false;retiredUnstableScopes.delete(key);action('scopeSelect',key);if(nativeShell)nativeShell={...nativeShell,scope:key};updateScopeHud();applyScope?.(key);return true;},undefined,redBelow,reportPins,()=>{if(!active)return false;action('openSettingsSubscriptions');return true;},range=>{const ok=requestRange(range);if(ok)headerRange.set(range);return ok;},key=>{if(!active)return false;action('refreshMember',key);return true;},()=>nativeShell?.range??INITIAL_RANGE,()=>plugins.dismissScreen());const tape=mountPrototypeTape(root,{knows:ref=>deck.knowsSession(ref),hover(session){deck.highlightSession(session?.sessionRef??null);const key=session?.subscriptionRef??null;for(const el of root.querySelectorAll<HTMLElement>('[data-col]'))el.classList.toggle('xhl',!!key&&el.dataset.col===key);},select(session){if(!active)return;if(stripSelected===session.sessionRef&&deck.sessionSelected(session.sessionRef)){stripSelected=null;deck.clearSession();return;}stripSelected=session.sessionRef;const key=session.subscriptionRef;if(key&&[...root.querySelectorAll<HTMLElement>('.ek[data-sub]')].some(el=>el.dataset.sub===key)){retiredUnstableScopes.delete(key);action('scopeSelect',key);if(nativeShell)nativeShell={...nativeShell,scope:key};updateScopeHud();applyScope?.(key);deck.scope(key);}deck.selectSession(session.sessionRef);},more(){if(active)deck.showWhere();},clear(){if(!active||stripSelected===null)return;const ref=stripSelected;stripSelected=null;if(deck.sessionSelected(ref))deck.clearSession();}});
 // G3-47: base bells under the engine columns; repainted from the drawn engine table.
 const base=mountPrototypeBase(root,()=>lastData,z=>{
  if(z.state==='plugin')return ht(locale,'plugin.nozzle',{name:z.name??''});
  const member=lastData?cockpitMembers(lastData).find(m=>m.key===z.key):undefined,name=member?(locale==='en'?member.row.name.en:member.row.name.zh):'';
  const what=z.state==='work'?(ht(locale,'host.workingNow'))+(z.rate===null?'':` · ${Math.round(z.rate)} t/s`):z.state==='stale'?(ht(locale,'host.readingIsNotCurrent')):(ht(locale,'host.idle'));
  return name?`${name} · ${what}`:what;});
 function updateScopeHud(){if(lastData)paintHud(frame.hud,lastData,tier!=='tall',locale,hudOptions());}
 const scopeShortcut=(event:KeyboardEvent)=>{if(!event.isTrusted||!active||disposed||!nativeShell||nativeShell.profile!=='open'||nativeShell.forcedClosed||event.altKey||event.ctrlKey||event.metaKey||event.shiftKey||event.repeat||!/^[0-6]$/.test(event.key))return;const target=event.target;if(target instanceof Element&&(target.closest('input,textarea,select,[contenteditable]:not([contenteditable="false"])')))return;const button=event.key==='0'?frame.engine.querySelector<HTMLButtonElement>('.ek[data-all]'):[...frame.engine.querySelectorAll<HTMLButtonElement>('.eng-keys .ek[data-sub]')][Number(event.key)-1];if(!button||!applyScope)return;const key=button.dataset.scope;if(key===undefined)return;const scope=key||'all';event.preventDefault();retiredUnstableScopes.delete(scope);action('scopeSelect',scope);nativeShell={...nativeShell,scope};deck.scope(scope);applyScope(scope);updateScopeHud();};
 window.addEventListener('keydown',scopeShortcut);
 const rangeShortcut=(event:KeyboardEvent)=>{if(!event.isTrusted||!active||disposed||!nativeShell||event.altKey||event.ctrlKey||event.metaKey||event.repeat||event.key.toLowerCase()!=='t')return;const target=event.target;if(target instanceof Element&&(target.closest('input,textarea,select,[contenteditable]:not([contenteditable="false"])')))return;const next=nextCockpitRange(nativeShell.range??INITIAL_RANGE);event.preventDefault();if(requestRange(next)){deck.range(next);headerRange.set(next);}};
 window.addEventListener('keydown',rangeShortcut);
 const caution=root.querySelector<HTMLButtonElement>('[data-caution]')!;const cautions=createCautionMemory(reportAcked);const motionQuery=matchMedia('(prefers-reduced-motion: reduce)');const finishCaution=(e:AnimationEvent)=>{if(e.animationName==='cockpit-caution-blink')caution.classList.remove('flash');};const syncReduced=()=>document.body.classList.toggle('reduced',reduceMotion||motionQuery.matches);/* body.reduced is the carried prototype CSS's Reduce Motion switch: app setting or OS preference. */const motionChanged=()=>{syncReduced();if(motionQuery.matches){caution.classList.remove('flash');stop();}};caution.addEventListener('animationend',finishCaution);motionQuery.addEventListener('change',motionChanged);
 function syncCaution(data:WireCockpitData,now:number){const items=cautionItems(data,now,redBelow()),fresh=cautions.update(items,readWindows(data,now),active&&nativeShell?.profile==='open'&&!reduceMotion&&!motionQuery.matches);if(!items.some(lights))caution.classList.remove('flash');else if(fresh&&active&&nativeShell?.profile==='open'&&!reduceMotion&&!motionQuery.matches){caution.classList.remove('flash');void caution.offsetWidth;caution.classList.add('flash');}}
 caution.onclick=e=>{if(!e.isTrusted||!active)return;caution.classList.remove('flash');const uncovered=plugins.dismissScreen();if(uncovered&&deck.alertsOpen())return;deck.showAlerts(deck.alertsOpen()?undefined:cautions.acknowledge());};
 const head=root.querySelector<HTMLElement>('.ck-head')!;head.style.pointerEvents='auto';
 const shutter=root.querySelector<HTMLButtonElement>('[data-shutter]')!;
 const requestShutter=(closed:boolean)=>{if(active&&nativeShell&&!nativeShell.forcedClosed&&(nativeShell.profile==='closed')!==closed)action('shutterToggle');};
 // WP-10: a click toggles. A press that travels past 4 px at any moment is a drag and never toggles, even when it ends
// back on the switch; a cancelled press is a drag too. The latch is set from window-level moves so travel outside the switch counts.
let shutterGesture:{x:number;y:number;dragged:boolean}|null=null,shutterLatched=false;
const shutterMove=(e:PointerEvent)=>{if(shutterGesture&&Math.hypot(e.clientX-shutterGesture.x,e.clientY-shutterGesture.y)>4)shutterGesture.dragged=true;};
const shutterEnd=(e:PointerEvent)=>{shutterMove(e);if(shutterGesture){shutterLatched=shutterGesture.dragged||e.type==='pointercancel';shutterGesture=null;}window.removeEventListener('pointermove',shutterMove);window.removeEventListener('pointerup',shutterEnd);window.removeEventListener('pointercancel',shutterEnd);};
shutter.onpointerdown=e=>{shutterLatched=false;shutterGesture={x:e.clientX,y:e.clientY,dragged:false};window.addEventListener('pointermove',shutterMove);window.addEventListener('pointerup',shutterEnd);window.addEventListener('pointercancel',shutterEnd);};
shutter.onclick=e=>{const latched=e.detail>0&&shutterLatched;shutterLatched=false;if(!e.isTrusted||latched)return;requestShutter(nativeShell?.profile!=='closed');};
shutter.onkeydown=e=>{const target=e.key==='ArrowRight'||e.key==='End'?true:e.key==='ArrowLeft'||e.key==='Home'?false:null;if(target!==null&&e.isTrusted){e.preventDefault();requestShutter(target);}};
 // WP-10: the header date keys. Until the app-owned range (WP-09) lands the keys only show the request locally.
 const headerRange=mountHeaderRange(root,range=>{if(requestRange(range))deck.range(range);else headerRange.set(nativeShell?.range??INITIAL_RANGE);},INITIAL_RANGE);
 const attach=root.querySelector<HTMLButtonElement>('[data-detach]')!,close=root.querySelector<HTMLButtonElement>('[data-close]')!;
 const noMenu=(e:Event)=>e.preventDefault();document.addEventListener('contextmenu',noMenu);
 // Owner badcase 11-21 (B1): a pressed control (the date keys' roving radio, the fader scale and travel, the record
 // lines, and any native button such as the session tape's linked lines and its "more sessions" key, ghglm-1135-1)
 // takes macOS WebKit focus from a mouse press, and the next key press (Esc, Space, T) then
 // matches :focus-visible and drew the keyboard ring around a control the user only clicked. A pointer press marks the
 // control (data-pointer-focus) and its ring stays off while it keeps that focus; it still takes focus, so the arrow
 // keys work after a click, and the first keyboard move to another control (Tab, an arrow) shows that one's ring.
 // Only a control that takes focus from that press is marked: WebKit does not focus a plain button on a click, and a
 // mark left on it would hide the ring of a later Tab to it.
 let pressed:HTMLElement|null=null;
 const pointerKeepsFocus=(e:MouseEvent)=>{pressed=null;if(!e.isTrusted||!(e.target instanceof Element))return;const c=e.target.closest(POINTER_UNFOCUSED);if(c instanceof HTMLElement&&root.contains(c)){pressed=c;if(document.activeElement===c)c.dataset.pointerFocus='';}};
 const pointerFocusStarts=(e:FocusEvent)=>{if(pressed&&e.target===pressed)pressed.dataset.pointerFocus='';};
 const pointerPressEnds=()=>{pressed=null;};
 const pointerFocusEnds=(e:FocusEvent)=>{if(e.target instanceof HTMLElement)delete e.target.dataset.pointerFocus;};
 root.addEventListener('mousedown',pointerKeepsFocus,true);root.addEventListener('focusin',pointerFocusStarts,true);
 window.addEventListener('mouseup',pointerPressEnds,true);root.addEventListener('focusout',pointerFocusEnds,true);
 frame.settings.classList.add('s6-strip-key');attach.classList.add('s6-strip-key');close.classList.add('s6-strip-key');
 const cap=element('section',undefined,'s6-closed-cap');cap.hidden=true;
 cap.style.pointerEvents='auto';cap.style.gridRow='1';cap.style.gridColumn='1';cap.style.alignSelf='end';cap.style.padding='12px';cap.style.background='var(--port-bg)';cap.style.borderRadius='8px';
 const reason=element('span');reason.id='s6-closed-reason';reason.setAttribute('role','status');cap.append(reason);root.append(cap);
 attach.onclick=e=>{if(e.isTrusted&&nativeShell)action(nativeShell.attached?'detach':'putBack');};
 close.onclick=e=>{if(e.isTrusted)action('close');};
 // WP-22 (macrevb-1062-3): the porthole marks the selected model's rocket by its published name (the still's one key).
 const markPorthole=(id:string|null)=>{const name=id===null?null:lastData?.details?.publishedModels?.find(m=>m.id===id)?.name??null;root.dispatchEvent(new CustomEvent('model-select',{detail:name}));};
 const unwireHud=wireHud(frame.hud,id=>{plugins.openScreen(null);hudSelected=id;markPorthole(id);deck.showTune(id);if(lastData)paintHud(frame.hud,lastData,tier!=='tall',locale,hudOptions());});
 let showProjectNames=true;
 const paintRecords=(data:WireCockpitData,at:number)=>{const shown=showProjectNames?data:withoutProjectNames(data);deck.render(shown,at);tape.render(shown,showProjectNames,at);};
 function shellControls(){
  const zh=locale==='zh-CN', closed=nativeShell?.profile==='closed', forced=!!nativeShell?.forcedClosed;
  const alert=root.querySelector<HTMLElement>('.s6-alert')!;alert.setAttribute('aria-label',alert.classList.contains('lit')?(ht(locale,'host.alertActive')):(ht(locale,'host.alertInactive')));
  attach.setAttribute('aria-pressed',String(!nativeShell?.attached));attach.setAttribute('aria-label',nativeShell?.attached?(ht(locale,'host.detachAria')):(ht(locale,'host.attach')));close.setAttribute('aria-label',ht(locale,'host.closeAria'));
  reason.textContent=forced?(ht(locale,'host.forcedClosedReason')):'';
  shutter.setAttribute('aria-label',ht(locale,'host.shutterAria'));shutter.setAttribute('aria-pressed',String(closed));shutter.setAttribute('aria-describedby',reason.id);shutter.title=reason.textContent||ht(locale,closed?'host.portholeOpen':'host.portholeClose');shutter.disabled=!active||!nativeShell||forced;
  attach.hidden=!nativeShell;close.hidden=!nativeShell;
  attach.disabled=!active||!nativeShell;close.disabled=!active||!nativeShell;
  shutterLayout(closed);
  if(closed){stop();caution.classList.remove('flash');}
 }
 function drawShell(closed:boolean){
  cap.hidden=!closed;cap.style.display=closed?'block':'none';
  root.querySelector<HTMLElement>('.ck-portrow')!.style.visibility=closed?'hidden':'';
  root.dataset.shell=closed?'closed':'open';root.style.setProperty('--body-h',(closed?(tier==='tall'?691:609):(tier==='tall'?905:635))+'px');
 }
 // G3-108 (owner, build 14e): the porthole itself closes and opens; the body never moves on the page (the closed root
 // stands on the open root's floor, cockpit.css), so the native window's own motion is the only one the body makes.
 // Closing, the glass slides down into the hull top (cockpit.css `cockpit-shutter`, 250 ms) and then
 // the slab is drawn; opening, the open shell is drawn at once and the glass rises out of the hull top. The native side uses the same 250 ms. Reduce Motion, a
 // hidden page and the first shell draw at once (CKP-MOT-03). The page keeps no timers (bundle.test.mjs): the motion
 // ends on the animation's own finish. That is its `finished` promise, settled with the animation itself, not the
 // animationend event, which waits for a later rendering update (macrev2-923-1: a loaded runner left it undelivered).
 // A cancelled run (the class removed, a newer motion) settles too, unless a newer motion has started since.
 const portrow=root.querySelector<HTMLElement>('.ck-portrow')!;
 let shutterRun:Animation|null=null;
 const shutterEnded=(run:Animation)=>{if(run===shutterRun){shutterRun=null;finishShutter();}};
 function shutterLayout(closed:boolean){
  const want=closed?'closed':'open',motion=root.dataset.shell!==undefined&&active&&!reduceMotion&&!motionQuery.matches;
  if(closed&&root.dataset.shutterMotion==='closing')return;
  // The opening twin (macrev2-923-1): a shell refresh in the 250 ms must not drop the motion and snap the glass open.
  if(!closed&&root.dataset.shutterMotion==='opening')return;
  delete root.dataset.shutterMotion;
  if(root.dataset.shell===want||!motion){drawShell(closed);return;}
  root.dataset.shutterMotion=closed?'closing':'opening';
  // Closing, the page shows the open layout under data-shell="closing", so every open-only motion (porthole flicker,
  // caution blink, cursors, mouth shimmer: [data-shell="open"]) stops at once, as for a closed page.
  if(closed)root.dataset.shell='closing';else drawShell(false);
  // No motion drawn (the stylesheet's own Reduce Motion rule): settle at once.
  const run=portrow.getAnimations().find(a=>(a as CSSAnimation).animationName==='cockpit-shutter');
  shutterRun=run??null;
  if(!run){finishShutter();return;}
  run.finished.then(()=>shutterEnded(run),()=>shutterEnded(run));
 }
 // The motion's end, or a hidden page cutting it short (MOT-2.3-08: a hidden page runs no animation).
 function finishShutter(){
  shutterRun=null;
  if(root.dataset.shutterMotion===undefined)return;
  delete root.dataset.shutterMotion;drawShell(nativeShell?.profile==='closed');
 }
 function localise(now?:number){
  document.documentElement.lang=locale;deck.locale(locale,now);tape.locale(locale);frame.settings.setAttribute('aria-label',ht(locale,'host.settingsAria'));
  for(const e of root.querySelectorAll<HTMLElement>('[data-en][data-zh]')){e.textContent=locale==='en'?e.dataset.en!:e.dataset.zh!;if(e.tagName==='BUTTON')e.setAttribute('aria-label',e.textContent);else if(e.classList.contains('ek-name'))e.parentElement?.setAttribute('aria-label',e.textContent);}
  shellControls();help.refresh();
 }
 const bilingual=(e:HTMLElement,en:string,zh:string)=>{e.dataset.en=en;e.dataset.zh=zh;return e;};
 frame.settings.onclick=e=>{if(e.isTrusted)action('openSettings');};
 // A website link never navigates the page: native opens the typed page it names, on a real press only.
 root.addEventListener('click',e=>{const link=(e.target as Element).closest?.<HTMLAnchorElement>('a.website-link');if(!link)return;e.preventDefault();const target=websiteAction(link.href);if(e.isTrusted&&target)action('openWebsite',target);});
 const stop=()=>frame.lamp.classList.remove('state-pulse');
 const displayedState=()=>[frame.engine.innerHTML,frame.hud.innerHTML,frame.mfd.innerHTML].join('\0');
 const pulse=()=>{stop();if(!active||nativeShell?.profile==='closed'||reduceMotion||matchMedia('(prefers-reduced-motion: reduce)').matches)return;void frame.lamp.offsetWidth;frame.lamp.classList.add('state-pulse');};
 // Plugin columns (D121/D124, D293): one host per page; the engine table lays its columns out through it.
 const plugins=mountPluginHost(root,reportPlugins);
 // S18 (sampling 11-21, ADR 0005): the engine's floating tooltip is appended outside the table (the document body when
 // the page root is #cockpit itself); it goes with the table, synchronously, so no private text outlives a clear or a re-render.
 const dropEngineTips=()=>{for(const tip of root.ownerDocument.querySelectorAll('.eng-hint'))tip.remove();};
 const setEmpty=(key:'waiting'|'cleared'|'empty',keepDeck=false)=>{dropEngineTips();root.dataset.engineEmpty=String(key==='empty');headerRange.dim(key==='empty');plugins.bindEngine(null);plugins.clearPlacement();plugins.display(null,lastRenderedAt);base.clear();frame.hud.replaceChildren();frame.hud.hidden=true;hudSelected=null;markPorthole(null);caution.classList.remove('flash');refreshEngine=null;localiseEngine=null;quotaFocusIdentity=null;const alert=root.querySelector<HTMLElement>('.s6-alert')!;alert.classList.remove('lit','red','amber');alert.setAttribute('aria-label',ht(locale,'host.alertInactive'));applyScope=null;const line=bilingual(element('p',ht(locale,'host.'+key),'ec-empty'),ht('en','host.'+key),ht('zh-CN','host.'+key));
  // CKP-SHELL-39: with no subscription read yet the screen says so in one line and offers one way in, Settings > Subscriptions.
  if(key==='empty'){const open=element('button',ht(locale,'host.emptyOpen'),'ec-empty-open');bilingual(open,ht('en','host.emptyOpen'),ht('zh-CN','host.emptyOpen'));open.type='button';open.setAttribute('aria-label',ht(locale,'host.emptyOpen'));open.onclick=e=>{if(e.isTrusted)action('openSettingsSubscriptions');};const box=element('div',undefined,'ec-empty-box');box.append(line,open);frame.engine.replaceChildren(box);}
  else frame.engine.replaceChildren(line);frame.hud.replaceChildren();if(!keepDeck){deck.clear();tape.clear();}};
 function nextDeadline(data:WireCockpitData,now:number):number|null {
  let next=Infinity;
  for(const row of data.projection.rows)for(const account of row.accounts)if(account.valueState==='current')for(const w of account.windows){
   if(!w.current||w.remainingPercent===null||w.validUntil===null)continue;
   const at=Date.parse(w.validUntil);if(Number.isFinite(at)&&at>now)next=Math.min(next,at);
  }
  for(const event of data.details?.resetEvents??[]){const at=Date.parse(event.expiresAt);if(Number.isFinite(at)&&at>now)next=Math.min(next,at);}
  // A run-out stops being a forecast when it passes; the amber lamp, row and cell must clear then, with no new reading.
  for(const forecast of data.details?.forecasts??[]){const at=forecast.runsOutAt?Date.parse(forecast.runsOutAt):NaN;if(Number.isFinite(at)&&at>now)next=Math.min(next,at);}
  // D277 (CKP-STRIP-16): the session strip's elapsed time and "6m ago" are "now"; while it lists a session, the next
  // whole minute is a deadline so they move without a new reading.
  const details=data.details;if(details?.sessionCoverage==='local-last-seen'&&details.sessions.some(s=>s.state==='running'||s.state==='idle'))next=Math.min(next,(Math.floor(now/60000)+1)*60000);
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
  let path:number[]|null=null;const keys=['data-al-id','data-focus-member','data-scope','data-page','data-mfd','data-opt','data-row','data-col','data-bpage','data-add-subscription','aria-label'];
  const key=focused&&area?keys.find(k=>focused.hasAttribute(k)):undefined;
  const keyValue=key&&focused?focused.getAttribute(key):null;
  const priorPage=key==='data-add-subscription'?frame.engine.querySelector('[data-page][aria-current="true"]')?.getAttribute('data-page')??null:null;
  if(focused&&area){path=[];for(let n:Element|null=focused;n&&n!==area;n=n.parentElement)path.unshift(Array.prototype.indexOf.call(n.parentElement?.children,n));}
  update();
  if(!focused||!area||focused.isConnected||!active||document.hidden)return;
  const current=document.activeElement;if(current&&current!==document.body&&current!==document.documentElement&&current!==focused)return;
  if(key==='data-add-subscription'&&priorPage!==(frame.engine.querySelector('[data-page][aria-current="true"]')?.getAttribute('data-page')??null))return;
  // CKP-MFD-56: an alert row names its subscription; a fallback identity (row#route#position) can be reassigned by a new
  // snapshot, so across a replacement the focus is kept only for a verified subscription present in both snapshots.
  if(key==='data-al-id'&&replacing){const alertMember=focused.dataset.alMember??'',has=(d:WireCockpitData|null)=>!!d?.subscriptions.some(s=>s.subscriptionRef===alertMember);if(!alertMember||!has(previousData)||!has(lastData))return;}
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
  // CKP-MFD-56: an alert row is found by its identity only; a refresh that re-sorts the list must never hand its focus to another subscription's row.
  if(!target&&path&&key!=='data-al-id'){let e:Element|null=area;for(const i of path)e=e?.children.item(i)??null;if(e instanceof HTMLElement&&e.tagName===focused.tagName&&(key?e.getAttribute(key)===keyValue:e.className===focused.className))target=e;}
  target?.focus({preventScroll:true});
 }
 function refreshDeadlines(now:number){if(!lastData||disposed)return;lastRenderedAt=now;preserveFocus(()=>{refreshEngine?.(now);deck.refresh(now);tape.refresh(now);syncCaution(lastData!,now);plugins.tick(now);});}
 // Recovery contract: a render is transactional. If it throws, the last rendered data is painted again (or the page
 // returns to its waiting state when there was none) and the error goes back to the bridge, which refuses the display
 // and keeps the page. Whether that repaint succeeds or fails, the whole cockpit view is
 // put back as it was before the render: every element under the root gets its own child nodes, attributes, handler
 // properties and form values back, so the engine, HUD, MFD, records and lamp keep their committed nodes and controls;
 // the view's own state (engine closures, shell scope, last data) is restored with them. Nothing is repainted afterwards, so
 // a failure that persists cannot erase the view again. lastData never points at data that did not render.
 let restoring=false;
 const HANDLERS=['onclick','onchange','oninput','onkeydown','onlostpointercapture','onpointercancel','onpointerdown','onpointerleave','onpointermove','onpointerover','onpointerup'] as const;
 type Handlers=Partial<Record<typeof HANDLERS[number],unknown>>;
 function snapshot(){
  const elements=[root,...root.querySelectorAll<HTMLElement>('*')].map(element=>{
   const handlers:Handlers={};for(const key of HANDLERS){const value=(element as unknown as Record<string,unknown>)[key];if(value)handlers[key]=value;}
   const form=element instanceof HTMLInputElement?{value:element.value,checked:element.checked}:null;
   return {element,children:[...element.childNodes],attributes:[...element.attributes].map(a=>[a.name,a.value] as const),handlers,form};
  });
  const saved={applyScope,refreshEngine,localiseEngine,quotaFocusIdentity,nativeShell,lastData,lastRenderedAt};
  // The deck, tape and lamp keep render state of their own (glm-990-1): it is put back with the view.
  const modules=[deck.checkpoint(),tape.checkpoint(),cautions.checkpoint()];
  return ()=>{
   for(const {element,children,attributes,handlers,form} of elements){
    element.replaceChildren(...children);
    for(const name of element.getAttributeNames())if(!attributes.some(([kept])=>kept===name))element.removeAttribute(name);
    for(const [name,value] of attributes)if(element.getAttribute(name)!==value)element.setAttribute(name,value);
    for(const key of HANDLERS)(element as unknown as Record<string,unknown>)[key]=handlers[key]??null;
    if(form&&element instanceof HTMLInputElement){element.value=form.value;element.checked=form.checked;}
   }
   ({applyScope,refreshEngine,localiseEngine,quotaFocusIdentity,nativeShell,lastData,lastRenderedAt}=saved);
   for(const restore of modules)restore();
  };
 }
 function renderData(data:WireCockpitData,now:number){
  // Owner badcase 11-21 (B1): within one page context (a consent or store change arrives as `clear` first and drops
  // lastData), a reply whose history the engine could not read this time ("unavailable" right after "local-history") is
  // a loading state, not "no usage record yet". The last local history stays for up to HISTORY_HOLD_MS; "recording-off"
  // and a newer local history always replace it.
  const held=heldHistory&&data.history?.coverage==='unavailable'&&now-heldHistory.at>=0&&now-heldHistory.at<HISTORY_HOLD_MS?heldHistory:null;
  const nextHeld=data.history?.coverage==='local-history'?{history:data.history,at:now}:held;
  if(held)data={...data,history:held.history};
  const previous=lastData,previousAt=lastRenderedAt,restore=snapshot(),restoreDeck=deck.checkpoint();
  try{renderInto(data,now);heldHistory=nextHeld;}
  catch(error){
   if(!restoring&&!disposed){
    restoring=true;
    try{restoreDeck(); /* the refused data was already the deck's (and its held efforts'): put the committed deck back before repainting the previous data (macrevb-1052-3) */if(previous)renderInto(previous,previousAt);else{lastData=null;frame.engine.replaceChildren();setEmpty('waiting');}}
    catch{/* The committed snapshot also covers a failed repaint. */}
    finally{restore();restoring=false;}
   }
   throw error;
  }
 }
 function renderInto(data:WireCockpitData,now:number){
  preserveFocus(()=>{
   const previousData=lastData;lastData=data;lastRenderedAt=now;
   if(disposed)throw Error('closed');const before=displayedState();const priorPage=Number(frame.engine.querySelector('[data-page][aria-current="true"]')?.getAttribute('data-page')??0);const priorButton=frame.engine.querySelector<HTMLButtonElement>('.ek[aria-pressed="true"]');const selectedScope=nativeShell?.scope??priorButton?.dataset.scope??'all';const unstable=(previousData?cockpitMembers(previousData):[]).some(m=>m.key===selectedScope&&m.unstable)||cockpitMembers(data).some(m=>m.key===selectedScope&&m.unstable);const priorScope=unstable?'':selectedScope==='all'?'':selectedScope;if(unstable){retiredUnstableScopes.add(selectedScope);if(nativeShell)nativeShell={...nativeShell,scope:'all'};}applyScope=null;pluginHostOf(root)?.hold();dropEngineTips();frame.engine.replaceChildren();
   const engine=renderPrototypeEngine(data,locale,root,priorScope,key=>{if(!active)return false;retiredUnstableScopes.delete(key);action('scopeSelect',key);if(nativeShell)nativeShell={...nativeShell,scope:key};updateScopeHud();deck.scope(key);return true;},()=>{if(!active)return false;action('openSettingsSubscriptions');return true;},priorPage,lastRenderedAt,redBelow,showUsed,key=>{if(!active)return false;action('refreshMember',key);return true;});
   // No widget subscription yet (every row still lacks a dock surface): the engine says so, but admitted sessions and
   // the publication's faders stay visible (post-merge sample 11-11, #847 finding 1).
   if(!engine){
    // A routine refresh must not reset an open alert list: when the deck still has something to show (details, or list-only
    // alerts) it is kept and repainted from the new data; only a projection with nothing left clears it.
    const keep=!!data.details||cautionItems(data,now,redBelow()).length>0;
    setEmpty('empty',keep);if(keep){deck.scope('all');paintRecords(data,lastRenderedAt);}return;}root.dataset.engineEmpty='false';headerRange.dim(false);frame.engine.append(engine.table);engine.fit();plugins.display(data,now);applyScope=engine.applyScope;refreshEngine=engine.refresh;localiseEngine=engine.setLocale;quotaFocusIdentity=engine.focusIdentity;deck.scope(nativeShell?.scope??'all');paintRecords(data,lastRenderedAt);paintHud(frame.hud,data,tier!=='tall',locale,hudOptions());syncCaution(data,now);help.refresh();
   if(before!==displayedState())pulse();
  },true);
 }
 setEmpty('waiting');
 return {
  restoreAcked(ids){cautions.restore(ids);},
  restorePins(ids){deck.restorePins(ids);},
  forgetAcked(){cautions.forget();},
  configure(value,threshold,used=false,allModels=false,order=[]){setMemberOrder(order);selectedRedBelow=threshold;showUsedPercent=used;deck.showAllModels(allModels);locale=value.locale;headerRange.locale(locale);showProjectNames=value.showProjectNames;reduceMotion=value.reduceMotion;syncReduced();document.documentElement.lang=locale;document.documentElement.dataset.theme=value.theme;document.documentElement.dataset.reduceMotion=String(value.reduceMotion);document.documentElement.dataset.reduceTransparency=String(value.reduceTransparency);frame.hud.classList.toggle('solid',value.reduceTransparency);deck.locale(locale);tape.locale(locale);frame.settings.setAttribute('aria-label',ht(locale,'host.settingsAria'));setEmpty('waiting');},
  updateAppearance(value:LiveAppearance,now:number,threshold,used=false,allModels=false,order=[]){const orderChanged=setMemberOrder(order);showUsedPercent=used;deck.showAllModels(allModels);const namesChanged=showProjectNames!==value.showProjectNames;showProjectNames=value.showProjectNames;selectedRedBelow=threshold;locale=value.locale;headerRange.locale(locale);reduceMotion=value.reduceMotion;syncReduced();document.documentElement.dataset.theme=value.theme;document.documentElement.dataset.reduceMotion=String(value.reduceMotion);document.documentElement.dataset.reduceTransparency=String(value.reduceTransparency);frame.hud.classList.toggle('solid',value.reduceTransparency);if(reduceMotion){stop();caution.classList.remove('flash');}if(lastData){lastRenderedAt=now;preserveFocus(()=>{localise(lastRenderedAt);localiseEngine?.(locale,lastRenderedAt);paintHud(frame.hud,lastData!,tier!=='tall',locale,hudOptions());if(namesChanged)paintRecords(lastData!,lastRenderedAt);syncCaution(lastData!,lastRenderedAt);});if(orderChanged)renderData(lastData,now);}else localise();},
  shell(value:ShellState){if(retiredUnstableScopes.has(value.scope))value={...value,scope:'all'};const changed=(nativeShell?.scope??'all')!==value.scope;nativeShell=value;preserveFocus(()=>{tier=value.tier;const h=tier==='tall'?890:640,layout=cockpitLayout(h);document.documentElement.dataset.profile=tier==='tall'?'full':'compact';root.dataset.layout=String(h);root.style.setProperty('--console-h',layout.console+'px');root.style.setProperty('--tape-h',layout.tapeH+'px');root.style.setProperty('--eng-h',layout.eng+'px');tape.layout(layout.tapeLines);shellControls();headerRange.set(value.range??INITIAL_RANGE);deck.range(value.range??INITIAL_RANGE);if(lastData)paintHud(frame.hud,lastData,tier!=='tall',locale,hudOptions());if(changed){applyScope?.(value.scope);deck.scope(value.scope);}});},
  ignite(on){if(on)root.dataset.ignite='true';else delete root.dataset.ignite;},
  // WP-22 (macrevb-1062-3): a rocket chosen or cleared in the enlarged field selects the same model on the HUD, the
  // faders and the porthole. Selection only: the MFD page does not change and no tried effort arrives with it.
  fieldClosed(){root.dispatchEvent(new CustomEvent('field-closed'));},
  selectModel(id){hudSelected=id;markPorthole(id);deck.selectModel(id);if(lastData)preserveFocus(()=>paintHud(frame.hud,lastData!,tier!=='tall',locale,hudOptions()));},
  render:renderData,
  nextDeadline(){if(!lastData)return null;const own=nextDeadline(lastData,lastRenderedAt),plugin=plugins.nextDeadline();return own===null?plugin:plugin===null?own:Math.min(own,plugin);},
  tick(now){refreshDeadlines(now);},
  clear(){retiredUnstableScopes.clear();caution.classList.remove('flash');lastData=null;heldHistory=null;stop();setEmpty('cleared');if(nativeShell)nativeShell={...nativeShell,scope:'all'};delete root.dataset.scope;},
  active(value,now){const was=active;active=value;plugins.setInteractive(value);root.dataset.active=String(value);if(!value)finishShutter();frame.settings.disabled=!value;shellControls();if(!value){deck.cancelPress();stop();caution.classList.remove('flash');help.hide();}else if(!was&&lastData){if(now!==undefined)lastRenderedAt=now;syncCaution(lastData,lastRenderedAt);}},
  visible(value){plugins.setVisible(value);},
  plugins(raw){return plugins.applyHostState(raw);},
  pluginData(id,data){return plugins.deliver(id,data);},
  openPluginScreen(id){return plugins.openScreen(id,true);},
  dispose(){if(disposed)return;disposed=true;shutterRun=null;plugins.dispose();base.dispose();unwireHud();document.removeEventListener('contextmenu',noMenu);root.removeEventListener('mousedown',pointerKeepsFocus,true);root.removeEventListener('focusin',pointerFocusStarts,true);window.removeEventListener('mouseup',pointerPressEnds,true);root.removeEventListener('focusout',pointerFocusEnds,true);pressed=null;window.removeEventListener('keydown',scopeShortcut);window.removeEventListener('keydown',rangeShortcut);caution.onclick=null;caution.removeEventListener('animationend',finishCaution);motionQuery.removeEventListener('change',motionChanged);applyScope=null;refreshEngine=null;localiseEngine=null;quotaFocusIdentity=null;lastData=null;nativeShell=null;deck.dispose();help.dispose();stop();frame.settings.onclick=null;attach.onclick=null;shutter.onclick=null;shutter.onpointerdown=null;shutter.onpointermove=null;shutter.onpointerup=null;shutter.onpointercancel=null;shutter.onlostpointercapture=null;shutter.onkeydown=null;close.onclick=null;root.replaceChildren();root.removeAttribute('data-active');delete root.dataset.scope;},
 };
}

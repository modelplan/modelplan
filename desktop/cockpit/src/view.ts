// SPDX-License-Identifier: MIT
import type { WireCockpitData, WireWindow } from '../generated/wire.js';
import type { Appearance,CockpitView,LiveAppearance,ShellState,PageAction } from './bridge.js';
import { prototypeFrame } from './prototype-frame.js';
import { cockpitLayout } from './prototype-layout.js';
import { renderPrototypeEngine } from './prototype-engine.js';
import { mountPrototypeDeck } from './prototype-deck.js';
const words={en:{all:'All',settings:'Settings',waiting:'Waiting for display data',cleared:'Display data cleared',empty:'No subscriptions',rows:['5h','Weekly','Other'],page:'Page',resets:'resets in',now:'now'},'zh-CN':{all:'全部',settings:'设置',waiting:'等待显示数据',cleared:'显示数据已清除',empty:'无订阅',rows:['5小时','每周','其他'],page:'第',resets:'后重置',now:'现在'}};
const element=<K extends keyof HTMLElementTagNameMap>(tag:K,text?:string,className?:string):HTMLElementTagNameMap[K]=>{const e=document.createElement(tag);if(text!==undefined)e.textContent=text;if(className)e.className=className;return e;};
const status=(n:number|null)=>n===null?'':n<=25?'red':n<=40?'amber':'ok';
const count=(n:number|null)=>n===null||n<=0?0:Math.max(1,Math.min(10,Math.round(n/10)));
export function mountCockpit(root:HTMLElement,action:(kind:PageAction,tool?:string)=>void):CockpitView {
 let locale:Appearance['locale']='en',disposed=false,active=false,reduceMotion=false;
 let nativeShell:ShellState|null=null,tier:ShellState['tier']='tall';
 let applyScope:((scope:string)=>void)|null=null;
 const frame=prototypeFrame(root);const deck=mountPrototypeDeck(root);
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
 const attach=element('button',undefined,'key'),close=element('button',undefined,'key');
 attach.dataset.detach='';close.dataset.close='';for(const b of [attach,close]){b.type='button';head.append(b);}
 frame.settings.classList.add('s6-strip-key');attach.classList.add('s6-strip-key');close.classList.add('s6-strip-key');
 const cap=element('section',undefined,'s6-closed-cap');cap.hidden=true;
 cap.style.pointerEvents='auto';cap.style.gridRow='1';cap.style.gridColumn='1';cap.style.alignSelf='end';cap.style.padding='12px';cap.style.background='var(--port-bg)';cap.style.borderRadius='8px';
 const reason=element('span');reason.id='s6-closed-reason';reason.setAttribute('role','status');cap.append(reason);root.append(cap);
 attach.onclick=e=>{if(e.isTrusted&&nativeShell)action(nativeShell.attached?'detach':'putBack');};
 close.onclick=e=>{if(e.isTrusted)action('close');};
 function shellControls(){
  const zh=locale==='zh-CN', closed=nativeShell?.profile==='closed', forced=!!nativeShell?.forcedClosed;
  root.querySelector<HTMLElement>('.s6-alert')!.setAttribute('aria-label',zh?'告警未激活':'Alert inactive');
  attach.textContent=nativeShell?.attached?'⇱':'⇲';
  attach.setAttribute('aria-pressed',String(!nativeShell?.attached));attach.setAttribute('aria-label',nativeShell?.attached?(zh?'分离':'Detach'):(zh?'放回':'Put back'));close.textContent='✕';close.setAttribute('aria-label',zh?'关闭':'Close');
  reason.textContent=forced?(zh?'窗口高度不足，无法打开':'Not enough window height to open'):'';
  shutter.setAttribute('aria-label',zh?'舷窗快门':'Porthole shutter');shutter.setAttribute('aria-pressed',String(closed));shutter.setAttribute('aria-describedby',reason.id);shutter.title=reason.textContent;shutter.disabled=!active||!nativeShell||forced;
  attach.hidden=!nativeShell;close.hidden=!nativeShell;
  attach.disabled=!active||!nativeShell;close.disabled=!active||!nativeShell;
  cap.hidden=!closed;cap.style.display=closed?'block':'none';
  root.querySelector<HTMLElement>('.ck-portrow')!.style.visibility=closed?'hidden':'';
  root.dataset.shell=closed?'closed':'open';root.style.setProperty('--body-h',(closed?(tier==='tall'?691:609):(tier==='tall'?890:640))+'px');
  if(closed)stop();
 }
 function localise(){
  document.documentElement.lang=locale;deck.locale(locale);frame.settings.textContent='⚙';frame.settings.setAttribute('aria-label',words[locale].settings);
  for(const e of root.querySelectorAll<HTMLElement>('[data-en][data-zh]')){e.textContent=locale==='en'?e.dataset.en!:e.dataset.zh!;if(e.tagName==='BUTTON')e.setAttribute('aria-label',e.textContent);else if(e.classList.contains('ek-name'))e.parentElement?.setAttribute('aria-label',e.textContent);}
  for(const e of root.querySelectorAll<HTMLElement>('[data-reset]'))e.textContent=relative(e.dataset.reset??null);
  for(const e of root.querySelectorAll<HTMLButtonElement>('.eng-led[data-page]')){const n=Number(e.dataset.page)+1;e.setAttribute('aria-label',locale==='en'?`Page ${n}`:`第 ${n} 页`);}
  shellControls();
 }
 const bilingual=(e:HTMLElement,en:string,zh:string)=>{e.dataset.en=en;e.dataset.zh=zh;return e;};
 frame.settings.onclick=e=>{if(e.isTrusted)action('openSettings');};
 const stop=()=>frame.lamp.classList.remove('state-pulse');
 const settled=()=>{if(!frame.lamp.getAnimations().some(a=>a.playState==='running'))stop();};
 frame.lamp.addEventListener('animationend',settled);frame.lamp.addEventListener('animationcancel',settled);
 const displayedState=()=>[frame.engine.innerHTML,frame.hud.innerHTML,frame.mfd.innerHTML].join('\0');
 const pulse=()=>{stop();if(!active||nativeShell?.profile==='closed'||reduceMotion||matchMedia('(prefers-reduced-motion: reduce)').matches)return;void frame.lamp.offsetWidth;frame.lamp.classList.add('state-pulse');};
 const setEmpty=(key:'waiting'|'cleared'|'empty')=>{applyScope=null;frame.engine.replaceChildren(bilingual(element('p',words[locale][key],'ec-empty'),words.en[key],words['zh-CN'][key]));frame.hud.replaceChildren();deck.clear();frame.tape.replaceChildren();};
 function relative(raw:string|null):string {
  if(!raw)return '';const delta=Date.parse(raw)-Date.now();if(!Number.isFinite(delta))return '';
  const mins=Math.max(0,Math.ceil(delta/60000)),d=Math.floor(mins/1440),h=Math.floor(mins%1440/60),m=mins%60;
  const t=[d?`${d}d`:'',h?`${h}h`:'',m||(!d&&!h)?`${m}m`:''].filter(Boolean).join(' ');
  return locale==='en'?`${words.en.resets} ${t}`:`${t} ${words['zh-CN'].resets}`;
 }
 function cell(w:WireWindow|undefined,other=false):HTMLElement {
  // DOM equivalent of the study engine-view cell; wire text is never HTML.
  const box=element('div',undefined,'qcell');if(!w){box.classList.add('none');return box;}
  const s=status(w.remainingPercent);box.dataset.status=s;
  const line=element('span',undefined,'qline'),num=element('b',undefined,'qnum');
  num.append(element('span',w.remainingPercent===null?'--':String(Math.round(w.remainingPercent)),'qvalue'));
  if(w.remainingPercent!==null)num.append(element('small','%'));line.append(num);
  const info=element('em',undefined,'qtxt');
  if(other){const en=w.role==='monthly'?'mo':w.label.en,zh=w.role==='monthly'?'月':w.label.zh;info.append(bilingual(element('span',locale==='en'?en:zh),en,zh));}
  if(w.resetsAt){const txt=relative(w.resetsAt);if(txt){const reset=element('span',txt,'qreset');reset.dataset.reset=w.resetsAt;info.append(reset);}}
  line.append(info);box.append(line);
  const meter=element('span',undefined,'qmeter'),bar=element('span',undefined,'qbar');for(let i=0;i<10;i++)bar.append(element('i',undefined,i<count(w.remainingPercent)?'on':''));meter.append(bar);
  if(w.resetsAt&&w.durationSeconds&&w.durationSeconds>0){const fraction=Math.max(0,Math.min(1,(Date.parse(w.resetsAt)-Date.now())/(w.durationSeconds*1000)));const dots=element('span',undefined,'qtime');for(let i=0;i<10;i++)dots.append(element('i',undefined,i<(fraction>0?Math.max(1,Math.ceil(fraction*10)):0)?'on':''));meter.append(dots);}
  box.append(meter);return box;
 }
 setEmpty('waiting');
 return {
  configure(value){locale=value.locale;reduceMotion=value.reduceMotion;document.documentElement.lang=locale;document.documentElement.dataset.theme='night';document.documentElement.dataset.reduceMotion=String(value.reduceMotion);document.documentElement.dataset.reduceTransparency=String(value.reduceTransparency);frame.hud.classList.toggle('solid',value.reduceTransparency);deck.locale(locale);frame.settings.textContent='⚙';frame.settings.setAttribute('aria-label',words[locale].settings);setEmpty('waiting');},
  updateAppearance(value:LiveAppearance){locale=value.locale;reduceMotion=value.reduceMotion;document.documentElement.dataset.theme='night';document.documentElement.dataset.reduceMotion=String(value.reduceMotion);document.documentElement.dataset.reduceTransparency=String(value.reduceTransparency);frame.hud.classList.toggle('solid',value.reduceTransparency);if(reduceMotion)stop();localise();},
  shell(value:ShellState){nativeShell=value;tier=value.tier;const h=tier==='tall'?890:640,layout=cockpitLayout(h);document.documentElement.dataset.profile=tier==='tall'?'full':'compact';root.dataset.layout=String(h);root.style.setProperty('--console-h',layout.console+'px');root.style.setProperty('--tape-h',layout.tapeH+'px');root.style.setProperty('--eng-h',layout.eng+'px');shellControls();applyScope?.(value.scope);},
  render(data:WireCockpitData){
   if(disposed)throw Error('closed');const before=displayedState();const priorButton=frame.engine.querySelector<HTMLButtonElement>('.ek[aria-pressed="true"]');const unstable=priorButton?.dataset.unstable==='true';const priorScope=unstable?'':priorButton?.dataset.scope??(nativeShell?.scope==='all'?'':nativeShell?.scope??'');if(unstable&&nativeShell)nativeShell={...nativeShell,scope:'all'};applyScope=null;frame.engine.replaceChildren();
   const engine=renderPrototypeEngine(data,locale,root,priorScope,cell,key=>{if(!active)return false;action('scopeSelect',key);if(nativeShell)nativeShell={...nativeShell,scope:key};return true;});
   if(!engine){setEmpty('empty');return;}frame.engine.append(engine.table);applyScope=engine.applyScope;frame.hud.replaceChildren();frame.tape.replaceChildren();
   if(before!==displayedState())pulse();
  },
  clear(){stop();setEmpty('cleared');if(nativeShell)nativeShell={...nativeShell,scope:'all'};delete root.dataset.scope;},
  active(value){active=value;root.dataset.active=String(value);frame.settings.disabled=!value;shellControls();if(!value)stop();},
  dispose(){if(disposed)return;disposed=true;applyScope=null;nativeShell=null;deck.dispose();stop();frame.lamp.removeEventListener('animationend',settled);frame.lamp.removeEventListener('animationcancel',settled);frame.settings.onclick=null;attach.onclick=null;shutter.onclick=null;shutter.onpointerdown=null;shutter.onpointermove=null;shutter.onpointerup=null;shutter.onpointercancel=null;shutter.onlostpointercapture=null;shutter.onkeydown=null;close.onclick=null;root.replaceChildren();root.removeAttribute('data-active');delete root.dataset.scope;},
 };
}

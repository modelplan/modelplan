// SPDX-License-Identifier: MIT
import type { WireCockpitData, WireWindow } from '../generated/wire.js';
import type { Appearance,CockpitView,LiveAppearance,ShellState,PageAction } from './bridge.js';
import { prototypeFrame } from './prototype-frame.js';
import { cockpitLayout } from './prototype-layout.js';
import { cockpitMembers } from './members.js';
const words={en:{all:'All',settings:'Settings',waiting:'Waiting for display data',cleared:'Display data cleared',empty:'No subscriptions',rows:['5h','Weekly','Other'],page:'Page',resets:'resets in',now:'now'},'zh-CN':{all:'全部',settings:'设置',waiting:'等待显示数据',cleared:'显示数据已清除',empty:'无订阅',rows:['5小时','每周','其他'],page:'第',resets:'后重置',now:'现在'}};
const element=<K extends keyof HTMLElementTagNameMap>(tag:K,text?:string,className?:string):HTMLElementTagNameMap[K]=>{const e=document.createElement(tag);if(text!==undefined)e.textContent=text;if(className)e.className=className;return e;};
// General plan quotas use only main/five_hour/weekly limits in the main pool.
const generalWindow=(w:WireWindow)=>!w.modelScope&&w.poolKey==='main'&&
  (w.role==='session'?(w.limitKey==='main'||w.limitKey==='five_hour'):
   w.role==='weekly'?(w.limitKey==='main'||w.limitKey==='weekly'):false);
const status=(n:number|null)=>n===null?'':n<=25?'red':n<=40?'amber':'ok';
const vendorMarks:Readonly<Record<string,string>>={claude:'claude',openai:'openai',cursor:'cursor',copilot:'copilot',kimi:'kimi',glm:'zai-white',opencode:'opencode'};
const count=(n:number|null)=>n===null||n<=0?0:Math.max(1,Math.min(10,Math.round(n/10)));
export function mountCockpit(root:HTMLElement,action:(kind:PageAction,tool?:string)=>void):CockpitView {
 let locale:Appearance['locale']='en',disposed=false,active=false,reduceMotion=false;
 let nativeShell:ShellState|null=null,tier:ShellState['tier']='tall';
 let applyScope:((scope:string)=>void)|null=null;
 const frame=prototypeFrame(root);
 const head=root.querySelector<HTMLElement>('.ck-head')!;head.style.pointerEvents='auto';
 const attach=element('button',undefined,'key'),close=element('button',undefined,'key');
 for(const b of [attach,close]){b.type='button';head.append(b);}
 frame.settings.classList.add('s6-strip-key');attach.classList.add('s6-strip-key');close.classList.add('s6-strip-key');
 const cap=element('section',undefined,'s6-closed-cap');cap.hidden=true;
 cap.style.pointerEvents='auto';cap.style.gridRow='1';cap.style.gridColumn='1';cap.style.alignSelf='end';cap.style.padding='12px';cap.style.background='var(--port-bg)';cap.style.borderRadius='8px';
 const reason=element('span');reason.id='s6-closed-reason';reason.setAttribute('role','status');cap.append(reason);root.append(cap);
 attach.onclick=e=>{if(e.isTrusted&&nativeShell)action(nativeShell.attached?'detach':'putBack');};
 close.onclick=e=>{if(e.isTrusted)action('close');};
 function shellControls(){
  const zh=locale==='zh-CN', closed=nativeShell?.profile==='closed', forced=!!nativeShell?.forcedClosed;
  attach.textContent=nativeShell?.attached?'⇱':'⇲';
  attach.setAttribute('aria-label',nativeShell?.attached?(zh?'分离':'Detach'):(zh?'放回':'Put back'));close.textContent='✕';close.setAttribute('aria-label',zh?'关闭':'Close');
  reason.textContent=forced?(zh?'窗口高度不足，无法打开':'Not enough window height to open'):'';
  attach.hidden=!nativeShell;close.hidden=!nativeShell;
  attach.disabled=!active||!nativeShell;close.disabled=!active||!nativeShell;
  cap.hidden=!closed;cap.style.display=closed?'block':'none';
  for(const selector of ['.ck-portrow','.ck-eng','.ck-deck','.ck-tape']){const e=root.querySelector<HTMLElement>(selector)!;e.style.display=closed?'none':'';}
  root.dataset.shell=closed?'closed':'open';root.style.setProperty('--body-h',(closed?(tier==='tall'?691:609):(tier==='tall'?890:640))+'px');
  if(closed)stop();
 }
 function localise(){
  document.documentElement.lang=locale;frame.settings.textContent='⚙';frame.settings.setAttribute('aria-label',words[locale].settings);
  for(const e of root.querySelectorAll<HTMLElement>('[data-en][data-zh]')){e.textContent=locale==='en'?e.dataset.en!:e.dataset.zh!;if(e.tagName==='BUTTON')e.setAttribute('aria-label',e.textContent);else if(e.classList.contains('ek-name'))e.parentElement?.setAttribute('aria-label',e.textContent);}
  for(const e of root.querySelectorAll<HTMLElement>('[data-reset]'))e.textContent=relative(e.dataset.reset??null);
  for(const e of root.querySelectorAll<HTMLButtonElement>('.eng-led[data-page]')){const n=Number(e.dataset.page)+1;e.setAttribute('aria-label',locale==='en'?`Page ${n}`:`第 ${n} 页`);}
  shellControls();
 }
 const bilingual=(e:HTMLElement,en:string,zh:string)=>{e.dataset.en=en;e.dataset.zh=zh;return e;};
 frame.settings.onclick=e=>{if(e.isTrusted)action('openSettings');};
 const label=(v:{en:string;zh:string})=>locale==='en'?v.en:v.zh;
 const stop=()=>frame.lamp.classList.remove('state-pulse');
 const settled=()=>{if(!frame.lamp.getAnimations().some(a=>a.playState==='running'))stop();};
 frame.lamp.addEventListener('animationend',settled);frame.lamp.addEventListener('animationcancel',settled);
 const displayedState=()=>[frame.engine.innerHTML,frame.hud.innerHTML,frame.mfd.innerHTML].join('\0');
 const pulse=()=>{stop();if(!active||nativeShell?.profile==='closed'||reduceMotion||matchMedia('(prefers-reduced-motion: reduce)').matches)return;void frame.lamp.offsetWidth;frame.lamp.classList.add('state-pulse');};
 const setEmpty=(key:'waiting'|'cleared'|'empty')=>{applyScope=null;frame.engine.replaceChildren(bilingual(element('p',words[locale][key],'ec-empty'),words.en[key],words['zh-CN'][key]));frame.hud.replaceChildren();frame.mfd.replaceChildren();frame.tape.replaceChildren();};
 function relative(raw:string|null):string {
  if(!raw)return '';const delta=Date.parse(raw)-Date.now();if(!Number.isFinite(delta))return '';
  const mins=Math.max(0,Math.ceil(delta/60000)),d=Math.floor(mins/1440),h=Math.floor(mins%1440/60),m=mins%60;
  const t=[d?`${d}d`:'',h?`${h}h`:'',m||(!d&&!h)?`${m}m`:''].filter(Boolean).join(' ');
  return locale==='en'?`${words.en.resets} ${t}`:`${t} ${words['zh-CN'].resets}`;
 }
 function cell(w:WireWindow|undefined,other=false):HTMLElement {
  const box=element('div',undefined,'qcell');if(!w)return box;
  const s=status(w.remainingPercent);box.dataset.status=s;
  const line=element('div',undefined,'qline'),num=element('b',w.remainingPercent===null?'--':`${w.remainingPercent}%`,'qnum');line.append(num);
  if(other){const en=w.role==='monthly'?'mo':w.label.en,zh=w.role==='monthly'?'月':w.label.zh;line.append(bilingual(element('span',locale==='en'?en:zh,'qtxt'),en,zh));}
  box.append(line);const bar=element('span',undefined,'qbar');for(let i=0;i<10;i++)bar.append(element('i',undefined,i<count(w.remainingPercent)?'on':''));box.append(bar);
  if(w.resetsAt){const txt=relative(w.resetsAt);if(txt){const reset=element('span',txt,'qreset');reset.dataset.reset=w.resetsAt;box.append(reset);}}
  if(w.resetsAt&&w.durationSeconds&&w.durationSeconds>0){const fraction=Math.max(0,Math.min(1,(Date.parse(w.resetsAt)-Date.now())/(w.durationSeconds*1000)));const dots=element('span',undefined,'qtime');for(let i=0;i<10;i++)dots.append(element('i',undefined,i<(fraction>0?Math.max(1,Math.ceil(fraction*10)):0)?'on':''));box.append(dots);}
  return box;
 }
 setEmpty('waiting');
 return {
  configure(value){locale=value.locale;reduceMotion=value.reduceMotion;document.documentElement.lang=locale;document.documentElement.dataset.theme='night';document.documentElement.dataset.reduceMotion=String(value.reduceMotion);document.documentElement.dataset.reduceTransparency=String(value.reduceTransparency);frame.hud.classList.toggle('solid',value.reduceTransparency);frame.settings.textContent='⚙';frame.settings.setAttribute('aria-label',words[locale].settings);setEmpty('waiting');},
  updateAppearance(value:LiveAppearance){locale=value.locale;reduceMotion=value.reduceMotion;document.documentElement.dataset.theme='night';document.documentElement.dataset.reduceMotion=String(value.reduceMotion);document.documentElement.dataset.reduceTransparency=String(value.reduceTransparency);frame.hud.classList.toggle('solid',value.reduceTransparency);if(reduceMotion)stop();localise();},
  shell(value:ShellState){nativeShell=value;tier=value.tier;const h=tier==='tall'?890:640,layout=cockpitLayout(h);document.documentElement.dataset.profile=tier==='tall'?'full':'compact';root.dataset.layout=String(h);root.style.setProperty('--console-h',layout.console+'px');root.style.setProperty('--tape-h',layout.tapeH+'px');root.style.setProperty('--eng-h',layout.eng+'px');shellControls();applyScope?.(value.scope);},
  render(data:WireCockpitData){
   if(disposed)throw Error('closed');const before=displayedState();const priorButton=frame.engine.querySelector<HTMLButtonElement>('.ek[aria-pressed="true"]');const unstable=priorButton?.dataset.unstable==='true';const priorScope=unstable?'':priorButton?.dataset.scope??(nativeShell?.scope==='all'?'':nativeShell?.scope??'');if(unstable&&nativeShell)nativeShell={...nativeShell,scope:'all'};applyScope=null;frame.engine.replaceChildren();
   const members=cockpitMembers(data),seen=new Set(members.map(member=>member.key));
   if(!members.length){setEmpty('empty');return;}
   const table=element('div',undefined,'u11-engine-table');const pages=element('div',undefined,'s6-pages');const leds=element('nav',undefined,'eng-pg');const pageCount=Math.ceil(members.length/6);
   const allButtons:HTMLButtonElement[]=[];let selected='';
   const select=(key:string,notify=false)=>{if(notify){if(!active)return;action('scopeSelect',key||'all');if(nativeShell)nativeShell={...nativeShell,scope:key||'all'};}selected=key;for(const b of allButtons){const on=(b.dataset.scope??'')===selected;b.setAttribute('aria-pressed',String(on));b.classList.toggle('on',on);}root.dataset.scope=key?'subscription':'all';};
   const show=(index:number)=>{for(const el of Array.from(pages.children) as HTMLElement[])el.hidden=Number(el.dataset.page)!==index;for(const el of Array.from(leds.children) as HTMLButtonElement[]){const current=Number(el.dataset.page)===index;el.setAttribute('aria-current',String(current));el.classList.toggle('lv-red',!current&&el.dataset.level==='red');el.classList.toggle('lv-amber',!current&&el.dataset.level==='amber');}};
   for(let page=0;page<pageCount;page++){
    const chunk=members.slice(page*6,page*6+6),panel=element('div',undefined,'s6-page');panel.dataset.page=String(page);panel.style.setProperty('--n',String(Math.max(3,chunk.length)));
    const keyrow=element('div',undefined,'eng-krow'),all=bilingual(element('button',words[locale].all,'ek ek-all on'),words.en.all,words['zh-CN'].all) as HTMLButtonElement;all.type='button';all.dataset.scope='';all.onclick=e=>{if(e.isTrusted)select('',true);};allButtons.push(all);keyrow.append(all);
    const keys=element('div',undefined,'eng-keys'),lcd=element('div',undefined,'eng-lcd'),labels=element('div',undefined,'eng-labels'),cols=element('div',undefined,'eng-cols');for(let i=0;i<3;i++)labels.append(bilingual(element('span',words[locale].rows[i],'lb'),words.en.rows[i],words['zh-CN'].rows[i]));
    for(const {key,row,account,unstable} of chunk){
     const button=element('button',undefined,'ek bd-r');const mark=row.vendorKey&&Object.hasOwn(vendorMarks,row.vendorKey)?vendorMarks[row.vendorKey]:null;if(mark){const img=element('img',undefined,'vendor-mark');img.src=`vendor-marks/${mark}.png`;img.alt='';button.append(img);}button.append(bilingual(element('span',label(row.name),'ek-name'),row.name.en,row.name.zh));button.type='button';button.dataset.scope=key;button.dataset.unstable=String(unstable);button.setAttribute('aria-label',label(row.name));button.onclick=e=>{if(e.isTrusted)select(key,true);};allButtons.push(button);keys.append(button);
     const col=element('article',undefined,'ec');col.dataset.rowId=row.id;
     const five=account.windows.find(w=>generalWindow(w)&&w.role==='session'&&w.durationSeconds===18000),week=account.windows.find(w=>generalWindow(w)&&w.role==='weekly'&&w.durationSeconds===604800);
     const other=account.windows.filter(w=>w!==five&&w!==week).sort((a,b)=>(a.remainingPercent??Infinity)-(b.remainingPercent??Infinity));
     const alert=[five,week,...other].filter((w):w is WireWindow=>!!w).map(w=>status(w.remainingPercent));if(alert.includes('red'))col.classList.add('tint-red');else if(alert.includes('amber'))col.classList.add('tint-amber');
     col.append(cell(five),cell(week),cell(other[0],true));if(other.length>1)col.lastElementChild?.append(element('span',`+${other.length-1}`,'qextra'));cols.append(col);
    }
    keyrow.append(keys);lcd.append(labels,cols);panel.append(keyrow,lcd);pages.append(panel);
    const severity=chunk.flatMap(({account})=>account.windows.map(w=>status(w.remainingPercent)));
    const led=element('button',String(page+1),'eng-led');led.dataset.level=severity.includes('red')?'red':severity.includes('amber')?'amber':'';led.type='button';led.dataset.page=String(page);led.setAttribute('aria-label',locale==='en'?`Page ${page+1}`:`第 ${page+1} 页`);led.onclick=()=>show(page);leds.append(led);
   }
   table.append(pages,leds);frame.engine.append(table);applyScope=(scope)=>{const key=scope!=='all'&&seen.has(scope)?scope:'';select(key);if(key){const selectedButton=allButtons.find(b=>b.dataset.scope===key);const page=selectedButton?.closest<HTMLElement>('.s6-page')?.dataset.page;if(page!==undefined)show(Number(page));}};show(0);applyScope(seen.has(priorScope)?priorScope:'all');frame.hud.replaceChildren(bilingual(element('span',label(data.projection.rowsSummary.text),'u11-summary'),data.projection.rowsSummary.text.en,data.projection.rowsSummary.text.zh));frame.mfd.replaceChildren();frame.tape.replaceChildren();
   if(before!==displayedState())pulse();
  },
  clear(){stop();setEmpty('cleared');if(nativeShell)nativeShell={...nativeShell,scope:'all'};delete root.dataset.scope;},
  active(value){active=value;root.dataset.active=String(value);frame.settings.disabled=!value;shellControls();if(!value)stop();},
  dispose(){if(disposed)return;disposed=true;applyScope=null;nativeShell=null;stop();frame.lamp.removeEventListener('animationend',settled);frame.lamp.removeEventListener('animationcancel',settled);frame.settings.onclick=null;attach.onclick=null;close.onclick=null;root.replaceChildren();root.removeAttribute('data-active');delete root.dataset.scope;},
 };
}

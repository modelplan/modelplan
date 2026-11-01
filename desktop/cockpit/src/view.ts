// SPDX-License-Identifier: MIT
import type { WireCockpitData, WireAccount, WireWindow, WireRow } from '../generated/wire.js';
import type { Appearance,CockpitView } from './bridge.js';
import { prototypeFrame } from './prototype-frame.js';
import { cockpitLayout } from './prototype-layout.js';
const words={en:{all:'All',settings:'Settings',waiting:'Waiting for display data',cleared:'Display data cleared',empty:'No subscriptions',rows:['5h','Weekly','Other'],page:'Page',resets:'resets in',now:'now'},'zh-CN':{all:'全部',settings:'设置',waiting:'等待显示数据',cleared:'显示数据已清除',empty:'无订阅',rows:['5小时','每周','其他'],page:'第',resets:'后重置',now:'现在'}};
const element=<K extends keyof HTMLElementTagNameMap>(tag:K,text?:string,className?:string):HTMLElementTagNameMap[K]=>{const e=document.createElement(tag);if(text!==undefined)e.textContent=text;if(className)e.className=className;return e;};
const status=(n:number|null)=>n===null?'':n<=25?'red':n<=40?'amber':'ok';
const count=(n:number|null)=>n===null||n<=0?0:Math.max(1,Math.min(10,Math.round(n/10)));
export function mountCockpit(root:HTMLElement,action:(kind:'chooseSetup'|'openSettings'|'openHistory',tool?:string)=>void):CockpitView {
 let locale:Appearance['locale']='en',disposed=false,active=false;
 const frame=prototypeFrame(root);
 frame.settings.onclick=e=>{if(e.isTrusted)action('openSettings');};
 const label=(v:{en:string;zh:string})=>locale==='en'?v.en:v.zh;
 const stop=()=>frame.lamp.classList.remove('state-pulse');
 const settled=()=>{if(!frame.lamp.getAnimations().some(a=>a.playState==='running'))stop();};
 frame.lamp.addEventListener('animationend',settled);frame.lamp.addEventListener('animationcancel',settled);
 const displayedState=()=>[frame.engine.innerHTML,frame.hud.innerHTML,frame.mfd.innerHTML].join('\0');
 const pulse=()=>{stop();if(!active||matchMedia('(prefers-reduced-motion: reduce)').matches)return;void frame.lamp.offsetWidth;frame.lamp.classList.add('state-pulse');};
 const setEmpty=(message:string)=>{frame.engine.replaceChildren(element('p',message,'ec-empty'));frame.hud.replaceChildren();frame.mfd.replaceChildren();frame.tape.replaceChildren();};
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
  if(other)line.append(element('span',w.role==='monthly'?(locale==='en'?'mo':'月'):label(w.label),'qtxt'));
  box.append(line);const bar=element('span',undefined,'qbar');for(let i=0;i<10;i++)bar.append(element('i',undefined,i<count(w.remainingPercent)?'on':''));box.append(bar);
  if(w.resetsAt){const txt=relative(w.resetsAt);if(txt)box.append(element('span',txt,'qreset'));}
  if(w.resetsAt&&w.durationSeconds&&w.durationSeconds>0){const fraction=Math.max(0,Math.min(1,(Date.parse(w.resetsAt)-Date.now())/(w.durationSeconds*1000)));const dots=element('span',undefined,'qtime');for(let i=0;i<10;i++)dots.append(element('i',undefined,i<(fraction>0?Math.max(1,Math.ceil(fraction*10)):0)?'on':''));box.append(dots);}
  return box;
 }
 setEmpty(words.en.waiting);
 return {
  configure(value){locale=value.locale;document.documentElement.lang=locale;document.documentElement.dataset.theme='night';document.documentElement.dataset.profile=value.profile;const h=value.profile==='full'?890:640,layout=cockpitLayout(h);root.dataset.layout=String(h);root.style.setProperty('--console-h',layout.console+'px');root.style.setProperty('--tape-h',layout.tapeH+'px');root.style.setProperty('--eng-h',layout.eng+'px');root.style.setProperty('--body-h',h+'px');frame.settings.textContent=words[locale].settings;frame.settings.setAttribute('aria-label',words[locale].settings);setEmpty(words[locale].waiting);},
  render(data:WireCockpitData){
   if(disposed)throw Error('closed');const before=displayedState();frame.engine.replaceChildren();
   const verified=new Set(data.subscriptions.map(s=>s.subscriptionRef));const members:{key:string;row:WireRow;account:WireAccount}[]=[];const seen=new Set<string>();
   for(const row of data.projection.rows)for(const account of row.accounts){const key=account.subscriptionRef&&verified.has(account.subscriptionRef)?account.subscriptionRef:`${row.id}#${account.route}`;if(!seen.has(key)){seen.add(key);members.push({key,row,account});}}
   if(!members.length){setEmpty(words[locale].empty);return;}
   const table=element('div',undefined,'u11-engine-table');const pages=element('div',undefined,'s6-pages');const leds=element('nav',undefined,'eng-pg');const pageCount=Math.ceil(members.length/6);
   const allButtons:HTMLButtonElement[]=[];let selected='';
   const select=(key:string)=>{selected=key;for(const b of allButtons){const on=(b.dataset.scope??'')===selected;b.setAttribute('aria-pressed',String(on));b.classList.toggle('on',on);}root.dataset.scope=key?'subscription':'all';};
   const show=(index:number)=>{for(const el of Array.from(pages.children) as HTMLElement[])el.hidden=Number(el.dataset.page)!==index;for(const el of Array.from(leds.children) as HTMLButtonElement[])el.setAttribute('aria-current',String(Number(el.dataset.page)===index));};
   for(let page=0;page<pageCount;page++){
    const chunk=members.slice(page*6,page*6+6),panel=element('div',undefined,'s6-page');panel.dataset.page=String(page);panel.style.setProperty('--n',String(Math.max(3,chunk.length)));
    const keyrow=element('div',undefined,'eng-krow'),all=element('button',words[locale].all,'ek ek-all on');all.type='button';all.dataset.scope='';all.onclick=()=>select('');allButtons.push(all);keyrow.append(all);
    const keys=element('div',undefined,'eng-keys'),lcd=element('div',undefined,'eng-lcd'),labels=element('div',undefined,'eng-labels'),cols=element('div',undefined,'eng-cols');for(const name of words[locale].rows)labels.append(element('span',name,'lb'));
    for(const {key,row,account} of chunk){
     const button=element('button',label(row.name),'ek bd-r');button.type='button';button.dataset.scope=key;button.setAttribute('aria-label',label(row.name));button.onclick=()=>select(key);allButtons.push(button);keys.append(button);
     const col=element('article',undefined,'ec');col.dataset.rowId=row.id;
     const five=account.windows.find(w=>w.role==='session'&&w.durationSeconds===18000),week=account.windows.find(w=>w.role==='weekly'&&w.durationSeconds===604800);
     const other=account.windows.filter(w=>w!==five&&w!==week).sort((a,b)=>(a.remainingPercent??Infinity)-(b.remainingPercent??Infinity));
     const alert=[five,week,...other].filter((w):w is WireWindow=>!!w).map(w=>status(w.remainingPercent));if(alert.includes('red'))col.classList.add('tint-red');else if(alert.includes('amber'))col.classList.add('tint-amber');
     col.append(cell(five),cell(week),cell(other[0],true));if(other.length>1)col.lastElementChild?.append(element('span',`+${other.length-1}`,'qextra'));cols.append(col);
    }
    keyrow.append(keys);lcd.append(labels,cols);panel.append(keyrow,lcd);pages.append(panel);
    const led=element('button',String(page+1),'eng-led');led.type='button';led.dataset.page=String(page);led.setAttribute('aria-label',locale==='en'?`Page ${page+1}`:`第 ${page+1} 页`);led.onclick=()=>show(page);leds.append(led);
   }
   table.append(pages,leds);frame.engine.append(table);show(0);select('');frame.hud.replaceChildren(element('span',label(data.projection.rowsSummary.text),'u11-summary'));frame.mfd.replaceChildren();frame.tape.replaceChildren();
   if(before!==displayedState())pulse();
  },
  clear(){stop();setEmpty(words[locale].cleared);delete root.dataset.scope;},
  active(value){active=value;root.dataset.active=String(value);frame.settings.disabled=!value;if(!value)stop();},
  dispose(){if(disposed)return;disposed=true;stop();frame.lamp.removeEventListener('animationend',settled);frame.lamp.removeEventListener('animationcancel',settled);frame.settings.onclick=null;root.replaceChildren();root.removeAttribute('data-active');delete root.dataset.scope;},
 };
}

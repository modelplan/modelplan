// SPDX-License-Identifier: MIT
import type { WireCockpitData,WireRow,WireAccount,WireWindow } from '../generated/wire.js';
import type { Appearance,CockpitView } from './bridge.js';
import { prototypeFrame } from './prototype-frame.js';
import { cockpitLayout } from './prototype-layout.js';
const words={en:{overview:'Overview',settings:'Settings',setup:'Choose setup',waiting:'Waiting for display data',cleared:'Display data cleared',subscriptions:'Verified subscriptions',history:'History',unknown:'Unknown',none:'No accounts',time:'Time unknown',route:'Source',readings:'READINGS',record:'OBSERVED',empty:'No verified subscriptions'},'zh-CN':{overview:'总览',settings:'设置',setup:'选择方案',waiting:'等待显示数据',cleared:'显示数据已清除',subscriptions:'已验证的订阅',history:'历史记录',unknown:'未知',none:'无账号',time:'时间未知',route:'来源',readings:'读数',record:'观测时间',empty:'无已验证订阅'}};
const element=<K extends keyof HTMLElementTagNameMap>(tag:K,text?:string,className?:string):HTMLElementTagNameMap[K]=>{const e=document.createElement(tag);if(text!==undefined)e.textContent=text;if(className)e.className=className;return e;};
// Ported display-only arithmetic from mfd-pages/fmt.js at the recorded source:
// this draws a value; it does not classify quota state or group accounts.
const litTens=(pct:number|null)=>pct===null||pct<=0?0:Math.max(1,Math.min(10,Math.round(pct/10)));
export function mountCockpit(root:HTMLElement,action:(kind:'chooseSetup'|'openSettings'|'openHistory',tool?:string)=>void):CockpitView {
  let locale:Appearance['locale']='en',disposed=false,active=false;
  const frame=prototypeFrame(root);
  frame.settings.onclick=e=>{if(e.isTrusted)action('openSettings');};
  frame.setup.onclick=e=>{if(e.isTrusted)action('chooseSetup');};
  const label=(value:{en:string;zh:string})=>locale==='en'?value.en:value.zh;
  const stop=()=>frame.lamp.classList.remove('state-pulse');
  const settled=()=>{if(!frame.lamp.getAnimations().some(a=>a.playState==='running'))stop();};
  frame.lamp.addEventListener('animationend',settled);
  frame.lamp.addEventListener('animationcancel',settled);
  // Compare the current private DOM within render; retain no DTO or signature.
  // Observation times on the tape do not turn a poll into a state change.
  const displayedState=()=>[frame.engine.innerHTML,frame.hud.innerHTML,frame.mfd.innerHTML].join('\0');
  const pulse=()=>{
    stop();
    if(!active||matchMedia('(prefers-reduced-motion: reduce)').matches)return;
    // Restart finite CSS motion on a changed display only; no scheduled callback.
    void frame.lamp.offsetWidth;
    frame.lamp.classList.add('state-pulse');
  };
  const setEmpty=(message:string)=>{
    frame.engine.replaceChildren(element('p',message,'ec-empty'));
    frame.hud.replaceChildren(element('span',words[locale].overview,'silk'));
    frame.mfd.replaceChildren(element('p',words[locale].empty,'u11-empty'));
    frame.tape.replaceChildren(element('span',words[locale].record,'silk'));
  };
  function windowReading(window:WireWindow):HTMLElement {
    const cell=element('div',undefined,'qcell');const line=element('span',undefined,'qline');
    line.append(element('span',label(window.label),'qtxt'));
    const number=element('b',undefined,'qnum');number.append(element('span',window.remainingPercent===null?'--':String(window.remainingPercent),'qvalue'));
    if(window.remainingPercent!==null)number.append(element('small','%'));line.append(number);cell.append(line);
    const meter=element('span',undefined,'qmeter'),bar=element('span',undefined,'qbar');
    for(let i=0;i<10;i++)bar.append(element('i',undefined,i<litTens(window.remainingPercent)?'on':''));meter.append(bar);cell.append(meter);return cell;
  }
  function account(value:WireAccount):HTMLElement {
    const container=element('div',undefined,'u11-account');
    container.append(element('span',value.plan.name?label(value.plan.name):value.plan.id,'u11-plan'));
    container.append(element('span',`${words[locale].route}: ${value.route}`,'u11-source'));
    for(const window of value.windows)container.append(windowReading(window));
    return container;
  }
  function column(row:WireRow):HTMLElement {
    const col=element('article',undefined,'ec');col.dataset.rowId=row.id;
    col.append(element('span',label(row.reason.text),'u11-reason'));
    if(!row.accounts.length)col.append(element('span',words[locale].none,'u11-empty'));
    for(const value of row.accounts)col.append(account(value));return col;
  }
  setEmpty(words.en.waiting);
  return {
    configure(value){
      locale=value.locale;document.documentElement.lang=locale;document.documentElement.dataset.theme=value.theme;document.documentElement.dataset.profile=value.profile;
      const h=value.profile==='full'?890:640,layout=cockpitLayout(h);root.dataset.layout=String(h);
      root.style.setProperty('--console-h',layout.console+'px');root.style.setProperty('--tape-h',layout.tapeH+'px');root.style.setProperty('--eng-h',layout.eng+'px');root.style.setProperty('--body-h',h+'px');
      frame.settings.textContent=words[locale].settings;frame.settings.setAttribute('aria-label',words[locale].settings);
      frame.setup.textContent=words[locale].setup;frame.setup.setAttribute('aria-label',words[locale].setup);
      setEmpty(words[locale].waiting);
    },
    render(data){
      if(disposed)throw Error('closed');const before=displayedState();
      frame.engine.replaceChildren();const table=element('div',undefined,'u11-engine-table');table.style.setProperty('--n',String(Math.max(1,data.projection.rows.length)));
      const keyrow=element('div',undefined,'eng-krow');keyrow.append(element('span',words[locale].readings,'ek ek-all'));const keys=element('div',undefined,'eng-keys');
      for(const row of data.projection.rows){
        const key=element('button',undefined,'ek bd-r on');key.type='button';key.append(element('span',label(row.name),'ek-name'));
        key.setAttribute('aria-label',label(row.name)+' · '+words[locale].history);
        const tool=row.id;key.onclick=e=>{if(e.isTrusted)action('openHistory',tool);};if(row.kind!=='tool')key.disabled=true;
        keys.append(key);
      }
      keyrow.append(keys);table.append(keyrow);
      const lcd=element('div',undefined,'eng-lcd');const cols=element('div',undefined,'eng-cols');for(const row of data.projection.rows)cols.append(column(row));lcd.append(cols);table.append(lcd);frame.engine.append(table);
      frame.hud.replaceChildren(element('span',label(data.projection.rowsSummary.text),'u11-summary'));
      // Go supplied these groups. Display members directly; no row-account inference.
      frame.mfd.replaceChildren(element('h2',words[locale].subscriptions,'silk'));
      if(!data.subscriptions.length)frame.mfd.append(element('p',words[locale].empty,'u11-empty'));
      for(const group of data.subscriptions){
        const members=element('section',undefined,'u11-subscription');
        for(const member of group.accounts)members.append(element('span',`${member.tool} · ${member.account.plan.name?label(member.account.plan.name):member.account.plan.id}`));
        frame.mfd.append(members);
      }
      frame.tape.replaceChildren(element('span',words[locale].record,'silk'));
      for(const row of data.projection.rows)for(const a of row.accounts)frame.tape.append(element('span',`${label(row.name)} · ${a.observedAt??words[locale].time}`,'u11-observed'));
      if(before!==displayedState())pulse();
    },
    clear(){stop();setEmpty(words[locale].cleared);},
    active(value){active=value;root.dataset.active=String(value);frame.settings.disabled=!value;frame.setup.disabled=!value;if(!value)stop();},
    dispose(){if(disposed)return;disposed=true;stop();frame.lamp.removeEventListener('animationend',settled);frame.lamp.removeEventListener('animationcancel',settled);frame.settings.onclick=null;frame.setup.onclick=null;root.replaceChildren();root.removeAttribute('data-active');},
  };
}

// SPDX-License-Identifier: MIT
// Safe DOM port of the study engine-view hierarchy (design e7d29f84).
// Wire-provided values are assigned through textContent, never markup.
import type {WireCockpitData,WireWindow} from '../generated/wire.js';
import type {Appearance} from './bridge.js';
import {cockpitMembers} from './members.js';
import {prototypeEngineSupplement} from './prototype-data-adapter.js';
const words={en:{all:'All',rows:['5h','Weekly','Other']},'zh-CN':{all:'全部',rows:['5小时','每周','其他']}};
const element=<K extends keyof HTMLElementTagNameMap>(tag:K,text?:string,className?:string):HTMLElementTagNameMap[K]=>{const e=document.createElement(tag);if(text!==undefined)e.textContent=text;if(className)e.className=className;return e;};
const bilingual=(e:HTMLElement,en:string,zh:string)=>{e.dataset.en=en;e.dataset.zh=zh;return e;};
const generalWindow=(w:WireWindow)=>!w.modelScope&&w.poolKey==='main'&&(w.role==='session'?(w.limitKey==='main'||w.limitKey==='five_hour'):w.role==='weekly'?(w.limitKey==='main'||w.limitKey==='weekly'):false);
const status=(n:number|null)=>n===null?'':n<=25?'red':n<=40?'amber':'ok';
const vendorMarks:Readonly<Record<string,string>>={claude:'claude',openai:'openai',cursor:'cursor',copilot:'copilot',kimi:'kimi',glm:'zai-white',opencode:'opencode'};
const vendorColors:Readonly<Record<string,string>>={openai:'#6aa8ff',claude:'#ff9a6a',cursor:'#eef2f6',copilot:'#c08cff',kimi:'#ff8fcf',glm:'#8f7dff',opencode:'#b5d65a',google:'#ffd166'};
export function renderPrototypeEngine(data:WireCockpitData,locale:Appearance['locale'],root:HTMLElement,priorScope:string,cell:(w:WireWindow|undefined,other?:boolean)=>HTMLElement,onSelect:(key:string)=>boolean):{table:HTMLElement;applyScope:(scope:string)=>void}|null {
 const label=(v:{en:string;zh:string})=>locale==='en'?v.en:v.zh;
   const members=cockpitMembers(data),seen=new Set(members.map(member=>member.key));
   if(!members.length)return null;
   const table=element('div',undefined,'u11-engine-table');const pages=element('div',undefined,'s6-pages');const leds=element('nav',undefined,'eng-pg');const pageCount=Math.ceil(members.length/6);
   const allButtons:HTMLButtonElement[]=[];let selected='';
   const select=(key:string,notify=false)=>{if(notify){if(!onSelect(key||'all'))return;}selected=key;for(const b of allButtons){const on=(b.dataset.scope??'')===selected;b.setAttribute('aria-pressed',String(on));b.classList.toggle('on',on);}root.dataset.scope=key?'subscription':'all';};
   const show=(index:number)=>{for(const el of Array.from(pages.children) as HTMLElement[])el.hidden=Number(el.dataset.page)!==index;for(const el of Array.from(leds.children) as HTMLButtonElement[]){const current=Number(el.dataset.page)===index;el.setAttribute('aria-current',String(current));el.classList.toggle('lv-red',!current&&el.dataset.level==='red');el.classList.toggle('lv-amber',!current&&el.dataset.level==='amber');}};
   for(let page=0;page<pageCount;page++){
    const chunk=members.slice(page*6,page*6+6),panel=element('div',undefined,'s6-page');panel.dataset.page=String(page);panel.style.setProperty('--n',String(Math.max(3,chunk.length)));
    const keyrow=element('div',undefined,'eng-krow'),all=bilingual(element('button',words[locale].all,'ek ek-all on'),words.en.all,words['zh-CN'].all) as HTMLButtonElement;all.type='button';all.dataset.scope='';all.onclick=e=>{if(e.isTrusted)select('',true);};allButtons.push(all);keyrow.append(all);
    const keys=element('div',undefined,'eng-keys'),lcd=element('div',undefined,'eng-lcd'),labels=element('div',undefined,'eng-labels'),cols=element('div',undefined,'eng-cols');for(let i=0;i<3;i++)labels.append(bilingual(element('span',words[locale].rows[i],'lb'),words.en.rows[i],words['zh-CN'].rows[i]));labels.append(bilingual(element('span',locale==='en'?'Today':'今日','lb lb-t'),'Today','今日'),bilingual(element('span',locale==='en'?'Reserve':'储备','lb lb-r'),'Reserve','储备'));
    for(const {key,row,account,unstable} of chunk){
     const button=element('button',undefined,'ek bd-r');button.style.setProperty('--vendor-color',row.vendorKey&&Object.hasOwn(vendorColors,row.vendorKey)?vendorColors[row.vendorKey]:'#c6ccd4');const mark=row.vendorKey&&Object.hasOwn(vendorMarks,row.vendorKey)?vendorMarks[row.vendorKey]:null;const identity=element('span',undefined,'ek-identity');if(mark){const img=element('img',undefined,'vendor-mark lamp');img.src=`vendor-marks/${mark}.png`;img.alt='';const glyph=element('span',undefined,'vendor-glyph');glyph.append(img);identity.append(glyph);}identity.append(bilingual(element('span',label(row.name),'ek-name'),row.name.en,row.name.zh));button.append(identity);const line=element('i',undefined,'bl');line.setAttribute('aria-hidden','true');line.style.setProperty('--v',row.vendorKey&&Object.hasOwn(vendorColors,row.vendorKey)?vendorColors[row.vendorKey]:'#c6ccd4');button.append(line);button.type='button';button.dataset.scope=key;button.dataset.unstable=String(unstable);button.setAttribute('aria-label',label(row.name));button.onclick=e=>{if(e.isTrusted)select(key,true);};allButtons.push(button);keys.append(button);
     const col=element('div',undefined,'ec');col.dataset.rowId=row.id;
     const five=account.windows.find(w=>generalWindow(w)&&w.role==='session'&&w.durationSeconds===18000),week=account.windows.find(w=>generalWindow(w)&&w.role==='weekly'&&w.durationSeconds===604800);
     const other=account.windows.filter(w=>w!==five&&w!==week).sort((a,b)=>(a.remainingPercent??Infinity)-(b.remainingPercent??Infinity));
     const alert=[five,week,...other].filter((w):w is WireWindow=>!!w).map(w=>status(w.remainingPercent));if(alert.includes('red'))col.classList.add('tint-red');else if(alert.includes('amber'))col.classList.add('tint-amber');
     col.append(cell(five),cell(week),cell(other[0],true));if(other.length>1)col.lastElementChild?.append(element('span',`+${other.length-1}`,'qextra'));const supplemental=prototypeEngineSupplement(account);const today=element('div',undefined,'qrow qrow-t'),reserve=element('div',undefined,'qrow qrow-r');today.dataset.available=String(supplemental.todayTokens!==null);reserve.dataset.available=String(supplemental.resetCards!==null||supplemental.reserveCredits?.balance!=null);if(supplemental.reserveCredits?.balance!=null)reserve.append(element('span',`${supplemental.reserveCredits.balance} ${supplemental.reserveCredits.unit}`,'qrv-p'));col.append(today,reserve);cols.append(col);
    }
    keyrow.append(keys);lcd.append(labels,cols);panel.append(keyrow,lcd);pages.append(panel);
    const severity=chunk.flatMap(({account})=>account.windows.map(w=>status(w.remainingPercent)));
    const led=element('button',String(page+1),'eng-led');led.dataset.level=severity.includes('red')?'red':severity.includes('amber')?'amber':'';led.type='button';led.dataset.page=String(page);led.setAttribute('aria-label',locale==='en'?`Page ${page+1}`:`第 ${page+1} 页`);led.onclick=()=>show(page);leds.append(led);
   }
   table.append(pages,leds);const applyScope=(scope:string)=>{const key=scope!=='all'&&seen.has(scope)?scope:'';select(key);if(key){const selectedButton=allButtons.find(b=>b.dataset.scope===key);const page=selectedButton?.closest<HTMLElement>('.s6-page')?.dataset.page;if(page!==undefined)show(Number(page));}};show(0);applyScope(seen.has(priorScope)?priorScope:'all');return {table,applyScope};
}

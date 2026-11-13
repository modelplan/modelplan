// SPDX-License-Identifier: MIT
// Cockpit annotations use the released study's captions, attached to the
// currently visible controls. They do not expose or retain reading data.
import {ht} from './host-text.js';
import {leaderAnchor,routeLeader} from '../study/rocket-r1/help-routing.js';
type Locale='en'|'zh-CN';
const notes:ReadonlyArray<readonly [string,string]>=[
 ['.ck-port','host.helpNote1'],
 ['[data-shutter]','host.helpNote2'],
 ['[data-caution]','host.helpNote3'],
 ['[data-settings]','host.helpNote4'],
 ['[data-detach]','host.helpNote5'],
 ['[data-close]','host.helpNote6'],
 ['.eng-krow','host.helpNote7'],
 ['.lb-t,.qrow-t,.qaverage','host.helpNote8'],
 ['.t-live','host.helpNote9'],
 ['.lb-first','host.helpNote10'],
 ['.lb-second','host.helpNote11'],
 ['.lb-other','host.helpNote12'],
 ['.dk-fad','host.helpNote13'],
 ['.mfd-pk','host.helpNote14'],
 ['.ck-tape','host.helpNote15'],
 ['.ck-base .bz-line','host.helpNote16']
];
export function mountPrototypeHelp(root:HTMLElement,getLocale:()=>Locale,isActive:()=>boolean,isAttached:()=>boolean){
 const layer=document.createElement('section');layer.id='help-map';layer.className='annot help-map';layer.hidden=true;layer.setAttribute('role','region');document.body.append(layer);
 const listeners=new AbortController();let held=false;
 const visible=(e:Element)=>{if(!e.isConnected||!e.getClientRects().length)return false;for(let p:Element|null=e;p;p=p.parentElement){const s=getComputedStyle(p);if((p as HTMLElement).hidden||s.display==='none'||s.visibility==='hidden'||s.opacity==='0')return false;}return true;};
 function render(){
  if(!held||!isActive()){layer.hidden=true;return;}
  const locale=getLocale();layer.replaceChildren();layer.hidden=false;layer.dataset.surface='cockpit';layer.setAttribute('aria-label',ht(locale,'host.helpAria'));
  const title=document.createElement('div');title.className='help-map-title';title.textContent=ht(locale,'host.helpTitle');
  const dismiss=document.createElement('span');dismiss.className='help-map-dismiss';dismiss.textContent=ht(locale,'host.helpDismiss');title.append(dismiss);layer.append(title);
  const targets=notes.flatMap(([selector,key])=>{const target=[...root.querySelectorAll(selector)].find(visible);if(!target)return [];const box=target.getBoundingClientRect(),caption=document.createElement('span');caption.className='an';caption.dataset.target=selector;caption.textContent=selector==='[data-detach]'&&!isAttached()?(ht(locale,'host.helpPutBack')):ht(locale,key);layer.append(caption);return [{target,box,caption}];}).sort((a,b)=>a.box.y-b.box.y);
  if(!targets.length){layer.hidden=true;return;}
  const viewportWidth=window.innerWidth,viewportHeight=window.innerHeight,ship=root.getBoundingClientRect();const available=Math.max(180,ship.x-28),width=Math.min(400,available),gap=root.dataset.layout==='890'?12:6,edge=ship.x;
  Object.assign(title.style,{left:Math.max(8,edge-width-14)+'px',top:'34px',width:width+'px'});
  for(const {caption} of targets)caption.style.width=width+'px';
  const start=34+title.offsetHeight+gap,space=viewportHeight-start-12,total=targets.reduce((n,x)=>n+x.caption.offsetHeight+gap,0),columns=total>space?2:1;
  if(columns===2)for(const {caption} of targets)caption.style.width=Math.min(width,(available-12)/2)+'px';
  const heights=Array<number>(columns).fill(start),columnWidth=targets[0].caption.offsetWidth;
  for(const [i,{caption}] of targets.entries()){const col=columns===1?0:Math.min(columns-1,Math.floor(i/Math.ceil(targets.length/columns)));Object.assign(caption.style,{left:Math.max(8,edge-14-columnWidth*(columns-col)-12*(columns-col-1))+'px',top:heights[col]+'px'});heights[col]+=caption.offsetHeight+gap;}
  const rect=(e:Element)=>{const r=e.getBoundingClientRect();return {x:r.x,y:r.y,width:r.width,height:r.height};};
  const labels=targets.map(x=>rect(x.caption)),live=[...root.querySelectorAll('.eng-cols,.fd-chs,.bank-lcd,.hud,.mfd-screen,.t-lines')].filter(visible).map(rect),titleRect=rect(title),viewport={width:viewportWidth,height:viewportHeight};
  const svg=document.createElementNS('http://www.w3.org/2000/svg','svg');svg.setAttribute('aria-hidden','true');svg.setAttribute('viewBox',`0 0 ${viewportWidth} ${viewportHeight}`);
  targets.forEach(({box,caption},i)=>{const r=labels[i],start={x:r.x+r.width+2,y:r.y+r.height/2},blocks=[...live,titleRect,...labels.filter((_,j)=>j!==i)],side=caption.dataset.target?.startsWith('[data-')||['.mfd-pk','.ck-tape'].includes(caption.dataset.target??'')?'top':caption.dataset.target==='.dk-fad'?'bottom':'left',preferred=side==='top'?{x:box.x+box.width/2,y:Math.max(28,box.y-4)}:side==='bottom'?{x:box.x+box.width/2,y:box.y+box.height+4}:{x:box.x-4,y:box.y+box.height/2};
   const end=leaderAnchor(box,preferred,blocks,viewport),points=end?routeLeader(start,end,blocks,viewport):[];if(!end||!points.length)return;
   const path=document.createElementNS(svg.namespaceURI,'path');path.setAttribute('d',points.map((p,j)=>(j?'L':'M')+p.x+' '+p.y).join(' '));svg.append(path);const circle=document.createElementNS(svg.namespaceURI,'circle');circle.setAttribute('cx',String(end.x));circle.setAttribute('cy',String(end.y));circle.setAttribute('r','2');svg.append(circle);
  });layer.prepend(svg);
 }
 const observer=new MutationObserver(()=>{if(held)render();});observer.observe(root,{childList:true,subtree:true,attributes:true,attributeFilter:['class','style','hidden','data-layout']});
 const down=(e:KeyboardEvent)=>{if(e.key==='Alt'&&isActive()){held=true;render();e.preventDefault();}else if(e.key==='Escape'&&held){held=false;render();e.preventDefault();}};
 const up=(e:KeyboardEvent)=>{if(e.key==='Alt'){held=false;render();}};
 window.addEventListener('keydown',down,{signal:listeners.signal});window.addEventListener('keyup',up,{signal:listeners.signal});window.addEventListener('blur',()=>{held=false;render();},{signal:listeners.signal});window.addEventListener('pointerdown',()=>{if(held){held=false;render();}},{signal:listeners.signal});window.addEventListener('resize',render,{signal:listeners.signal});
 return {refresh:render,hide(){held=false;render();},dispose(){listeners.abort();observer.disconnect();layer.remove();}};
}

// SPDX-License-Identifier: MIT
// The porthole HUD from public published data: on the tall profile a mini frontier above the first six chart models,
// on the compact profile one strip of three. It reads no scores of its own and shows nothing personal except which
// effort a running session last reported. Prototype: rocket-r1/porthole.js:49-76 for behaviour; the code is written here.
import type {WireCockpitData} from '../generated/wire.js';
import {FIELD_LIMIT,fieldModel,type FieldModel} from './field-model.js';

const SVG='http://www.w3.org/2000/svg',TALL_ROWS=6,COMPACT_ROWS=3;
const svg=<K extends keyof SVGElementTagNameMap>(tag:K,attributes:Record<string,string|number>)=>{const e=document.createElementNS(SVG,tag);for(const [k,v] of Object.entries(attributes))e.setAttribute(k,String(v));return e;};

/** The user's vendors first, then publication order; the same list feeds the frontier and the HUD. */
export function publishedFleet(data:WireCockpitData|null|undefined):FieldModel[] {
 const models=(data?.details?.publishedModels??[]).flatMap(m=>{const f=fieldModel(m);return f?[f]:[];}),lineup=new Set(data?.details?.publication?.models.map(m=>m.id)??[]);
 return models.filter(m=>lineup.has(m.id)).concat(models.filter(m=>!lineup.has(m.id))).slice(0,FIELD_LIMIT);
}
/** Each model's most recently seen effort, when a session reported one that the model publishes. */
function seenEfforts(data:WireCockpitData|null|undefined,models:readonly FieldModel[]) {
 const seen=new Map<string,readonly [string,number,number,number]>();
 const sessions=[...(data?.details?.sessions??[])].sort((a,b)=>Date.parse(a.lastObservedAt)-Date.parse(b.lastObservedAt));
 for(const s of sessions){const m=models.find(x=>x.id===s.model),row=s.effort&&m?m.e.find(r=>r[0].toLowerCase()===s.effort!.toLowerCase()):undefined;if(m&&row)seen.set(m.id,row);}
 return seen;
}
/** One point per model at ★: log cost from the cheapest ★, linear ability. */
export function miniChart(models:readonly FieldModel[],seen:ReadonlyMap<string,readonly [string,number,number,number]>,width:number,height:number,label:string) {
 const root=svg('svg',{class:'hud-mini',viewBox:`0 0 ${width} ${height}`,width,height,role:'img','aria-label':label});
 const stars=models.filter(m=>m.sel[2]>0);if(!stars.length)return root;
 const all=[...stars.map(m=>m.sel),...seen.values()].filter(r=>r[2]>0),pad=5;
 const low=Math.min(...all.map(r=>Math.log10(r[2]))),span=Math.max(...all.map(r=>Math.log10(r[2])))-low||1;
 const bottom=Math.min(...all.map(r=>r[1])),rise=Math.max(...all.map(r=>r[1]))-bottom||1;
 const X=(r:readonly [string,number,number,number])=>pad+(Math.log10(r[2])-low)/span*(width-2*pad),Y=(r:readonly [string,number,number,number])=>height-pad-(r[1]-bottom)/rise*(height-2*pad);
 const front:FieldModel[]=[];let best=-Infinity;for(const m of [...stars].sort((a,b)=>a.sel[2]-b.sel[2]))if(m.sel[1]>best){front.push(m);best=m.sel[1];}
 const leaders=new Set(front.map(m=>m.id));
 root.append(svg('polyline',{class:'hud-front',points:front.map(m=>`${X(m.sel).toFixed(1)},${Y(m.sel).toFixed(1)}`).join(' ')}));
 for(const m of stars){
  const row=seen.get(m.id);
  if(row&&row!==m.sel&&row[0]!==m.sel[0]&&row[2]>0){root.append(svg('line',{class:'hud-link',x1:X(m.sel).toFixed(1),y1:Y(m.sel).toFixed(1),x2:X(row).toFixed(1),y2:Y(row).toFixed(1)}),svg('circle',{class:'hud-cur',cx:X(row).toFixed(1),cy:Y(row).toFixed(1),r:2.2}));}
  root.append(svg('circle',{class:'hud-dot'+(leaders.has(m.id)?'':' dominated'),cx:X(m.sel).toFixed(1),cy:Y(m.sel).toFixed(1),r:2.6,'data-hud-model':m.id}));
 }
 return root;
}
export function paintHud(host:HTMLElement,data:WireCockpitData|null|undefined,compact:boolean,locale:string) {
 const fleet=publishedFleet(data),rows=fleet.slice(0,compact?COMPACT_ROWS:TALL_ROWS);
 host.replaceChildren();host.hidden=!rows.length;host.classList.toggle('hud-b',!compact);host.classList.toggle('hud-strip',compact);if(!rows.length)return;
 host.setAttribute('role','group');host.setAttribute('aria-label',locale==='en'?'Published models':'已发布模型');
 if(!compact){const chart=document.createElement('div');chart.className='hud-chart';chart.append(miniChart(rows,seenEfforts(data,rows),162,77,locale==='en'?'Ability against cost at each recommended effort':'各推荐档位的能力与成本'));host.append(chart);}
 const list=document.createElement('div');list.className='hud-list';
 for(const [i,m] of rows.entries()){
  const row=document.createElement('button');row.type='button';row.className='hp';row.dataset.hudModel=m.id;row.title=m.name;
  const n=document.createElement('span');n.className='hp-n';n.textContent=String(i+1);
  const name=document.createElement('b');name.textContent=m.short;
  const rec=document.createElement('span');rec.className='hp-rec';rec.textContent='★'+m.rec;
  row.append(n,name,rec);list.append(row);
 }
 host.append(list);
}
/** A row or point opens the model on 档位; hovering one tells the porthole which rocket to light. */
export function wireHud(host:HTMLElement,pick:(id:string)=>void):()=>void {
 const controller=new AbortController(),{signal}=controller,idOf=(e:Event)=>(e.target as Element).closest?.('[data-hud-model]')?.getAttribute('data-hud-model')??null;
 const hover=(id:string|null)=>host.dispatchEvent(new CustomEvent('hud-hover',{detail:id,bubbles:true}));
 host.addEventListener('click',e=>{const id=idOf(e);if(id&&e.isTrusted)pick(id);},{signal});
 host.addEventListener('pointerover',e=>hover(idOf(e)),{signal});host.addEventListener('pointerleave',()=>hover(null),{signal});
 host.addEventListener('focusin',e=>hover(idOf(e)),{signal});host.addEventListener('focusout',()=>hover(null),{signal});
 return ()=>controller.abort();
}

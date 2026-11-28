// SPDX-License-Identifier: MIT
// The porthole HUD from public published data: a mini frontier above the first six chart models (D444: the one
// layout; the 640 strip is retired). It reads no scores of its own and shows nothing personal except which
// effort a running session last reported. Prototype: rocket-r1/porthole.js:49-76 for behaviour; the code is written here.
import {hudAxisPath} from './hud-axis.js';
import {ht} from './host-text.js';
import type {WireCockpitData} from '../generated/wire.js';
import {FIELD_LIMIT,type FieldModel} from './field-model.js';
import {chartFleetOf,frontierFleetOf,fleetOf,type HudModel,type HudOptions} from './hud-fleet.js';
import {shortLabel} from '../study/rocket-r1/short-label.js';

export type {HudModel,HudOptions};
const SVG='http://www.w3.org/2000/svg',ROWS=6;
const svg=<K extends keyof SVGElementTagNameMap>(tag:K,attributes:Record<string,string|number>)=>{const e=document.createElementNS(SVG,tag);for(const [k,v] of Object.entries(attributes))e.setAttribute(k,String(v));return e;};

/** The scope's models in the order the enlarged chart takes them (frontier first, then dim points). */
export const publishedFleet=(data:WireCockpitData|null|undefined,scope='all',now=Date.now(),limit=FIELD_LIMIT):HudModel[]=>chartFleetOf(shortLabel,data,scope,now,limit);
/** The Models list retains its recent-use ordering independently of the chart's frontier order. */
export const listFleet=(data:WireCockpitData|null|undefined,scope='all',now=Date.now(),limit=FIELD_LIMIT):HudModel[]=>fleetOf(shortLabel,data,scope,now,limit,Infinity);
/** D386: the small HUD lists only the ability frontier, best ability first. */
export const hudFleet=(data:WireCockpitData|null|undefined,scope='all',now=Date.now()):HudModel[]=>frontierFleetOf(shortLabel,data,scope,now);
/** Each model's most recently seen effort, when a session reported one that the model publishes. */
function seenEfforts(models:readonly HudModel[]) {
 const seen=new Map<string,readonly [string,number,number,number]>();
 for(const m of models){const row=m.latestEffort?m.e.find(r=>r[0].toLowerCase()===m.latestEffort!.toLowerCase()):undefined;if(row)seen.set(m.id,row);}
 return seen;
}
/** One point per model at ★: log cost relative to the cheapest ★, linear ability, as the study's hud-selection/chart.js
 * draws it (axis corner, no captions since D386, rank numbers on the first three points). No names inside. */
export function miniChart(models:readonly FieldModel[],seen:ReadonlyMap<string,readonly [string,number,number,number]>,width:number,height:number,label:string) {
 const root=svg('svg',{class:'hud-mini',viewBox:`0 0 ${width} ${height}`,width,height,role:'img','aria-label':label});
 type Row=readonly [string,number,number,number];
 const valid=(r:Row|undefined):r is Row=>!!r&&Number.isFinite(r[1])&&r[2]>0;
 const points=models.flatMap((m,i)=>{if(!valid(m.sel))return [];const row=seen.get(m.id),c=row&&row!==m.sel&&row[0]!==m.sel[0]&&valid(row)?row:null;return [{m,i,r:m.sel,c}];});
 if(!points.length)return root;
 const base=Math.min(...points.map(p=>p.r[2])),values=points.flatMap(p=>p.c?[p.r,p.c]:[p.r]);
 const lx0=Math.min(0,...values.map(r=>Math.log2(r[2]/base))),lx1=Math.max(1,Math.ceil(Math.max(...values.map(r=>Math.log2(r[2]/base)))));
 const a0=Math.floor((Math.min(...values.map(r=>r[1]))-4)/5)*5,a1=Math.ceil((Math.max(...values.map(r=>r[1]))+4)/5)*5;
 const L=8,R=9,T=6,B=12,X=(r:Row)=>L+(Math.log2(r[2]/base)-lx0)/(lx1-lx0)*(width-L-R),Y=(r:Row)=>T+(a1-r[1])/(a1-a0)*(height-T-B);
 const f=(v:number)=>v.toFixed(1);
 root.append(svg('path',{class:'hud-axis',d:hudAxisPath(width,height,L,R,T,B)}));
 const front:typeof points=[];for(const p of [...points].sort((a,b)=>a.r[2]-b.r[2]||b.r[1]-a.r[1]))if(!front.length||p.r[1]>front.at(-1)!.r[1])front.push(p);
 const leaders=new Set(front.map(p=>p.m.id));
 root.append(svg('polyline',{class:'hud-front',points:front.map(p=>`${f(X(p.r))},${f(Y(p.r))}`).join(' ')}));
 const placed:[number,number][]=[];
 for(const p of points){
  if(p.c)root.append(svg('line',{class:'hud-link',x1:f(X(p.r)),y1:f(Y(p.r)),x2:f(X(p.c)),y2:f(Y(p.c))}),svg('circle',{class:'hud-cur',cx:f(X(p.c)),cy:f(Y(p.c)),r:2.2}));
  root.append(svg('circle',{class:'hud-dot'+(leaders.has(p.m.id)?'':' dominated'),cx:f(X(p.r)),cy:f(Y(p.r)),r:2.6,'data-hud-model':p.m.id,'data-hud-name':p.m.name}));
  if(p.i>=3)continue;
  // The rank sits beside its point, in the first free spot that stays inside the chart (chart.js ranks()).
  const x=X(p.r),y=Y(p.r),spots:[number,number][]=[[x+5,y-3],[x+5,y+9],[x-10,y-3],[x-10,y+9]];
  const spot=spots.find(([a,b])=>a>=0&&a+9<width&&b>=9&&b<height-B+3&&!placed.some(([c,d])=>Math.abs(c-a)<9&&Math.abs(d-b)<10))??[Math.max(1,Math.min(width-10,x+4)),Math.max(9,y-3)];
  placed.push(spot);
  const rank=svg('text',{class:'hud-rank'+(leaders.has(p.m.id)?'':' dominated'),x:f(spot[0]),y:f(spot[1])});rank.textContent=String(p.i+1);root.append(rank);
 }
 return root;
}
export function paintHud(host:HTMLElement,data:WireCockpitData|null|undefined,locale:string,options:HudOptions={}) {
 const fleet=hudFleet(data,options.scope,options.now),rows=fleet.slice(0,ROWS);
 host.replaceChildren();host.hidden=!!options.closed||!rows.length;host.classList.add('hud-b');if(host.hidden)return;
 host.setAttribute('role','group');host.setAttribute('aria-label',ht(locale,'host.hudAria'));
 const chart=document.createElement('div');chart.className='hud-chart';chart.append(miniChart(rows,seenEfforts(rows),162,77,ht(locale,'host.hudChartLabel')));host.append(chart);
 const list=document.createElement('div');list.className='hud-list';
 for(const [i,m] of rows.entries()){
  const row=document.createElement('button');row.type='button';row.className='hp'+(m.id===options.selected?' selected':'')+(m.dominated?' dominated':'');row.dataset.hudModel=m.id;row.dataset.hudName=m.name;row.title=m.name;
  const n=document.createElement('span');n.className='hp-n';n.textContent=String(i+1);
  // A running session at ★ glows the star; at any other effort the name turns gold (porthole.js:56-63).
  const atStar=m.latestEffort!==undefined&&m.latestEffort?.toLowerCase()===m.rec.toLowerCase(),elsewhere=m.latestEffort!==undefined&&!atStar;
  const name=document.createElement('b');name.textContent=m.short;if(elsewhere)name.className='gold';
  const rec=document.createElement('span');rec.className='hp-rec'+(atStar?' on':'');rec.textContent='★'+m.rec;
  row.append(n,name,rec);
  // CKP-PORT-51: a small green dot after the ★ effort (final-3: at the row's end) while a session runs this model now.
  if(m.running){const on=document.createElement('i');on.className='hp-on';on.setAttribute('role','img');on.setAttribute('aria-label',ht(locale,'host.running'));row.append(on);}
  list.append(row);
 }
 host.append(list);fitRows(host,list);
}
/** D371 B2 (CKP-PORT-04): when six rows do not fit above the safe-area line (10 px in from the port's bottom edge), show fewer
 *  whole rows; never a cut row, never an ellipsis. */
function fitRows(host:HTMLElement,list:HTMLElement):void {
 const port=host.closest('.ck-port');if(!port)return;
 const edge=port.getBoundingClientRect();if(edge.height<=0)return;
 const limit=edge.bottom-10;
 for(const row of [...list.children].reverse()){if(list.children.length<=1||row.getBoundingClientRect().bottom<=limit+.5)break;row.remove();}
}
/** A row or point opens the model on 模型; hovering one tells the porthole which rocket to light. */
export function wireHud(host:HTMLElement,pick:(id:string)=>void):()=>void {
 const controller=new AbortController(),{signal}=controller,idOf=(e:Event)=>(e.target as Element).closest?.('[data-hud-model]')?.getAttribute('data-hud-model')??null;
 const hover=(name:string|null)=>host.dispatchEvent(new CustomEvent('hud-hover',{detail:name,bubbles:true})),nameOf=(e:Event)=>(e.target as Element).closest?.('[data-hud-name]')?.getAttribute('data-hud-name')??null;
 host.addEventListener('click',e=>{const id=idOf(e);if(id&&e.isTrusted)pick(id);},{signal});
 host.addEventListener('pointerover',e=>hover(nameOf(e)),{signal});host.addEventListener('pointerleave',()=>hover(null),{signal});
 host.addEventListener('focusin',e=>hover(nameOf(e)),{signal});host.addEventListener('focusout',()=>hover(null),{signal});
 return ()=>controller.abort();
}

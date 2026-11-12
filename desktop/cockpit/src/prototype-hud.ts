// SPDX-License-Identifier: MIT
// The porthole HUD from public published data: on the tall profile a mini frontier above the first six chart models,
// on the compact profile one strip: a small frontier beside three stacked rows. It reads no scores of its own and shows nothing personal except which
// effort a running session last reported. Prototype: rocket-r1/porthole.js:49-76 for behaviour; the code is written here.
import type {WireCockpitData} from '../generated/wire.js';
import {FIELD_LIMIT,fieldModel,type FieldModel} from './field-model.js';
import {cockpitMembers} from './members.js';
import {sessionMember} from './session-binding.js';
import {shortLabel} from '../study/rocket-r1/short-label.js';

const SVG='http://www.w3.org/2000/svg',TALL_ROWS=6,COMPACT_ROWS=3;
const svg=<K extends keyof SVGElementTagNameMap>(tag:K,attributes:Record<string,string|number>)=>{const e=document.createElementNS(SVG,tag);for(const [k,v] of Object.entries(attributes))e.setAttribute(k,String(v));return e;};

// A subscription's tool to its model developer, the same map as eligibleCockpitVendors in the CLI.
const toolDevelopers:Readonly<Record<string,string>>={codex:'openai',claude:'anthropic',gemini:'google',grok:'xai',kimi:'kimi',zai:'zhipuai',minimax:'minimax',qwen:'alibaba'};
const WEEK=7*864e5,USED_LIMIT=3;
export interface HudOptions {readonly scope?:string;readonly now?:number;readonly selected?:string|null;readonly closed?:boolean}
export type HudModel=FieldModel&{readonly dominated:boolean;readonly latestEffort?:string|null};
function roundRobin(list:readonly HudModel[]) {
 const groups=new Map<string,HudModel[]>();for(const m of list)(groups.get(m.dev)??groups.set(m.dev,[]).get(m.dev)!).push(m);
 const out:HudModel[]=[];for(let slot=0;slot<Math.max(0,...[...groups.values()].map(g=>g.length));slot++)for(const g of groups.values())if(g[slot])out.push(g[slot]!);
 return out;
}
/** One order for the scope (hud-selection/selection.js): models used this week, the lineup, then developers in turn; dominated last. */
export function publishedFleet(data:WireCockpitData|null|undefined,scope='all',now=Date.now()):HudModel[] {
 const published=data?.details?.publishedModels??[],developerOf=new Map(published.map(m=>[m.id,m.developerId]));
 const members=data?cockpitMembers(data):[],member=scope==='all'?null:members.find(m=>m.key===scope)??null;
 if(scope!=='all'&&!member)return [];
 const recent=[...(data?.details?.sessions??[])].filter(s=>{const at=Date.parse(s.lastObservedAt);return (!member||sessionMember(members,s)?.key===member.key)&&at>=now-WEEK&&at<=now;}).sort((a,b)=>Date.parse(b.lastObservedAt)-Date.parse(a.lastObservedAt));
 const latest=new Map<string,string|null>();for(const s of recent)if(!latest.has(s.model))latest.set(s.model,s.effort);
 const developer=member?toolDevelopers[member.row.id]:undefined;
 const candidates=published.flatMap(m=>{const f=fieldModel(m,shortLabel);return f&&(!member||developerOf.get(m.id)===developer||latest.has(m.id))?[f]:[];});
 const beaten=(m:FieldModel)=>candidates.some(n=>n.id!==m.id&&n.sel[2]>0&&m.sel[2]>0&&n.sel[1]>=m.sel[1]&&n.sel[2]<=m.sel[2]&&(n.sel[1]>m.sel[1]||n.sel[2]<m.sel[2]));
 const models=candidates.map((m):HudModel=>({...m,dominated:beaten(m),...(latest.has(m.id)?{latestEffort:latest.get(m.id)??null}:{})}));
 const byId=new Map(models.map(m=>[m.id,m]));
 const used=[...latest.keys()].flatMap(id=>{const m=byId.get(id);return m?[m]:[];}).slice(0,USED_LIMIT),taken=new Set(used.map(m=>m.id));
 const rest=models.filter(m=>!taken.has(m.id)),lineup=(data?.details?.publication?.models??[]).flatMap(p=>{const m=rest.find(x=>x.id===p.id&&!x.dominated);return m?[m]:[];}),picked=new Set(lineup.map(m=>m.id));
 return [...used,...lineup,...roundRobin(rest.filter(m=>!m.dominated&&!picked.has(m.id))),...roundRobin(rest.filter(m=>m.dominated&&!picked.has(m.id)))].slice(0,FIELD_LIMIT);
}
/** Each model's most recently seen effort, when a session reported one that the model publishes. */
function seenEfforts(models:readonly HudModel[]) {
 const seen=new Map<string,readonly [string,number,number,number]>();
 for(const m of models){const row=m.latestEffort?m.e.find(r=>r[0].toLowerCase()===m.latestEffort!.toLowerCase()):undefined;if(row)seen.set(m.id,row);}
 return seen;
}
/** One point per model at ★: log cost relative to the cheapest ★, linear ability, as the study's hud-selection/chart.js
 * draws it (axis corner, "Ability ↑" and "Cost ×" captions, rank numbers on the first three points). No names inside. */
export function miniChart(models:readonly FieldModel[],seen:ReadonlyMap<string,readonly [string,number,number,number]>,width:number,height:number,label:string,captions:{ability:string;cost:string}={ability:'Ability',cost:'Cost'}) {
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
 root.append(svg('path',{class:'hud-axis',d:`M${L} ${T}V${height-B}H${width-R}`}));
 const ability=svg('text',{class:'hud-axis-label',x:1,y:height-1});ability.textContent=captions.ability+' ↑';
 const cost=svg('text',{class:'hud-axis-label',x:width-1,y:height-1,'text-anchor':'end'});cost.textContent=captions.cost+' ×';
 root.append(ability,cost);
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
export function paintHud(host:HTMLElement,data:WireCockpitData|null|undefined,compact:boolean,locale:string,options:HudOptions={}) {
 const fleet=publishedFleet(data,options.scope,options.now),rows=fleet.slice(0,compact?COMPACT_ROWS:TALL_ROWS);
 host.replaceChildren();host.hidden=!!options.closed||!rows.length;host.classList.toggle('hud-b',!compact);host.classList.toggle('hud-strip',compact);if(host.hidden)return;
 host.setAttribute('role','group');host.setAttribute('aria-label',locale==='en'?'Published models':'已发布模型');
 // G3-48: the compact strip follows the study at 640 (86x30 chart, then three 10 px rows), not three columns.
 const chart=document.createElement('div');chart.className='hud-chart';chart.append(miniChart(rows,seenEfforts(rows),compact?86:162,compact?30:77,locale==='en'?'Ability against cost at each recommended effort':'各推荐档位的能力与成本',locale==='en'?{ability:'Ability',cost:'Cost'}:{ability:'能力',cost:'成本'}));host.append(chart);
 const list=document.createElement('div');list.className='hud-list';
 for(const [i,m] of rows.entries()){
  const row=document.createElement('button');row.type='button';row.className='hp'+(m.id===options.selected?' selected':'')+(!compact&&m.dominated?' dominated':'');row.dataset.hudModel=m.id;row.dataset.hudName=m.name;row.title=m.name;
  const n=document.createElement('span');n.className='hp-n';n.textContent=String(i+1);
  // A running session at ★ glows the star; at any other effort the name turns gold (porthole.js:56-63).
  const atStar=m.latestEffort!==undefined&&m.latestEffort?.toLowerCase()===m.rec.toLowerCase(),elsewhere=m.latestEffort!==undefined&&!atStar;
  const name=document.createElement('b');name.textContent=m.short;if(elsewhere)name.className='gold';
  const rec=document.createElement('span');rec.className='hp-rec'+(atStar?' on':'');rec.textContent='★'+m.rec;
  row.append(n,name,rec);list.append(row);
 }
 host.append(list);
}
/** A row or point opens the model on 档位; hovering one tells the porthole which rocket to light. */
export function wireHud(host:HTMLElement,pick:(id:string)=>void):()=>void {
 const controller=new AbortController(),{signal}=controller,idOf=(e:Event)=>(e.target as Element).closest?.('[data-hud-model]')?.getAttribute('data-hud-model')??null;
 const hover=(name:string|null)=>host.dispatchEvent(new CustomEvent('hud-hover',{detail:name,bubbles:true})),nameOf=(e:Event)=>(e.target as Element).closest?.('[data-hud-name]')?.getAttribute('data-hud-name')??null;
 host.addEventListener('click',e=>{const id=idOf(e);if(id&&e.isTrusted)pick(id);},{signal});
 host.addEventListener('pointerover',e=>hover(nameOf(e)),{signal});host.addEventListener('pointerleave',()=>hover(null),{signal});
 host.addEventListener('focusin',e=>hover(nameOf(e)),{signal});host.addEventListener('focusout',()=>hover(null),{signal});
 return ()=>controller.abort();
}

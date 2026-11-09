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
 // D86: "All" is the union of the user's own subscriptions, never the whole published field. A model counts when its
 // developer is one of those subscriptions' developers, or a session bound to one of them used it this week.
 const owned=member?[member]:members;
 const recent=[...(data?.details?.sessions??[])].filter(s=>{const at=Date.parse(s.lastObservedAt),bound=sessionMember(members,s);return (member?bound?.key===member.key:bound!==null&&bound!==undefined)&&at>=now-WEEK&&at<=now;}).sort((a,b)=>Date.parse(b.lastObservedAt)-Date.parse(a.lastObservedAt));
 const latest=new Map<string,string|null>();for(const s of recent)if(!latest.has(s.model))latest.set(s.model,s.effort);
 const developers=new Set(owned.flatMap(m=>toolDevelopers[m.row.id]?[toolDevelopers[m.row.id]!]:[]));
 const candidates=published.flatMap(m=>{const f=fieldModel(m,shortLabel);return f&&(developers.has(developerOf.get(m.id)??'')||latest.has(m.id))?[f]:[];});
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
  root.append(svg('circle',{class:'hud-dot'+(leaders.has(m.id)?'':' dominated'),cx:X(m.sel).toFixed(1),cy:Y(m.sel).toFixed(1),r:2.6,'data-hud-model':m.id,'data-hud-name':m.name}));
 }
 return root;
}
export function paintHud(host:HTMLElement,data:WireCockpitData|null|undefined,compact:boolean,locale:string,options:HudOptions={}) {
 const fleet=publishedFleet(data,options.scope,options.now),rows=fleet.slice(0,compact?COMPACT_ROWS:TALL_ROWS);
 host.replaceChildren();host.hidden=!!options.closed||!rows.length;host.classList.toggle('hud-b',!compact);host.classList.toggle('hud-strip',compact);if(host.hidden)return;
 host.setAttribute('role','group');host.setAttribute('aria-label',locale==='en'?'Published models':'已发布模型');
 // G3-48: the compact strip follows the study at 640 (86x30 chart, then three 10 px rows), not three columns.
 const chart=document.createElement('div');chart.className='hud-chart';chart.append(miniChart(rows,seenEfforts(rows),compact?86:162,compact?30:77,locale==='en'?'Ability against cost at each recommended effort':'各推荐档位的能力与成本'));host.append(chart);
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
/** A row or point opens the model on 模型; hovering one tells the porthole which rocket to light. */
export function wireHud(host:HTMLElement,pick:(id:string)=>void):()=>void {
 const controller=new AbortController(),{signal}=controller,idOf=(e:Event)=>(e.target as Element).closest?.('[data-hud-model]')?.getAttribute('data-hud-model')??null;
 const hover=(name:string|null)=>host.dispatchEvent(new CustomEvent('hud-hover',{detail:name,bubbles:true})),nameOf=(e:Event)=>(e.target as Element).closest?.('[data-hud-name]')?.getAttribute('data-hud-name')??null;
 host.addEventListener('click',e=>{const id=idOf(e);if(id&&e.isTrusted)pick(id);},{signal});
 host.addEventListener('pointerover',e=>hover(nameOf(e)),{signal});host.addEventListener('pointerleave',()=>hover(null),{signal});
 host.addEventListener('focusin',e=>hover(nameOf(e)),{signal});host.addEventListener('focusout',()=>hover(null),{signal});
 return ()=>controller.abort();
}

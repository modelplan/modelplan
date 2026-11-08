// SPDX-License-Identifier: MIT
// Copyright (c) 2026 ModelPlan.
// G3-47: the cockpit base row in the 34 px reserve below the root, one bell per visible subscription, directly
// under its engine column, plus a dimmed socket under each empty bay. Port of the study's rocket-r1/base.js
// (spec 3.9, entrance C) and base-bells notes: a subscription with a running session bound to it burns (a status-
// coloured sheet below the bell, 12-24 px by output rate); a stale or failed reading is grey; otherwise idle.
// The official edition paints the bells with the released base-bell art; the community edition keeps a plain line. Columns are measured from the drawn engine table, so the row follows paging and the page zoom.
// The host CSP blocks style attributes: every value goes through CSSOM, and wire text never becomes CSS.
import type { WireCockpitData } from '../generated/wire.js';
import { cockpitMembers } from './members.js';

const INSET=4,FLAME_MIN=12,FLAME_MAX=24;
// Status colours shared with the engine fills (study colour-mode.js STATUS_HEX).
const FUEL:Readonly<Record<string,string>>={ok:'#5ad9ba',mid:'#eac17b',low:'#ef4444'};
const RANK:Readonly<Record<string,number>>={ok:1,mid:2,low:3};
const COLOUR=/^#[0-9a-f]{6}$/i;

export type BaseLight={key:string;col:string;x:number;w:number;cw:number;colour:string;fuel:string;state:'work'|'stale'|'idle';rate:number|null;len:number};

// Glow sheet length: 30 t/s or less -> 12, 120 t/s or more -> 24, no rate -> the middle (study flameLen).
export function flameLength(rate:number|null):number {
 if(rate===null)return (FLAME_MIN+FLAME_MAX)/2;
 return Math.round(FLAME_MIN+(FLAME_MAX-FLAME_MIN)*Math.max(0,Math.min(1,(rate-30)/90)));
}

// Which subscription a session runs on, by the rule of session-binding.ts sessionMember() (PR #761), so the bells
// agree with the faders and the record strip: a producer-verified subscriptionRef wins, and one that names no member
// leaves the session unbound; without one, the session joins the single subscription of its tool, and with two or
// more of that tool it stays unbound. Kept here until #761 is on main; then this imports sessionMember().
const SESSION_TOOLS:Readonly<Record<string,string>>={codex:'codex','claude-code':'claude',claude:'claude',zcode:'zai',zai:'zai',glm:'zai',opencode:'opencodego',opencodego:'opencodego',gemini:'gemini',grok:'grok',kimi:'kimi',qwen:'qwen',cursor:'cursor',copilot:'copilot'};
type Session=NonNullable<WireCockpitData['details']>['sessions'][number];
export function sessionMemberKey(members:readonly {key:string;row:{id:string}}[],session:Pick<Session,'source'|'subscriptionRef'>):string|null {
 if(session.subscriptionRef)return members.some(m=>m.key===session.subscriptionRef)?session.subscriptionRef:null;
 const tool=SESSION_TOOLS[session.source.toLowerCase()];if(!tool)return null;
 const same=members.filter(m=>m.row.id===tool);
 return same.length===1?same[0]!.key:null;
}

// A member works while one of its sessions is running (the in-use state the engine reports).
function running(data:WireCockpitData,members:readonly {key:string;row:{id:string}}[],key:string):{working:boolean;rate:number|null} {
 const detail=data.details;if(!detail||detail.sessionCoverage!=='local-last-seen')return {working:false,rate:null};
 const live=detail.sessions.filter(s=>s.state==='running'&&sessionMemberKey(members,s)===key);
 const rates=live.map(s=>s.rate).filter((r):r is number=>typeof r==='number'&&Number.isFinite(r)&&r>=0);
 return {working:live.length>0,rate:rates.length?rates.reduce((a,b)=>a+b,0):null};
}

export function baseLights(root:HTMLElement,data:WireCockpitData):{lights:BaseLight[];sockets:{x:number;cw:number}[]} {
 const box=root.getBoundingClientRect(),k=box.width?root.offsetWidth/box.width:1;
 const members=cockpitMembers(data),keys=new Set(members.map(m=>m.key));
 const lights:BaseLight[]=[];
 for(const key of root.querySelectorAll<HTMLElement>('.eng-keys .ek[data-sub]')){
  const id=key.dataset.sub??'',member=key.dataset.scope??'';
  const column=[...root.querySelectorAll<HTMLElement>('.ck-eng .ec[data-col]')].find(e=>e.dataset.col===id);
  const r=(column??key).getBoundingClientRect();if(!r.width)continue;
  const vendor=key.querySelector<HTMLElement>('.bl')?.style.getPropertyValue('--v').trim()??'';
  const level=[...(column?.querySelectorAll<HTMLElement>('.qcell')??[])].map(c=>['ok','mid','low'].find(l=>c.classList.contains('lv-'+l))).filter((l):l is string=>!!l).sort((a,b)=>RANK[b]-RANK[a])[0];
  const grey=!!column?.classList.contains('grey'),live=keys.has(member)?running(data,members,member):{working:false,rate:null};
  const state=grey?'stale':live.working?'work':'idle',cw=r.width*k;
  lights.push({key:member,col:id,x:(r.left+r.width/2-box.left)*k,w:Math.max(8,cw-2*INSET),cw,colour:COLOUR.test(vendor)?vendor:'#7d868e',
   fuel:level?FUEL[level]:'#7d868e',state,rate:live.rate,len:state==='work'?flameLength(live.rate):0});
 }
 const sockets=[...root.querySelectorAll<HTMLElement>('.ck-eng .eng-cols .ec-bay')].map(e=>{const r=e.getBoundingClientRect();return {x:(r.left+r.width/2-box.left)*k,cw:r.width*k};}).filter(s=>s.cw>0);
 return {lights,sockets};
}

function px(n:number){return n.toFixed(2)+'px';}

// Paints the row into its own layer under the root; returns a disposer.
export function mountPrototypeBase(root:HTMLElement,data:()=>WireCockpitData|null,label:(light:BaseLight)=>string) {
 let layer=root.querySelector<HTMLElement>(':scope > .ck-base');
 if(!layer){layer=document.createElement('div');layer.className='ck-base';root.append(layer);}
 const base=layer;let last='';
 const paint=()=>{
  const value=data();
  if(!value||!root.offsetWidth){if(base.childElementCount)base.replaceChildren();last='';return;}
  const {lights,sockets}=baseLights(root,value),key=JSON.stringify([lights,sockets,lights.map(label)]);
  if(key===last)return;last=key;
  const nodes:HTMLElement[]=[];
  for(const [j,z] of lights.entries()){
   const b=document.createElement('span');b.className='bz '+z.state;b.setAttribute('role','img');b.setAttribute('aria-label',label(z));
   for(const [k,v] of [['left',px(z.x)],['--w',px(z.w)],['--cw',px(z.cw)],['--v',z.colour],['--fuel',z.fuel],['--len',z.len+'px'],
    ['--fd',(.19+(j*37%5)*.017).toFixed(3)+'s'],['--fo',(-(j*53%7)*.023).toFixed(3)+'s']] as const)b.style.setProperty(k,v);
   const glow=document.createElement('i');glow.className='bz-glow';const line=document.createElement('i');line.className='bz-line';b.append(glow,line);
   // D73: a working bell burns a faint flame from its mouth, under the mouth glow.
   if(z.state==='work'){const plume=document.createElement('i');plume.className='bz-plume';const sheet=document.createElement('i');sheet.className='bz-sheet';b.append(plume,sheet);}
   // CKP-ENG-20: hovering lights the column and shows the name (text only).
   const tip=document.createElement('span');tip.className='bz-tip';tip.setAttribute('aria-hidden','true');tip.textContent=label(z);b.append(tip);
   const column=()=>[...root.querySelectorAll<HTMLElement>('.ck-eng .ec[data-col]')].find(e=>e.dataset.col===z.col);
   b.addEventListener('pointerenter',()=>column()?.classList.add('xhl'));b.addEventListener('pointerleave',()=>column()?.classList.remove('xhl'));
   nodes.push(b);
  }
  for(const s of sockets){const e=document.createElement('span');e.className='bz-empty';e.setAttribute('aria-hidden','true');e.style.setProperty('left',px(s.x));e.style.setProperty('--cw',px(s.cw));const line=document.createElement('i');line.className='bz-line';e.append(line);nodes.push(e);}
  base.replaceChildren(...nodes);
 };
 const engine=root.querySelector<HTMLElement>('.ck-eng');
 const mutations=new MutationObserver(paint),resize=typeof ResizeObserver==='undefined'?null:new ResizeObserver(paint);
 if(engine){mutations.observe(engine,{childList:true,subtree:true});resize?.observe(engine);}
 resize?.observe(root);
 // Clearing is synchronous: no private name may outlive a clear or a waiting/empty page (privacy contract).
 return {paint,clear(){base.replaceChildren();last='';},dispose(){mutations.disconnect();resize?.disconnect();base.replaceChildren();}};
}

// SPDX-License-Identifier: MIT
// Copyright (c) 2026 ModelPlan.
// Static porthole scene: replays one owner-approved baked projection of the default public fleet
// (official edition only). Background first, then per model flame, halo and body at the recorded
// logical rectangles; flames and halos add with plus-lighter and flicker (owner D39/D-H: on, static under
// Reduce Motion; web/cockpit.css gates it on an active, open, visible page). No WebGL, no personal data:
// the roster is the public study fleet.
// Prototype: rocket-r1/porthole.js:187-192 (syncStill) and study/porthole-sprites/composer.js:13-31,34.
export type StillLayer={left:number;top:number;width:number;height:number;file:string};
export type StillModel={id:string;name?:string;nozzle:{x:number;y:number};body?:StillLayer;flame?:StillLayer;halo?:StillLayer};
export type StillProjection={id:string;theme:'night'|'day';layout:890|640;width:number;height:number;background:string;models:StillModel[]};
export type StillPack={base:string;projections:StillProjection[]};
// A click within 28 px of a rocket's centre names that rocket (prototype hud-selection/still.js:hitStillRocket); nearest wins.
export function stillRocketAt(field:HTMLElement,x:number,y:number,radius=28):string|null {
  let nearest:string|null=null,best=radius*radius;
  for(const e of field.querySelectorAll<HTMLElement>('.ck-still-body[data-model-name]')){
    const r=e.getBoundingClientRect();if(!(r.width>0&&r.height>0))continue;
    const inside=x>=r.left&&x<=r.right&&y>=r.top&&y<=r.bottom,d=inside?0:(x-(r.left+r.width/2))**2+(y-(r.top+r.height/2))**2;
    if(d<=best){best=d;nearest=e.dataset.modelName??null;}
  }
  return nearest;
}
export function mountPortholeStill(field:HTMLElement,cockpit:HTMLElement,pack:StillPack|null,enlarge?:(focus?:string)=>void):{dispose():void}|null{
  if(!pack?.projections.length)return null;
  // The port opens the enlarged field by click, double-click, Enter, Space or its ⤢ key (the community edition has no
  // field). A click on a rocket focuses that rocket. The second click of a double-click and the dblclick itself do not
  // ask again (prototype porthole.js bindPorthole: "idempotent after the first click").
  const port=field.parentElement,opener=new AbortController();let big:HTMLButtonElement|null=null;
  if(port&&enlarge){
   port.tabIndex=0;port.setAttribute('role','button');
   big=document.createElement('button');big.type='button';big.className='hud-x port-big';big.dataset.bigfield='';big.textContent='⤢';port.append(big);
   const name=()=>{const en=document.documentElement.lang==='en';port.setAttribute('aria-label',en?'Open the 3D view':'打开 3D 视图');
    big?.setAttribute('aria-label',en?'Open the 3D launch field · Or click anywhere on the field':'打开 3D 发射场 · 点击视野也可以打开');};name();
   port.addEventListener('focus',name,{signal:opener.signal});
   big.addEventListener('focus',name,{signal:opener.signal});
   big.addEventListener('click',e=>{e.stopPropagation();if(e.isTrusted&&e.detail<2)enlarge();},{signal:opener.signal});
   big.addEventListener('dblclick',e=>e.stopPropagation(),{signal:opener.signal});
   // The HUD lives inside the port and has its own actions; they must not open the field too.
   // A HUD click repaints the rows before it bubbles here, so the event's path is read, not the detached target.
   const inHud=(e:Event)=>e.composedPath().some(n=>n instanceof Element&&n.classList.contains('hud'));
   port.addEventListener('click',e=>{if(!e.isTrusted||inHud(e)||e.detail>1)return;const rocket=stillRocketAt(field,e.clientX,e.clientY);if(rocket)enlarge(rocket);else enlarge();},{signal:opener.signal});
   port.addEventListener('keydown',e=>{if((e.key==='Enter'||e.key===' ')&&!inHud(e)&&e.target!==big){e.preventDefault();enlarge();}},{signal:opener.signal});
  }
  // A HUD row lights its rocket by published display name, the one key the still's roster and the publication share.
  const lit=(event:Event)=>{const name=(event as CustomEvent<string|null>).detail;for(const e of field.querySelectorAll<HTMLElement>('[data-model-name]'))e.classList.toggle('ck-hot',e.dataset.modelName===name);};
  cockpit.addEventListener('hud-hover',lit,{signal:opener.signal});
  const host=document.createElement('div');host.className='ck-still';host.setAttribute('aria-hidden','true');field.prepend(host);
  const base=new URL(pack.base,document.baseURI).href;let painted='';
  // Prototype placeBigKey: 22 px, 40 px in from the right and 36 px down at night (12 px on a short port); by day it
  // sits 17 px in, just under the canopy arch (border-radius 38% / 18%).
  const placeBig=()=>{
    if(!big||!port)return;const W=port.clientWidth,H=port.clientHeight,size=22;if(!W||!H)return;
    let right=40,top=H<80?12:36;
    if(document.documentElement.dataset.theme==='day'){right=17;const rx=.38*W,ry=.18*H,dx=Math.max(0,rx-right);top=Math.ceil(ry*(1-Math.sqrt(Math.max(0,1-(dx/rx)**2))))+3;}
    Object.assign(big.style,{right:right+'px',top:top+'px',width:size+'px',height:size+'px',display:'grid',placeItems:'center',zIndex:'3'});
  };
  const paint=()=>{
    placeBig();
    const theme=document.documentElement.dataset.theme==='day'?'day':'night',layout=cockpit.dataset.layout==='640'?640:890;
    const frame=pack.projections.find(p=>p.theme===theme&&p.layout===layout);
    const port=field.parentElement??field,W=port.clientWidth,H=port.clientHeight;
    if(!frame||!W||!H){field.dataset.still=frame?'sizing':'none';return;}
    const key=`${frame.id}:${W}x${H}`;if(key===painted)return;painted=key;
    // Cover the field like a background: scale to the larger ratio and centre; the port clips the rest.
    const s=Math.max(W/frame.width,H/frame.height);
    const stage=document.createElement('div');stage.className='ck-still-stage';
    stage.style.width=frame.width+'px';stage.style.height=frame.height+'px';
    stage.style.transform=`translate(${(W-frame.width*s)/2}px,${(H-frame.height*s)/2}px) scale(${s})`;
    const layer=(className:string,l:{left:number;top:number;width:number;height:number},file:string)=>{
      const e=document.createElement('i');e.className='ck-still-layer '+className;
      Object.assign(e.style,{left:l.left+'px',top:l.top+'px',width:l.width+'px',height:l.height+'px',backgroundImage:`url("${new URL(file,base).href}")`});
      stage.append(e);return e;
    };
    layer('ck-still-bg',{left:0,top:0,width:frame.width,height:frame.height},frame.background);
    for(const [index,m] of frame.models.entries())for(const kind of ['flame','halo','body'] as const){
      const l=m[kind];if(!l)continue;
      // Prototype composer.js:26: per-model period 0.43 + (i mod 4) x 0.07 s and phase -(i mod 3) x 0.13 s, scaled about the nozzle.
      const flicker=kind==='body'?'':` ck-flicker ck-p${index%4} ck-o${index%3}`;
      const e=layer('ck-still-'+kind+(kind!=='body'&&m.halo?' ck-still-add':'')+flicker,l,l.file);
      if(kind==='body'&&m.name)e.dataset.modelName=m.name;
      if(flicker)e.style.transformOrigin=`${m.nozzle.x-l.left}px ${m.nozzle.y-l.top}px`;
    }
    host.replaceChildren(stage);host.dataset.projection=frame.id;field.dataset.still='ready';
  };
  paint();
  const resize=new ResizeObserver(paint);resize.observe(field.parentElement??field);
  const attributes=new MutationObserver(paint);
  attributes.observe(document.documentElement,{attributes:true,attributeFilter:['data-theme']});
  attributes.observe(cockpit,{attributes:true,attributeFilter:['data-layout']});
  return {dispose(){opener.abort();big?.remove();if(port&&enlarge){port.removeAttribute('tabindex');port.removeAttribute('role');port.removeAttribute('aria-label');}resize.disconnect();attributes.disconnect();host.remove();delete field.dataset.still;}};
}

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
export function mountPortholeStill(field:HTMLElement,cockpit:HTMLElement,pack:StillPack|null,enlarge?:()=>void):{dispose():void}|null{
  if(!pack?.projections.length)return null;
  // The port opens the enlarged field by click, Enter or Space (the community edition has no field).
  const port=field.parentElement,opener=new AbortController();
  if(port&&enlarge){
   port.tabIndex=0;port.setAttribute('role','button');
   const name=()=>port.setAttribute('aria-label',document.documentElement.lang==='en'?'Open the 3D view':'打开 3D 视图');name();
   port.addEventListener('focus',name,{signal:opener.signal});
   port.addEventListener('click',e=>{if(e.isTrusted)enlarge();},{signal:opener.signal});
   port.addEventListener('keydown',e=>{if(e.key==='Enter'||e.key===' '){e.preventDefault();enlarge();}},{signal:opener.signal});
  }
  // A HUD row lights its rocket by published display name, the one key the still's roster and the publication share.
  const lit=(event:Event)=>{const name=(event as CustomEvent<string|null>).detail;for(const e of field.querySelectorAll<HTMLElement>('[data-model-name]'))e.classList.toggle('ck-hot',e.dataset.modelName===name);};
  cockpit.addEventListener('hud-hover',lit,{signal:opener.signal});
  const host=document.createElement('div');host.className='ck-still';host.setAttribute('aria-hidden','true');field.prepend(host);
  const base=new URL(pack.base,document.baseURI).href;let painted='';
  const paint=()=>{
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
  return {dispose(){opener.abort();if(port&&enlarge){port.removeAttribute('tabindex');port.removeAttribute('role');port.removeAttribute('aria-label');}resize.disconnect();attributes.disconnect();host.remove();delete field.dataset.still;}};
}

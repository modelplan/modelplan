// SPDX-License-Identifier: MIT
// Copyright (c) 2026 ModelPlan.
// Static porthole scene: replays one owner-approved baked projection of the default public fleet
// (official edition only). Background first, then per model flame, halo and body at the recorded
// logical rectangles; flames and halos add with plus-lighter. No animation (flicker waits for the
// owner's D-H ruling), no WebGL, no personal data: the roster is the public study fleet.
// Prototype: rocket-r1/porthole.js:187-192 (syncStill) and study/porthole-sprites/composer.js:13-31.
export type StillLayer={left:number;top:number;width:number;height:number;file:string};
export type StillModel={id:string;body?:StillLayer;flame?:StillLayer;halo?:StillLayer};
export type StillProjection={id:string;theme:'night'|'day';layout:890|640;width:number;height:number;background:string;models:StillModel[]};
export type StillPack={base:string;projections:StillProjection[]};
export function mountPortholeStill(field:HTMLElement,cockpit:HTMLElement,pack:StillPack|null):{dispose():void}|null{
  if(!pack?.projections.length)return null;
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
      stage.append(e);
    };
    layer('ck-still-bg',{left:0,top:0,width:frame.width,height:frame.height},frame.background);
    for(const m of frame.models)for(const kind of ['flame','halo','body'] as const){
      const l=m[kind];if(l)layer('ck-still-'+kind+(kind!=='body'&&m.halo?' ck-still-add':''),l,l.file);
    }
    host.replaceChildren(stage);host.dataset.projection=frame.id;field.dataset.still='ready';
  };
  paint();
  const resize=new ResizeObserver(paint);resize.observe(field.parentElement??field);
  const attributes=new MutationObserver(paint);
  attributes.observe(document.documentElement,{attributes:true,attributeFilter:['data-theme']});
  attributes.observe(cockpit,{attributes:true,attributeFilter:['data-layout']});
  return {dispose(){resize.disconnect();attributes.disconnect();host.remove();delete field.dataset.still;}};
}

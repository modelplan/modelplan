// SPDX-License-Identifier: MIT
// THROWAWAY SPIKE (session C, 2026-11-06): live porthole sprite composition for measurement only.
// Clean-room composition of the owner-approved porthole-stills pack (official edition only): one
// projected background, then per model a flame, halo and body layer at the recorded logical
// rectangles; flames/halos use plus-lighter and the manifest's flicker range. No WebGL, no three.js.
type Layer={left:number;top:number;width:number;height:number;file:string;file1x?:string};
type Model={id:string;nozzle?:{x:number;y:number};root:{x:number;y:number};body?:Layer;flame?:Layer;halo?:Layer};
type Projection={id:string;theme:string;layout:number;width:number;height:number;background:string;models:Model[]};
type Pack={defaultProjectionId:string;projections:Projection[];animation:{opacity:[number,number];scaleX:[number,number];scaleY:[number,number]}};
export type PortholeMode='off'|'still'|'live';
export async function mountLivePorthole(field:HTMLElement,mode:PortholeMode,layout:()=>number):Promise<{stats():Record<string,unknown>}|null>{
  if(mode==='off')return null;
  let pack:Pack;
  try{pack=(await import(new URL('./porthole-data.js',import.meta.url).href)).default as Pack;}catch{field.dataset.porthole='unavailable';return null;}
  const base=new URL('../runtime/porthole-stills/',import.meta.url).href;
  // Keyframes in cockpit.css hard-code the manifest range (CSS variables in keyframes can block accelerated animation).
  const a=pack.animation;if(a.opacity.join()!=='0.94,1'||a.scaleX.join()!=='0.985,1.015'||a.scaleY.join()!=='0.98,1.02')field.dataset.porthole='animation-mismatch';
  field.classList.add('ph-on');const host=document.createElement('div');host.className='ph-live';host.setAttribute('aria-hidden','true');field.prepend(host);
  let painted='';
  const paint=()=>{
    const want=layout()===640?640:890;
    const frame=pack.projections.find(p=>p.theme==='night'&&p.layout===want&&p.models.length===7)??pack.projections.find(p=>p.id===pack.defaultProjectionId)!;
    const W=field.clientWidth,H=field.clientHeight;if(!W||!H)return;
    const key=frame.id+':'+W+'x'+H;if(key===painted)return;painted=key;
    host.replaceChildren();
    const stage=document.createElement('div');stage.className='ph-stage';
    // Cover the field like the composer: scale the logical frame to the field width, centre vertically.
    const s=Math.max(W/frame.width,H/frame.height);
    stage.style.width=frame.width+'px';stage.style.height=frame.height+'px';
    stage.style.transform=`translate(${(W-frame.width*s)/2}px,${(H-frame.height*s)/2}px) scale(${s})`;
    const bg=document.createElement('div');bg.className='ph-layer';bg.style.inset='0';bg.style.backgroundImage=`url("${base+frame.background}")`;stage.append(bg);
    frame.models.forEach((m,index)=>{
      for(const kind of ['flame','halo','body'] as const){
        const l=m[kind];if(!l)continue;
        const e=document.createElement('div');e.className='ph-layer ph-'+kind+(kind!=='body'&&m.halo?' ph-add':'');
        Object.assign(e.style,{left:l.left+'px',top:l.top+'px',width:l.width+'px',height:l.height+'px',backgroundImage:`url("${base+l.file}")`});
        if(kind!=='body'){
          const n=m.nozzle??{x:m.root.x,y:l.top};e.style.transformOrigin=`${n.x-l.left}px ${n.y-l.top}px`;
          if(mode==='live'){e.classList.add('ph-flicker','ph-d'+(index%4),'ph-l'+(index%3));}
        }
        stage.append(e);
      }
    });
    host.append(stage);host.dataset.projection=frame.id;
  };
  paint();new ResizeObserver(paint).observe(field);
  return {stats:()=>({mode,projection:host.dataset.projection??null,layers:host.querySelectorAll('.ph-layer').length,animated:host.querySelectorAll('.ph-flicker').length})};
}

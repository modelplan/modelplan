// SPDX-License-Identifier: MIT
// Measurement harness only: mounts the shipped launch-field scene with chosen render modes so the
// native driver can sample CPU/GPU/memory. Synthetic public-style models; no personal data.
const devs=[['openai','#6aa8ff'],['anthropic','#ff9a6a'],['zhipu','#8f7dff']];
const efforts=['low','medium','high','xhigh'];
const MODELS=Array.from({length:10},(_,i)=>{
  const [dev,colour]=devs[i%3];
  const e=efforts.map((label,k)=>[label,40+i*3+k*4,0.2*(i+1)*(1+k*0.8),10+k*5]);
  return {id:`synthetic-${i}`,name:`Synthetic ${i}`,short:`Syn ${i}`,dev,colour,rec:'high',e,sel:e[2],reportedEffort:null,previewEffort:null};
});
let scene=null,failed=false,mode='none';
const stage=document.getElementById('stage');
function size(w,h,scale){
  stage.style.width=`${w*scale}px`;stage.style.height=`${h*scale}px`;stage.style.transform=`scale(${1/scale})`;
}
window.spike={
  async mount(o){
    window.spike.unmount();failed=false;mode=o.kind;size(o.w,o.h,o.scale||1);
    if(o.kind==='still'){
      const img=document.createElement('img');img.src=o.src;stage.replaceChildren(img);
      await img.decode().catch(()=>{failed=true;});return window.spike.stats();
    }
    const host=document.createElement('div');host.className='r1-field p2-field';
    host.innerHTML='<div class="wb-canvas"></div><svg class="wb-leaders"></svg><div class="wb-plates"></div><div class="wb-voyage"></div>';
    stage.replaceChildren(host);
    const {mountWorkbenchField}=await import('./runtime/field-scene/cockpit-scene.bundle.js');
    scene=mountWorkbenchField(host,{models:MODELS.slice(0,o.n||10),focus:MODELS[0].id,quiet:!!o.quiet,showPath:true,language:'en',
      onDemand:!!o.onDemand,noIntro:true,onSelect(){},onFail(){failed=true;}});
    scene.renderFor?.(1400);
    if(o.active)scene.setActive?.(true);
    return window.spike.stats();
  },
  stats(){
    const s=scene?.stats?.()??{};const c=stage.querySelector('canvas');
    let gl=null;try{const ctx=c?.getContext('webgl2');const ext=ctx?.getExtension('WEBGL_debug_renderer_info');gl=ctx?(ext?ctx.getParameter(ext.UNMASKED_RENDERER_WEBGL):ctx.getParameter(ctx.RENDERER)):null;}catch{}
    return {mode,failed,frames:s.frames??null,active:s.active??null,scheduled:s.scheduled??null,requests:s.requests??null,
      canvasW:c?.width??null,canvasH:c?.height??null,dpr:devicePixelRatio,hidden:document.hidden,renderer:gl,
      reducedMotionQuery:matchMedia('(prefers-reduced-motion: reduce)').matches,t:performance.now()};
  },
  unmount(){scene?.dispose?.();scene=null;stage.replaceChildren();mode='none';return true;},
};

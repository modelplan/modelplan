// SPDX-License-Identifier: MIT
// Inject after the page's own animation setup. Does not create/resume animations.
globalThis.installVerificationAnimationObserver = function (groups) {
  let stopped=false, raf=0, frames=0;
  const totals=Object.fromEntries(Object.keys(groups).map(k=>[k,0]));
  const running=Object.fromEntries(Object.keys(groups).map(k=>[k,0]));
  let previous=new WeakMap();
  function tick() {
    if(stopped)return;
    frames++;
    const advanced=new Set();
    for(const k of Object.keys(groups))running[k]=0;
    for(const animation of document.getAnimations()) {
      const target=animation.effect?.target, time=animation.currentTime;
      if(!(target instanceof Element)||typeof time!=='number')continue;
      const old=previous.get(animation);previous.set(animation,time);
      if(document.hidden||animation.playState!=='running')continue;
      const style=getComputedStyle(target),box=target.getBoundingClientRect();
      if(style.visibility==='hidden'||style.display==='none'||box.width<=0||box.height<=0)continue;
      for(const [name,selector] of Object.entries(groups)) {
        if(!target.closest(selector))continue;
        running[name]++;
        if(old!==undefined&&time>old)advanced.add(name);
      }
    }
    for(const name of advanced)totals[name]++;
    raf=requestAnimationFrame(tick);
  }
  raf=requestAnimationFrame(tick);
  return {
    snapshot:()=>({event:'animation-frames',documentVisible:!document.hidden,observerFrames:frames,
      groups:Object.fromEntries(Object.keys(groups).map(k=>[k,{advancingFrames:totals[k],visibleRunningAnimations:running[k]}]))}),
    stop:()=>{stopped=true;cancelAnimationFrame(raf);previous=new WeakMap();}
  };
};

// Inject only from a test-flagged host with its own scoped message handler.
globalThis.installVerificationRAFTicks = function (handlerName) {
  const handler=globalThis.webkit?.messageHandlers?.[handlerName];
  if(!handler)throw Error('test frame handler unavailable');
  let count=0,id=0,stopped=false;
  function tick(){if(stopped)return;handler.postMessage({frames:++count});id=requestAnimationFrame(tick)}
  id=requestAnimationFrame(tick);
  return ()=>{stopped=true;cancelAnimationFrame(id)};
};

// SPDX-License-Identifier: MIT
// Installed before the application. A timer scheduled by an interaction is an outstanding task at the deadline;
// callbacks retain their originating step even if they fire later, so their DOM mutations cannot disappear.
export function watch(){
 const pending=new Set(),timers=new Map(),raf=window.requestAnimationFrame.bind(window),cancel=window.cancelAnimationFrame.bind(window);
 const setTimer=window.setTimeout.bind(window),clearTimer=window.clearTimeout.bind(window);
 const setRepeater=window.setInterval.bind(window),clearRepeater=window.clearInterval.bind(window);
 const state=window.__walk={current:null,results:[],rejections:[]};
 const mark=(step,event)=>{if(!step)return;const now=performance.now();step.last=now;step.lastEvent=event;if(now-step.start>150)step.late.push(event);};
 const mutations=(step,records)=>{for(const r of records){const el=r.target.nodeType===1?r.target:r.target.parentElement;mark(step,{kind:'mutation',type:r.type,attribute:r.attributeName,target:el?.outerHTML?.slice(0,250)});}};
 const observer=new MutationObserver(records=>{if(!state.current)return;const chosen=performance.now()-state.current.start>150?records:[records.at(-1)];mutations(state.current,chosen);});
 observer.observe(document,{subtree:true,childList:true,attributes:true,characterData:true});
 window.requestAnimationFrame=cb=>{const scheduled=new Error().stack;let id;id=raf(t=>{pending.delete(id);mark(state.current,{kind:'frame',scheduled});cb(t);});pending.add(id);return id;};
 window.cancelAnimationFrame=id=>{if(pending.has(id))mark(state.current,{kind:'cancel-frame'});pending.delete(id);cancel(id);};
 function schedule(repeat,callback,delay,args){
  const step=state.current,native=repeat?setRepeater:setTimer;
  if(!step||typeof callback!=='function')return native(callback,delay,...args);
  let id;id=native((...values)=>{if(!repeat)timers.delete(id);try{callback(...values);}finally{mutations(step,observer.takeRecords());}},delay,...args);
  timers.set(id,step);return id;
 }
 window.setTimeout=(callback,delay,...args)=>schedule(false,callback,delay,args);
 window.setInterval=(callback,delay,...args)=>schedule(true,callback,delay,args);
 window.clearTimeout=id=>{timers.delete(id);clearTimer(id);};
 window.clearInterval=id=>{timers.delete(id);clearRepeater(id);};
 const start=()=>{const now=performance.now(),step={start:now,last:now,displayAt:state.displayAt??null,late:[]};state.current=step;setTimer(()=>{step.pending=pending.size;step.pendingTimers=[...timers.values()].filter(x=>x===step).length;step.elapsed=performance.now()-now;state.results.push(step);if(state.current===step)state.current=null;},150);};
 document.addEventListener('mousedown',start,true);
 document.addEventListener('keydown',e=>{if(e.key==='Escape')start();},true);
 window.addEventListener('unhandledrejection',e=>state.rejections.push(String(e.reason)));
}

export function timingVerdict(step){
 if(step.pending)return {failure:'pending animation frames at 150 ms'};
 if(step.pendingTimers)return {failure:'pending timers at 150 ms'};
 if(step.last-step.start<=150)return {};
 return {failure:'last mutation or frame exceeded 150 ms'};
}

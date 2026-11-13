// SPDX-License-Identifier: MIT
// Screen-space lanes for the enlarged field's axis labels (QA 11-08: they overlapped). The scene still projects its
// ticks and values; this only moves the projected plates into rows on the page and hides any that would collide.
// Price ticks share one row left to right, the two captions share the row below it, time ticks stack at the right.
// Event driven: it runs in the observers' own batched callbacks for plate changes and resizes, with no timer or frame
// loop of its own (the page's no-scheduling rule; only the scene schedules frames). Its own writes settle in one pass.
// Prototype: clients/official-visuals/study/field-picker-tags/axis-layout.js (task 91); the code is written here.

/** The usable horizontal span at row `y` for a label `height` tall; the default is the view inset by 4 px. */
export type SafeSpan=(width:number,height:number,y:number,labelHeight:number)=>{left:number;right:number};
export const rectangleSpan:SafeSpan=width=>({left:4,right:width-4});

export function layoutFieldAxes(host:HTMLElement,span:SafeSpan=rectangleSpan):()=>void {
 const found=host.querySelector<HTMLElement>('.wb-plates');if(!found)return()=>{};const plates:HTMLElement=found;
 let disposed=false;
 const write=(el:HTMLElement,x:number,y:number,show=true)=>{
  el.classList.add('field-axis-placed');
  const values={'--field-axis-position':`translate(${Math.round(x)}px, ${Math.round(y)}px)`,'--field-axis-opacity':show?'1':'0'};
  for(const [key,value] of Object.entries(values))if(el.style.getPropertyValue(key)!==value)el.style.setProperty(key,value);
 };
 // The scene places each plate with an inline translate; read the projected point from it.
 const point=(el:HTMLElement)=>{try{const m=new DOMMatrixReadOnly(el.style.transform);return {x:m.m41,y:m.m42};}catch{return {x:0,y:0};}};
 const shown=(el:HTMLElement)=>Number(el.style.opacity||'1')>.02;
 const ticks=(kind:string)=>[...plates.querySelectorAll<HTMLElement>('.tick3.'+kind)].map(el=>({el,...point(el)}));
 function place() {
  if(disposed)return;
  const W=host.clientWidth,H=host.clientHeight;if(!W||!H)return;
  const priceY=Math.round(H*.76),captionY=Math.round(H*.84),priceSpan=span(W,H,priceY,20);
  let edge=priceSpan.left;
  for(const {el,x} of ticks('cost').sort((a,b)=>a.x-b.x)){
   const width=el.offsetWidth,left=x-width/2,show=left>=edge&&left+width<=priceSpan.right&&shown(el);
   write(el,left,priceY,show);if(show)edge=left+width+8;
  }
  const time=ticks('time').filter(t=>shown(t.el)).sort((a,b)=>a.y-b.y),step=21,ceiling=Math.round(H*.63);
  let last=Math.max(80,Math.min(time[0]?.y??80,ceiling-time.length*step));
  for(const [index,{el,y}] of time.entries()){
   const placed=Math.min(ceiling-(time.length-index-1)*step,Math.max(last,y)),row=span(W,H,placed,el.offsetHeight);
   write(el,row.right-el.offsetWidth,placed,row.right-row.left>=el.offsetWidth);last=placed+step;
  }
  for(const el of plates.querySelectorAll<HTMLElement>('.tick3.time'))if(!time.some(t=>t.el===el))write(el,0,0,false);
  const lane=plates.querySelector<HTMLElement>('.tick3.lane'),axis=plates.querySelector<HTMLElement>('.tick3.axis'),captions=span(W,H,captionY,20);
  if(lane)write(lane,captions.left,captionY,shown(lane));
  // The cost caption yields to the front-row caption when the row is too narrow for both.
  if(axis)write(axis,captions.right-axis.offsetWidth,captionY,shown(axis)&&(!lane||!shown(lane)||captions.left+lane.offsetWidth+8<=captions.right-axis.offsetWidth));
 }
 const observer=new MutationObserver(place);
 observer.observe(plates,{childList:true,subtree:true,attributes:true,attributeFilter:['style']});
 const resize=new ResizeObserver(place);resize.observe(host);place();
 return ()=>{disposed=true;observer.disconnect();resize.disconnect();};
}

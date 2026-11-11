// SPDX-License-Identifier: MIT
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';

// Build 13 owner review, regressed in build 14c: the cockpit's tab marks differ in size (OpenAI's file keeps half of
// its canvas clear, Claude's fills it), so the Codex tab showed a dot. Every vendor tab mark is fitted by its glyph
// bounds, as the widget card does (#741). (Marks for keyless tools, #754's other half, are not part of this fix.)
function data(vk={codex:'openai',claude:'claude',cursor:'cursor',gemini:'copilot'}){
 const d=visualFixture().data;
 for(const r of d.projection.rows)r.vendorKey=vk[r.id]??null;
 return d;
}
async function open(page,d){
 await page.setViewportSize({width:636,height:911});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance:{...appearance,reduceMotion:true},shell}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data:d}))).toBe(true);
 await page.waitForFunction(()=>document.querySelectorAll('.eng-keys .ek[data-sub]').length>=4);await page.waitForTimeout(200);
}
// The longest side of each mark's drawn glyph, in CSS px, from the file's own pixels and the box it is drawn in.
function measure(){
 return Promise.all([...document.querySelectorAll('.eng-keys .ek[data-sub] img.lamp')].map(async img=>{
  const probe=new Image();probe.src=img.currentSrc;await probe.decode();
  const S=256,c=document.createElement('canvas');c.width=c.height=S;const x=c.getContext('2d');
  const k=Math.min(S/probe.naturalWidth,S/probe.naturalHeight),w=probe.naturalWidth*k,h=probe.naturalHeight*k;
  x.drawImage(probe,(S-w)/2,(S-h)/2,w,h);
  const px=x.getImageData(0,0,S,S).data;let x0=S,y0=S,x1=-1,y1=-1;
  for(let y=0;y<S;y++)for(let i=0;i<S;i++)if(px[(y*S+i)*4+3]>16){x0=Math.min(x0,i);x1=Math.max(x1,i);y0=Math.min(y0,y);y1=Math.max(y1,y);}
  const fraction=Math.max(x1-x0+1,y1-y0+1)/S,box=img.getBoundingClientRect();
  return {src:img.getAttribute('src'),loaded:img.complete&&img.naturalWidth>0,glyph:Math.max(box.width,box.height)*fraction,
   keyHeight:img.closest('.ek').getBoundingClientRect().height};
 }));
}

for(const [label,vk,files] of [
 ['openai, claude, cursor, copilot',{codex:'openai',claude:'claude',cursor:'cursor',gemini:'copilot'},['claude-rounded.svg','copilot.svg','cursor.svg','openai-white.svg']],
 ['openai, kimi, opencode, claude (glm-842-3)',{codex:'openai',claude:'kimi',cursor:'opencode',gemini:'claude'},['claude-rounded.svg','kimi-white.svg','openai-white.svg','opencode.svg']],
])test(`Cockpit vendor tab marks have one visible size (the Codex tab is not a dot): ${label}`,async({page})=>{
 const missing=[];page.on('response',r=>{if(r.status()>=400)missing.push(new URL(r.url()).pathname);});
 await open(page,data(vk));
 const marks=await page.evaluate(measure);
 expect(marks.map(m=>m.src.split('/').pop()).sort()).toEqual(files);
 expect(marks.map(m=>m.loaded)).toEqual([true,true,true,true]);
 const sizes=marks.map(m=>m.glyph),mean=sizes.reduce((a,b)=>a+b,0)/sizes.length;
 for(const m of marks)expect(Math.abs(m.glyph-mean)/mean,`${m.src} glyph ${m.glyph.toFixed(2)}px against mean ${mean.toFixed(2)}`).toBeLessThan(0.06);
 for(const m of marks)expect(m.glyph,`${m.src} glyph stays inside its key`).toBeLessThan(m.keyHeight-8);
 expect(missing).toEqual([]);
});

// SPDX-License-Identifier: MIT
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';
import {inflateSync} from 'node:zlib';

// G3-82 (owner, build 14c): a raised light band stood on the top centre of the porthole and a bright line ran down its
// sides. The owner-approved canopy (#801, 2026-11-09 v10: tall A3 as generated, compact A1, the current strip) has glass
// up to the top of its art box, but the porthole still stopped at the port's padding box (12 px lower, 26 px in), so
// the desktop showed through the window there. This measures what the page actually paints (transparent screenshot,
// alpha), at 1x and at the 2x the owner's Mac draws:
// - nothing inside the silhouette is see-through (no desktop through the canopy, frame or walls);
// - open shapes: the outline is within 1% of the 636 px hull (6.4 px) of the approved v10 render, row by row from the
//   canopy's top (A3 tall, A1 compact; read from the owner-approved side-by-side images, 2x, in px from the first
//   painted row);
// - below the canopy the hull only widens.
const TOL=6.4;
const APPROVED={
 tall:[[4,240.5],[6,281.5],[8,316],[10,345.5],[14,392.5],[20,448.5],[30,516],[40,554.5],[60,586.5],[80,599],[100,605.5],[120,611],
  [140,616],[160,621],[180,624.5],[200,621],[220,620],[240,620],[260,620.5],[300,620.5],[400,620.5],[560,636],[700,636]],
 compact:[[4,409.5],[6,482],[8,531.5],[10,559.5],[14,582.5],[20,595],[30,607],[40,615.5],[48,620],[100,620.5],[200,620.5],[400,636]],
};
const shapes=[
 {tier:'tall',closed:false,canvas:939,root:905,cap:244,approved:APPROVED.tall},
 {tier:'compact',closed:false,canvas:669,root:635,cap:56,approved:APPROVED.compact},
 {tier:'tall',closed:true,canvas:725,root:691,cap:30},
 {tier:'compact',closed:true,canvas:643,root:609,cap:30},
];
async function open(page,s){
 await page.setViewportSize({width:636,height:s.canvas});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance:{...appearance,reduceMotion:true},shell:{...shell,tier:s.tier,profile:s.closed?'closed':'open'}}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data:visualFixture().data}))).toBe(true);
 if(!s.closed)await expect(page.locator('.ck-field')).toHaveAttribute('data-still','ready');
 await page.waitForTimeout(300);
}
// Per device row: [left,right] of the painted silhouette in CSS px (alpha >= 128) and how many device pixels between
// them are see-through (alpha < 128).
async function silhouette(page,height,scale){
 const buffer=await page.screenshot({omitBackground:true,clip:{x:0,y:0,width:636,height}});
 let offset=8,width=0,rowsN=0;const data=[];
 while(offset<buffer.length){const size=buffer.readUInt32BE(offset),name=buffer.toString('latin1',offset+4,offset+8),body=buffer.subarray(offset+8,offset+8+size);
  if(name==='IHDR'){width=body.readUInt32BE(0);rowsN=body.readUInt32BE(4);if(body[8]!==8||body[9]!==6)throw new Error('expected 8-bit RGBA');}
  if(name==='IDAT')data.push(body);offset+=size+12;}
 const raw=inflateSync(Buffer.concat(data)),stride=width*4,out=Buffer.alloc(stride*rowsN),rows=[];
 for(let y=0;y<rowsN;y++){const f=raw[y*(stride+1)],src=raw.subarray(y*(stride+1)+1,(y+1)*(stride+1)),row=out.subarray(y*stride,(y+1)*stride),up=y?out.subarray((y-1)*stride,y*stride):Buffer.alloc(stride);
  for(let i=0;i<stride;i++){const a=i>=4?row[i-4]:0,b=up[i],c=i>=4?up[i-4]:0;let p=src[i];
   if(f===1)p+=a;else if(f===2)p+=b;else if(f===3)p+=(a+b)>>1;else if(f===4){const q=a+b-c,pa=Math.abs(q-a),pb=Math.abs(q-b),pc=Math.abs(q-c);p+=pa<=pb&&pa<=pc?a:pb<=pc?b:c;}
   row[i]=p&255;}
  let l=-1,r=-1;for(let x=0;x<width;x++)if(row[x*4+3]>=128){if(l<0)l=x;r=x;}
  let holes=0;for(let x=l+1;x<r;x++)if(row[x*4+3]<128)holes++;
  rows.push(l<0?null:{l:l/scale,r:(r+1)/scale,holes});}
 return rows;
}
for(const scale of [1,2])test.describe(`@${scale}x`,()=>{
 test.use({deviceScaleFactor:scale});
 for(const s of shapes)test(`G3-82 ${s.tier}${s.closed?' closed':''} @${scale}x: the approved canopy outline, nothing see-through inside it`,async({page})=>{
  await open(page,s);
  // The closed page draws its slab at the window's top edge (#cockpit margin-top -14 px); open roots start at 0.
  const top=await page.evaluate(()=>Math.round(document.querySelector('#cockpit').getBoundingClientRect().top));
  const lowerTop=await page.evaluate(()=>Math.round(document.querySelector('.ck-shell .hull-lower').getBoundingClientRect().top));
  // No desktop through the canopy, its frame or the walls, from the first painted row to the lower wall.
  // The hull art is CSS background PNGs decoded lazily: on a loaded hosted WebKit runner the first screenshot can
  // land before they paint (whole rows see-through, runs 43401327557 and 43448154939). A real hole stays, so measure
  // again after a pause, up to 4 times, and fail only if the last measurement still has holes.
  let rows,seeThrough;
  for(let attempt=0;attempt<4;attempt++){
   rows=await silhouette(page,s.root+top,scale);
   seeThrough=[];
   for(let y=0;y<(lowerTop+40)*scale;y++){const r=rows[y];if(r&&r.holes)seeThrough.push(`${(y/scale).toFixed(1)}: ${r.holes} px`);}
   if(!seeThrough.length)break;
   await page.waitForTimeout(500);
  }
  expect(seeThrough.slice(0,8),'see-through pixels inside the silhouette').toEqual([]);
  // Below the canopy the hull only widens (the A3 frame's own slight flare above the strip is approved art).
  const strip=await page.evaluate(()=>Math.round(document.querySelector('.ck-head').getBoundingClientRect().top));
  const narrower=[];let edge=null;
  for(let y=strip*scale;y<(lowerTop+40)*scale;y++){const r=rows[y];if(!r)continue;
   if(edge&&(r.l>edge[0]||r.r<edge[1]))narrower.push(`${(y/scale).toFixed(1)}: [${r.l},${r.r}] narrower than [${edge}] above`);
   edge=edge?[Math.min(edge[0],r.l),Math.max(edge[1],r.r)]:[r.l,r.r];}
  expect(narrower.slice(0,8),'below the canopy every row at least as wide as every row above it').toEqual([]);
  if(s.approved){
   const first=rows.findIndex(Boolean),off=[];
   // The approved render is 2x; at 1x a whole-pixel row cannot follow the arch's first rows (10-50 px per row), so 1x
   // starts where the arch is gentler.
   for(const [y,want] of s.approved.filter(([y])=>scale>1||y>=14)){const r=rows[first+Math.round(y*scale)],got=r?r.r-r.l:0;
    if(Math.abs(got-want)>TOL)off.push(`${y}: ${got} vs approved ${want}`);}
   expect(off,'outline vs the approved v10 A3/A1 render (1% of 636 px)').toEqual([]);
  }
 });
});

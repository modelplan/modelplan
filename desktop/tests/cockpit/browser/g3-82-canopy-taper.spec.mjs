// SPDX-License-Identifier: MIT
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';
import {inflateSync} from 'node:zlib';

// G3-82 (owner, build 14c; decision D156): the top of the cockpit stood out above the strip. The D74/D100 canopy
// (#801) was 28 px (tall) / 8 px (compact) taller than the opus-r7 study's, with a raised dome, and its tall frame
// swelled 2 px past the 620 px upper walls above its foot. D156 restores the study's own c01 canopy. This measures
// what the page actually paints (alpha >= 128, transparent screenshot) rather than boxes, at 1x and at the 2x the
// owner's Mac draws, in all four shapes:
// - the canopy never wider than the upper wall at the strip;
// - every row from the top down to the lower wall at least as wide as every row above it;
// - the whole silhouette within 1% of the 636 px hull (6.4 px) of the study's profile.
// Study profile: painted width (px, alpha >= 128) of opus-r7 rocket-r1.html (night, 956 / 700 px tall, open and
// shutter=1, 2x) at heights measured from the strip's top (negative = canopy; 0 width = nothing painted, no dome).
const TOL=6.4;
const PROTO={
 tall:[[-230,0],[-225,510.5],[-222,529.5],[-218,549],[-215,560],[-210,572],[-200,585],[-190,592],[-180,596],[-160,604],[-140,610],
  [-120,617],[-100,620],[-80,620],[-60,620],[-40,620],[-20,620],[-5,620],[5,620],[40,620],[120,620],[200,620],[260,620],[300,636],[400,636],[600,636]],
 compact:[[-60,0],[-57,517],[-55,560],[-52,583],[-50,590],[-45,600],[-40,608],[-35,615],[-30,620],[-20,620],[-10,620],[-5,620],[5,620],[40,620],
  [120,620],[200,620],[250,620],[300,636],[500,636]],
 tallClosed:[[-30,0],[-25,605],[-20,615],[-14,620],[-10,620],[-5,620],[5,620],[40,620],[120,620],[200,620],[260,620],[300,636],[400,636],[620,636]],
 compactClosed:[[-30,0],[-25,605],[-20,615],[-14,620],[-10,620],[-5,620],[5,620],[40,620],[120,620],[200,620],[230,620],[260,623],[300,636],[400,636],[540,636]],
};
// Strip tops in the window: the study's 225 / 57 open; closed, the page draws the slab at the window's top edge (25).
const shapes=[
 {tier:'tall',closed:false,canvas:911,root:877,cap:216,strip:225,proto:PROTO.tall},
 {tier:'compact',closed:false,canvas:661,root:627,cap:48,strip:57,proto:PROTO.compact},
 {tier:'tall',closed:true,canvas:725,root:691,cap:30,strip:25,proto:PROTO.tallClosed},
 {tier:'compact',closed:true,canvas:643,root:609,cap:30,strip:25,proto:PROTO.compactClosed},
];
async function open(page,s){
 await page.setViewportSize({width:636,height:s.canvas});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance:{...appearance,reduceMotion:true},shell:{...shell,tier:s.tier,profile:s.closed?'closed':'open'}}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data:visualFixture().data}))).toBe(true);
 await page.waitForTimeout(300);
}
// Per-row [left,right] of the painted silhouette in CSS px (a device row counts if any of its pixels is >= 128 alpha).
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
  let l=-1,r=-1;for(let x=0;x<width;x++)if(row[x*4+3]>=128){if(l<0)l=x;r=x;}rows.push(l<0?null:[l/scale,(r+1)/scale]);}
 return rows;
}
for(const scale of [1,2])test.describe(`@${scale}x`,()=>{
 test.use({deviceScaleFactor:scale});
 for(const s of shapes)test(`G3-82 ${s.tier}${s.closed?' closed':''} @${scale}x: the canopy stays inside the walls and the hull widens downward`,async({page})=>{
  await open(page,s);
  // The closed page draws its slab at the window's top edge (#cockpit margin-top -14 px); open roots start at 0.
  const top=await page.evaluate(()=>Math.round(document.querySelector('#cockpit').getBoundingClientRect().top));
  const rows=await silhouette(page,s.root+top,scale);
  // The walls under the cap: the narrowest painted body the canopy has to sit inside (the strip's own hull row).
  const strip=await page.evaluate(()=>{const r=document.querySelector('.ck-head').getBoundingClientRect();return [Math.round(r.top),Math.round(r.bottom)];});
  const wall=rows[strip[0]*scale+Math.round(4*scale)];
  expect(wall,'upper wall at the strip').toEqual([8,628]);
  const cap=rows.slice(0,(s.cap+top)*scale).filter(Boolean);
  expect(cap.length,'the canopy paints').toBeGreaterThan(0);
  const capLeft=Math.min(...cap.map(r=>r[0])),capRight=Math.max(...cap.map(r=>r[1]));
  expect([capLeft,capRight],'canopy frame never wider than the wall below it').toEqual([Math.max(capLeft,wall[0]),Math.min(capRight,wall[1])]);
  // Monotone taper top to bottom, down to the lower wall (the aft plate's rounded foot below is not part of it), up to
  // the 1 px anti-aliasing jitter the study's own c01 art has.
  const lowerTop=await page.evaluate(()=>Math.round(document.querySelector('.ck-shell .hull-lower').getBoundingClientRect().top));
  const bad=[];let edge=null;
  for(let y=0;y<(lowerTop+40)*scale;y++){const r=rows[y];if(!r)continue;
   if(edge&&(r[0]>edge[0]+1||r[1]<edge[1]-1))bad.push(`${(y/scale).toFixed(1)}: [${r}] narrower than [${edge}] above`);
   edge=edge?[Math.min(edge[0],r[0]),Math.max(edge[1],r[1])]:r;}
  expect(bad.slice(0,8),'every row at least as wide as every row above it').toEqual([]);
  expect(strip[0],'strip top in the window').toBe(s.strip);
  const off=[];
  for(const [y,want] of s.proto){const r=rows[Math.round((strip[0]+y)*scale)],got=r?r[1]-r[0]:0;
   if(Math.abs(got-want)>TOL)off.push(`${y}: ${got} vs study ${want}`);}
  expect(off,'silhouette profile vs the opus-r7 study (1% of 636 px)').toEqual([]);
 });
});

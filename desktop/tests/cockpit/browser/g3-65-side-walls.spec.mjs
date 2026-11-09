// SPDX-License-Identifier: MIT
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';
import {inflateSync} from 'node:zlib';

// G3-65 / C-04 (owner, MacBook Air 1470x956 at the Auto 85 %, builds 13 and 14b): the hull's side walls were cut on
// both sides. The lower walls are painted across the whole 636 CSS px canvas, edge to edge. The native window shows the
// page at a WebKit page zoom, and WebKit lays a web view out in whole points: a 636 x 0.85 = 540.6 pt window gave the
// page 540 pt, and the 620 px shell, centred by margin:auto, lost the outer columns of both walls. The native layout
// now rounds the window UP to whole points (CockpitShellLayout.windowSize); this is the page side of that contract.
// Playwright has no page zoom, so a root `zoom` stands in for it: WebKit implements page zoom as the root's zoom.
const scale=0.85,canvas=911;
const nativeWidth=Math.ceil(636*scale-1e-6),nativeHeight=Math.ceil(canvas*scale-1e-6);

async function open(page,width){
 await page.setViewportSize({width,height:nativeHeight});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance:{...appearance,reduceMotion:true},shell:{...shell,tier:'tall'}}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data:visualFixture().data}))).toBe(true);
 await page.evaluate(z=>{document.documentElement.style.zoom=String(z);},scale);
 await page.waitForTimeout(200);
}
// Per-row painted extent (alpha >= 128) of a transparent screenshot of the whole viewport.
async function silhouette(page,width){
 const buffer=await page.screenshot({omitBackground:true,clip:{x:0,y:0,width,height:nativeHeight}});
 let offset=8,w=0,h=0;const data=[];
 while(offset<buffer.length){const size=buffer.readUInt32BE(offset),name=buffer.toString('latin1',offset+4,offset+8),body=buffer.subarray(offset+8,offset+8+size);
  if(name==='IHDR'){w=body.readUInt32BE(0);h=body.readUInt32BE(4);if(body[8]!==8||body[9]!==6)throw new Error('expected 8-bit RGBA');}
  if(name==='IDAT')data.push(body);offset+=size+12;}
 const raw=inflateSync(Buffer.concat(data)),stride=w*4,out=Buffer.alloc(stride*h),rows=[];
 for(let y=0;y<h;y++){const f=raw[y*(stride+1)],src=raw.subarray(y*(stride+1)+1,(y+1)*(stride+1)),row=out.subarray(y*stride,(y+1)*stride),up=y?out.subarray((y-1)*stride,y*stride):Buffer.alloc(stride);
  for(let i=0;i<stride;i++){const a=i>=4?row[i-4]:0,b=up[i],c=i>=4?up[i-4]:0;let p=src[i];
   if(f===1)p+=a;else if(f===2)p+=b;else if(f===3)p+=(a+b)>>1;else if(f===4){const q=a+b-c,pa=Math.abs(q-a),pb=Math.abs(q-b),pc=Math.abs(q-c);p+=pa<=pb&&pa<=pc?a:pb<=pc?b:c;}
   row[i]=p&255;}
  let l=-1,r=-1;for(let x=0;x<w;x++)if(row[x*4+3]>=128){if(l<0)l=x;r=x;}rows.push(l<0?null:[l,r]);}
 return rows;
}
const widths=rows=>rows.map(r=>r&&r[1]-r[0]+1);

test('G3-65 at 85 %: no painted hull pixel is clipped by the viewport the native window gives the page',async({page})=>{
 expect([nativeWidth,nativeHeight]).toEqual([541,775]);
 // Reference: the same zoom with room on both sides, so nothing can be cut. The page centres the shell, so the whole
 // silhouette only moves right; its width on every row is what the window must show.
 await open(page,nativeWidth+40);
 const room=await silhouette(page,nativeWidth+40);
 const hull=Math.max(...widths(room).filter(Boolean));
 expect(hull,'the shell is painted').toBeGreaterThanOrEqual(Math.floor(620*scale));
 // Every painted row keeps a transparent column on both sides of the reference: nothing reaches its edge.
 for(const r of room.filter(Boolean))expect(r[0]>0&&r[1]<nativeWidth+39).toBe(true);

 // The window the native layout gives the page: every row is as wide as with room to spare.
 await open(page,nativeWidth);
 expect(await page.evaluate(()=>[...document.querySelectorAll('.ck-shell :is(.hull-crown,.hull-upper,.hull-cone,.hull-lower,.hull-record)')]
  .filter(e=>getComputedStyle(e).display!=='none'&&e.getBoundingClientRect().width>0).length),'hull parts painted').toBeGreaterThan(0);
 const fitted=await silhouette(page,nativeWidth);
 const lost=fitted.map((r,y)=>({y,room:room[y]&&room[y][1]-room[y][0]+1,fitted:r&&r[1]-r[0]+1})).filter(r=>r.room!==r.fitted);
 expect(lost,'rows whose painted width differs from the uncut reference').toEqual([]);
 expect(Math.max(...widths(fitted).filter(Boolean))).toBe(hull);

 // The cause, kept as a regression: the old fractional window (540.6 pt) reached the page as 540 pt. Where the hull
 // paints the whole 636 px canvas (the study's full-width lower walls, #760), that page cuts both walls.
 if(hull>=Math.floor(636*scale)){
  await open(page,nativeWidth-1);
  const cut=await silhouette(page,nativeWidth-1);
  expect(Math.max(...widths(cut).filter(Boolean)),'a 540 pt page cannot hold the 540.6 pt hull').toBeLessThan(hull);
 }
});

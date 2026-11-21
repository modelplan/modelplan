// SPDX-License-Identifier: MIT
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';
import {decodePng} from '../png-pixel.mjs';

// G3-118 (owner, build 14f-preview, MacBook at the Auto 85 % page zoom): a thin light line ran across both side walls
// at the joint between the taper and the lower wall. The hull walls are separate layers stacked edge to edge
// (upper | taper at --hull-taper-top | lower at taper + 31 px). At a fractional page zoom a shared edge falls inside
// a device pixel; each layer then covers only part of that row and the desktop shows through the sum (G3-108 was the
// same fault between the closed slab and the upper walls). Every wall layer now reaches 1 px under the next one.
// Playwright has no page zoom, so a root `zoom` stands in for it (WebKit implements page zoom as the root's zoom),
// as in g3-65-side-walls.
const canvas=939;
async function open(page,tier,profile,zoom){
 await page.setViewportSize({width:Math.ceil(636*zoom),height:Math.ceil(canvas*zoom)});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance:{...appearance,reduceMotion:true},shell:{...shell,tier,profile}}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data:visualFixture().data}))).toBe(true);
 await page.evaluate(z=>{document.documentElement.style.zoom=String(z);},zoom);
 await page.waitForTimeout(200);
}
// The wall layers' boxes in unzoomed CSS px relative to the shell, and every shared edge between consecutive layers.
const walls=page=>page.evaluate(()=>{
 // WebKit reports boxes under a root zoom in unzoomed CSS px.
 const s=document.querySelector('.ck-shell').getBoundingClientRect();
 return ['.hull-crown','.hull-upper','.hull-cone','.hull-lower'].map(q=>document.querySelector('.ck-shell '+q))
  .filter(e=>getComputedStyle(e).display!=='none').map(e=>{const r=e.getBoundingClientRect();return {name:e.className,top:r.top-s.top,bottom:r.bottom-s.top};});
});
// Rows inside the side walls where a row is clearly more transparent than the rows two above and two below: a seam.
function seams(png,from,to,edge){
 const {width,data,channels}=png,alpha=(x,y)=>data[(y*width+x)*channels+3],found=[];
 for(let y=Math.max(2,from);y<Math.min(png.height-2,to);y++){
  let l=-1,r=-1;for(let x=0;x<width;x++)if(alpha(x,y-2)>=250&&alpha(x,y+2)>=250){if(l<0)l=x;r=x;}
  if(l<0)continue;
  for(const x of [...Array(edge).keys()].flatMap(i=>[l+i,r-i])){
   if(alpha(x,y-2)<250||alpha(x,y+2)<250)continue;
   if(alpha(x,y)<235){found.push({y,x,a:alpha(x,y)});break;}
  }
 }
 return found;
}
for(const [tier,profile] of [['tall','open'],['compact','open'],['tall','closed']])
for(const zoom of [0.85,0.849,0.8,0.9,1.15])
test(`G3-118 ${tier} ${profile} at ${Math.round(zoom*1000)/10} %: no seam at the hull wall joints`,async({page})=>{
 await open(page,tier,profile,zoom);
 const layers=await walls(page);
 expect(layers.length,'wall layers painted').toBeGreaterThanOrEqual(3);
 const png=decodePng(await page.screenshot({omitBackground:true}));
 const box=await page.evaluate(()=>{const r=document.querySelector('.ck-shell').getBoundingClientRect();return {top:r.top,bottom:r.bottom};});
 // Scan the side walls from the top of the upper wall (below the canopy) down through the aft plate (the engine
 // bells below the shell are shaped art, not walls).
 const from=Math.floor((box.top+layers.find(l=>/hull-upper/.test(l.name)).top)*zoom)+2;
 expect(seams(png,from,Math.floor(box.bottom*zoom)-2,Math.round(20*zoom)),'transparent rows across the side walls').toEqual([]);
 // Consecutive wall layers overlap by 1 px (the G3-108 rule, now at every joint).
 for(let i=1;i<layers.length;i++)
  expect(layers[i-1].bottom-layers[i].top,`${layers[i-1].name} overlaps ${layers[i].name}`).toBeGreaterThanOrEqual(0.9);
});

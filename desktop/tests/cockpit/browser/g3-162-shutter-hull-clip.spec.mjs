// SPDX-License-Identifier: MIT
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';
import {mkdirSync} from 'node:fs';

// G3-162 (owner, internal build 2): while the shutter moved, the porthole showed half-retracted outside the hull.
// Samples the motion at several points (paused animation) and checks the canopy's visible bounds.
const OUT=process.env.SHUTTER_SHOTS;
async function mount(page){
 await page.setViewportSize({width:636,height:939});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance:{...appearance,reduceMotion:false},shell:{...shell,tier:'tall'}}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data:visualFixture().data}))).toBe(true);
 await page.waitForTimeout(100);
 return {send,receive};
}
const seek=(page,t)=>page.evaluate(t=>{const a=document.querySelector('.ck-portrow').getAnimations()[0];a.pause();a.currentTime=t;return new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r)));},t);
// G3-214 (owner, build 5): the shutter showed a plain rectangular box (top-left corner missing, flat top) while moving. The
// canopy row is sampled alone (everything else hidden) as real pixels: the alpha of each frame is compared with the open
// canopy's own silhouette, so the outline is the art's, whatever the art is (current or the grey hull).
const H=420;
async function alpha(page){
 await page.evaluate(()=>{document.querySelector('#cockpit').style.visibility='hidden';document.querySelector('.ck-portrow').style.visibility='visible';});
 const buf=await page.screenshot({omitBackground:true,clip:{x:0,y:0,width:636,height:H}});
 const out=await page.evaluate(async b64=>{const img=new Image();img.src='data:image/png;base64,'+b64;await img.decode();const c=document.createElement('canvas');c.width=img.width;c.height=img.height;const x=c.getContext('2d');x.drawImage(img,0,0);const d=x.getImageData(0,0,c.width,c.height).data;const a=new Array(c.width*c.height);for(let i=0;i<a.length;i++)a[i]=d[i*4+3];return {w:c.width,h:c.height,a};},buf.toString('base64'));
 await page.evaluate(()=>{document.querySelector('#cockpit').style.visibility='';document.querySelector('.ck-portrow').style.visibility='';});
 return out;
}
function bbox(f,min=128){let x0=1e9,x1=-1,y0=1e9,y1=-1;for(let y=0;y<f.h;y++)for(let x=0;x<f.w;x++)if(f.a[y*f.w+x]>=min){if(x<x0)x0=x;if(x>x1)x1=x;if(y<y0)y0=y;if(y>y1)y1=y;}return x1<0?null:{x0,x1,y0,y1};}
for(const dir of ['closing','opening'])
test(`G3-214 ${dir}: the canopy keeps its rounded outline at every point of the motion, nothing outside it`,async({page})=>{
 const {send,receive}=await mount(page);
 const open=await alpha(page);
 const ob=bbox(open);
 expect(ob,'the open canopy has pixels').not.toBeNull();
// The page removes the motion marker on a timer, so each frame is its own transition (sampled paused, then settled back).
 const go=async p=>{await receive(send('shell',{...shell,tier:'tall',profile:p}));};
 const settle=async p=>{await go(p);await page.evaluate(()=>{for(const a of document.querySelector('.ck-portrow').getAnimations())a.finish();});await page.waitForFunction(()=>!document.querySelector('#cockpit').dataset.shutterMotion,null,{timeout:5000});};
 const from=dir==='closing'?'open':'closed',to=dir==='closing'?'closed':'open';
 for(const t of [20,60,125,190]){
  await settle(from);await go(to);
  await seek(page,t);const f=await alpha(page);const b=bbox(f);
  let leak=0;for(let i=0;i<f.a.length;i++)if(f.a[i]>24&&open.a[i]<=2)leak++;
  expect(leak,`${dir} ${t} ms: no pixel outside the open canopy's silhouette`).toBe(0);
  if(!b)continue;
  expect(b.x0,`${dir} ${t} ms: left inside the hull`).toBeGreaterThanOrEqual(0);
  expect(b.x1,`${dir} ${t} ms: right inside the hull`).toBeLessThanOrEqual(635);
  // A rectangle has square shoulders: its first visible row is as wide as the rows below it. The canopy's own outline is
  // dome-shaped, so the visible part starts narrow and widens with every row under the cut.
  const ext=(g,y)=>{let l=-1,r=-1;for(let x=0;x<g.w;x++)if(g.a[y*g.w+x]>=128){if(l<0)l=x;r=x;}return l<0?null:{l,r};};
  const top=ext(f,b.y0+1),mid=ext(f,Math.min(b.y1,b.y0+60));
  if(b.y1-b.y0>90)expect(top.r-top.l,`${dir} ${t} ms: the first visible row (${top.r-top.l}px) is narrower than the row 60 px below (${mid.r-mid.l}px): rounded shoulders, not a box`).toBeLessThan(mid.r-mid.l-60);
 }
});

test('G3-162 shots',async({page})=>{
 test.skip(!OUT);
 mkdirSync(OUT,{recursive:true});
 const {send,receive}=await mount(page);
 await page.screenshot({path:`${OUT}/${process.env.SHUTTER_TAG}-open.png`,clip:{x:0,y:0,width:636,height:420}});
 await receive(send('shell',{...shell,tier:'tall',profile:'closed'}));
 for(const t of [60,125,190]){await seek(page,t);await page.screenshot({path:`${OUT}/${process.env.SHUTTER_TAG}-close-${t}ms.png`,clip:{x:0,y:0,width:636,height:420}});}
 await page.evaluate(()=>{for(const a of document.getAnimations())a.finish();});await page.waitForTimeout(300);
 await receive(send('shell',{...shell,tier:'tall',profile:'open'}));
 for(const t of [60,125,190]){await seek(page,t);await page.screenshot({path:`${OUT}/${process.env.SHUTTER_TAG}-open-${t}ms.png`,clip:{x:0,y:0,width:636,height:420}});}
});

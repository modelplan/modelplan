// SPDX-License-Identifier: MIT
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';
import {inflateSync} from 'node:zlib';

// Owner build 13 (hull A, collapsed gap, strip logo): the hull is narrow at the top and wide at the bottom, as the
// opus-r7 study composes it (canopy-h1 + canopy-c01 + strip-hull-unify). Below the c01 canopy the side walls are an
// upper wall 8 px in from the 636 px hull, a 31 px taper and the full-width lower wall, each the lower-skin tile cut
// by the study's own alpha masks; the canopy frame takes the study's solid outline. Boxes measured on the study in
// each shape, relative to the root.
const shapes=[
 {tier:'tall',closed:false,canvas:911,plate:890,upper:[216,270],cone:486,lower:338,phase:225},
 {tier:'compact',closed:false,canvas:661,plate:640,upper:[48,264],cone:312,lower:262,phase:57},
 {tier:'tall',closed:true,canvas:725,plate:890,upper:[30,270],cone:300,lower:338,phase:39},
 {tier:'compact',closed:true,canvas:643,plate:640,upper:[30,264],cone:294,lower:262,phase:39},
];
async function open(page,s){
 await page.setViewportSize({width:636,height:s.canvas});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance:{...appearance,reduceMotion:true},shell:{...shell,tier:s.tier,profile:s.closed?'closed':'open'}}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data:visualFixture().data}))).toBe(true);
 await page.waitForTimeout(200);
}
// Per-row extent of what the page paints (alpha >= 128), from a transparent screenshot (8-bit RGBA PNG).
async function silhouette(page,height){
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
  let l=-1,r=-1;for(let x=0;x<width;x++)if(row[x*4+3]>=128){if(l<0)l=x;r=x;}rows.push([l,r]);}
 return rows;
}
for(const s of shapes)test(`B13 ${s.tier}${s.closed?' closed':''}: study hull walls narrow above the taper, wide below`,async({page})=>{
 const bad=[];page.on('response',r=>{if(r.status()>=400)bad.push(new URL(r.url()).pathname);});
 await open(page,s);
 const v=await page.evaluate(()=>{const ck=document.querySelector('#cockpit').getBoundingClientRect();
  const name=u=>(u.match(/[^/"]+\.(png|svg)/g)??[]).join(',');
  const el=q=>{const e=document.querySelector('.ck-shell '+q),c=getComputedStyle(e),r=e.getBoundingClientRect();
   return {display:c.display,box:[r.left-ck.left,r.top-ck.top,r.width,r.height].map(Math.round),bg:name(c.backgroundImage),pos:c.backgroundPosition,mask:name(c.webkitMaskImage),size:c.webkitMaskSize,mpos:c.webkitMaskPosition};};
  const canopy=getComputedStyle(document.querySelector('.ck-portrow'),'::before');
  return {upper:el('.hull-upper'),cone:el('.hull-cone'),lower:el('.hull-lower'),record:getComputedStyle(document.querySelector('.ck-shell .hull-record')).display,
   canopyMask:name(canopy.webkitMaskImage),canopySize:canopy.webkitMaskSize,body:getComputedStyle(document.querySelector('.ck-shell'),'::before').clipPath};});
 const v2=s.closed?'closed':s.plate,lowerMask=s.closed?890:s.plate;
 expect(v.upper).toMatchObject({display:'block',box:[-8,s.upper[0],636,s.upper[1]],pos:'50% 9px',
  mask:`upper-walls-${v2}-1x.png,upper-skin-${v2}-1x.png`,size:`636px ${s.closed?283:s.plate===890?283:277}px, 636px 32px`});
 expect(v.cone).toMatchObject({display:'block',box:[-8,s.cone,636,31],pos:`50% ${s.phase-s.cone}px`,mask:'taper-890-1x.png',size:'636px 31px'});
 expect(v.lower).toMatchObject({display:'block',box:[-8,s.cone+31,636,s.lower],pos:`50% ${s.phase-s.cone-31}px`,
  mask:`lower-stage-${lowerMask}-1x.png,lower-skin-890-1x.png`,size:`636px ${s.closed?338:s.lower}px, 636px 32px`});
 for(const part of [v.upper,v.cone,v.lower])expect(part.bg).toBe('lower-skin-890-1x.png,lower-skin-890-2x.png');
 expect(v.record).toBe('none');
 // The c01 frame's raw lower sides run straight to the image edge; the study rounds them with its solid outline.
 if(!s.closed)expect([v.canopyMask,v.canopySize]).toEqual([`solid-outline-${s.plate}-1x.png`,`636px ${s.plate===890?216:48}px`]);
 expect(bad.filter(p=>/^\/(assets\/(hull\/|logo)|runtime\/canopy-c01\/)/.test(p))).toEqual([]);

 // Silhouette: the canopy frame and upper walls stand 8 px inside the 636 px lower body.
 const root=s.closed?(s.tier==='tall'?691:609):(s.tier==='tall'?877:627),top=s.closed?-14:0,rows=await silhouette(page,root+top);
 const at=y=>rows[y+top];
 if(!s.closed){
  const foot=s.plate===890?200:40;
  expect(at(foot)[0],'canopy frame foot, left').toBeGreaterThanOrEqual(8);
  expect(at(foot)[1],'canopy frame foot, right').toBeLessThanOrEqual(627);
 }
 for(const y of [s.upper[0]+30,s.cone-2])expect(at(y),`upper wall at ${y}`).toEqual([8,627]);
 for(const y of [s.cone+40,s.cone+31+s.lower-10])expect(at(y),`lower wall at ${y}`).toEqual([0,635]);
 const frame=at(s.closed?20:(s.plate===890?200:40)),body=at(s.cone+60);
 expect(frame[1]-frame[0],'porthole frame narrower than the lower body').toBeLessThan(body[1]-body[0]);
});

// Collapsed (owner build 13): the study's 16 px slab meets the 620 px upper walls, and the page draws it at the
// window's top edge: the study's 14 px band above the slab would only widen the gap under the menu bar.
for(const tier of ['tall','compact'])test(`B13 ${tier} closed: the slab is the window's top edge and lines up with the upper walls`,async({page})=>{
 await open(page,shapes.find(s=>s.tier===tier&&s.closed));
 const v=await page.evaluate(()=>{const ck=document.querySelector('#cockpit').getBoundingClientRect(),c=document.querySelector('.ck-shell .hull-crown').getBoundingClientRect(),w=document.querySelector('.ck-shell .hull-upper').getBoundingClientRect();
  return {ckTop:ck.top,slab:[c.left,c.top,c.width,c.height],slabInRoot:c.top-ck.top,walls:[w.left+8,w.width-16]};});
 expect(v).toEqual({ckTop:-14,slab:[8,0,620,16],slabInRoot:14,walls:[8,620]});
 const rows=await silhouette(page,40);
 expect(rows[10],'slab below its 8 px cuts').toEqual([8,627]);
 expect(rows[17],'wall under the slab').toEqual([8,627]);
});

// Strip logo (owner, repeatedly): the study's rocket mark beside the live "ModelPlan" wordmark, Plan in red.
test('B13 strip shows the study rocket mark and the live ModelPlan wordmark',async({page})=>{
 await open(page,shapes[0]);
 const v=await page.evaluate(()=>{const ck=document.querySelector('#cockpit').getBoundingClientRect(),m=document.querySelector('.ck-head .brand-mark'),w=document.querySelector('.ck-head .wordmark'),b=w.querySelector('b');
  const box=e=>{const r=e.getBoundingClientRect();return [r.left-ck.left,r.top-ck.top,r.width,r.height].map(Math.round);};
  const cw=getComputedStyle(w);
  return {mark:getComputedStyle(m).backgroundImage.match(/[^/"]+\.svg/)?.[0],markBox:box(m),text:w.textContent,font:cw.fontSize+' '+cw.fontWeight+' '+cw.lineHeight,transform:cw.textTransform,
   plan:getComputedStyle(b).color,planSize:getComputedStyle(b).fontSize,raster:[getComputedStyle(w,'::before').content,getComputedStyle(w,'::after').content],wordBox:box(w)};});
 expect(v).toEqual({mark:'logo.svg',markBox:[24,224,28,28],text:'ModelPlan',font:'14px 600 20px',transform:'none',plan:'rgb(223, 96, 76)',planSize:'14px',raster:['none','none'],wordBox:[60,228,112,20]});
});

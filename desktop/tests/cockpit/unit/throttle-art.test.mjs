// SPDX-License-Identifier: MIT
// CKP-FAD-24 / G3-92: the baked throttle art is centred on its slot, frame by frame, so every column's lever sits on the
// column centre; the plates have transparent surroundings (no panel tone baked around the slot).
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {inflateSync} from 'node:zlib';
const dir=new URL('../../../official-visuals/cockpit/throttle/assets/',import.meta.url);
// Minimal 8-bit RGBA PNG decoder (all five row filters) for the reserved throttle rasters.
function rgba(name){
 const buffer=readFileSync(new URL(name,dir));let offset=8,width=0,height=0;const data=[];
 while(offset<buffer.length){const size=buffer.readUInt32BE(offset),type=buffer.toString('latin1',offset+4,offset+8),body=buffer.subarray(offset+8,offset+8+size);
  if(type==='IHDR'){width=body.readUInt32BE(0);height=body.readUInt32BE(4);assert.equal(body[8],8);assert.equal(body[9],6,name+' must be RGBA');assert.equal(body[12],0);}
  if(type==='IDAT')data.push(body);offset+=size+12;}
 const raw=inflateSync(Buffer.concat(data)),stride=width*4,out=Buffer.alloc(stride*height);
 for(let y=0;y<height;y++){const filter=raw[y*(stride+1)],src=raw.subarray(y*(stride+1)+1,(y+1)*(stride+1)),row=y*stride;
  for(let x=0;x<stride;x++){const a=x>=4?out[row+x-4]:0,b=y?out[row-stride+x]:0,c=x>=4&&y?out[row-stride+x-4]:0;let v=src[x];
   if(filter===1)v+=a;else if(filter===2)v+=b;else if(filter===3)v+=(a+b)>>1;else if(filter===4){const p=a+b-c,pa=Math.abs(p-a),pb=Math.abs(p-b),pc=Math.abs(p-c);v+=pa<=pb&&pa<=pc?a:pb<=pc?b:c;}
   out[row+x]=v&255;}}
 return {width,height,alpha:(x,y)=>out[(y*width+x)*4+3]};
}
// Horizontal centre (px) of the opaque pixels in rows y0..y1; the soft shadow never reaches alpha 240.
function opaqueCentre(img,y0,y1){let lo=Infinity,hi=-Infinity;for(let y=y0;y<y1;y++)for(let x=0;x<img.width;x++)if(img.alpha(x,y)>240){lo=Math.min(lo,x);hi=Math.max(hi,x);}return (lo+hi+1)/2;}

for(const theme of ['night','day']){
 test(`G3-92 ${theme} lever frames keep the lever on the slot centre at every frame`,()=>{
  const sheet=rgba(`lever-${theme}.png`),frame=268;
  assert.equal(sheet.width,128);assert.equal(sheet.height,33*frame);
  for(let i=0;i<33;i++)assert.ok(Math.abs(opaqueCentre(sheet,i*frame,(i+1)*frame)-64)<=1,`frame ${i}`);
 });
 test(`CKP-FAD-24 ${theme} plate is centred and has transparent surroundings`,()=>{
  const plate=rgba(`plate-${theme}.png`);
  assert.deepEqual([plate.width,plate.height],[76,268]);
  assert.ok(Math.abs(opaqueCentre(plate,40,230)-38)<=.5);
  // the corners and the panel beside the slot (between tick rows) are fully transparent
  for(const [x,y] of [[0,0],[75,0],[0,267],[75,267],[4,140],[71,140],[4,60],[71,200]])assert.equal(plate.alpha(x,y),0,`${x},${y}`);
 });
 test(`CKP-FAD-17 ${theme} ghost grip is translucent`,()=>{
  const ghost=rgba(`ghost-${theme}.png`);let max=0,sum=0,n=0;
  for(let y=0;y<ghost.height;y++)for(let x=0;x<ghost.width;x++){const a=ghost.alpha(x,y);max=Math.max(max,a);if(a>0){sum+=a;n++;}}
  assert.ok(max<255,'never opaque');assert.ok(sum/n>(theme==='day'?120:60),'visible at 1x');
 });
}

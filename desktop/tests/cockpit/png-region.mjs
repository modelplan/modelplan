// SPDX-License-Identifier: MIT
// Test-only PNG decoder (8-bit RGB/RGBA, non-interlaced, all five filters) for region statistics of screenshots.
import {inflateSync} from 'node:zlib';
export function decode(buffer) {
 let offset=8,width=0,height=0,type=0;const data=[];
 while(offset<buffer.length){const size=buffer.readUInt32BE(offset),name=buffer.toString('latin1',offset+4,offset+8),body=buffer.subarray(offset+8,offset+8+size);
  if(name==='IHDR'){width=body.readUInt32BE(0);height=body.readUInt32BE(4);type=body[9];}if(name==='IDAT')data.push(body);offset+=size+12;}
 const bpp=type===6?4:3,raw=inflateSync(Buffer.concat(data)),stride=width*bpp,out=Buffer.alloc(height*stride);
 for(let y=0;y<height;y++){const f=raw[y*(stride+1)],line=raw.subarray(y*(stride+1)+1,(y+1)*(stride+1));
  for(let x=0;x<stride;x++){const a=x>=bpp?out[y*stride+x-bpp]:0,b=y?out[(y-1)*stride+x]:0,c=x>=bpp&&y?out[(y-1)*stride+x-bpp]:0;
   let v=line[x];if(f===1)v+=a;else if(f===2)v+=b;else if(f===3)v+=(a+b)>>1;else if(f===4){const p=a+b-c,pa=Math.abs(p-a),pb=Math.abs(p-b),pc=Math.abs(p-c);v+=pa<=pb&&pa<=pc?a:pb<=pc?b:c;}
   out[y*stride+x]=v&255;}}
 return {width,height,pixel:(x,y)=>{const i=y*stride+x*bpp;return [out[i],out[i+1],out[i+2],bpp===4?out[i+3]:255];}};
}
// Mean and standard deviation of luminance over opaque pixels (alpha >= 200).
export function luminance(png) {
 const values=[];for(let y=0;y<png.height;y++)for(let x=0;x<png.width;x++){const [r,g,b,a]=png.pixel(x,y);if(a>=200)values.push(0.2126*r+0.7152*g+0.0722*b);}
 const mean=values.reduce((s,v)=>s+v,0)/Math.max(1,values.length),sd=Math.sqrt(values.reduce((s,v)=>s+(v-mean)**2,0)/Math.max(1,values.length));
 return {mean,sd,count:values.length};
}
// Mean colour, mean luminance and luminance percentiles over opaque pixels (alpha >= 200).
export function stats(png) {
 const l=[],sum=[0,0,0];for(let y=0;y<png.height;y++)for(let x=0;x<png.width;x++){const [r,g,b,a]=png.pixel(x,y);if(a>=200){sum[0]+=r;sum[1]+=g;sum[2]+=b;l.push(0.2126*r+0.7152*g+0.0722*b);}}
 l.sort((a,b)=>a-b);const n=Math.max(1,l.length),pct=q=>l[Math.min(l.length-1,Math.floor(q*(l.length-1)))]??0;
 return {rgb:sum.map(v=>v/n),mean:l.reduce((s,v)=>s+v,0)/n,p50:pct(0.5),p97:pct(0.97),count:l.length};
}

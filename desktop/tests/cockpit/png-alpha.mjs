// SPDX-License-Identifier: MIT
// Hairline-gap scan for a transparent window capture (8-bit RGBA PNG): used by the browser spec on its own screenshot
// and by the walkthrough's window evidence (verification/walkthrough/silhouette_gaps.py is the same rule in Python).
import {inflateSync} from 'node:zlib';
export function decodeRgba(buffer){
 let offset=8,width=0,height=0;const data=[];
 while(offset<buffer.length){const size=buffer.readUInt32BE(offset),name=buffer.toString('latin1',offset+4,offset+8),body=buffer.subarray(offset+8,offset+8+size);
  if(name==='IHDR'){width=body.readUInt32BE(0);height=body.readUInt32BE(4);if(body[8]!==8||body[9]!==6)throw new Error('expected 8-bit RGBA');}
  if(name==='IDAT')data.push(body);offset+=size+12;}
 const raw=inflateSync(Buffer.concat(data)),stride=width*4,out=Buffer.alloc(stride*height),rows=[];
 for(let y=0;y<height;y++){const f=raw[y*(stride+1)],src=raw.subarray(y*(stride+1)+1,(y+1)*(stride+1)),row=out.subarray(y*stride,(y+1)*stride),up=y?out.subarray((y-1)*stride,y*stride):Buffer.alloc(stride);
  for(let i=0;i<stride;i++){const a=i>=4?row[i-4]:0,b=up[i],c=i>=4?up[i-4]:0;let p=src[i];
   if(f===1)p+=a;else if(f===2)p+=b;else if(f===3)p+=(a+b)>>1;else if(f===4){const q=a+b-c,pa=Math.abs(q-a),pb=Math.abs(q-b),pc=Math.abs(q-c);p+=pa<=pb&&pa<=pc?a:pb<=pc?b:c;}
   row[i]=p&255;}
  rows.push(row);}
 return {width,height,rows};
}
// The silhouette starts at `firstRow` or the first row at least `solid` (default 50 %) fully opaque across the window's painted width and
// ends at `lastRow` (default: the last such row). Inside it, a row whose central columns (the middle `core`, default
// 60 %, which skips the rounded shoulders) are less than fully opaque for `share` (default 20 %) of that width is a
// gap. Returns the failing rows as {y, share}.
export function interiorGaps({width,height,rows},{firstRow,lastRow,share=.2,core=.6,solid=.5}={}){
 let left=width,right=-1;
 for(const row of rows)for(let x=0;x<width;x++)if(row[x*4+3]>=128){left=Math.min(left,x);right=Math.max(right,x);}
 if(right<0)return [{y:0,share:1}];
 const x0=Math.ceil(left+(right-left+1)*(1-core)/2),x1=Math.floor(right-(right-left+1)*(1-core)/2);
 const frac=(row,pred)=>{let n=0;for(let x=x0;x<=x1;x++)if(pred(row[x*4+3]))n++;return n/(x1-x0+1);};
 // The rim's own anti-aliased first row is not a gap: the scan starts at the first fully opaque row.
 let top=firstRow??rows.findIndex(row=>frac(row,a=>a===255)>=solid);
 if(top<0)return [{y:0,share:1}];
 let bottom=lastRow??rows.map(row=>frac(row,a=>a===255)>=solid).lastIndexOf(true);
 const gaps=[];
 for(let y=top;y<=bottom;y++){const s=frac(rows[y],a=>a<255);if(s>=share)gaps.push({y,share:s});}
 return gaps;
}

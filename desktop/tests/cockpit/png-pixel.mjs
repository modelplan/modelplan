// SPDX-License-Identifier: MIT
// Test-only decoder for the 1x1 screenshots of the colour contract: returns [r,g,b,a] of the first pixel.
import {inflateSync} from 'node:zlib';
export function firstPixel(buffer) {
 let offset=8,type=0;const data=[];
 while(offset<buffer.length){const size=buffer.readUInt32BE(offset),name=buffer.toString('latin1',offset+4,offset+8),body=buffer.subarray(offset+8,offset+8+size);
  if(name==='IHDR')type=body[9];if(name==='IDAT')data.push(body);offset+=size+12;}
 const channels=type===6?4:3,row=inflateSync(Buffer.concat(data));
 if(row[0]!==0&&row[0]!==1&&row[0]!==2)throw new Error('unsupported PNG filter');
 return [...row.subarray(1,1+channels),...(channels===3?[255]:[])];
}

// Test-only full decoder (8-bit RGB/RGBA, all PNG filters): returns {width,height,channels,data}.
export function decodePng(buffer) {
 let offset=8,width=0,height=0,type=0;const data=[];
 while(offset<buffer.length){const size=buffer.readUInt32BE(offset),name=buffer.toString('latin1',offset+4,offset+8),body=buffer.subarray(offset+8,offset+8+size);
  if(name==='IHDR'){width=body.readUInt32BE(0);height=body.readUInt32BE(4);type=body[9];if(body[8]!==8||body[12]!==0)throw new Error('unsupported PNG');}
  if(name==='IDAT')data.push(body);offset+=size+12;}
 const channels=type===6?4:3,raw=inflateSync(Buffer.concat(data)),stride=width*channels,out=Buffer.alloc(stride*height);
 for(let y=0;y<height;y++){const f=raw[y*(stride+1)],src=raw.subarray(y*(stride+1)+1,(y+1)*(stride+1));
  for(let x=0;x<stride;x++){const a=x>=channels?out[y*stride+x-channels]:0,b=y?out[(y-1)*stride+x]:0,c=x>=channels&&y?out[(y-1)*stride+x-channels]:0;
   const p=a+b-c,pa=Math.abs(p-a),pb=Math.abs(p-b),pc=Math.abs(p-c);
   out[y*stride+x]=(src[x]+(f===0?0:f===1?a:f===2?b:f===3?(a+b>>1):(pa<=pb&&pa<=pc?a:pb<=pc?b:c)))&255;}}
 return {width,height,channels,data:out};
}

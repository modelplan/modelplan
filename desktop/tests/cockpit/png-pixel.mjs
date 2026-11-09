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

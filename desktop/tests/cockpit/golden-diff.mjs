// SPDX-License-Identifier: MIT
// Compare the batch-017 cockpit crops. Paths are caller-supplied; this check
// does not fetch or create the separately maintained study or its fixtures.
import {readFile,writeFile} from 'node:fs/promises';
import {join} from 'node:path';
import {chromium} from '../../cockpit/node_modules/playwright/index.mjs';
const [referenceDir,candidateDir,outputPath]=process.argv.slice(2);
if(!referenceDir||!candidateDir||!outputPath){
 console.error('Usage: node desktop/tests/cockpit/golden-diff.mjs <reference-dir> <candidate-dir> <output.json>');process.exit(2);
}
const scenarios=[];
for(const height of [956,760])for(const locale of ['zh','en'])for(const profile of ['open','closed'])
 scenarios.push(`night-${height}-${locale}-${profile}-attached`);
const browser=await chromium.launch({headless:true});
try {
 const page=await browser.newPage();const results=[];
 for(const id of scenarios){
  const reference=(await readFile(join(referenceDir,`${id}-prototype.png`))).toString('base64');
  const candidate=(await readFile(join(candidateDir,`${id}-implementation.png`))).toString('base64');
  const result=await page.evaluate(async({reference,candidate})=>{
   const decode=async data=>{const image=new Image();image.src=`data:image/png;base64,${data}`;await image.decode();const canvas=document.createElement('canvas');canvas.width=image.width;canvas.height=image.height;const ctx=canvas.getContext('2d');ctx.drawImage(image,0,0);return {width:image.width,height:image.height,data:ctx.getImageData(0,0,image.width,image.height).data};};
   const a=await decode(reference),b=await decode(candidate),width=Math.max(a.width,b.width),height=Math.max(a.height,b.height);let changed=0;
   for(let y=0;y<height;y++)for(let x=0;x<width;x++){
    const ai=x<a.width&&y<a.height?(y*a.width+x)*4:-1,bi=x<b.width&&y<b.height?(y*b.width+x)*4:-1;let delta=0;
    for(let c=0;c<4;c++)delta=Math.max(delta,Math.abs((ai<0?0:a.data[ai+c])-(bi<0?0:b.data[bi+c])));
    if(delta>8)changed++;
   }
   return {width,height,changedPixels:changed,totalPixels:width*height,threshold:8};
  },{reference,candidate});results.push({scenario:id,...result});
 }
 await writeFile(outputPath,JSON.stringify({alignment:'cockpit top-left; missing pixels transparent',results},null,2)+'\n');
 if(results.some(r=>r.changedPixels>0)){console.error('Golden images differ; see '+outputPath);process.exitCode=1;}
 else console.log('All cockpit golden images match.');
} finally {await browser.close();}

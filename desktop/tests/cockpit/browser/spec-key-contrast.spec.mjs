// SPDX-License-Identifier: MIT
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,currentSample,pageId,shell} from '../fixture.mjs';

test('THM-10-02 active subscription key text reaches 4.5 contrast in both themes',async({page})=>{
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 for(const raw of [send('load',{appearance,shell}),send('visibility',{visible:true,occluded:false,key:true}),send('display',{data:currentSample()})])expect(await receive(raw)).toBe(true);
 const key=page.locator('.eng-keys .ek[data-sub]').first();await expect(key).toBeVisible();const box=await key.boundingBox();expect(box).not.toBeNull();await page.mouse.click(box.x+box.width/2,box.y+box.height/2);await expect(key).toHaveAttribute('aria-pressed','true');
 for(const theme of ['night','day']){
  expect(await receive(send('appearance',{...appearance,theme}))).toBe(true);
  const area=await key.boundingBox();expect(area).not.toBeNull();const png=await page.screenshot({clip:area,animations:'disabled'});
  const result=await page.evaluate(async bytes=>{const e=document.querySelector('.eng-keys .ek[data-sub] .ek-name'),fg=getComputedStyle(e).color.match(/[\d.]+/g).slice(0,3).map(Number);const img=await createImageBitmap(new Blob([new Uint8Array(bytes)],{type:'image/png'}));const c=document.createElement('canvas');c.width=img.width;c.height=img.height;const ctx=c.getContext('2d');ctx.drawImage(img,0,0);const p=ctx.getImageData(0,0,img.width,img.height).data,channels=[[],[],[]];for(let i=0;i<p.length;i+=4)for(let j=0;j<3;j++)channels[j].push(p[i+j]);const bg=channels.map(x=>x.sort((a,b)=>a-b)[Math.floor(x.length/2)]);const lum=rgb=>rgb.map(x=>{x/=255;return x<=.04045?x/12.92:((x+.055)/1.055)**2.4;}).reduce((s,x,i)=>s+x*[.2126,.7152,.0722][i],0);const [a,b]=[lum(fg),lum(bg)].sort((x,y)=>y-x);return {fg,bg,ratio:(a+.05)/(b+.05)};},[...png]);
  expect(result.ratio,`${theme} fg=${result.fg} bg=${result.bg}`).toBeGreaterThanOrEqual(4.5);
 }
});

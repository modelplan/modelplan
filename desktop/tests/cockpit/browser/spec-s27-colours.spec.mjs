// SPDX-License-Identifier: MIT
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,currentSample,pageId,shell} from '../fixture.mjs';

async function open(page){
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 for(const raw of [send('load',{appearance,shell,redBelow:25}),send('visibility',{visible:true,occluded:false,key:true}),send('display',{data:currentSample()})])expect(await receive(raw)).toBe(true);
 const colours=()=>page.evaluate(()=>{const s=getComputedStyle(document.documentElement);return Object.fromEntries(['--metal-1','--metal-2','--metal-3','--gold-metal','--fire-metal'].map(k=>[k,s.getPropertyValue(k).trim().toLowerCase()]));});
 return {send,receive,colours};
}
test('C-27 night page metal, gold and fire tokens',async({page})=>{
 const {colours}=await open(page);expect(await colours()).toEqual({'--metal-1':'#202124','--metal-2':'#1c1d1f','--metal-3':'#141517','--gold-metal':'#d4b994','--fire-metal':'#df604c'});
});
test('C-27 day page metal endpoints await accepted-baseline disposition',async({page})=>{
 test.fixme(true,'C-27 day spec conflicts with the accepted opus-r7 metal palette; owner disposition requested');
 const {send,receive,colours}=await open(page);expect(await receive(send('appearance',{...appearance,theme:'day'}))).toBe(true);
 const day=await colours();expect(day['--gold-metal']).toBe('#90704d');expect(day['--fire-metal']).toBe('#bb342c');expect(day['--metal-1']).toBe('#e9eaec');expect(day['--metal-3']).toBe('#d7d9dc');
});

test('C-27 active engine-key text contrasts against both resolved pressed-metal endpoints',async({page})=>{
 const {send,receive}=await open(page);
 for(const theme of ['night','day']){
  expect(await receive(send('appearance',{...appearance,theme}))).toBe(true);
  for(const selector of ['.ek-all.on span','.eng-keys .ek[data-sub].on .ek-name']){
  if(selector.includes('data-sub'))await page.locator('.eng-keys .ek[data-sub]').first().click();
  const key=page.locator(selector).first();await expect(key).toBeVisible();
  const values=await key.evaluate(e=>{const root=getComputedStyle(document.documentElement),probe=document.createElement('span');document.body.append(probe);const resolve=value=>{probe.style.color=value;return getComputedStyle(probe).color;};const result={ink:getComputedStyle(e).color,backgrounds:['--key-p1','--key-p2'].map(k=>resolve(root.getPropertyValue(k).trim()))};probe.remove();return result;});
  const rgb=s=>s.match(/\d+(?:\.\d+)?/g).slice(0,3).map(Number),lum=s=>{const c=rgb(s).map(n=>n/255).map(n=>n<=0.04045?n/12.92:((n+0.055)/1.055)**2.4);return .2126*c[0]+.7152*c[1]+.0722*c[2];};
  for(const bg of values.backgrounds){const a=lum(values.ink),b=lum(bg);expect((Math.max(a,b)+.05)/(Math.min(a,b)+.05)).toBeGreaterThanOrEqual(4.5);}
  }
  await page.locator('.ek-all').click();
 }
});

test('C-27 current quota bars contrast with the resolved LCD gradient in both themes',async({page})=>{
 const {send,receive}=await open(page),data=currentSample();data.projection.rows=data.projection.rows.slice(0,1);data.subscriptions=[];
 const w=data.projection.rows[0].accounts[0].windows[0];
 for(const theme of ['night','day']){
  expect(await receive(send('appearance',{...appearance,theme}))).toBe(true);
  for(const [remaining,level] of [[75,'ok'],[35,'mid'],[10,'low']]){
   w.remainingPercent=remaining;expect(await receive(send('display',{data}))).toBe(true);
   const cell=page.locator(`.eng-cols .qcell.lv-${level}`).first(),segment=cell.locator('.qbar i.on').first();await expect(segment).toBeVisible();
   const values=await segment.evaluate(e=>({foreground:getComputedStyle(e).backgroundColor,gradient:getComputedStyle(e.closest('.eng-lcd')).backgroundImage}));
   const colors=values.gradient.match(/rgba?\([^)]*\)/g);expect(colors?.length).toBeGreaterThanOrEqual(2);
   const rgb=s=>s.match(/\d+(?:\.\d+)?/g).slice(0,3).map(Number),lum=s=>{const c=rgb(s).map(n=>n/255).map(n=>n<=0.04045?n/12.92:((n+0.055)/1.055)**2.4);return .2126*c[0]+.7152*c[1]+.0722*c[2];};
   for(const bg of colors){const a=lum(values.foreground),b=lum(bg);expect((Math.max(a,b)+.05)/(Math.min(a,b)+.05)).toBeGreaterThanOrEqual(3);}
  }
 }
});

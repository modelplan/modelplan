// SPDX-License-Identifier: MIT
// CKP-MFD-24 on the built page through its normal bridge: a real press on an MFD website link asks native for one
// typed public page. The page never navigates and never sends a URL. The posted bridge message is the read-only seam.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';

async function open(page,locale='en') {
 await page.addInitScript(()=>{window.sent=[];window.webkit={messageHandlers:{cockpit:{postMessage(raw){window.sent.push(JSON.parse(raw));}}}};});
 await page.clock.setFixedTime(new Date('2026-11-04T12:00:00Z'));
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const fx=visualFixture();fx.data.projection.rows[0].vendorKey='openai';
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance:{...appearance,locale},shell,redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data:fx.data}))).toBe(true);
 return {fx,send,receive};
}
const member=index=>(index+1).toString(16).padStart(16,'0');
const links=page=>page.evaluate(()=>window.sent.filter(m=>m.type==='action'&&m.action==='openWebsite').map(({page,value})=>({page,value})));

test('CKP-MFD-24 a scoped subscription links its plans page in the reader\'s language',async({page})=>{
 const {send,receive}=await open(page);
 expect(await receive(send('shell',{...shell,scope:member(0)}))).toBe(true);
 await page.getByRole('button',{name:'Subscription',exact:true}).click();
 const link=page.locator('.sp-h a.website-link');
 await expect(link).toHaveText('Plan details ↗');
 await expect(link).toHaveAttribute('href','https://modelplan.ai/plans?seller=openai');
 const url=page.url();await link.click();
 expect(await links(page)).toEqual([{page:'plans',value:'openai'}]);
 expect(page.url()).toBe(url);
 await link.evaluate(e=>e.click());
 expect(await links(page),'a scripted click asks for nothing').toHaveLength(1);
 const style=await link.evaluate(e=>{const s=getComputedStyle(e);return {size:parseFloat(s.fontSize),line:s.textDecorationLine,animation:s.animationName};});
 expect(style).toEqual({size:10,line:'none',animation:'none'});
});

test('CKP-MFD-24 the plans link is Chinese in Chinese and absent for an unknown maker',async({page})=>{
 const {send,receive}=await open(page,'zh-CN');
 expect(await receive(send('shell',{...shell,scope:member(0)}))).toBe(true);
 await page.getByRole('button',{name:'订阅',exact:true}).click();
 await expect(page.locator('.sp-h a.website-link')).toHaveText('套餐详情 ↗');
 expect(await receive(send('shell',{...shell,scope:member(1)}))).toBe(true);
 await expect(page.locator('.sp-h b')).toBeVisible();
 await expect(page.locator('.sp-h a.website-link')).toHaveCount(0);
});

// The Effort page itself needs publication data; this presses the exact links its render emits.
test('CKP-MFD-24 the recommendation links reach native as typed pages',async({page})=>{
 await open(page);
 await page.evaluate(async()=>{const {secondaryLink,methodologyUrl,modelUrl,websiteWords}=await import('/study/rocket-r1/mfd-pages/public-helpers.js');
  const words=websiteWords('en'),host=document.createElement('span');host.className='tune-links';
  host.innerHTML=secondaryLink(methodologyUrl('effort-ladder'),words.how)+secondaryLink(modelUrl('gpt-6.1-sol'),words.compare)+'<a class="website-link" href="https://example.com/plans?seller=x">x</a>';
  document.querySelector('.mfd-screen').append(host);});
 const anchors=page.locator('.tune-links a.website-link');
 await expect(anchors.first()).toHaveText('How it’s worked out ↗');
 for(const index of [0,1,2])await anchors.nth(index).click();
 expect(await links(page)).toEqual([{page:'methodology',value:'effort-ladder'},{page:'effort',value:'gpt-6.1-sol'}]);
});

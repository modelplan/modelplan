// SPDX-License-Identifier: MIT
// CKP-SHELL-39 on the built page through its normal bridge: with no subscription read yet the engine screen says so in
// one line and offers one button into Settings > Subscriptions. A real press posts the one typed bridge action.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';

async function open(page,{locale='en',theme='night',empty=true}={}) {
 await page.addInitScript(()=>{window.sent=[];window.webkit={messageHandlers:{cockpit:{postMessage(raw){window.sent.push(JSON.parse(raw));}}}};});
 await page.clock.setFixedTime(new Date('2026-11-04T12:00:00Z'));
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const data=visualFixture().data;if(empty){data.projection.rows=[];data.subscriptions=[];data.details=null;}
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance:{...appearance,locale,theme},shell,redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data}))).toBe(true);
 return {send,receive,data};
}
const posted=page=>page.evaluate(()=>window.sent.filter(m=>m.type==='action').map(m=>m.action));
const COPY={
 en:{line:'No quota read yet. Sign in to a coding tool and it appears here.',button:'Open Settings › Subscriptions'},
 'zh-CN':{line:'还没读到订阅额度。登录一个编程工具后，这里会自动显示。',button:'打开 设置 › 订阅'},
};

for(const locale of ['en','zh-CN']) for(const theme of ['night','day']) {
 test(`CKP-SHELL-39 the empty engine screen is one line and one Settings button (${locale}, ${theme})`,async({page})=>{
  await open(page,{locale,theme});
  await expect(page.locator('.ck-eng .ec-empty')).toHaveCount(1);
  await expect(page.locator('.ck-eng .ec-empty')).toHaveText(COPY[locale].line);
  const button=page.locator('.ck-eng button.ec-empty-open');
  await expect(button).toHaveCount(1);await expect(button).toHaveText(COPY[locale].button);
  const [line,box]=await Promise.all([page.locator('.ck-eng .ec-empty').boundingBox(),button.boundingBox()]);
  expect(box.y,'the button sits under the line').toBeGreaterThan(line.y+line.height-1);
  expect(Math.abs((box.x+box.width/2)-(line.x+line.width/2)),'both are centred on the screen').toBeLessThan(2);
  const lamp=await page.locator('.s6-alert').getAttribute('aria-label');
  expect(lamp,'the lamp copy is not part of this change').toBe(locale==='en'?'Alert inactive':'告警未激活');
 });
}

test('CKP-SHELL-39 a real press asks native for Settings > Subscriptions, a scripted click asks for nothing',async({page})=>{
 await open(page);
 const button=page.locator('.ck-eng button.ec-empty-open');
 await button.evaluate(e=>e.click());
 expect(await posted(page),'a scripted click asks for nothing').not.toContain('openSettingsSubscriptions');
 await button.click();
 expect((await posted(page)).filter(a=>a==='openSettingsSubscriptions')).toHaveLength(1);
 expect(await posted(page),'the plain Settings key keeps its own action').not.toContain('openSettings');
});

test('CKP-SHELL-39 the button follows a language change and goes away once a subscription is read',async({page})=>{
 const {send,receive}=await open(page);
 expect(await receive(send('appearance',{...appearance,locale:'zh-CN'}))).toBe(true);
 await expect(page.locator('.ck-eng button.ec-empty-open')).toHaveText(COPY['zh-CN'].button);
 const full=visualFixture().data;
 expect(await receive(send('display',{data:full}))).toBe(true);
 await expect(page.locator('.ck-eng button.ec-empty-open')).toHaveCount(0);
 await expect(page.locator('.ck-eng .ec-empty')).toHaveCount(0);
});

// SPDX-License-Identifier: MIT
// Page-side journeys use synthetic data through the production bridge.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';

async function open(page){
 await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};});
 await page.clock.setFixedTime(new Date('2026-11-04T12:00:00Z'));
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance,shell,redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data:visualFixture().data}))).toBe(true);
 return {send,receive};
}

test('CKP-ENTRY-03 usage opens first without a publication-backed comparison',async({page})=>{
 const {send,receive}=await open(page);
 await expect(page.getByRole('button',{name:'Overview',exact:true})).toHaveAttribute('aria-pressed','true');
 await expect(page.locator('.pg-overview')).toBeVisible();
 await expect(page.locator('.mfd-compare,[data-comparison]')).toHaveCount(0);
 await expect(page.locator('.fd-strip:not(:disabled)')).toHaveCount(0);
 for(const tier of ['compact','tall']){expect(await receive(send('shell',{...shell,tier}))).toBe(true);await expect(page.locator('.pg-overview')).toBeVisible();await expect(page.locator('.mfd-compare,[data-comparison]')).toHaveCount(0);}
 await page.getByRole('button',{name:'Subscription',exact:true}).click();await expect(page.locator('.pg-sub')).toBeVisible();
 expect(await receive(send('clear',{generation:'42',viewRevision:'4'}))).toBe(true);
 await expect(page.locator('.mfd-compare,[data-comparison]')).toHaveCount(0);
});

test('CKP-MFD-02 page keys show and illuminate the selected page in both languages',async({page})=>{
 const {send,receive}=await open(page),buttons=page.locator('.mfd-pk .pk');await expect(buttons).toHaveCount(4);
 for(const [locale,labels] of [['en',['Overview','Subscription','Effort','Breakdown']],['zh-CN',['总览','订阅','档位','去向']]]){
  expect(await receive(send('appearance',{...appearance,locale}))).toBe(true);
  for(const [i,label] of labels.entries()){
   const key=buttons.nth(i);await expect(key).toHaveAttribute('aria-label',label);await key.click();
   await expect(key).toHaveAttribute('aria-pressed','true');await expect(key).toHaveClass(/\bon\b/);
   const active=await key.locator('.pk-led').evaluate(e=>getComputedStyle(e).backgroundColor);
   for(let j=0;j<4;j++)if(i!==j){await expect(buttons.nth(j)).toHaveAttribute('aria-pressed','false');expect(await buttons.nth(j).locator('.pk-led').evaluate(e=>getComputedStyle(e).backgroundColor)).not.toBe(active);}
   expect(await receive(send('display',{data:visualFixture().data}))).toBe(true);await expect(key).toHaveAttribute('aria-pressed','true');
  }
 }
});

test('CKP-STRIP-07 Option help changes the detach caption without moving the other labels',async({page})=>{
 const {send,receive}=await open(page),map=page.locator('#help-map'),detach=page.locator('[data-detach]');
 await expect(page.locator('[data-help],button[aria-label="Help"]')).toHaveCount(0);const before=await detach.boundingBox();
 await page.keyboard.down('Alt');await expect(map).toBeVisible();await expect(map.locator('[data-target="[data-detach]"]')).toContainText('Detach');
 const labels=()=>map.locator('.an:not([data-target="[data-detach]"])').evaluateAll(nodes=>nodes.map(n=>({target:n.dataset.target,x:n.getBoundingClientRect().x,y:n.getBoundingClientRect().y})));
 const positions=await labels();expect(await detach.boundingBox()).toEqual(before);await page.keyboard.up('Alt');await expect(map).toBeHidden();
 expect(await receive(send('shell',{...shell,attached:false}))).toBe(true);
 await page.keyboard.down('Alt');await expect(map.locator('[data-target="[data-detach]"]')).toContainText('Put back');expect(await labels()).toEqual(positions);
 await page.keyboard.up('Alt');await expect(map).toBeHidden();
 expect(await receive(send('appearance',{...appearance,locale:'zh-CN'}))).toBe(true);await page.keyboard.down('Alt');await expect(map).toHaveAttribute('aria-label','驾驶舱说明');await expect(map.locator('[data-target="[data-detach]"]')).toContainText('放回');await page.keyboard.up('Alt');await expect(map).toBeHidden();
});

test('CKP-MOT-05 day metal lightens while both LCDs stay dark',async({page})=>{
 const {send,receive}=await open(page),read=()=>page.evaluate(()=>{const get=q=>getComputedStyle(document.querySelector(q)).backgroundImage;return {hull:get('.ck-shell'),key:get('.ek-all'),engine:get('.eng-lcd'),screen:get('.mfd-screen')};});
 const night=await read();expect(await receive(send('appearance',{...appearance,theme:'day'}))).toBe(true);const day=await read();
 await expect(page.locator('.ck-port')).toBeVisible();await expect(page.locator('.dk-fad')).toBeVisible();
 const components=s=>[...s.matchAll(/rgb\((\d+),\s*(\d+),\s*(\d+)\)/g)].map(m=>m.slice(1).map(Number));
 const mean=s=>components(s).flat().reduce((a,b)=>a+b,0)/Math.max(1,components(s).flat().length);
 expect(mean(day.hull)).toBeGreaterThan(mean(night.hull));expect(mean(day.key)).toBeGreaterThan(mean(night.key));
 for(const lcd of [day.engine,day.screen]){expect(components(lcd).length).toBeGreaterThan(0);expect(Math.max(...components(lcd).flat())).toBeLessThan(32);}
});

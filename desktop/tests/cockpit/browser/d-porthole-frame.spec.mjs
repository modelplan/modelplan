// SPDX-License-Identifier: MIT
// Porthole frame (coordinator 11-08, visual gate L1.zone.porthole-corners): as in the opus-r7 study, the sky fills the
// whole c01 canopy window, not just the port row. The study's port is the canopy box (636 x 216 tall, 636 x 48 short,
// 24 px past the port row on each side and 12 px above it), masked by the c01 window, and the porthole stills are
// authored at exactly that size. The study's task 88 gunmetal transfer, saturate(.12) brightness(.78), tints the
// canopy frame and its glass pane.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,sample,shell} from '../fixture.mjs';
// The study's root heights (877 tall, 627 short), where its port row is 204 / 36 px.
for(const theme of ['night','day'])for(const [tier,height,plate] of [['tall',216,890],['compact',48,640]])
test(`porthole sky fills the canopy window: ${theme} ${tier}`,async({page})=>{
  await page.setViewportSize({width:636,height:tier==='tall'?877:627});
  await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
  const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
  expect(await receive(send('load',{appearance:{...appearance,theme},shell:{...shell,tier}}))).toBe(true);
  expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
  expect(await receive(send('display',{data:sample()}))).toBe(true);
  await expect(page.locator('.ck-field')).toHaveAttribute('data-still','ready');
  const v=await page.evaluate(()=>{
    const r=s=>document.querySelector(s).getBoundingClientRect(),row=r('.ck-portrow'),f=r('.ck-field'),field=document.querySelector('.ck-field');
    const stage=field.querySelector('.ck-still-stage'),q=getComputedStyle(field),pseudo=(s,p)=>getComputedStyle(document.querySelector(s),p);
    return {dx:Math.round(f.left-row.left),dy:Math.round(f.top-row.top),w:Math.round(f.width),h:Math.round(f.height),rowW:Math.round(row.width),rowH:Math.round(row.height),
      transform:stage.style.transform,mask:q.webkitMaskImage||q.maskImage,
      canopy:pseudo('.ck-portrow','::before').filter,pane:pseudo('.ck-port','::before').filter};
  });
  expect(v).toMatchObject({dx:-24,dy:-12,w:v.rowW+48,h:v.rowH+12});
  expect([v.w,v.h]).toEqual([636,height]);
  // The still is painted 1:1: its 636-wide frame is not rescaled into a smaller box.
  expect(v.transform).toMatch(/^translate\(0px(, 0px)?\) scale\(1\)$/);
  expect(v.mask).toContain(`/runtime/canopy-c01/window-${plate}-`);
  expect(v.canopy).toBe('saturate(0.12) brightness(0.78)');
  expect(v.pane).toBe('saturate(0.12) brightness(0.78)');
});

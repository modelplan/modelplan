// SPDX-License-Identifier: MIT
// G3-102 (owner D234): the close key is a matte oxblood cap with an off-white cross, centred, no glow, own tokens.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {decodePng} from '../png-pixel.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';

async function open(page,theme) {
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands();expect(await page.evaluate(raw=>window.modelPlanCockpit.receive(raw),send('load',{appearance:{...appearance,theme},shell}))).toBe(true);
 expect(await page.evaluate(raw=>window.modelPlanCockpit.receive(raw),send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
}

test.use({deviceScaleFactor:4});
for(const theme of ['night','day'])test(`close key uses the oxblood tokens and a centred cross (${theme})`,async({page})=>{
 await open(page,theme);const key=page.locator('.ck-head [data-close]');await expect(key).toBeVisible();
 await expect(key).toHaveAttribute('aria-label','Close');
 const info=await key.evaluate(el=>{
  const root=getComputedStyle(document.documentElement),pick=n=>root.getPropertyValue(n).trim();
  const body=getComputedStyle(el,'::before'),cross=getComputedStyle(el,'::after'),r=el.getBoundingClientRect();
  return {tokens:{c1:pick('--close-1'),c2:pick('--close-2'),h1:pick('--close-h1'),p1:pick('--close-p1'),off1:pick('--close-off1'),ink:pick('--close-ink')},
   bodyImage:body.backgroundImage,bodyShadow:body.boxShadow,bodyW:parseFloat(body.width),bodyH:parseFloat(body.height),radius:body.borderTopLeftRadius,
   inkBg:cross.backgroundImage,key:{w:r.width,h:r.height}};
 });
 for(const [name,value] of Object.entries(info.tokens))expect(value,name).toMatch(/^#[0-9a-f]{6}$/i);
 expect(info.bodyImage).toContain('linear-gradient');expect(info.bodyImage).not.toContain('url(');
 expect(info.bodyShadow).not.toMatch(/\d+px \d+px [1-9]\d+px/);// no bloom: only 1-2 px bevel and edge
 expect(info.bodyW).toBe(info.key.w);expect(info.bodyH).toBe(info.key.h);expect(info.radius).toBe('4px');
 // same key geometry as the neighbours
 const gear=await page.locator('.ck-head [data-settings]').boundingBox();expect(info.key.w).toBeCloseTo(gear.width,0);expect(info.key.h).toBeCloseTo(gear.height,0);
 // pixel check at 4x: the off-white cross pixels' bounding box is centred on the key within 0.5 px
 const rect=await key.boundingBox(),shot=decodePng(await key.screenshot({scale:'device'})),scale=shot.width/Math.ceil(info.key.w+(rect.x%1)),offX=rect.x%1,offY=rect.y%1,edge=3*scale;let x0=1e9,y0=1e9,x1=-1,y1=-1;
 for(let y=Math.ceil(edge);y<shot.height-edge;y++)for(let x=Math.ceil(edge);x<shot.width-edge;x++){const i=(y*shot.width+x)*shot.channels,[r,g,b]=[shot.data[i],shot.data[i+1],shot.data[i+2]];
  if(r>170&&g>160&&b>140){x0=Math.min(x0,x);x1=Math.max(x1,x);y0=Math.min(y0,y);y1=Math.max(y1,y);}}
 expect(x1,'cross pixels found').toBeGreaterThan(0);
 const cx=(x0+x1+1)/2/scale-offX,cy=(y0+y1+1)/2/scale-offY;
 expect(Math.abs(cx-info.key.w/2),`cross centre x ${cx}`).toBeLessThanOrEqual(0.5);expect(Math.abs(cy-info.key.h/2),`cross centre y ${cy}`).toBeLessThanOrEqual(0.5);
 expect((x1-x0+1)/scale).toBeGreaterThan(8);expect((x1-x0+1)/scale).toBeLessThan(18);
 // hover is lighter and pressed darker, from tokens
 await key.hover();const hover=await key.evaluate(el=>getComputedStyle(el,'::before').backgroundImage);expect(hover).toContain(hexToRgb(info.tokens.h1));
 await page.mouse.down();const down=await key.evaluate(el=>getComputedStyle(el,'::before').backgroundImage);await page.mouse.up();expect(down).toContain(hexToRgb(await page.evaluate(()=>getComputedStyle(document.documentElement).getPropertyValue('--close-p1').trim())));
 // the cross is painted from the ink token
 expect(info.inkBg).toContain(`rgb(${hexToRgb(info.tokens.ink)})`);
});

function hexToRgb(h){const n=parseInt(h.slice(1),16);return `${n>>16}, ${(n>>8)&255}, ${n&255}`;}

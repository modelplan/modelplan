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


// Painted face of a key: the darkest rim pixel on each side of the key's middle row and column, searched in a 3.5 px band
// around the box edge (the key art and the CSS cap both end in a dark rim), measured on a 4x page screenshot, in CSS px.
async function face(page,locator) {
 const r=await locator.boundingBox(),m=6,dpr=4,shot=decodePng(await page.screenshot({clip:{x:Math.floor(r.x)-m,y:Math.floor(r.y)-m,width:Math.ceil(r.width)+2*m+1,height:Math.ceil(r.height)+2*m+1},scale:'device'}));
 const lum=(x,y)=>{const i=(y*shot.width+x)*shot.channels;return shot.data[i]+shot.data[i+1]+shot.data[i+2];},ox=r.x-Math.floor(r.x)+m,oy=r.y-Math.floor(r.y)+m;
 const min=(from,to,at)=>{let best=from,v=1e9;for(let t=Math.round(from*dpr);t<=Math.round(to*dpr);t++){const l=at(t);if(l<v){v=l;best=t;}}return best/dpr;};
 const cy=Math.round((oy+r.height/2)*dpr),cx=Math.round((ox+r.width/2)*dpr);
 const left=min(ox-1,ox+2.5,x=>lum(x,cy)),right=min(ox+r.width-2.5,ox+r.width+1,x=>lum(x,cy)),top=min(oy-1,oy+2.5,y=>lum(cx,y)),bottom=min(oy+r.height-2.5,oy+r.height+1,y=>lum(cx,y));
 return {w:right-left,h:bottom-top,left:left-ox,top:top-oy};
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
 // painted cap + 1 px edge ring (~31 px) matches the gear's ~30.5 px painted face; never larger than the key box
 expect(info.bodyW).toBeCloseTo(info.key.w-1.7,1);expect(info.bodyH).toBeCloseTo(info.key.h-1.7,1);expect(info.radius).toBe('4px');
 // same key geometry as the neighbours
 const gear=await page.locator('.ck-head [data-settings]').boundingBox();const close=await key.boundingBox();expect(Math.abs(close.width-gear.width)).toBeLessThanOrEqual(0.5);expect(Math.abs(close.height-gear.height)).toBeLessThanOrEqual(0.5);expect(Math.abs(close.y-gear.y)).toBeLessThanOrEqual(0.5);
 const detach=await page.locator('.ck-head [data-detach]').boundingBox();expect(Math.abs(close.y-detach.y)).toBeLessThanOrEqual(0.5);expect(Math.abs(close.height-detach.height)).toBeLessThanOrEqual(0.5);expect(Math.abs(close.width-detach.width)).toBeLessThanOrEqual(0.5);
 // pixel check at 4x: the off-white cross pixels' bounding box is centred on the key within 0.5 px
 const rect=await key.boundingBox(),shot=decodePng(await key.screenshot({scale:'device'})),scale=shot.width/Math.ceil(info.key.w+(rect.x%1)),offX=rect.x%1,offY=rect.y%1,edge=3*scale;let x0=1e9,y0=1e9,x1=-1,y1=-1;
 for(let y=Math.ceil(edge);y<shot.height-edge;y++)for(let x=Math.ceil(edge);x<shot.width-edge;x++){const i=(y*shot.width+x)*shot.channels,[r,g,b]=[shot.data[i],shot.data[i+1],shot.data[i+2]];
  if(r>170&&g>160&&b>70){x0=Math.min(x0,x);x1=Math.max(x1,x);y0=Math.min(y0,y);y1=Math.max(y1,y);}}
 expect(x1,'cross pixels found').toBeGreaterThan(0);
 const cx=(x0+x1+1)/2/scale-offX,cy=(y0+y1+1)/2/scale-offY;
 expect(Math.abs(cx-info.key.w/2),`cross centre x ${cx}`).toBeLessThanOrEqual(0.5);expect(Math.abs(cy-info.key.h/2),`cross centre y ${cy}`).toBeLessThanOrEqual(0.5);
 expect((x1-x0+1)/scale).toBeGreaterThan(8);expect((x1-x0+1)/scale).toBeLessThan(18);
 // painted faces: the close cap (with its edge ring) is the same size and place as the gear's face, within 1 px
 const fg=await face(page,page.locator('.ck-head [data-settings]')),fc=await face(page,key);
 // the gear art is not square (30 x 31.5 px between rims) and its day edges are textured, so: night only, 1 px tolerance
 if(theme==='night')for(const k of ['w','h','left','top'])expect(Math.abs(fc[k]-fg[k]),`face ${k}: close ${fc[k]} gear ${fg[k]}`).toBeLessThanOrEqual(1);
 // hover is lighter and pressed darker, from tokens
 await key.hover();const hover=await key.evaluate(el=>getComputedStyle(el,'::before').backgroundImage);expect(hover).toContain(hexToRgb(info.tokens.h1));
 await page.mouse.down();const down=await key.evaluate(el=>getComputedStyle(el,'::before').backgroundImage);await page.mouse.up();expect(down).toContain(hexToRgb(await page.evaluate(()=>getComputedStyle(document.documentElement).getPropertyValue('--close-p1').trim())));
 // the cross is painted from the ink token
 expect(info.inkBg).toContain(`rgb(${hexToRgb(info.tokens.ink)})`);
});

function hexToRgb(h){const n=parseInt(h.slice(1),16);return `${n>>16}, ${(n>>8)&255}, ${n&255}`;}

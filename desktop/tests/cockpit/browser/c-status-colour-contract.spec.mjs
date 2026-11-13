// SPDX-License-Identifier: MIT
// Colour contract on the built page through its normal bridge (COL-2.1-01/02/03/04/12/13/17, THM-2.4-02).
// The rendered page is the read-only seam: nothing here adds a test hook to the product. Status colour is read
// from computed paint and from the screenshot's own pixels, so a token that exists but does not reach the
// screen fails. The 75/40/20 readings sit inside every band of every threshold rule, so the band boundary
// (D22) stays with its own tests.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {firstPixel} from '../png-pixel.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {visualFixture,renderVisualDeck} from '../visual-fixture.mjs';

const STATUS={ok:[90,217,186],mid:[234,193,123],low:[239,68,68]};
const DAY_LOW=[179,51,51];
const BRAND={night:[223,96,76],day:[187,52,44]};
const css=([r,g,b])=>`rgb(${r}, ${g}, ${b})`;
const near=(a,b,tolerance)=>a.slice(0,3).every((v,i)=>Math.abs(v-b[i])<=tolerance);

function reading(remaining=[75,40,20]) {
 const fx=visualFixture(),rows=fx.data.projection.rows;
 rows.forEach((row,index)=>{row.vendorKey=['openai','claude','cursor','glm'][index];row.accounts[0].windows[0].remainingPercent=remaining[index%remaining.length];row.accounts[0].windows[1].remainingPercent=remaining[index%remaining.length];});
 for(const [index,group] of fx.data.subscriptions.entries())group.accounts[0].account.windows=structuredClone(rows[index].accounts[0].windows);
 return fx;
}
async function open(page,data,theme='night') {
 await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};});
 await page.clock.setFixedTime(new Date('2026-11-04T12:00:00Z'));
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance:{...appearance,theme},shell,redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data}))).toBe(true);
 return {send,receive};
}
// Canvas normalises every CSS colour form (color-mix computes to color(srgb ...) in WebKit) to 8-bit sRGB.
const paints=(page,root='body')=>page.evaluate(root=>{
 const canvas=document.createElement('canvas').getContext('2d',{willReadFrequently:true});canvas.canvas.width=canvas.canvas.height=1;
 const rgba=value=>{canvas.clearRect(0,0,1,1);canvas.fillStyle='#000';canvas.fillStyle=value;canvas.fillRect(0,0,1,1);return [...canvas.getImageData(0,0,1,1).data];};
 const shown=e=>{const r=e.getBoundingClientRect();return r.width>0&&r.height>0&&getComputedStyle(e).visibility!=='hidden';};
 const out=[],colour=/(?:rgba?|color)\([^)]*\)|#[0-9a-f]{3,8}\b/gi,scope=document.querySelector(root);
 for(const e of [scope,...scope.querySelectorAll('*')]){if(!shown(e))continue;
  const name=e.tagName.toLowerCase()+(e.getAttribute('class')?'.'+e.getAttribute('class').trim().split(/\s+/).join('.'):'');
  for(const pseudo of [null,'::before','::after']){const s=getComputedStyle(e,pseudo);if(pseudo&&s.content==='none')continue;
   const text=e.childNodes.length&&[...e.childNodes].some(n=>n.nodeType===3&&n.textContent.trim());
   const channels={backgroundColor:s.backgroundColor,backgroundImage:s.backgroundImage,boxShadow:s.boxShadow,fill:s.fill,stroke:s.stroke,textShadow:s.textShadow};
   if(text)channels.color=s.color;
   if(parseFloat(s.borderTopWidth)>0)channels.borderTopColor=s.borderTopColor;
   for(const [property,value] of Object.entries(channels))for(const found of String(value).match(colour)??[]){const rgb=rgba(found);if(rgb[3]>12)out.push({name:name+(pseudo??''),property,rgb});}}}
 return out;},root);
const statusBearing=/\b(qcell|qnum|qbar|mb10|eng-led|caution|lv-(ok|mid|low|amber|red)|al-(red|amber))\b/;

async function pixel(locator) {
 const box=await locator.boundingBox(),png=await locator.page().screenshot({clip:{x:Math.floor(box.x+box.width/2),y:Math.floor(box.y+box.height/2),width:1,height:1}});
 return firstPixel(png);
}

for(const theme of ['night','day'])test(`COL-2.1-01/02/03 status colours reach the dark LCDs in ${theme}`,async({page})=>{
 const fx=reading();await open(page,fx.data,theme);
 for(const [level,rgb] of Object.entries(STATUS)){
  const cell=page.locator(`.qcell.lv-${level}`).first(),segment=cell.locator('.qbar i.on').first();
  await expect(segment).toHaveCSS('background-color',css(rgb));
  expect(near(await pixel(segment),rgb,8),`${level} bar pixel`).toBe(true); // the LCD glass glare lifts a few levels
  if(level!=='ok')await expect(cell.locator('.qnum')).toHaveCSS('color',css(rgb));
 }
 await page.getByRole('button',{name:'Subscription',exact:true}).click();
 for(const level of ['mid','low'])await expect(page.locator(`.mb10.lv-${level} i.on`).first()).toHaveCSS('background-color',css(STATUS[level]));
});

test('COL-2.1-04 critical takes the day step on light surfaces and never the night red',async({page})=>{
 await open(page,reading().data,'day');
 expect(await page.evaluate(()=>{const c=document.createElement('canvas').getContext('2d'),probe=document.createElement('i');probe.style.color='var(--st-low-day)';document.body.append(probe);c.fillStyle=getComputedStyle(probe).color;c.fillRect(0,0,1,1);probe.remove();return [...c.getImageData(0,0,1,1).data].slice(0,3);})).toEqual(DAY_LOW);
 for(const page2 of [null,'Subscription','Breakdown']){
  if(page2)await page.getByRole('button',{name:page2,exact:true}).click();
  const onLight=await page.evaluate(([low])=>{const c=document.createElement('canvas').getContext('2d',{willReadFrequently:true});c.canvas.width=c.canvas.height=1;
   const rgba=v=>{c.clearRect(0,0,1,1);c.fillStyle=v;c.fillRect(0,0,1,1);return [...c.getImageData(0,0,1,1).data];};
   const backing=e=>{for(let n=e;n;n=n.parentElement){const s=getComputedStyle(n);if(s.backgroundImage!=='none')return (s.backgroundImage.match(/(?:rgba?|color)\([^)]*\)|#[0-9a-f]{3,8}\b/i)??[s.backgroundColor])[0];const v=rgba(s.backgroundColor);if(v[3]>200)return s.backgroundColor;}return 'transparent';};
   const light=v=>{const [r,g,b,a]=rgba(v);return a>0&&(r*.2126+g*.7152+b*.0722)>140;};
   return [...document.querySelectorAll('#cockpit *')].filter(e=>[...e.childNodes].some(n=>n.nodeType===3&&n.textContent.trim())).filter(e=>rgba(getComputedStyle(e).color).slice(0,3).join()===low.join()&&light(backing(e))).map(e=>e.className);},[STATUS.low]);
  expect(onLight).toEqual([]);
 }
});

test('THM-2.4-02 night metal and inks hold their values',async({page})=>{
 await open(page,reading().data,'night');
 const tokens=await page.evaluate(()=>{const s=getComputedStyle(document.documentElement);return Object.fromEntries(['--metal-1','--metal-2','--metal-3','--gold-metal','--fire-metal'].map(n=>[n,s.getPropertyValue(n).trim().toLowerCase()]));});
 expect(tokens).toEqual({'--metal-1':'#202124','--metal-2':'#1c1d1f','--metal-3':'#141517','--gold-metal':'#d4b994','--fire-metal':'#df604c'});
 const silk=await page.locator('.eng-labels').first().evaluate(e=>getComputedStyle(e).color);
 expect(silk.match(/\d+/g).slice(0,3).every(v=>Number(v)>120),`silkscreen ink ${silk}`).toBe(true);
});

for(const theme of ['night','day'])test(`COL-2.1-12/17 brand red stays out of every painted surface in ${theme}`,async({page})=>{
 const fx=reading();await open(page,fx.data,theme);await renderVisualDeck(page,fx,'en');
 const seen=[];
 for(const name of ['Overview','Subscription','Effort','Breakdown']){await page.getByRole('button',{name,exact:true}).click();seen.push(...await paints(page));}
 await page.keyboard.down('Alt');seen.push(...await paints(page));await page.keyboard.up('Alt');
 expect(seen.length).toBeGreaterThan(200);
 // The only cockpit place for it is the strip's live "Plan" wordmark (owner build 13: the study's hud-selection
 // wordmark replaced the early raster); no other surface paints it.
 const brand=seen.filter(p=>near(p.rgb,BRAND.night,20)||near(p.rgb,BRAND.day,20));
 expect([...new Set(brand.map(p=>`${p.name} ${p.property}`))]).toEqual(['b color']);
 expect(await page.evaluate(()=>[...document.querySelectorAll('#cockpit b')].filter(e=>getComputedStyle(e).color==='rgb(223, 96, 76)').map(e=>e.closest('.ck-head .wordmark')?'wordmark':e.className))).toEqual(['wordmark']);
 // Status places carry only their status palette, never a value close to the brand reds.
 expect(seen.filter(p=>statusBearing.test(p.name)&&near(p.rgb,STATUS.low,2)&&(near(p.rgb,BRAND.night,2)||near(p.rgb,BRAND.day,2)))).toEqual([]);
});

test('COL-2.1-13 status never carries identity and identity never carries status',async({page})=>{
 const healthy=reading([75]),{send,receive}=await open(page,healthy.data);
 const identity=()=>page.evaluate(()=>[...document.querySelectorAll('[style*="--v"]')].map(e=>getComputedStyle(e).getPropertyValue('--v').trim()).filter(Boolean));
 const statusOf=level=>page.locator(`.qcell.lv-${level} .qbar i.on`).evaluateAll(list=>[...new Set(list.map(e=>getComputedStyle(e).backgroundColor))]);
 const before=await identity();
 expect(new Set(before).size).toBeGreaterThan(2);
 // Different makers in one status paint one status colour.
 expect(await statusOf('ok')).toEqual([css(STATUS.ok)]);
 // A maker's status change leaves its identity paint alone, and the status palette stays apart from identity.
 const low=reading([20]);expect(await receive(send('display',{data:low.data}))).toBe(true);
 await expect(page.locator('.qcell.lv-low').first()).toBeVisible();
 expect(await identity()).toEqual(before);
 expect(await statusOf('low')).toEqual([css(STATUS.low)]);
 const hex=([r,g,b])=>'#'+[r,g,b].map(v=>v.toString(16).padStart(2,'0')).join('');
 for(const value of Object.values(STATUS))expect(before).not.toContain(hex(value));
});

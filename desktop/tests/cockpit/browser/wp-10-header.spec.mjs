// SPDX-License-Identifier: MIT
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';

// WP-10 (CKP-STRIP-06 amended, CKP-SHELL-51/52): the header layout of the approved round 3 design.
// Coordinates are header-content-box points; the viewport is 636 wide, so page x = header x + 24.
async function open(page,{theme='night',locale='en',profile='open'}={}){
 await page.addInitScript(()=>{window.__ev=[];window.webkit={messageHandlers:{cockpit:{postMessage(raw){window.__ev.push(JSON.parse(raw));}}}};});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance:{...appearance,theme,locale},shell:{...shell,profile}}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 return {send,receive};
}
const rel=async(page,selector)=>{const head=await page.locator('.ck-head').boundingBox(),b=await page.locator(selector).first().boundingBox();return {x:b.x-head.x,y:b.y-head.y,width:b.width,height:b.height};};
const near=(a,b,eps=0.06)=>expect(Math.abs(a-b)).toBeLessThanOrEqual(eps);

test('WP-10 the header places ALERT, the porthole switch, the date keys and the three buttons by the approved round 3 numbers',async({page})=>{
 await open(page);
 const alert=await rel(page,'.ck-head .caution'),port=await rel(page,'[data-shutter]');
 near(alert.x,190,1);expect(alert.width).toBe(44);expect(alert.height).toBe(32);
 near(port.x,248.17);near(port.width,91.67);near(port.height,30);near(port.y,-2);
 const head=await page.locator('.ck-head').boundingBox();near(port.x+port.width/2,head.width/2);
 const keys=[];for(const k of ['today','7d','30d'])keys.push(await rel(page,`[data-range-key="${k}"] .rk-cap`));
 [353.5,389.83,426.17].forEach((x,i)=>{near(keys[i].x,x);near(keys[i].width,34.33);near(keys[i].height,17);near(keys[i].y,11.5);});
 for(let i=1;i<3;i++)near(keys[i].x-(keys[i-1].x+keys[i-1].width),2);
 const buttons=[];for(const s of ['[data-settings]','[data-detach]','[data-close]'])buttons.push(await rel(page,s));
 [474,512,550].forEach((x,i)=>{near(buttons[i].x,x);expect(buttons[i].width).toBe(32);expect(buttons[i].height).toBe(32);});
 // gap alert -> porthole equals gap porthole -> first date key body (SPEC R3.2, 14.17 vs 14.13)
 near(port.x-(alert.x+alert.width),14.17,0.1);
});

for(const locale of ['en','zh-CN'])
test(`WP-10 date labels are live text (${locale})`,async({page})=>{
 await open(page,{locale});
 const words=locale==='en'?['Today','7d','30d']:['今天','7天','30天'];
 for(const [i,k] of ['today','7d','30d'].entries()){
  const label=page.locator(`[data-range-key="${k}"] .rk-label`);await expect(label).toHaveText(words[i]);
  const style=await label.evaluate(e=>{const s=getComputedStyle(e);return {size:s.fontSize,weight:s.fontWeight,family:s.fontFamily};});
  expect(style.size).toBe(locale==='en'?'10.5px':'10px');expect(style.weight).toBe(locale==='en'?'600':'500');expect(style.family).toContain('DM Sans');
 }
 await expect(page.locator('[data-range]')).toHaveAttribute('role','radiogroup');
});

// Owner 11-18: each date control is one click target covering its label, its key and the gaps to the neighbours, up to
// the midpoint of each gap, and the full header-row height. A label, the gap midpoint and 2 pt above a key all select it.
test('WP-10 a click on the label, at the gap midpoint or 2 pt above a key selects that range',async({page})=>{
 await open(page);
 const pressed=async()=>page.evaluate(()=>[...document.querySelectorAll('[data-range-key]')].filter(b=>b.getAttribute('aria-checked')==='true').map(b=>b.dataset.rangeKey));
 expect(await pressed()).toEqual(['7d']);
 const box=async k=>(await page.locator(`[data-range-key="${k}"] .rk-cap`).boundingBox());
 const [t,s,m]=[await box('today'),await box('7d'),await box('30d')];
 const click=async(x,y)=>{await page.mouse.click(x,y);},head=await page.locator('.ck-head').boundingBox();
 await click(t.x+t.width/2,t.y-9);                    // on the label line
 expect(await pressed()).toEqual(['today']);
 await click(s.x+s.width/2,s.y-2);                    // 2 pt above the key
 expect(await pressed()).toEqual(['7d']);
 await click((s.x+s.width+m.x)/2+1.2,s.y+s.height/2); // gap midpoint (within pixel snapping), on the 30d side
 expect(await pressed()).toEqual(['30d']);
 await click((s.x+s.width+m.x)/2-1.2,s.y+s.height/2); // gap midpoint (within pixel snapping), on the 7d side
 expect(await pressed()).toEqual(['7d']);

 // no dead zone: every point across the three keys and both gaps, at every height of the row, lands on a date key
 expect(await page.evaluate(({x0,x1,y0,y1})=>{const miss=[];for(let x=x0;x<=x1;x+=0.5)for(let y=y0;y<=y1;y+=2)if(!document.elementFromPoint(x,y)?.closest('[data-range-key]'))miss.push([x,y]);return miss;},{x0:t.x,x1:m.x+m.width,y0:head.y+0.5,y1:head.y+25})).toEqual([]);
 await click((t.x+t.width+s.x)/2-1.2,s.y-6);          // gap between today and 7d, above the keys
 expect(await pressed()).toEqual(['today']);

 await click(m.x+m.width/2,head.y+0.5);               // top of the row
 expect(await pressed()).toEqual(['30d']);
 await page.keyboard.press('ArrowLeft');expect(await pressed()).toEqual(['7d']);
});

test('WP-10 the porthole switch has the same frame open and closed, a click toggles, and there is no drag',async({page})=>{
 const {send,receive}=await open(page);
 const frame=()=>page.locator('[data-shutter]').evaluate(e=>{const h=document.querySelector('.ck-head').getBoundingClientRect(),q=e.getBoundingClientRect(),r={x:q.x-h.x,y:q.y-h.y,width:q.width,height:q.height},layer=part=>{const s=getComputedStyle(e,part);return {size:s.backgroundSize,pos:s.backgroundPosition,top:s.top,left:s.left,width:s.width,height:s.height,image:s.backgroundImage,opacity:Number(s.opacity)};};return {x:r.x,y:r.y,w:r.width,h:r.height,open:layer('::before'),closed:layer('::after'),cursor:getComputedStyle(e).cursor};});
 const a=await frame();
 expect(a.open.image).toContain('porthole-switch-open@3x.png');expect(a.closed.image).toContain('porthole-switch-closed@3x.png');
 expect([a.open.opacity,a.closed.opacity]).toEqual([1,0]);
 expect(await receive(send('shell',{...shell,profile:'closed'}))).toBe(true);
 await expect(page.locator('[data-shutter]')).toHaveAttribute('aria-pressed','true');
 await expect.poll(async()=>(await frame()).closed.opacity).toBe(1);
 const b=await frame();
 expect([b.open.opacity,b.closed.opacity]).toEqual([0,1]);
 // the frame is identical in both states: same box, same layer geometry, same size of art
 const geometry=f=>({x:f.x,y:f.y,w:f.w,h:f.h,open:{...f.open,image:0,opacity:0},closed:{...f.closed,image:0,opacity:0}});
 expect(geometry(b)).toEqual(geometry(a));
 expect(a.open.size).toBe(a.closed.size);expect(parseFloat(a.open.size)).toBeCloseTo(91.67,1);
 expect(a.cursor).toBe('pointer');
 expect(await page.locator('[data-shutter] .shutter-thumb').count()).toBe(0);
 await page.locator('[data-shutter]').click();
 expect(await page.evaluate(()=>window.__ev.filter(e=>e.type==='action').map(e=>e.action))).toEqual(['shutterToggle']);
 await expect(page.locator('[data-shutter]')).toHaveAttribute('title','Open porthole');
});

test('WP-10 the close button keeps its dark red caps and its 32 x 32 box',async({page})=>{
 await open(page);
 const paint=s=>page.locator(s).evaluate(e=>{const b=getComputedStyle(e,'::before');return {bg:b.backgroundImage,shadow:b.boxShadow,w:e.offsetWidth,h:e.offsetHeight};});
 const close=await paint('[data-close]');expect(close.bg).toContain('gradient');expect(close.w).toBe(32);expect(close.h).toBe(32);
});

// WP-10 after WP-09 (#1047): the date keys are wired to the app's one range (shell.range / rangeSelect).
async function openWithData(page,{range='7d',empty=false}={}){
 const {visualFixture}=await import('../visual-fixture.mjs');
 await page.addInitScript(()=>{window.__ev=[];window.webkit={messageHandlers:{cockpit:{postMessage(raw){window.__ev.push(JSON.parse(raw));}}}};});
 await page.clock.setFixedTime(new Date('2026-11-04T12:00:00Z'));
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const data=visualFixture().data;if(empty){data.projection.rows=[];data.subscriptions=[];data.details=null;}
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance,shell:{...shell,range},redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data}))).toBe(true);
 return {send,receive};
}
const checked=page=>page.evaluate(()=>[...document.querySelectorAll('[data-range-key]')].filter(b=>b.getAttribute('aria-checked')==='true').map(b=>b.dataset.rangeKey));
const asks=page=>page.evaluate(()=>window.__ev.filter(e=>e.type==='action'&&e.action==='rangeSelect').map(e=>e.key));

test('WP-10 the date keys show the host range and a click asks the app with rangeSelect',async({page})=>{
 const {send,receive}=await openWithData(page,{range:'30d'});
 expect(await checked(page)).toEqual(['30d']);
 await page.locator('[data-range-key="today"]').click();
 expect(await asks(page)).toEqual(['today']);
 expect(await checked(page)).toEqual(['today']);
 await page.locator('[data-range-key="today"]').focus();await page.keyboard.press('ArrowRight');
 expect(await asks(page)).toEqual(['today','7d']);
 // the host decides: its shell is the source of truth for both the keys and the MFD footer key
 expect(await receive(send('shell',{...shell,range:'30d'}))).toBe(true);
 expect(await checked(page)).toEqual(['30d']);
 await expect(page.locator('[data-opt="range"] b.on')).toHaveText('30d');
 // T (the other surface of the same range) moves the keys too
 await page.keyboard.press('t');
 expect(await checked(page)).toEqual(['today']);
});

test('WP-10 a shell without a range (an older host) leaves the date keys on 7d',async({page})=>{
 await openWithData(page,{range:undefined});
 expect(await checked(page)).toEqual(['7d']);
});

test('WP-10 with no usage source the date keys are dimmed and ask for nothing',async({page})=>{
 await openWithData(page,{empty:true});
 const keys=page.locator('[data-range-key]');
 for(const k of await keys.all()){await expect(k).toHaveAttribute('aria-disabled','true');expect(Number(await k.evaluate(e=>getComputedStyle(e).opacity))).toBeLessThan(0.6);}
 await page.locator('[data-range-key="30d"]').click({force:true});
 expect(await asks(page)).toEqual([]);
 expect(await checked(page)).toEqual(['7d']);
});

test('WP-10 the date keys are live again once a usage source reports',async({page})=>{
 const {send,receive}=await openWithData(page,{empty:true});
 const {visualFixture}=await import('../visual-fixture.mjs');
 expect(await receive(send('display',{data:visualFixture().data}))).toBe(true);
 for(const k of await page.locator('[data-range-key]').all())await expect(k).not.toHaveAttribute('aria-disabled','true');
 await page.locator('[data-range-key="30d"]').click();
 expect(await asks(page)).toEqual(['30d']);
});

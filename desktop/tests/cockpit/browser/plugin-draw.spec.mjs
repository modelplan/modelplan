// SPDX-License-Identifier: MIT
// Cockpit plugin custom draw (owner D323): a plugin that cells cannot express may give its column or big screen a `draw`
// and paint inside the one clipped area the host gives it. The key, its dashed underline, the bottom line, the screen's
// title bar and the lifecycle stay the framework's; a draw that throws falls back to cells (or lines); focus on a
// `data-focus` element survives a redraw. A probe plugin is mounted through the page's own modules on the real cockpit.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,sample,shell,excludePortholeFlicker} from '../fixture.mjs';
test.beforeEach(async({page})=>excludePortholeFlicker(page));

async function open(page) {
 await page.clock.setFixedTime(new Date('2026-11-04T12:00:00Z'));
 await page.addInitScript(()=>{
  window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};
  // Count the plugin draw areas any ResizeObserver still watches (black box: the host's own observer is not exposed).
  const Native=window.ResizeObserver,watched=new Set();window.__watchedAreas=()=>[...watched].filter(e=>e.matches('.pl-draw,.pl-screen-d')).length;
  window.ResizeObserver=class extends Native{observe(e,o){watched.add(e);return super.observe(e,o);}unobserve(e){watched.delete(e);return super.unobserve(e);}disconnect(){watched.clear();return super.disconnect();}};
 });
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 const data=sample();data.projection.rows=[data.projection.rows[0]];
 expect(await receive(send('load',{appearance,shell,redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data}))).toBe(true);
 // The probe: mode 'draw' paints, 'throw' throws, 'escape' tries to paint over the whole window.
 await page.evaluate(async()=>{
  const {mountPluginHost}=await import('/src/plugin-host.js'),{PluginRegistry,PLUGIN_ICON_FRAME}=await import('/src/plugin-registry.js');
  const probe=window.__probe={mode:'draw',screenMode:'draw',draws:[],clicks:0};
  const draw=where=>ctx=>{
   const mode=where==='column'?probe.mode:probe.screenMode;
   probe.draws.push({where,w:ctx.width,h:ctx.height,opening:ctx.opening});
   if(mode==='throw')throw Error('probe');
   const mark=document.createElement('div');mark.className='probe-mark';mark.style.cssText=`position:absolute;inset:0;background:${ctx.tokens.ghost}`;
   const button=document.createElement('button');button.type='button';button.className='probe-b';button.style.cssText='position:relative;z-index:1';button.dataset.focus='probe';button.textContent=`n${ctx.memo.n??0}`;
   button.onclick=()=>{ctx.memo.n=(ctx.memo.n??0)+1;probe.clicks++;ctx.redraw();};
   ctx.area.append(mark,button);
   if(mode==='escape'){
    const fixed=document.createElement('div');fixed.className='probe-escape';fixed.style.cssText='position:fixed;left:0;top:0;width:100vw;height:100vh;background:red;z-index:99999';
    const wide=document.createElement('div');wide.className='probe-escape';wide.style.cssText='position:absolute;left:-2000px;top:-2000px;width:5000px;height:5000px;background:red;z-index:99999';
    ctx.area.append(fixed,wide);
   }
  };
  const plugin={id:'probe',title:'plugin.placeholderTitle',summary:'plugin.placeholderSummary',icon:`<svg viewBox="0 0 16 16">${PLUGIN_ICON_FRAME}</svg>`,underline:'#87939e',defaultEnabled:true,settings:[],
   accept:data=>data,
   column:(state,ctx)=>({cells:[{tag:ctx.words('plugin.placeholderTag'),value:42,unit:'%'}],foot:{label:ctx.words('plugin.placeholderFoot')},draw:draw('column')}),
   screen:()=>({lines:[{label:'fallback',value:'line'}],draw:draw('screen')}),
  };
  window.__host=mountPluginHost(document.getElementById('cockpit'),{state(){},running(){}},new PluginRegistry([plugin]));
  window.__host.applyHostState({version:1,entries:[{id:'probe',enabled:true,pinned:false}],settings:{}});
  window.__host.setVisible(true);window.__host.setInteractive(true);
 });
 // Repaint: the engine now lays its table out through the probe's host.
 expect(await receive(send('display',{data}))).toBe(true);
 return {send,receive,data,repaint:()=>receive(send('display',{data}))};
}
const column=page=>page.locator('.eng-cols .pl-col[data-plugin="probe"]');
const key=page=>page.locator('.eng-keys .pl-key[data-plugin="probe"]');
const probe=page=>page.evaluate(()=>window.__probe);
const setMode=(page,mode,screenMode=mode)=>page.evaluate(([mode,screenMode])=>{window.__probe.mode=mode;window.__probe.screenMode=screenMode;},[mode,screenMode]);

test('D323 a plugin with draw paints its own area over the column\'s cell rows; key, underline and bottom line stay the framework\'s',async({page})=>{
 await open(page);
 await expect(column(page)).toHaveAttribute('data-draw','custom');
 await expect(column(page).locator('.pl-draw .probe-mark')).toHaveCount(1);
 await expect(column(page).locator('.pl-cell')).toHaveCount(0);
 await expect(column(page).locator('.pl-foot')).toHaveText('Framework');
 await expect(key(page).locator('.pl-dash')).toHaveCount(1);
 const g=await page.evaluate(()=>{
  const col=document.querySelector('.pl-col[data-plugin="probe"]'),area=col.querySelector('.pl-draw'),foot=col.querySelector('.pl-foot'),sub=document.querySelector('.eng-cols .ec[data-col]');
  const r=e=>e.getBoundingClientRect(),cells=[...sub.querySelectorAll('.qcell')];
  return {area:r(area).toJSON(),col:r(col).toJSON(),foot:r(foot).toJSON(),firstCell:r(cells[0]).toJSON(),lastCell:r(cells[cells.length-1]).toJSON(),client:[area.clientWidth,area.clientHeight]};
 });
 // The area covers exactly the cell rows of a subscription column: from the first cell's top to the last cell's bottom.
 expect(Math.abs(g.area.top-g.firstCell.top)).toBeLessThan(1);expect(Math.abs(g.area.bottom-g.lastCell.bottom)).toBeLessThan(1);
 expect(g.area.bottom).toBeLessThanOrEqual(g.foot.top+0.5);
 expect(g.area.left).toBeGreaterThanOrEqual(g.col.left-0.5);expect(g.area.right).toBeLessThanOrEqual(g.col.right+0.5);
 // Once laid out (the table is drawn before it is attached), the plugin is drawn again at the area's real size.
 await expect.poll(async()=>{const d=(await probe(page)).draws.filter(d=>d.where==='column').at(-1);return [d.w,d.h,d.opening];}).toEqual([...g.client,false]);
 expect(g.client[0]).toBeGreaterThan(0);expect(g.client[1]).toBeGreaterThan(40);
});

test('D323 a custom draw cannot paint outside its area',async({page})=>{
 const {repaint}=await open(page);
 await setMode(page,'escape');expect(await repaint()).toBe(true);
 await expect(column(page).locator('.probe-escape')).toHaveCount(2);
 const hits=await page.evaluate(()=>{
  const area=document.querySelector('.pl-col[data-plugin="probe"] .pl-draw'),a=area.getBoundingClientRect(),style=getComputedStyle(area);
  const sub=document.querySelector('.eng-cols .ec[data-col] .qcell').getBoundingClientRect(),key=document.querySelector('.eng-keys .pl-key').getBoundingClientRect(),foot=document.querySelector('.pl-col[data-plugin="probe"] .pl-foot').getBoundingClientRect();
  const at=(x,y)=>{const e=document.elementFromPoint(x,y);return !!e?.closest('.pl-draw');};
  return {inside:at(a.left+a.width/2,a.top+a.height/2),sub:at(sub.left+sub.width/2,sub.top+sub.height/2),key:at(key.left+key.width/2,key.top+key.height/2),foot:at(foot.left+foot.width/2,foot.top+foot.height/2),
   corner:at(2,2),overflow:style.overflow,contain:style.contain};
 });
 expect(hits.inside).toBe(true);
 expect({sub:hits.sub,key:hits.key,foot:hits.foot,corner:hits.corner}).toEqual({sub:false,key:false,foot:false,corner:false});
 expect(hits.overflow).toBe('hidden');expect(hits.contain).toMatch(/strict|paint/);
 // The big screen's body is clipped the same way: the page keys stay uncovered (D413: there is no title bar).
 await setMode(page,'draw','escape');await key(page).click();
 await expect(page.locator('.pl-screen .pl-screen-d .probe-escape')).toHaveCount(2);
 const screenHits=await page.evaluate(()=>{
  const at=e=>{const r=e.getBoundingClientRect(),hit=document.elementFromPoint(r.left+r.width/2,r.top+r.height/2);return !!hit?.closest('.pl-screen-d');};
  return {title:document.querySelector('.pl-screen .pl-screen-t')===null,pageKey:at(document.querySelector('.dk-mfd .mfd-pk .pk[data-mfd="page:sub"]')),body:at(document.querySelector('.pl-screen .pl-screen-d'))};
 });
 expect(screenHits).toEqual({title:true,pageKey:false,body:true});// D413: no title row at all
 // D387: there is no Close button; the key toggles the screen shut (this harness mounts a bare host without the deck's switch).
 await key(page).click();await expect(page.locator('.pl-screen')).toHaveCount(0);
});

test('D323 a draw that throws falls back to the plugin\'s cells (and lines on the screen); the next good draw takes over again',async({page})=>{
 const {repaint}=await open(page);
 await setMode(page,'throw');expect(await repaint()).toBe(true);
 await expect(column(page)).toHaveAttribute('data-draw','fallback');
 await expect(column(page).locator('.pl-draw')).toHaveCount(0);
 await expect(column(page).locator('.pl-cell .qvalue')).toHaveText('42');
 await expect(column(page).locator('.pl-foot')).toHaveText('Framework');
 // The rest of the cockpit is untouched.
 await expect(page.locator('.eng-cols .ec[data-col]')).toHaveCount(1);
 await key(page).click();
 await expect(page.locator('.pl-screen')).toHaveAttribute('data-draw','fallback');
 await expect(page.locator('.pl-screen .pl-screen-d')).toBeHidden();
 await expect(page.locator('.pl-screen dt')).toHaveText('fallback');
 // A reading with a working draw: custom again, in the column and on the open screen.
 await setMode(page,'draw');
 expect(await page.evaluate(()=>window.__host.deliver('probe',{v:1}))).toBe(true);
 await expect(column(page)).toHaveAttribute('data-draw','custom');
 await expect(page.locator('.pl-screen')).toHaveAttribute('data-draw','custom');
 await expect(page.locator('.pl-screen .pl-screen-l')).toBeHidden();
 await expect(page.locator('.pl-screen .pl-screen-d .probe-mark')).toHaveCount(1);
});

test('D323 the screen draw knows its first draw per opening; view memory is shared by column and screen and redraws both',async({page})=>{
 await open(page);
 await key(page).click();
 await expect(page.locator('.pl-screen .pl-screen-d .probe-b')).toHaveText('n0');
 await page.evaluate(()=>window.__host.deliver('probe',{v:2}));
 const screens=(await probe(page)).draws.filter(d=>d.where==='screen');
 expect(screens[0].opening).toBe(true);expect(screens[0].h).toBeGreaterThan(40);expect(screens.slice(1).every(d=>!d.opening)).toBe(true);
 // A click in the column changes the shared memory; the plugin's redraw updates its column and its open screen.
 await column(page).locator('.probe-b').click();
 await expect(column(page).locator('.probe-b')).toHaveText('n1');
 await expect(page.locator('.pl-screen .probe-b')).toHaveText('n1');
 await page.locator('.pl-screen .probe-b').click();
 await expect(column(page).locator('.probe-b')).toHaveText('n2');
 // Reopened: opening again.
 await key(page).click();await expect(page.locator('.pl-screen')).toHaveCount(0);
 const before=(await probe(page)).draws.length;
 await key(page).click();await expect(page.locator('.pl-screen .probe-b')).toHaveText('n2');
 // The first screen draw of the new opening has `opening` and the area's real size; any later draw does not.
 const reopened=(await probe(page)).draws.slice(before).filter(d=>d.where==='screen');
 expect(reopened[0].opening).toBe(true);expect(reopened[0].h).toBeGreaterThan(40);expect(reopened.slice(1).every(d=>!d.opening)).toBe(true);
});

test('D323 keyboard focus on a data-focus element survives host-driven redraws',async({page})=>{
 const {repaint}=await open(page);
 const button=column(page).locator('.probe-b');await button.focus();await expect(button).toBeFocused();
 const before=(await probe(page)).draws.length;
 expect(await page.evaluate(()=>window.__host.deliver('probe',{v:3}))).toBe(true);
 expect(await repaint()).toBe(true);
 expect((await probe(page)).draws.length).toBeGreaterThan(before);
 await expect(button).toBeFocused();
 // The same on the screen.
 await key(page).click();const inScreen=page.locator('.pl-screen .probe-b');await inScreen.focus();
 await page.evaluate(()=>window.__host.deliver('probe',{v:4}));
 await expect(inScreen).toBeFocused();
});

test('D323 focus on a drawn control survives full engine repaints that replace the table (host state, tick, locale, new data), column and screen',async({page})=>{
 const {send,receive,repaint}=await open(page);
 const button=column(page).locator('.probe-b');
 const keep=async(label,act)=>{
  await button.focus();await expect(button,label).toBeFocused();
  const old=await button.elementHandle();
  await act();
  // The table really was replaced: the focused element is a new one.
  await expect.poll(()=>old.evaluate(e=>e.isConnected),label).toBe(false);
  await expect(button,label).toBeFocused();
 };
 // A plugin-state change from the host (Settings) repaints the engine directly, outside the view's own focus keeping.
 await keep('host plugin state',()=>page.evaluate(()=>window.__host.applyHostState({version:1,entries:[{id:'probe',enabled:true,pinned:false}],settings:{}})));
 await keep('host tick',()=>receive(send('tick',{nowUnixMs:String(Date.parse('2026-11-04T12:01:00Z')),reason:'deadline'})));
 await keep('locale',()=>receive(send('appearance',{...appearance,locale:'zh-CN'})));
 await keep('new display data',repaint);
 // The open screen keeps focus on its drawn control across the same repaints.
 await key(page).click();const inScreen=page.locator('.pl-screen .probe-b');await inScreen.focus();
 expect(await receive(send('appearance',{...appearance,locale:'en'}))).toBe(true);
 expect(await repaint()).toBe(true);
 await expect(inScreen).toBeFocused();
 // Focus somewhere else is never taken back by a later repaint.
 await page.locator('.eng-keys .ek[data-sub]').first().focus();
 expect(await repaint()).toBe(true);
 await expect(page.locator('.eng-keys .ek[data-sub]').first()).toBeFocused();
});

test('D323 the size observer only watches draw areas that are on the page: repeated full repaints, removal and screen close',async({page})=>{
 const {send,receive,repaint}=await open(page);
 const watched=()=>page.evaluate(()=>window.__watchedAreas());
 await expect.poll(watched).toBe(1);
 for(let i=0;i<4;i++){expect(await repaint()).toBe(true);expect(await receive(send('tick',{nowUnixMs:String(Date.parse('2026-11-04T12:00:00Z')+(i+1)*60000),reason:'deadline'}))).toBe(true);}
 expect(await receive(send('appearance',{...appearance,locale:'zh-CN'}))).toBe(true);
 await expect.poll(watched).toBe(1);
 await key(page).click();await expect.poll(watched).toBe(2);
 expect(await repaint()).toBe(true);await expect.poll(watched).toBe(2);
 await key(page).click();await expect(page.locator('.pl-screen')).toHaveCount(0);await expect.poll(watched).toBe(1);
 // Removed: nothing left to watch. Cleared readings: the same.
 expect(await page.evaluate(()=>window.__host.remove('probe'))).toBe(true);
 expect(await repaint()).toBe(true);
 await expect(column(page)).toHaveCount(0);await expect.poll(watched).toBe(0);
 expect(await page.evaluate(()=>window.__host.add('probe'))).toBe(true);expect(await repaint()).toBe(true);await expect.poll(watched).toBe(1);
 // Cleared readings: the view clears its host's placement (in the app that host is this one; the probe host is extra).
 expect(await receive(send('clear',{viewRevision:'4'}))).toBe(true);await page.evaluate(()=>window.__host.clearPlacement());
 await expect(column(page)).toHaveCount(0);await expect.poll(watched).toBe(0);
});

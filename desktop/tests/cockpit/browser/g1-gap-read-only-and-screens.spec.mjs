// SPDX-License-Identifier: MIT
// v1 gate G1, batch 4: requirement IDs that had no test on main (CKP-SHELL-21, CKP-MFD-25, CKP-ENT-02, THM-2.4-04,
// THM-10-02, COL-2.1-15). The built page through its normal bridge, synthetic data only. Nothing here adds a
// test hook to the product: traps are installed on the page's own globals before it loads, and every reading is
// taken from computed style or from the messages the page posts to the native bridge.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';

const model=(id,developerId)=>({id,name:'Synthetic '+id,developerId,recommended:'medium',efforts:[{effort:'low',label:'Low',star:false,ability:30,cost:1,time:null},{effort:'medium',label:'Med',star:true,ability:40,cost:2,time:null}]});
// One normal-entry client: published models (so faders, the compare page and the frontier exist) and a live session.
function fixture(vendors){
 const data=visualFixture().data;
 if(vendors)data.projection.rows.forEach((row,i)=>{row.vendorKey=vendors[i]??null;});
 const publication=[model('used','openai'),model('lineup-1','openai'),model('lineup-2','anthropic')];
 data.details.publication={contractVersion:1,publicationId:'0123456789abcdef01234567',publishedAt:'2026-10-24T12:00:00Z',source:'client',truncated:true,models:publication};
 data.details.publishedModels=publication;
 data.details.sessions=[{sessionRef:'00000000000000a1',source:'codex',subscriptionRef:null,model:'used',effort:'medium',projectLabel:null,lastObservedAt:new Date().toISOString(),state:'running',rate:null}];
 return data;
}
// The page loads with the native bridge stubbed by a recorder, and with every way of leaving the page trapped.
async function open(page,{data=fixture(),theme='night',tier='tall',height=890}={}){
 await page.setViewportSize({width:636,height});
 await page.addInitScript(()=>{
  const log={posts:[],net:[],gl:[]};Object.defineProperty(window,'__probe',{value:log});
  window.webkit={messageHandlers:{cockpit:{postMessage(m){log.posts.push(String(m));}}}};
  const trap=(owner,name)=>{if(!owner||!(name in owner))return;const own=owner[name];owner[name]=function(...a){log.net.push(name+' '+String(a[0]));return own.apply(this,a);};};
  trap(window,'fetch');trap(XMLHttpRequest.prototype,'open');trap(navigator,'sendBeacon');
  for(const name of ['WebSocket','EventSource']){const Own=window[name];if(Own)window[name]=function(...a){log.net.push(name+' '+String(a[0]));return new Own(...a);};}
  const context=HTMLCanvasElement.prototype.getContext;
  HTMLCanvasElement.prototype.getContext=function(kind,...rest){if(/webgl|webgpu|bitmaprenderer/i.test(String(kind)))log.gl.push(String(kind));return context.call(this,kind,...rest);};
  if(window.OffscreenCanvas){const off=OffscreenCanvas.prototype.getContext;OffscreenCanvas.prototype.getContext=function(kind,...rest){if(/webgl|webgpu/i.test(String(kind)))log.gl.push('offscreen '+String(kind));return off.call(this,kind,...rest);};}
 });
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance:{...appearance,theme},shell:{...shell,tier},redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data}))).toBe(true);
 return {send,receive};
}
const probe=page=>page.evaluate(()=>({posts:[...window.__probe.posts].map(p=>JSON.parse(p)),net:[...window.__probe.net],gl:[...window.__probe.gl]}));

// CKP-SHELL-21: every try control is read-only and local. Pressing them sends nothing but the bridge's own
// message types, makes no request, and never carries a model, effort, credential or path to native.
test('CKP-SHELL-21 every try control stays local: zero requests and only whitelisted bridge messages',async({page})=>{
 const requests=[];page.on('request',r=>requests.push(r.url()));
 await open(page);await page.waitForLoadState('networkidle');
 const loaded=requests.length,before=(await probe(page)).posts.length;
 // Block everything that is not the page itself from now on: a try control that reached for the network would fail loudly.
 await page.route('**/*',route=>route.abort());
 const strips=page.locator('.fd-ch:not(.empty) .fd-strip');expect(await strips.count()).toBeGreaterThan(0);
 for(const strip of await strips.all()){
  await strip.click();
  const screen=page.locator('.mfd-page.pg-compare');await expect(screen).toBeVisible();
  for(const key of await screen.locator('[data-mfd^="try:"]').all())await key.click();
  const fast=screen.locator('[data-mfd="fast"]');if(await fast.count())await fast.first().click();
 }
 // The fader's own travel and the page and option keys are try controls too.
 const travel=page.locator('.fd-ch:not(.empty) .fd-travel').first();const box=await travel.boundingBox();await page.mouse.click(box.x+box.width/2,box.y+box.height*0.2);await page.mouse.click(box.x+box.width/2,box.y+box.height*0.8);
 await travel.focus();await page.keyboard.press('ArrowUp');await page.keyboard.press('ArrowDown');
 for(const key of await page.locator('.mfd-pk .pk').all())await key.click();
 for(const key of await page.locator('.mfd-ok button').all())await key.click();
 const after=await probe(page);
 expect(requests.length,'requests after load').toBe(loaded);
 expect(after.net,'fetch/XHR/beacon/WebSocket/EventSource calls').toEqual([]);
 const types=new Set(after.posts.map(m=>m.type));
 for(const type of types)expect(['ready','rendered','nextDeadline','cleared','action'],`bridge message ${type}`).toContain(type);
 const sent=after.posts.slice(before).filter(m=>m.type==='action');
 // Trying an effort or a model is not an action native could apply: no try control produces any action at all.
 expect(sent.map(m=>m.action),'actions sent while trying').toEqual([]);
 for(const m of after.posts)expect(JSON.stringify(m),'no model, effort, credential or path leaves the page').not.toMatch(/"(model|effort|setModel|setEffort|token|credential|password|apiKey|path|file)"\s*:/i);
});

// CKP-MFD-25: pages are modules in one registry. A click inside a page reaches that page's module, and the charts
// that are drawn at the measured size of the screen area (the compare chart and the Overview heatmap) take it at
// both tiers. (The Effort frontier and the Overview bars are drawn at a fixed size; see the PR notes.)
const NOW=new Date(2026,10,4,12).getTime();
const localDay=back=>{const d=new Date(2026,10,4-back);return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`;};
const sums=out=>({inputTokens:null,outputTokens:out,cacheReadTokens:null,cacheWriteTokens:null,cacheHitRatio:null,generationTps:null,observedRequests:1,eligibleRequests:1});
const ranking={measure:'observed-output-tokens',attribution:'unattributed',recent7d:{entities:0,totalObservedOutputTokens:0,top:[]},recent30d:{entities:0,totalObservedOutputTokens:0,top:[]}};
function withHistory(){
 const data=fixture(),ref=data.projection.rows[0].accounts[0].subscriptionRef;
 data.history={version:1,sources:['local-history'],coverage:'local-history',recordingSince:null,dailyFrom:localDay(39),
  subscriptions:[{subscriptionRef:ref,sources:[{source:'codex',bindingBasis:'source-wide-current-binding',recent7d:sums(1),recent30d:sums(1)}]}],
  models:ranking,tools:ranking,daily:[[0,200],[1,1000],[3,4000],[5,9000],[8,20000],[39,1500]].map(([back,n])=>({at:localDay(back),source:'codex',origin:'live',observedOutputTokens:n})),hourly:[],projects:{recent7d:[],recent30d:[]},cycles:[]};
 return data;
}
for(const [tier,height] of [['tall',890],['compact',640]]){
 test(`CKP-MFD-25 a click inside a page reaches its module and the charts take the measured screen at ${tier}`,async({page})=>{
  await page.clock.setFixedTime(new Date(NOW));
  await open(page,{data:withHistory(),tier,height});
  // Overview: the Grid key is inside the page; pressing it reaches the overview module, which draws the heatmap into
  // its measured area with the largest cells that fit (5 to 14 px).
  await expect(page.locator('.pg-overview svg.ov-chart')).toBeVisible();
  await page.locator('[data-opt="chart"] b',{hasText:/^Grid$/}).click();
  await expect(page.locator('.pg-overview svg.ov-heat')).toBeVisible();
  await expect.poll(()=>page.evaluate(()=>{
   const area=document.querySelector('[data-fill="ov"]'),svg=area?.querySelector('svg.ov-heat');if(!svg)return null;
   const cell=Number(svg.querySelector('rect.hm').getAttribute('width')),w=Number(svg.getAttribute('width')),h=Number(svg.getAttribute('height'));
   return {fitsW:w<=area.clientWidth,fitsH:h<=area.clientHeight,nextWouldNotFit:cell>=14||26*(cell+3)-2>area.clientWidth||12+7*(cell+3)-2>area.clientHeight};
  })).toEqual({fitsW:true,fitsH:true,nextWouldNotFit:true});
  // Compare: a fader press opens it, a try key inside it reaches the compare module, and its chart fills its measured area.
  await page.locator('.fd-strip[aria-label^="Synthetic lineup-1:"]').click();
  const screen=page.locator('.mfd-page.pg-compare');await expect(screen).toBeVisible();
  const key=screen.locator('.cmp-lad [data-mfd="try:Low"]');await key.click();
  // CKP-FAD-18 (47c2b884): the trial note now shows in every shell size, so the compact screen has no room left for the
  // chart while a trial is shown (the chart needs 34 px). The trial itself is still reached through the ladder key; the tall
  // screen keeps the chart and its trial marker.
  await expect(screen.locator('.cmp-lad .lad.try')).toHaveCount(1);await expect(screen.locator('.cmp-trial-note')).toHaveCount(1);
  if(tier==='compact')return;
  await expect(screen.locator('svg.cmp-chart .cfg-trial')).not.toHaveCount(0);
  await expect.poll(()=>page.evaluate(()=>{const area=document.querySelector('[data-fill="cmp"]'),svg=area?.querySelector('svg.cmp-chart');if(!svg||!area.clientWidth)return null;return {width:Math.abs(svg.getBoundingClientRect().width-area.clientWidth)<=1,height:svg.getBoundingClientRect().height<=area.clientHeight+1};})).toEqual({width:true,height:true});
 });
}

// CKP-ENT-02 (page half): opening the cockpit page allocates no renderer. No WebGL or WebGPU context is requested
// by the page, no canvas exists in it, and the reveal animates no clip-path or mask.
test('CKP-ENT-02 opening the cockpit page creates no GL context, no canvas and no clip or mask animation',async({page})=>{
 await open(page);
 await page.getByRole('button',{name:'Effort',exact:true}).click();
 const {gl}=await probe(page);expect(gl,'getContext(webgl*) calls').toEqual([]);
 expect(await page.locator('canvas').count(),'canvas elements in the cockpit page').toBe(0);
 expect(await page.locator('iframe,webview,embed,object').count()).toBe(0);
 const animated=await page.evaluate(()=>document.getAnimations().flatMap(a=>(a.effect?.getKeyframes?.()??[]).flatMap(k=>Object.keys(k))).filter(k=>/clip|mask/i.test(k)));
 expect(animated,'animated clip/mask properties').toEqual([]);
 expect(await page.evaluate(()=>[document.documentElement,document.body,document.getElementById('cockpit')].map(e=>{const s=getComputedStyle(e);return [s.clipPath,s.maskImage||s.webkitMaskImage||'none'];}))).toEqual([['none','none'],['none','none'],['none','none']]);
});

// Colour maths on computed paint (THM-2.4-04, THM-10-02). Computed colours come back as rgb()/rgba()/color(srgb).
const channel=v=>{v/=255;return v<=0.03928?v/12.92:((v+0.055)/1.055)**2.4;};
const luminance=([r,g,b])=>0.2126*channel(r)+0.7152*channel(g)+0.0722*channel(b);
const contrast=(a,b)=>{const [hi,lo]=[luminance(a),luminance(b)].sort((x,y)=>y-x);return (hi+0.05)/(lo+0.05);};
// The colours a surface paints: every colour stop of its gradient and its solid fill.
const surfaceColours=(page,selector)=>page.locator(selector).first().evaluate(e=>{
 const canvas=document.createElement('canvas').getContext('2d',{willReadFrequently:true});canvas.canvas.width=canvas.canvas.height=1;
 const rgb=value=>{canvas.clearRect(0,0,1,1);canvas.fillStyle='#000';canvas.fillStyle=value;canvas.fillRect(0,0,1,1);return [...canvas.getImageData(0,0,1,1).data];};
 const s=getComputedStyle(e),found=[];
 if(s.backgroundColor&&rgb(s.backgroundColor)[3]>200)found.push(rgb(s.backgroundColor).slice(0,3));
 for(const stop of s.backgroundImage.match(/rgba?\([^)]*\)/g)??[]){const c=rgb(stop);if(c[3]>200)found.push(c.slice(0,3));}
 return found;
});
const inkOf=(page,selector)=>page.locator(selector).first().evaluate(e=>{
 const canvas=document.createElement('canvas').getContext('2d',{willReadFrequently:true});canvas.canvas.width=canvas.canvas.height=1;
 canvas.fillStyle=getComputedStyle(e).color;canvas.fillRect(0,0,1,1);return [...canvas.getImageData(0,0,1,1).data].slice(0,3);
});

// THM-2.4-04: LCD windows stay dark in the day theme, while the metal around them goes light.
for(const theme of ['night','day'])test(`THM-2.4-04 the LCD windows stay dark in the ${theme} theme`,async({page})=>{
 await open(page,{theme});
 for(const selector of ['.mfd-screen','.fd-strip','.ck-tape']){
  const colours=await surfaceColours(page,selector);expect(colours.length,selector+' paints something').toBeGreaterThan(0);
  for(const colour of colours)expect(luminance(colour),`${selector} ${colour} is dark in ${theme}`).toBeLessThan(0.05);
 }
 const metal=await surfaceColours(page,'.pk');expect(metal.length).toBeGreaterThan(0);
 for(const colour of metal)theme==='day'?expect(luminance(colour),'metal is light in day').toBeGreaterThan(0.3):expect(luminance(colour),'metal is dark at night').toBeLessThan(0.1);
});

// THM-10-02: text on metal reaches 4.5:1 and the LCD status bars 3:1, in both themes (inactive and decorative text
// is exempt, so only the page keys, engine keys and bar segments are measured).
for(const theme of ['night','day'])test(`THM-10-02 metal text reaches 4.5:1 and LCD status bars 3:1 in ${theme}`,async({page})=>{
 const data=visualFixture().data;data.details=null;
 [75,40,20,75].forEach((value,i)=>{for(const w of data.projection.rows[i].accounts[0].windows)w.remainingPercent=value;});
 for(const [i,group] of data.subscriptions.entries())group.accounts[0].account.windows=structuredClone(data.projection.rows[i].accounts[0].windows);
 await open(page,{data,theme});
 for(const [text,surface] of [['.pk','.pk'],['.ek-name','.ek']]){
  const ink=await inkOf(page,text),behind=await surfaceColours(page,surface);expect(behind.length).toBeGreaterThan(0);
  for(const colour of behind)expect(contrast(ink,colour),`${text} on ${surface} ${theme}`).toBeGreaterThanOrEqual(4.5);
 }
 const lcd=await surfaceColours(page,'.fd-strip');
 for(const level of ['ok','mid','low']){
  const bar=page.locator(`.qcell.lv-${level} .qbar i.on`).first();await expect(bar).toHaveCount(1);
  const [paint]=await bar.evaluate(e=>{const c=document.createElement('canvas').getContext('2d',{willReadFrequently:true});c.canvas.width=c.canvas.height=1;c.fillStyle=getComputedStyle(e).backgroundColor;c.fillRect(0,0,1,1);return [[...c.getImageData(0,0,1,1).data].slice(0,3)];});
  for(const colour of lcd)expect(contrast(paint,colour),`${level} bar ${paint} on LCD ${colour} in ${theme}`).toBeGreaterThanOrEqual(3);
 }
});

// COL-2.1-15: the grey-logo vendors keep identity colours close to their real brand colours on the engine keys.
test('COL-2.1-15 Cursor, Copilot and OpenCode keys carry their brand-near accents',async({page})=>{
 await open(page,{data:fixture(['cursor','copilot','opencode','glm'])});
 const accents=await page.locator('.eng-keys .ek[data-sub] .bl').evaluateAll(l=>l.map(e=>e.getAttribute('style')));
 expect(accents.slice(0,3).map(s=>/--v:\s*(#[0-9a-f]{6})/i.exec(s)?.[1].toLowerCase())).toEqual(['#eef2f6','#c08cff','#b5d65a']);
});

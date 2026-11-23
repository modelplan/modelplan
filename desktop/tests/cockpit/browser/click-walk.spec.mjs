// SPDX-License-Identifier: MIT
// Seeded, replayable exploration of the real bridge and the visible cockpit controls.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {mkdir,writeFile} from 'node:fs/promises';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {walkScenarios,WALK_CLOCK} from '../walk-fixtures.mjs';
import {expectedWalkFailures} from '../walk-expected-failures.mjs';
import {watch,timingVerdict} from '../walk-timing.mjs';
import {replayTargetMatches} from '../walk-replay.mjs';
import {setTimeout as delay} from 'node:timers/promises';

const output=fileURLToPath(new URL('../.tmp/walk/',import.meta.url));
const long=process.env.COCKPIT_WALK_LONG==='1';
const replay=process.env.COCKPIT_WALK_REPLAY?JSON.parse(readFileSync(process.env.COCKPIT_WALK_REPLAY,'utf8')):null;
const clock=replay?.clock??WALK_CLOCK;
test.use({timezoneId:'UTC'});
const selectors=[
 '[data-range-key]', '[data-caution]', '.mfd-pk .pk', '.eng-krow [data-all]', '.eng-keys .ek[data-sub]',
 '.eng-keys .pl-key', '.eng-pg button:not([aria-disabled="true"])', '.hud .hp',
 '.mfd-ok .ok [data-choice]', '.mfd-page .md-row', '.fd-ch:not(.empty) .fd-strip',
 '.cmp-lad [data-mfd^="try:"]', '[data-bank]', '.pl-screen-x',
 '.mfd-page [data-mfd^="scope:"]', '.mfd-page .pc-hit[data-mfd^="try:"]',
 '.mfd-ok button[data-mfd="fast"]', '.mfd-ok button[data-mfd="back"]',
 '.mfd-page button[data-mfd="back"]', '.pl-screen .wk-dh', '.fd-scale .sc-l:not(.na)',
];
const topSelectors=new Set(['[data-range-key]','[data-caution]','.mfd-pk .pk','.eng-krow [data-all]','.eng-keys .ek[data-sub]','.eng-keys .pl-key','.eng-pg button:not([aria-disabled="true"])','.hud .hp']);
const random=seed=>()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed;};

async function choices(page){
 return page.evaluate(selectors=>selectors.flatMap(selector=>[...document.querySelectorAll(selector)].flatMap((el,index)=>{
  const r=el.getBoundingClientRect(),s=getComputedStyle(el),x=r.left+r.width/2,y=r.top+r.height/2,hit=document.elementFromPoint(x,y);
  if(!r.width||!r.height||s.visibility==='hidden'||s.display==='none'||!hit||!(hit===el||el.contains(hit)))return [];
  return [{selector,index,label:el.getAttribute('aria-label')||el.getAttribute('data-choice')||el.textContent.trim(),key:el.getAttribute('data-range-key')||el.getAttribute('data-mfd')||el.getAttribute('data-plugin')||el.getAttribute('data-hud-model')||el.getAttribute('data-sub')||el.getAttribute('data-bpage')||el.getAttribute('data-focus')||el.getAttribute('data-strip'),choice:el.getAttribute('data-choice'),option:el.closest('[data-opt]')?.getAttribute('data-opt')}];
 })),selectors);
}

async function inspect(page,checkPointer=false){
 return page.evaluate(checkPointer=>{
  const p=document.querySelector('.mfd-page'),overlay=[...document.querySelectorAll('.mfd-screen .pl-screen')],selected=[...document.querySelectorAll('.mfd-pk .pk[aria-pressed="true"]')],header=[...document.querySelectorAll('[data-range-key][aria-checked="true"]')];
  const range=header[0]?.getAttribute('data-range-key'),opt=document.querySelector('.mfd-ok [data-opt="range"] b.on')?.getAttribute('data-choice');
  const violations=[];
  if(!p||overlay.length>1)violations.push('one lower-panel view');
  if(header.length!==1)violations.push('one header range');
  if(!overlay.length&&!p?.classList.contains('pg-compare')&&!p?.classList.contains('pg-alerts')){
   if(selected.length!==1||!p?.classList.contains('pg-'+selected[0]?.getAttribute('data-mfd')?.split(':')[1]))violations.push('page key matches view');
  }
  if(overlay.length&&document.querySelector(`.eng-keys .pl-key[data-plugin="${overlay[0].dataset.plugin}"]`)?.getAttribute('aria-expanded')!=='true')violations.push('plugin key matches view');
  if(p?.querySelector('.cal-wk,.pl-screen'))violations.push('plugin content in page');
  const foreign={overview:'.sp-now,.sa-list,.md-list,.cmp-lad',sub:'.ov-top,.ov-chart,.md-list,.cmp-lad',tune:'.ov-top,.ov-chart,.sp-now,.sa-list,.cmp-lad',where:'.ov-top,.ov-chart,.sp-now,.sa-list,.md-list,.cmp-lad',compare:'.ov-top,.ov-chart,.sp-now,.sa-list,.md-list'};
  for(const [id,selector] of Object.entries(foreign))if(p?.classList.contains('pg-'+id)&&p.querySelector(selector))violations.push(`foreign content in ${id}`);
  if(opt&&opt!==range)violations.push(`range mismatch ${range}/${opt}`);
  const stats=p?.querySelector('.sp-stats[data-days]')?.getAttribute('data-days');
  if(stats&&stats!==({today:'today','7d':'7','30d':'30'})[range])violations.push(`statistics range mismatch ${range}/${stats}`);
  const chart=p?.querySelector('.ov-chart[data-buckets]')?.getAttribute('data-buckets');
  if(chart&&Number(chart)!==({today:24,'7d':7,'30d':30})[range])violations.push(`chart range mismatch ${range}/${chart}`);
  const overviewLabel=p?.classList.contains('pg-overview')&&!overlay.length?p.querySelector('.ov-top .lbl')?.textContent?.trim():null;
  if(overviewLabel&&['今天','7天','30天'].includes(overviewLabel)&&overviewLabel!==({today:'今天','7d':'7天','30d':'30天'})[range])violations.push(`overview range mismatch ${range}/${overviewLabel}`);
  const ring=[...document.querySelectorAll('body *')].filter(e=>{if(!e.matches(':focus-visible'))return false;const s=getComputedStyle(e),b=getComputedStyle(e,'::before');return s.outlineStyle!=='none'&&parseFloat(s.outlineWidth)>0||b.content!=='none'&&parseFloat(b.borderTopWidth)>0;});
  if(checkPointer&&ring.length)violations.push('focus ring after pointer');
  const view=overlay[0]||p,box=view?.getBoundingClientRect();
  if(view&&box)for(const e of view.querySelectorAll('button,svg')){const r=e.getBoundingClientRect(),s=getComputedStyle(e);if(r.width&&r.height&&s.visibility!=='hidden'&&(r.left<box.left-1||r.right>box.right+1||r.top<box.top-1||r.bottom>box.bottom+1))violations.push(`view overflow ${e.className?.baseVal||e.className}`);}
  // Measure the rendered text itself, including descendants of overflow containers; fully offscreen scroll rows are not visible.
  const root=document.querySelector('#cockpit'),walker=document.createTreeWalker(root,NodeFilter.SHOW_TEXT);
  while(walker.nextNode()){
   const node=walker.currentNode,e=node.parentElement;if(!node.textContent.trim()||!e||overlay.length&&p?.contains(e))continue;
   const style=getComputedStyle(e),elementBox=e.getBoundingClientRect();if(style.visibility==='hidden'||style.display==='none'||elementBox.width<=1&&elementBox.height<=1&&style.clipPath==='inset(50%)')continue;
   const text=document.createRange();text.selectNodeContents(node);
   for(const rect of text.getClientRects()){
    if(!rect.width||!rect.height)continue;
    for(let parent=e;parent&&parent!==root;parent=parent.parentElement){const s=getComputedStyle(parent),r=parent.getBoundingClientRect(),clipX=s.display!=='inline'&&/^(hidden|clip|auto|scroll)$/.test(s.overflowX),clipY=s.display!=='inline'&&/^(hidden|clip|auto|scroll)$/.test(s.overflowY);if(!clipX&&!clipY)continue;
     if(rect.right<=r.left||rect.left>=r.right||rect.bottom<=r.top||rect.top>=r.bottom)break;
     if(clipX&&(rect.left<r.left-1||rect.right>r.right+1)||clipY&&(rect.top<r.top-1||rect.bottom>r.bottom+1)){const fontBoxOnly=rect.left>=r.left-1&&rect.right<=r.right+1&&rect.top>=r.top-2.5&&rect.bottom<=r.bottom+1.5;const named=fontBoxOnly&&parent.matches('.mfd-pk .pk > span')?'.mfd-pk .pk > span':fontBoxOnly&&parent.matches('.pl-foot .pl-fit')?'.pl-foot .pl-fit':fontBoxOnly&&parent.matches('.mfd-ok .ok-l')?'.mfd-ok .ok-l':fontBoxOnly&&parent.matches('.sp-h b')?'.sp-h b':parent.matches('.eng-keys[data-slots="6"] .ek-name')&&e.textContent==='Claude Code'&&rect.right-r.right<=9&&rect.left>=r.left-1&&rect.top>=r.top-1&&rect.bottom<=r.bottom+1?'.eng-keys .ek-name Claude Code':null;violations.push(named?`clipped text ${named}`:`clipped text ${e.outerHTML.slice(0,140)} in ${parent.outerHTML.slice(0,150)} (${s.display} ${s.overflowX}/${s.overflowY}, ${r.width}x${r.height}): ${Math.round(rect.left-r.left)},${Math.round(rect.right-r.right)},${Math.round(rect.top-r.top)},${Math.round(rect.bottom-r.bottom)}`);break;}
    }
   }
  }
  return {violations,range,page:p?.className,content:(overlay[0]||p)?.textContent,overviewTotal:p?.querySelector('.ov-top .ov-total')?.textContent??null,plugin:overlay[0]?.dataset.plugin??null,selected:selected.map(e=>e.getAttribute('data-mfd')),choices:[...document.querySelectorAll('.mfd-ok [data-opt]')].map(e=>[e.getAttribute('data-opt'),e.querySelector('b.on')?.getAttribute('data-choice')]),scope:document.querySelector('.eng-keys .ek[aria-pressed="true"]')?.getAttribute('data-sub')??'all',hud:document.querySelector('.hud .hp.selected')?.getAttribute('data-hud-model')??null,pager:document.querySelector('.eng-pgn')?.textContent??null,faders:[...document.querySelectorAll('.fd-ch:not(.empty)')].map(e=>[e.className,e.querySelector('.fd-strip')?.textContent]),picks:[...document.querySelectorAll('.mfd-screen .sel,.mfd-screen .trial')].map(e=>[e.className?.baseVal||e.className,e.getAttribute('data-mfd'),e.textContent])};
 },checkPointer);
}

for(const scenario of walkScenarios(clock).filter(s=>!replay||s.name===replay.scenario))test(`click walk: ${scenario.name}`,async({page})=>{
 test.setTimeout(long?900000:120000);
 const path=[],operations=[],seen=new Set(),errors=[],known=new Set(),timings=[];let slowest=0;
 page.on('pageerror',e=>errors.push({kind:'pageerror',message:e.message}));page.on('console',m=>{if(m.type()==='error')errors.push({kind:'console',message:m.text(),url:m.location().url});});
 await mkdir(output,{recursive:true});await page.clock.setFixedTime(new Date(clock));await page.addInitScript(watch);
 await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};});
 let send=commands();const receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 const boot=async(data)=>{
  path.push(`BOOT ${scenario.name} ${data?'display':'loading'}`);
  operations.push({type:'boot',data:data?'display':'loading'});
  send=commands();await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
  expect(await receive(send('load',{appearance:{...appearance,locale:'zh-CN'},shell,redBelow:25}))).toBe(true);
  expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
  expect(await receive(send('plugins',{plugins:scenario.plugins}))).toBe(true);
  if(data){expect(await receive(send('display',{data}))).toBe(true);await page.evaluate(()=>{window.__walk.displayAt=performance.now();});}
  await snapshot();
 };
 const snapshot=async(checkPointer=false)=>{const state=await inspect(page,checkPointer),key=JSON.stringify(state),id=createHash('sha256').update(key).digest('hex').slice(0,16);if(!seen.has(key)){seen.add(key);await page.screenshot({path:`${output}${scenario.name}-${id}.png`});}return state;};
 const step=async(action)=>{
  path.push(action==='Escape'?'Escape':`${action.selector} [${action.index}] ${action.label}`);
  operations.push(action==='Escape'?{type:'escape'}:{type:'click',action});
  const prior=await inspect(page);
  const before=await page.evaluate(()=>window.__walk.results.length);
  if(action==='Escape')await page.keyboard.press('Escape');else{const actual=(await choices(page)).find(x=>x.selector===action.selector&&x.index===action.index);expect(replayTargetMatches(action,actual),`click target ${action.label}`).toBe(true);const r=await page.locator(action.selector).nth(action.index).boundingBox();expect(r,'click target').not.toBeNull();await page.mouse.click(r.x+r.width/2,r.y+r.height/2);}
  // Poll from Node rather than scheduling page timers that would themselves be measured.
  let ready=false;for(let n=0;n<100&&!ready;n++){await delay(25);ready=await page.evaluate(n=>window.__walk.results.length>n,before);}expect(ready,'timing deadline observed').toBe(true);
  const timing=await page.evaluate(()=>window.__walk.results.at(-1));slowest=Math.max(slowest,timing.last-timing.start);
  timings.push({step:path.at(-1),ms:timing.last-timing.start});
  const state=await snapshot(action!=='Escape');
  const verdict=timingVerdict(timing);if(verdict.expected)known.add(expectedWalkFailures.find(x=>x.kind==='timing'&&x.message===verdict.expected).name);
  expect(verdict.failure??null,'interaction timing').toBeNull();
  const unexpectedGeometry=state.violations.filter(message=>{const failure=expectedWalkFailures.find(x=>x.kind==='geometry'&&x.message===message);if(failure)known.add(failure.name);return !failure;});
  expect(unexpectedGeometry).toEqual([]);
  const normal=value=>value?.replace(/http:\/\/127\.0\.0\.1:\d+/g,'http://127.0.0.1:41783');
  const unexpected=errors.filter(error=>{const failure=expectedWalkFailures.find(x=>x.kind===error.kind&&x.message===normal(error.message)&&(!x.url||x.url===normal(error.url)));if(failure)known.add(failure.name);return !failure;});
  expect(unexpected).toEqual([]);
  expect(await page.evaluate(()=>window.__walk.rejections)).toEqual([]);
  if(scenario.name==='one'&&!state.plugin&&state.page.includes('pg-overview'))expect(state.overviewTotal,'overview uses the selected fixture range').toBe(({today:'12k','7d':'1k','30d':'21k'})[state.range]);
  if(action!=='Escape'&&action.selector==='[data-range-key]')expect(state.range).toBe(action.key);
  if(action!=='Escape'&&action.selector==='.mfd-pk .pk'){expect(state.page).toContain('pg-'+action.key.split(':')[1]);expect(state.plugin).toBeNull();}
  if(action!=='Escape'&&action.selector==='.hud .hp'){expect(state.page).toContain('pg-tune');expect(state.hud).toBe(action.key);expect(state.plugin).toBeNull();}
  if(action!=='Escape'&&action.selector==='.eng-keys .pl-key')expect(state.plugin).toBe(prior.plugin===action.key?null:action.key);
  if(action!=='Escape'&&action.selector==='.eng-keys .ek[data-sub]')expect(state.scope).toBe(prior.scope===action.key?'all':action.key);
  if(action!=='Escape'&&action.selector==='.pl-screen-x')expect(state.plugin).toBeNull();
  if(action!=='Escape'&&action.selector==='.pl-screen .wk-dh')await expect(page.locator(action.selector).nth(action.index)).toHaveAttribute('aria-pressed','true');
  if(action!=='Escape'&&action.selector==='[data-caution]'&&prior.plugin){expect(state.plugin).toBeNull();expect(state.page).toContain('pg-alerts');}
  if(action!=='Escape'&&action.selector==='.mfd-ok .ok [data-choice]')expect(state.choices).toContainEqual([action.option,action.choice]);
  if(action!=='Escape'&&action.selector==='.mfd-page .md-row')expect(state.picks.some(p=>p[1]===action.key)).toBe(true);
  if(action==='Escape'&&prior.plugin)expect(state.plugin).toBeNull();
 };
 try{
  if(replay){
   for(const op of replay.operations){
    if(op.type==='boot')await boot(op.data==='loading'?null:scenario.data??scenario.afterLoading);
    else if(op.type==='display'){path.push('DISPLAY afterLoading');operations.push(op);expect(await receive(send('display',{data:scenario.afterLoading}))).toBe(true);await page.evaluate(()=>{window.__walk.displayAt=performance.now();});await snapshot();}
    else if(op.type==='escape')await step('Escape');
    else if(op.type==='click')await step(op.action);
    else throw Error(`Unknown replay operation ${op.type}`);
   }
  }else{
  await boot(scenario.data);
  if(scenario.afterLoading){await step((await choices(page)).find(a=>a.selector==='[data-range-key]'));path.push('DISPLAY afterLoading');operations.push({type:'display'});expect(await receive(send('display',{data:scenario.afterLoading}))).toBe(true);await page.evaluate(()=>{window.__walk.displayAt=performance.now();});await snapshot();}
  const next=random(0xc0c01123),count=long?200:8;
  for(let i=0;i<count;i++){const actions=await choices(page);expect(actions.length).toBeGreaterThan(0);await step(i%17===16?'Escape':actions[next()%actions.length]);if(process.env.COCKPIT_WALK_FORCE_FAILURE==='1'&&scenario.name==='empty'&&i===0)throw Error('synthetic walk artifact probe');if(long&&(i+1)%50===0)console.log(`walk ${scenario.name}: ${i+1}/${count} random steps`);}
  // Each ordered pair starts from the same fixture. The long run enumerates all controls reachable directly after A;
  // the short CI run samples pairs. A subscription on a later engine page is reached by its pager first.
  const data=scenario.data??scenario.afterLoading,top=a=>topSelectors.has(a.selector),same=(a,b)=>a.selector===b.selector&&a.key===b.key;
  await boot(data);
  const first=await choices(page),all=first.filter(top).map(a=>({...a,setup:[]}));
  const forward=first.find(a=>a.selector.startsWith('.eng-pg')&&a.key==='1');
  if(forward){await step(forward);for(const a of (await choices(page)).filter(top))if(!all.some(x=>same(x,a)))all.push({...a,setup:[forward]});}
  const targets=long?all:all.slice(0,1);
  for(const a of targets){
   if(long)console.log(`walk ${scenario.name}: pairs from ${a.selector} ${a.label}`);
   const prepare=async()=>{await boot(data);for(const prerequisite of a.setup){const next=(await choices(page)).find(x=>same(x,prerequisite));expect(next,`reachable prerequisite ${prerequisite.label}`).toBeTruthy();await step(next);}const current=(await choices(page)).find(x=>same(x,a));expect(current,`reachable first control ${a.label}`).toBeTruthy();await step(current);};
   await prepare();const seconds=(await choices(page)).filter(top),sample=long?seconds:seconds.slice(0,3);
   if(long)for(const b of seconds)if(!all.some(x=>same(x,b)))all.push({...b,setup:[...a.setup,{selector:a.selector,key:a.key,label:a.label}]});
   for(const b of sample){await prepare();const current=(await choices(page)).find(x=>same(x,b));expect(current,`reachable second control ${b.label}`).toBeTruthy();await step(current);}
  }
  // The owner's reported transition is always included in the short run when both controls exist.
  await boot(data);let current=await choices(page),cal=current.find(a=>a.selector==='.eng-keys .pl-key'&&a.key==='calendar');
  if(!cal&&scenario.plugins.entries.find(e=>e.id==='calendar')?.enabled){const nextPage=current.find(a=>a.selector.startsWith('.eng-pg')&&a.key==='1');if(nextPage){await step(nextPage);current=await choices(page);cal=current.find(a=>a.selector==='.eng-keys .pl-key'&&a.key==='calendar');}expect(cal,'enabled Calendar key').toBeTruthy();}
  if(cal){await step(cal);const hud=(await choices(page)).find(a=>a.selector==='.hud .hp');if(hud){await step(hud);expect((await inspect(page)).plugin).toBeNull();}
   const calendar=(await choices(page)).find(a=>a.selector==='.eng-keys .pl-key'&&a.key==='calendar');expect(calendar).toBeTruthy();await step(calendar);
   const alert=(await choices(page)).find(a=>a.selector==='[data-caution]');expect(alert).toBeTruthy();await step(alert);}
  }
 }catch(e){await page.screenshot({path:`${output}${scenario.name}-failure.png`});const replayFile=`${output}${scenario.name}-failure.json`;await writeFile(replayFile,JSON.stringify({scenario:scenario.name,seed:'0xc0c01123',clock,timezone:'UTC',operations},null,2));const monitor=await page.evaluate(()=>({current:window.__walk.current,results:window.__walk.results.slice(-3),rejections:window.__walk.rejections}));throw Error(`${e.message}\nScenario ${scenario.name}; replay: COCKPIT_WALK_REPLAY=${replayFile}; monitor ${JSON.stringify(monitor)}; path:\n${path.join('\n')}`);}
 finally{console.log(`walk ${scenario.name}: ${timings.length} steps; slowest ${slowest.toFixed(1)} ms; ${seen.size} states; expected failures: ${[...known].join(', ')||'none'}; slowest steps: ${JSON.stringify(timings.sort((a,b)=>b.ms-a.ms).slice(0,5))}`);}
});

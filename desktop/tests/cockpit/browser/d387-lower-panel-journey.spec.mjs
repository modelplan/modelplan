// SPDX-License-Identifier: MIT
// D387 / G3-173..175: the lower panel shows exactly one view at a time. A state machine walks overview, each subscription,
// Calendar, Resources and the HUD big chart in several orders and across range switches; at every step the visible
// panel content and the active key are asserted. Synthetic data only.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell,excludePortholeFlicker} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';
test.beforeEach(async({page})=>excludePortholeFlicker(page));
const effort=(key,ability,cost,star=false)=>({effort:key,label:key,star,ability,cost,time:30});
const model=(id,ability,cost)=>({id,name:'Synthetic '+id,developerId:'openai',recommended:'high',efforts:[effort('low',ability-8,cost/3),effort('high',ability,cost,true)]});
const models=Array.from({length:8},(_,i)=>model('m'+i,40+i,.1*(i+1)));
const on={version:1,entries:[{id:'calendar',enabled:true,pinned:false},{id:'resources',enabled:true,pinned:false}],settings:{}};
async function open(page){
 const {data}=visualFixture();data.details.publishedModels=models;
 await page.addInitScript(()=>{window.__actions=[];window.webkit={messageHandlers:{cockpit:{postMessage(raw){const m=JSON.parse(raw);if(m.type==='action')window.__actions.push(m.action??m.payload?.action);}}}};});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance,shell:{...shell,range:'7d'},redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('plugins',{plugins:on}))).toBe(true);
 expect(await receive(send('display',{data}))).toBe(true);
 return {send,receive};
}
// What the owner sees: which lower-panel view is visible, which keys are lit, what the Overview tab reads.
const snap=page=>page.evaluate(()=>{
 const shown=e=>!!e&&!e.hidden&&e.getClientRects().length>0;
 const screen=document.querySelector('.dk-mfd .pl-screen'),pg=document.querySelector('.dk-mfd .mfd-page');
 const pageKeys=[...document.querySelectorAll('.dk-mfd .mfd-pk > .pk[data-mfd^="page:"]')].filter(shown);
 const seg=document.querySelector('.dk-mfd .mfd-pk .pk-seg'),tabs=shown(seg)?[...seg.querySelectorAll('[role=tab]')]:[];
 const plugins=Object.fromEntries([...document.querySelectorAll('.eng-keys .pl-key')].map(k=>[k.dataset.plugin,{on:k.classList.contains('on'),pressed:k.getAttribute('aria-pressed')}]));
 return {
  plugin:shown(screen)?screen.dataset.plugin:null,
  page:shown(pg)?[...pg.classList].find(c=>c.startsWith('pg-')):null,
  pageKeysOn:pageKeys.filter(k=>k.getAttribute('aria-pressed')==='true').map(k=>k.dataset.mfd.slice(5)),
  overviewKeyShown:pageKeys.some(k=>k.dataset.mfd==='page:overview'),
  tablist:shown(seg)?seg.getAttribute('role'):null,
  tabs:tabs.map(t=>({text:t.textContent.trim(),selected:t.getAttribute('aria-selected')})),
  options:[...document.querySelectorAll('.dk-mfd .mfd-ok [data-opt]')].length,
  oldBack:document.querySelectorAll('.dk-mfd .mfd-back,.dk-mfd .pl-screen-x').length,
  plugins,
 };});
// The expected state machine. A view is 'overview', 'plans', 'tune', 'where' (pages), 'calendar', 'resources' (plugin screens)
// (D400: a HUD click opens the Models page, 'tune', exactly as its key does.)
const PAGE={overview:'pg-overview',sub:'pg-sub',tune:'pg-tune',where:'pg-where'};
const SCREEN_NAME={calendar:'Calendar',resources:'Resources'};
const next=(view,action)=>{
 const [kind,arg]=action.split(':');
 switch(kind){
  case 'scope':return ['calendar','resources'].includes(view)?'overview':view;
  case 'plugin':return view===arg?'overview':arg;
  case 'hud':return 'tune';
  case 'page':return arg;
  case 'overviewtab':return 'overview';
  case 'esc':return ['calendar','resources'].includes(view)?'overview':view;
  default:return view;// range
 }};
async function expectView(page,view,label,{keys=true}={}){
 const s=await snap(page),at=`${label}: ${JSON.stringify(s)}`;
 const screen=['calendar','resources'].includes(view),big=screen;
 // Visible content: exactly the one view's own.
 if(screen){expect(s.plugin,at).toBe(view);expect(s.page,at).toBe(null);expect(s.options,at).toBe(0);}
 else{expect(s.plugin,at).toBe(null);expect(s.page,at).toBe(PAGE[view]);}
 if(view==='overview')expect(s.options,at).toBeGreaterThan(0);
 // Active key: the plugin key is lit exactly for its open screen; page keys follow the visible page (none under a plugin screen).
 expect(s.pageKeysOn,at).toEqual(screen?[]:[view]);
 expect(s.oldBack,at).toBe(0);
 if(!keys)return;
 for(const id of ['calendar','resources'])expect(s.plugins[id],at).toEqual({on:view===id,pressed:String(view===id)});
 // The Overview tab: plain "Overview" key, or the two-way switch "Overview | <screen>" with the screen tab selected.
 if(big){expect(s.overviewKeyShown,at).toBe(false);expect(s.tablist,at).toBe('tablist');expect(s.tabs,at).toEqual([{text:'Overview',selected:'false'},{text:SCREEN_NAME[view],selected:'true'}]);}
 else{expect(s.overviewKeyShown,at).toBe(true);expect(s.tablist,at).toBe(null);}
}
const act={
 'scope:1':page=>page.keyboard.press('1'),
 'scope:0':page=>page.keyboard.press('0'),
 'plugin:calendar':page=>page.locator('.eng-keys .pl-key[data-plugin="calendar"]').click(),
 'plugin:resources':page=>page.locator('.eng-keys .pl-key[data-plugin="resources"]').click(),
 'hud':page=>page.locator('.hud .hp').first().click(),
 'page:overview':page=>page.locator('[data-mfd="page:overview"]').click(),
 'page:sub':page=>page.locator('[data-mfd="page:sub"]').click(),
 'page:where':page=>page.locator('[data-mfd="page:where"]').click(),
 'overviewtab':page=>page.getByRole('tab',{name:'Overview'}).click(),
 'esc':page=>page.keyboard.press('Escape'),
 'range:today':page=>page.locator('[data-range-key="today"]').click(),
 'range:30d':page=>page.locator('[data-range-key="30d"]').click(),
};
async function walk(page,actions,opts){
 let view='overview';await expectView(page,view,'start',opts);
 for(const [i,a] of actions.entries()){
  if(a==='overviewtab'&&!['calendar','resources'].includes(view))continue;// the switch exists only over a screen
  if(a==='page:overview'&&['calendar','resources'].includes(view))continue;// over a screen the Overview key is the switch's tab
  if(a==='hud')await page.waitForTimeout(350);// a porthole press right after a repaint can be a drag
  await act[a](page);view=next(view,a);await page.waitForTimeout(60);await expectView(page,view,`#${i} ${a} -> ${view}`,opts);
 }
}
test('D387 every order of overview, subscription, Calendar, Resources and HUD chart shows only its own view',async({page})=>{
 await open(page);
 await walk(page,['scope:1','plugin:calendar','plugin:resources','hud','overviewtab','plugin:resources','scope:0','plugin:calendar','plugin:calendar','hud','page:sub','plugin:calendar','page:where','hud','plugin:resources','overviewtab']);
 await walk(page,['hud','plugin:calendar','hud','esc','plugin:resources','esc','plugin:calendar','plugin:resources','plugin:calendar','overviewtab','page:sub','hud','page:overview']);
});
// The leak: a screen's content must never share the panel with another view's content (page, bottom keys, a second screen).
test('D387 content only: each lower-panel view renders only its own content, whatever order the views were opened in',async({page})=>{
 await open(page);
 await walk(page,['plugin:calendar','scope:1','plugin:resources','hud','plugin:calendar','page:sub','plugin:resources','page:overview','plugin:calendar','hud','page:where','plugin:calendar','overviewtab'],{keys:false});
});
test('D387 range switches never change which view is open or what it shows',async({page})=>{
 await open(page);
 await walk(page,['plugin:calendar','range:30d','plugin:resources','range:today','overviewtab','range:30d','scope:1','plugin:calendar','range:today','overviewtab','hud','range:30d','overviewtab','page:sub','range:today','plugin:resources','range:30d','page:overview']);
});
test('D387 a seeded walk over every transition keeps the view and the key in step',async({page})=>{
 await open(page);
 const names=Object.keys(act);let seed=387;const rnd=()=>(seed=(seed*1103515245+12345)&0x7fffffff)/0x7fffffff;
 await walk(page,Array.from({length:50},()=>names[Math.floor(rnd()*names.length)]));
});
test('D387 the Overview key reads "Overview" alone on the overview and every plain page',async({page})=>{
 await open(page);
 await expect(page.locator('[data-mfd="page:overview"]')).toHaveText('Overview');
 await page.locator('[data-mfd="page:sub"]').click();
 await expect(page.locator('[data-mfd="page:overview"]')).toHaveText('Overview');await expect(page.getByRole('tablist')).toHaveCount(0);
});
test('D387 the switch is keyboard operable: arrows move between its tabs, Enter on Overview returns, Escape returns',async({page})=>{
 await open(page);
 await page.locator('.eng-keys .pl-key[data-plugin="calendar"]').click();
 const tabs=page.getByRole('tab');await expect(tabs).toHaveCount(2);
 await tabs.nth(1).focus();await page.keyboard.press('ArrowLeft');await expect(tabs.nth(0)).toBeFocused();
 await page.keyboard.press('Enter');await expectView(page,'overview','enter');
 await page.locator('.eng-keys .pl-key[data-plugin="resources"]').click();await expectView(page,'resources','reopen');
 await page.keyboard.press('Escape');await expectView(page,'overview','esc');
 await page.locator('.hud .hp').first().click();await expectView(page,'tune','hud');
 await page.keyboard.press('Escape');await expectView(page,'tune','hud esc: the page stays, as from its key');
});
test('D387 the Calendar and Resources keys press and light like a subscription key',async({page})=>{
 await open(page);
 for(const id of ['calendar','resources']){
  const key=page.locator(`.eng-keys .pl-key[data-plugin="${id}"]`);
  await key.click();await expect(key).toHaveClass(/\bon\b/);await expect(key).toHaveAttribute('aria-pressed','true');
  const sub=page.locator('.eng-keys .ek[data-sub].on').first();
  if(await sub.count()){const a=await sub.evaluate(e=>{const c=getComputedStyle(e);return [c.transform,c.boxShadow,c.backgroundImage];});const b=await key.evaluate(e=>{const c=getComputedStyle(e);return [c.transform,c.boxShadow,c.backgroundImage];});expect(b).toEqual(a);}
  await key.click();await expect(key).not.toHaveClass(/\bon\b/);await expect(key).toHaveAttribute('aria-pressed','false');
 }
});

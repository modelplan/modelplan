// SPDX-License-Identifier: MIT
// Cockpit recovery step 2 (G3-96, G3-116): a display whose render throws is refused, the built page stays loaded with
// the last rendered data on screen, and the next good display renders. The host's correlated health probe names its
// page: another page id is a mismatch, never an answer. Built page, normal bridge, real Go capture.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,capture,commands,pageId,shell,excludePortholeFlicker} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';

test.beforeEach(async({page})=>excludePortholeFlicker(page));
async function open(page){
  await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};});
  await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
  const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
  expect(await receive(send('load',{appearance,shell,redBelow:25}))).toBe(true);
  expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
  return {send,receive};
}
const engine=page=>page.evaluate(()=>document.querySelector('#cockpit .ck-engine, #cockpit [class*="engine"]')?.innerHTML??document.getElementById('cockpit').innerHTML);
test('S1: a refused publication preserves the comparison even when the previous-data repaint succeeds',async({page})=>{
  const {send,receive}=await open(page),data=visualFixture().data;
  data.details.publication={contractVersion:1,publicationId:'0123456789abcdef01234567',publishedAt:'2026-10-24T12:00:00Z',source:'client',truncated:false,models:[
    {id:'model-a',name:'Synthetic A',developerId:'openai',recommended:'medium',efforts:[{effort:'medium',label:'Med',star:true,ability:40,cost:2,time:null}]},
  ]};
  expect(await receive(send('display',{data}))).toBe(true);
  await page.locator('.fd-ch:not(.empty) .fd-strip').first().click();
  await expect(page.locator('.mfd-page.pg-compare')).toBeVisible();
  const next=structuredClone(data);next.details.publication.publicationId='fedcba9876543210fedcba98';
  const refused=await page.evaluate(raw=>{
    const append=Element.prototype.append,replace=Element.prototype.replaceChildren;let failed=false;
    const gate=original=>function(...nodes){if(!failed&&this.closest?.('.hud')){failed=true;throw Error('synthetic HUD failure');}return original.apply(this,nodes);};
    Element.prototype.append=gate(append);Element.prototype.replaceChildren=gate(replace);
    try{return {accepted:window.modelPlanCockpit.receive(raw),reject:window.modelPlanCockpit.reject(),failed};}
    finally{Element.prototype.append=append;Element.prototype.replaceChildren=replace;}
  },send('display',{data:next}));
  expect(refused).toEqual({accepted:false,reject:'display.render',failed:true});
  await expect(page.locator('.mfd-page.pg-compare')).toBeVisible();
  expect(await receive(send('tick',{nowUnixMs:String(Date.now()),reason:'deadline'}))).toBe(true);
  await expect(page.locator('.mfd-page.pg-compare')).toBeVisible();
});

test('S2: deck checkpoints restore the selected page, alert overlay and tune return target after clear',async({page})=>{
  await open(page);
  const fixture=visualFixture();
  fixture.data.details.publication={contractVersion:1,publicationId:'0123456789abcdef01234567',publishedAt:'2026-10-24T12:00:00Z',source:'client',truncated:false,models:[
    {id:'sol',name:'Synthetic A',developerId:'openai',recommended:'medium',efforts:[{effort:'medium',label:'Med',star:true,ability:40,cost:2,time:null}]},
  ]};
  fixture.data.details.publishedModels=fixture.data.details.publication.models;
  await page.evaluate(async fixture=>{
    const {mountPrototypeDeck}=await import('/src/prototype-deck.js');
    window.checkpointDeck=mountPrototypeDeck(document.querySelector('#cockpit'),undefined,{publication:fixture.publication,liveSessions:fixture.data.details.sessions,resetEvents:null,history:null});
    window.checkpointDeck.render(fixture.data,Date.now());
  },fixture);
  await page.locator('[data-mfd="page:sub"]').click();
  await page.evaluate(()=>window.checkpointDeck.showTune('sol'));
  const tune=await page.locator('.mfd-screen').innerHTML();
  expect(tune).toContain('Synthetic A');
  await page.evaluate(()=>{const d=window.checkpointDeck,restore=d.checkpoint();d.clear();restore();d.refresh();});
  expect(await page.locator('.mfd-screen').innerHTML()).toBe(tune);
  // D400: the Models page opened by the deck is the 模型 page itself; the Overview key leaves it.
  await page.locator('[data-mfd="page:overview"]').click();
  await expect(page.locator('[data-mfd="page:overview"]')).toHaveAttribute('aria-pressed','true');
  await page.evaluate(()=>window.checkpointDeck.showAlerts());
  const alerts=await page.locator('.mfd-screen').innerHTML();
  await page.evaluate(()=>{const d=window.checkpointDeck,restore=d.checkpoint();d.clear();restore();d.refresh();});
  expect(await page.evaluate(()=>window.checkpointDeck.alertsOpen())).toBe(true);
  expect(await page.locator('.mfd-screen').innerHTML()).toBe(alerts);
});
test('a render that throws keeps the page and its last rendered data; the next display renders',async({page})=>{
  const {send,receive}=await open(page);
  expect(await receive(send('display',{data:capture()}))).toBe(true);
  const before=await engine(page);
  const next=capture();next.projection.rows[0].name={en:'Replaced',zh:'已替换'};
  // One DOM append inside the render throws, as a view bug would; the restore of the last data then succeeds.
  const refused=await page.evaluate(raw=>{
    const original=Element.prototype.append;let armed=true;
    Element.prototype.append=function(...nodes){if(armed){armed=false;throw Error('synthetic render failure');}return original.apply(this,nodes);};
    try{return {accepted:window.modelPlanCockpit.receive(raw),reject:window.modelPlanCockpit.reject()};}
    finally{Element.prototype.append=original;}
  },send('display',{data:next}));
  expect(refused).toEqual({accepted:false,reject:'display.render'});
  expect(await page.evaluate(()=>!!window.modelPlanCockpit)).toBe(true);
  expect(await page.evaluate(()=>window.modelPlanCockpit.state())).toBe('ready');
  expect(await engine(page)).toBe(before);
  expect(await page.evaluate(()=>document.body.innerText.includes('Replaced'))).toBe(false);
  const after=capture();after.projection.rows[0].name={en:'Recovered',zh:'已恢复'};
  expect(await receive(send('display',{data:after}))).toBe(true);
});
test('when the repaint of the last data fails too, the previous view is put back as it was (glm-990-1)',async({page})=>{
  const {send,receive}=await open(page);
  expect(await receive(send('display',{data:capture()}))).toBe(true);
  const before=await engine(page);
  const next=capture();next.projection.rows[0].name={en:'Replaced',zh:'已替换'};
  // The failure persists: the new render and the repaint of the last data both throw on their first append.
  const refused=await page.evaluate(raw=>{
    const original=Element.prototype.append;let failures=2;
    Element.prototype.append=function(...nodes){if(failures>0){failures--;throw Error('synthetic render failure');}return original.apply(this,nodes);};
    try{return {accepted:window.modelPlanCockpit.receive(raw),reject:window.modelPlanCockpit.reject(),left:failures};}
    finally{Element.prototype.append=original;}
  },send('display',{data:next}));
  expect(refused).toEqual({accepted:false,reject:'display.render',left:0});
  expect(await page.evaluate(()=>window.modelPlanCockpit.state())).toBe('ready');
  expect(await engine(page)).toBe(before);
  expect(await page.evaluate(()=>document.body.innerText.includes('Replaced'))).toBe(false);
  const after=capture();after.projection.rows[0].name={en:'Recovered',zh:'已恢复'};
  expect(await receive(send('display',{data:after}))).toBe(true);
});
test('a failure that persists in the MFD/record surface keeps every committed control (macrev2-990-1, macrevb-990-1)',async({page})=>{
  const {send,receive}=await open(page);
  expect(await receive(send('display',{data:capture()}))).toBe(true);
  const view=()=>page.evaluate(()=>({footer:document.querySelector('.mfd-ok')?.innerHTML??'none',controls:document.querySelectorAll('.mfd-ok > *').length,
    cockpit:document.getElementById('cockpit').innerHTML}));
  const before=await view();
  expect(before.controls).toBeGreaterThan(0);
  const next=capture();next.projection.rows[0].name={en:'Replaced',zh:'已替换'};
  // Every append into the MFD footer throws for the whole delivery: the render, the repaint of the last data and
  // anything after them hit the same failure.
  const refused=await page.evaluate(raw=>{
    const original=Element.prototype.append;let hits=0;
    Element.prototype.append=function(...nodes){if(this.classList?.contains('mfd-ok')){hits++;throw Error('synthetic MFD failure');}return original.apply(this,nodes);};
    try{return {accepted:window.modelPlanCockpit.receive(raw),reject:window.modelPlanCockpit.reject(),hit:hits>0};}
    finally{Element.prototype.append=original;}
  },send('display',{data:next}));
  expect(refused).toEqual({accepted:false,reject:'display.render',hit:true});
  expect(await page.evaluate(()=>window.modelPlanCockpit.state())).toBe('ready');
  const after=await view();
  expect(after.controls).toBe(before.controls);
  expect(after.footer).toBe(before.footer);
  expect(after.cockpit).toBe(before.cockpit);
  const later=capture();later.projection.rows[0].name={en:'Recovered',zh:'已恢复'};
  expect(await receive(send('display',{data:later}))).toBe(true);
});
test('after a refused render the deck, tape and lamp repaint only committed data (glm-990-1)',async({page})=>{
  const NOW=Date.UTC(2026,9,29,12,30);await page.clock.setFixedTime(new Date(NOW));
  const {send,receive}=await open(page);
  expect(await receive(send('display',{data:capture()}))).toBe(true);
  const mfd=()=>page.evaluate(()=>document.querySelector('.mfd-screen')?.innerHTML??'none');
  const tape=()=>page.evaluate(()=>document.querySelector('.ck-tape')?.innerHTML??'none');
  const committed={mfd:await mfd(),tape:await tape()};
  const next=capture();
  for(const row of next.projection.rows)row.name={en:'Replaced',zh:'已替换'};
  for(const group of next.subscriptions)for(const member of group.accounts)member.account.plan.name={en:'Replaced',zh:'已替换'};
  for(const session of next.details?.recentSessions??[])if('project' in session)session.project='Replaced';
  // The first attempt fails in the HUD, after the deck and tape took the new data; the repaint of the committed data
  // fails at its first DOM write, before it reaches them. Only the snapshot rollback is left.
  const refused=await page.evaluate(raw=>{
    const append=Element.prototype.append,replace=Element.prototype.replaceChildren;let stage=0;
    const gate=function(original){return function(...nodes){
      if(stage===0&&this.closest?.('.hud')){stage=1;throw Error('synthetic HUD failure');}
      if(stage===1){stage=2;throw Error('synthetic repaint failure');}
      return original.apply(this,nodes);};};
    Element.prototype.append=gate(append);Element.prototype.replaceChildren=gate(replace);
    try{return {accepted:window.modelPlanCockpit.receive(raw),reject:window.modelPlanCockpit.reject(),stage};}
    finally{Element.prototype.append=append;Element.prototype.replaceChildren=replace;}
  },send('display',{data:next}));
  expect(refused).toEqual({accepted:false,reject:'display.render',stage:2});
  expect(await mfd()).toBe(committed.mfd);
  // A deadline tick repaints the deck and the lamp from their own state: it must be the committed data.
  expect(await receive(send('tick',{nowUnixMs:String(NOW),reason:'deadline'}))).toBe(true);
  expect(await mfd()).toBe(committed.mfd);
  expect(await tape()).toBe(committed.tape);
  expect(await page.evaluate(()=>document.getElementById('cockpit').innerText.includes('Replaced'))).toBe(false);
});
test('the correlated probe answers only for its own page',async({page})=>{
  await open(page);
  expect(await page.evaluate(id=>window.modelPlanCockpit.state(id),pageId)).toBe('ready');
  expect(await page.evaluate(id=>window.modelPlanCockpit.state(id.toUpperCase()),pageId)).toBe('ready');
  expect(await page.evaluate(()=>window.modelPlanCockpit.state('00000000-0000-4000-8000-00000000ffff'))).toBe('mismatch');
  expect(await page.evaluate(()=>window.modelPlanCockpit.state())).toBe('ready');
});

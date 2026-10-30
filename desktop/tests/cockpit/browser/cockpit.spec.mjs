// SPDX-License-Identifier: MIT
import { test,expect } from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import { appearance,commands,pageId,sample } from '../fixture.mjs';
import { setTimeout as sleep } from 'node:timers/promises';
import { writeFile,mkdir } from 'node:fs/promises';
import { dirname } from 'node:path';
async function open(page,options=appearance) {
  await page.addInitScript(()=>{
    const counts={requests:0,callbacks:0,timeouts:0,intervals:0};
    const raf=window.requestAnimationFrame.bind(window),timeout=window.setTimeout.bind(window),interval=window.setInterval.bind(window);
    window.requestAnimationFrame=callback=>{counts.requests++;return raf(time=>{counts.callbacks++;callback(time);});};
    window.setTimeout=(...args)=>{counts.timeouts++;return timeout(...args);};
    window.setInterval=(...args)=>{counts.intervals++;return interval(...args);};
    window.__counts=counts;window.__events=[];
    window.webkit={messageHandlers:{cockpit:{postMessage(raw){const message=JSON.parse(raw);window.__events.push({...message,privateAtClear:message.type==='cleared'?document.querySelector('.private-content').textContent:null});}}}};
    window.__resetCounts=()=>Object.keys(counts).forEach(key=>counts[key]=0);
    // Real browser callbacks/timing; only document.hidden is controlled because
    // headless WebKit has no native occlusion/key window. Not an OS visibility proof.
    window.__setHidden=value=>{Object.defineProperty(document,'hidden',{configurable:true,get:()=>value});document.dispatchEvent(new Event('visibilitychange'));};
  });
  await page.goto('/?pageId='+pageId);
  await page.waitForFunction(()=>!!window.modelPlanCockpit);
  const send=commands();
  expect(await receive(page,send('load',{appearance:options}))).toBe(true);
  return {send};
}
function receive(page,raw,method='receive') {return page.evaluate(({raw,method})=>window.modelPlanCockpit[method](raw),{raw,method});}
async function display(page,send,data=sample()) {
  expect(await receive(page,send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
  expect(await receive(page,send('display',{data}))).toBe(true);
}
test('browser rejects malformed/unknown input; private HTML is text and clear precedes acknowledgement',async({page})=>{
  const {send}=await open(page);
  const data=sample();data.projection.rows[0].name.en='<img src=x onerror="window.__xss=true"> PRIVATE-CANARY';
  await display(page,send,data);
  await expect(page.locator('.ck-eng')).toContainText('PRIVATE-CANARY');
  expect(await page.evaluate(()=>window.__xss)).toBeUndefined();
  expect(await page.locator('.private-content img').count()).toBe(0);
  for(const raw of ['{','null',send('plugin/install'),send('display',{data:{...sample(),credentials:'forbidden'}})])expect(await receive(page,raw)).toBe(false);
  const old=send('display',{data});
  expect(await receive(page,send('clear',{generation:'42',viewRevision:'4'}),'clear')).toBe(true);
  await expect(page.getByText('PRIVATE-CANARY',{exact:false})).toHaveCount(0);
  const proof=await page.evaluate(()=>({html:document.getElementById('cockpit').innerHTML,ack:window.__events.filter(e=>e.type==='cleared').at(-1)}));
  expect(proof.html).not.toContain('PRIVATE-CANARY');expect(proof.ack.privateAtClear).not.toContain('PRIVATE-CANARY');
  expect(proof.ack.generation).toBe('42');
  expect(await receive(page,old)).toBe(false);
  expect(await receive(page,send('display',{data}))).toBe(false);
  expect(await receive(page,send('display',{generation:'42',viewRevision:'4',data:sample()}))).toBe(true);
});
async function infiniteAnimations(page) {
  return page.evaluate(()=>{
    const found=[];
    for(const element of document.querySelectorAll('*'))for(const pseudo of [null,'::before','::after']) {
      const style=getComputedStyle(element,pseudo);
      if(style.animationIterationCount.split(',').some(value=>value.trim()==='infinite'))found.push(element.tagName+'.'+element.className+(pseudo??''));
    }
    for(const animation of document.getAnimations())if(!Number.isFinite(animation.effect.getTiming().iterations))found.push('unbounded runtime effect');
    return found;
  });
}
async function finishMotion(page) {
  await page.evaluate(()=>Promise.all(document.getAnimations().map(a=>a.finished.catch(()=>{}))));
}
test('real WebKit callback counts stay zero; finite opacity motion stops on every visibility gate',async({page},info)=>{
  const {send}=await open(page);
  await page.evaluate(()=>new Promise(resolve=>requestAnimationFrame(()=>resolve())));
  expect(await page.evaluate(()=>window.__counts.callbacks)).toBeGreaterThan(0);
  const evidence=[];
  async function count(state,expected) {
    await page.evaluate(()=>window.__resetCounts());
    const before=await page.evaluate(()=>document.getAnimations().map(a=>a.currentTime));
    await sleep(250);
    const actual=await page.evaluate(()=>({counts:{...window.__counts},animations:document.getAnimations().map(a=>({playState:a.playState,timing:a.effect.getTiming(),keyframes:a.effect.getKeyframes()}))}));
    expect(actual.counts).toEqual({requests:0,callbacks:0,timeouts:0,intervals:0});
    expect(actual.animations.map(a=>a.playState)).toEqual(expected);
    expect(await infiniteAnimations(page)).toEqual([]);
    evidence.push({state,currentTimeBefore:before,...actual});
  }
  await count('loaded-awaiting-data',[]);
  await display(page,send);
  const timing=await page.evaluate(()=>({...document.getAnimations()[0].effect.getTiming(),easing:getComputedStyle(document.querySelector('.activity')).animationTimingFunction}));
  expect(timing.iterations).toBe(2);expect(timing.duration).toBe(240);
  const steps=Number(timing.easing.match(/steps\((\d+)/)[1]);expect(steps/(timing.duration/1000)).toBeLessThanOrEqual(30);
  const frames=await page.evaluate(()=>document.getAnimations()[0].effect.getKeyframes());
  expect(frames.every(frame=>Object.keys(frame).every(key=>['offset','computedOffset','easing','composite','opacity'].includes(key)))).toBe(true);
  await count('ready-key-visible',['running']);
  await finishMotion(page);await count('visible-idle',[]);
  let reading=74;
  async function changed() {
    const data=sample();data.projection.rows[0].accounts[0].windows[0].remainingPercent=reading--;
    expect(await receive(page,send('display',{data}))).toBe(true);
    expect(await page.evaluate(()=>document.getAnimations().map(a=>a.playState))).toEqual(['running']);
  }
  for(const [name,visibility] of [
    ['native-hidden',{visible:false,occluded:false,key:true}],
    ['native-occluded',{visible:true,occluded:true,key:true}],
    ['native-not-key',{visible:true,occluded:false,key:false}],
  ]){
    expect(await receive(page,send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
    await changed();expect(await receive(page,send('visibility',visibility))).toBe(true);await count(name,[]);
  }
  expect(await receive(page,send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
  await changed();await page.evaluate(()=>window.__setHidden(true));await count('document-hidden',[]);
  await page.evaluate(()=>window.__setHidden(false));await count('visible-again-no-replay',[]);
  await changed();expect(await receive(page,send('clear',{viewRevision:'4'}),'clear')).toBe(true);await count('cleared',[]);
  expect(await receive(page,send('unload',{viewRevision:'4'}))).toBe(true);await count('unloaded',[]);
  expect(await page.evaluate(()=>window.modelPlanCockpit)).toBeUndefined();expect(await page.locator('#cockpit').textContent()).toBe('');
  const path=info.outputPath('callback-counts.json');await mkdir(dirname(path),{recursive:true});
  await writeFile(path,JSON.stringify({profile:'headless WebKit; document.hidden controlled by test',scenarios:evidence},null,2));
  await info.attach('callback-counts',{path,contentType:'application/json'});
});
test('computed animation iteration counts reject infinity, including pseudo-elements',async({page})=>{
  const {send}=await open(page);await display(page,send);
  expect(await infiniteAnimations(page)).toEqual([]);
  // Negative controls prove that the computed-style guard sees both cases,
  // including disabled animations whose iteration declaration is still infinite.
  await page.evaluate(()=>document.body.style.setProperty('animation-iteration-count','infinite','important'));
  expect(await infiniteAnimations(page)).toContain('BODY.r1 reduced');
  await page.evaluate(()=>document.body.style.removeProperty('animation-iteration-count'));
  // A same-origin stylesheet meets the page CSP and exercises the pseudo scan.
  await page.route('**/infinite-guard.css',route=>route.fulfill({contentType:'text/css',body:'#cockpit::before{animation-iteration-count:infinite!important}'}));
  const probe=await page.addStyleTag({url:'/infinite-guard.css'});
  expect(await infiniteAnimations(page)).toContain('DIV.ck private-content::before');
  await probe.evaluate(node=>node.remove());
  expect(await infiniteAnimations(page)).toEqual([]);
});
test('identical and timestamp-only deliveries do not restart motion; hidden changes are not queued',async({page})=>{
  const {send}=await open(page);await display(page,send);
  await page.evaluate(()=>window.__firstPulse=document.getAnimations()[0]);
  expect(await receive(page,send('display',{data:sample()}))).toBe(true);
  expect(await page.evaluate(()=>document.getAnimations()[0]===window.__firstPulse)).toBe(true);
  await finishMotion(page);
  const data=sample();data.projection.rows[0].accounts[0].observedAt='2026-10-29T12:01:00Z';
  expect(await receive(page,send('display',{data}))).toBe(true);
  expect(await page.evaluate(()=>document.getAnimations().length)).toBe(0);
  data.projection.rows[0].accounts[0].windows[0].remainingPercent=74;
  expect(await receive(page,send('display',{data}))).toBe(true);
  expect(await page.evaluate(()=>document.getAnimations().length)).toBe(1);
  expect(await receive(page,send('visibility',{visible:false,occluded:false,key:true}))).toBe(true);
  data.projection.rows[0].accounts[0].windows[0].remainingPercent=73;
  expect(await receive(page,send('display',{data}))).toBe(true);
  expect(await receive(page,send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
  expect(await page.evaluate(()=>document.getAnimations().length)).toBe(0);
  expect(await infiniteAnimations(page)).toEqual([]);
});
test('fixed keyboard-reachable actions have current context; reduced motion has no animations',async({page})=>{
  await page.emulateMedia({reducedMotion:'reduce'});
  const {send}=await open(page);await display(page,send);
  await page.getByRole('button',{name:'Settings',exact:true}).focus();await page.keyboard.press('Enter');
  const event=await page.evaluate(()=>window.__events.filter(e=>e.type==='action').at(-1));
  expect(event.action).toBe('openSettings');expect(event.generation).toBe('41');
  expect(await page.evaluate(()=>document.getAnimations().length)).toBe(0);
  await expect(page.getByRole('button',{name:'Codex · History',exact:true})).toBeVisible();
  expect(await page.locator('svg,canvas,img').count()).toBe(0);
  await page.evaluate(()=>window.postMessage({type:'plugin/install',url:'https://example.invalid'},'*'));
  expect(await page.evaluate(()=>window.__events.filter(e=>e.type==='action').length)).toBe(1);
});
for(const profile of ['full','compact'])for(const theme of ['day','night'])for(const locale of ['en','zh-CN']){
  test(`visual ${profile} ${theme} ${locale}`,async({page})=>{
    await page.setViewportSize({width:636,height:profile==='full'?890:640});await page.emulateMedia({reducedMotion:'reduce'});
    const {send}=await open(page,{theme,locale,profile});await display(page,send);
    await page.evaluate(()=>document.fonts.ready);
    expect(await infiniteAnimations(page)).toEqual([]);
    await expect(page).toHaveScreenshot(`${profile}-${theme}-${locale}.png`,{animations:'disabled',maxDiffPixels:0});
  });
}

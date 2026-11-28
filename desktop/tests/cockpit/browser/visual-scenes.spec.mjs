// SPDX-License-Identifier: MIT
// D489: the four full-cockpit scenes (day/night x en/zh-CN), captured for the base-vs-head visual diff
// (desktop/tests/cockpit/visual-diff.mjs). Nothing here compares against a committed image: CI renders the PR's
// base and head with this spec on the same runner and diffs the two captures.
//   COCKPIT_VISUAL_OUT    directory for <scene>.png and <scene>.areas.json (default: this test's output dir)
//   COCKPIT_VISUAL_AREAS  the area map whose selectors are measured (default: ../visual-areas.json)
// The scene set-up is the one the retired full-* baselines used (cockpit.spec.mjs before D489).
import { test,expect } from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import { appearance,commands,pageId,shell,excludePortholeFlicker } from '../fixture.mjs';
import { renderVisualDeck,visualFixture } from '../visual-fixture.mjs';
import { mkdir,readFile,writeFile } from 'node:fs/promises';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
test.beforeEach(async({page})=>excludePortholeFlicker(page));

const SCENES=['full-day-en','full-day-zh-CN','full-night-en','full-night-zh-CN'];
const areasPath=process.env.COCKPIT_VISUAL_AREAS||fileURLToPath(new URL('../visual-areas.json',import.meta.url));

function receive(page,raw) {return page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);}
async function open(page,options) {
  await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};});
  await page.goto('/?pageId='+pageId);
  await page.waitForFunction(()=>!!window.modelPlanCockpit);
  const send=commands();
  const {profile,...liveAppearance}=options;
  expect(await receive(page,send('load',{appearance:{...appearance,...liveAppearance},shell:{...shell,tier:'tall'}}))).toBe(true);
  return send;
}
function infiniteAnimations(page) {
  return page.evaluate(()=>{
    const found=[];
    for(const element of document.querySelectorAll('*'))for(const pseudo of [null,'::before','::after']) {
      if(getComputedStyle(element,pseudo).animationIterationCount.split(',').some(value=>value.trim()==='infinite'))found.push(element.tagName+'.'+element.className+(pseudo??''));
    }
    for(const animation of document.getAnimations())if(!Number.isFinite(animation.effect.getTiming().iterations))found.push('unbounded runtime effect');
    return found;
  });
}
// Like toHaveScreenshot: retake until two consecutive captures are byte-identical.
async function stableShot(page) {
  let last=null;
  for(let i=0;i<6;i++){
    const shot=await page.screenshot({animations:'disabled',caret:'hide',scale:'css'});
    if(last&&shot.equals(last))return shot;
    last=shot;
  }
  throw new Error('cockpit screenshot did not settle in 6 captures');
}
// Each area's selectors, measured on the rendered page: one box per visible match, in CSS px. Matches are never joined:
// the two side boosters joined would span the whole deck (macrev2-1320-2).
function measure(page,areas) {
  return page.evaluate(areas=>Object.fromEntries(Object.entries(areas).map(([name,area])=>[name,(area.selectors??[]).flatMap(selector=>
    [...document.querySelectorAll(selector)].map(e=>e.getBoundingClientRect()).filter(r=>r.width>0&&r.height>0)
      .map(r=>[Math.floor(r.left),Math.floor(r.top),Math.ceil(r.right)-Math.floor(r.left),Math.ceil(r.bottom)-Math.floor(r.top)]))])),areas);
}

for(const scene of SCENES){
  const [,theme,locale]=/^full-(day|night)-(.+)$/.exec(scene);
  test(`visual scene ${scene}`,async({page},info)=>{
    await page.setViewportSize({width:636,height:951});await page.emulateMedia({reducedMotion:'reduce'});
    await page.clock.setFixedTime(new Date('2026-11-03T12:00:00Z'));
    const send=await open(page,{theme,locale,profile:'full'}),fixture=visualFixture();
    expect(await receive(page,send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
    expect(await receive(page,send('display',{data:fixture.data}))).toBe(true);
    await renderVisualDeck(page,fixture,locale);
    await page.evaluate(()=>document.fonts.ready);
    expect(await infiniteAnimations(page)).toEqual([]);
    const out=process.env.COCKPIT_VISUAL_OUT||info.outputPath();
    await mkdir(out,{recursive:true});
    const areas=JSON.parse(await readFile(areasPath,'utf8')).areas;
    await writeFile(join(out,`${scene}.png`),await stableShot(page));
    const measured=await measure(page,areas);
    // A measured box never reaches the centre of another area's box (macrev2-1320-2: joined boosters spanned the MFD).
    const inside=([x,y,w,h],[cx,cy])=>cx>=x&&cx<x+w&&cy>=y&&cy<y+h;
    for(const [a,boxesA] of Object.entries(measured))for(const [b,boxesB] of Object.entries(measured))if(a!==b)
      for(const r of boxesA)for(const q of boxesB)expect(inside(r,[q[0]+q[2]/2,q[1]+q[3]/2]),`${a} ${r} covers the centre of ${b} ${q}`).toBe(false);
    await writeFile(join(out,`${scene}.areas.json`),JSON.stringify(measured));
  });
}

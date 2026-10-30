// SPDX-License-Identifier: MIT
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
async function mount(page) {
  await page.addInitScript(()=>{
    const counts={raf:0,timers:0};
    const raf=requestAnimationFrame.bind(window),timeout=setTimeout.bind(window),interval=setInterval.bind(window);
    window.requestAnimationFrame=fn=>{counts.raf++;return raf(fn);};
    window.setTimeout=(...args)=>{counts.timers++;return timeout(...args);};
    window.setInterval=(...args)=>{counts.timers++;return interval(...args);};
    window.__sessionCounts=counts;
  });
  await page.goto('/');
  await page.evaluate(async()=>{
    const {SessionStateTracker,mountSessionState}=await import('/src/session-state.js');
    const root=document.createElement('span');root.id='session-probe';document.body.append(root);
    window.__sessionTime=0;
    window.__sessionModel=new SessionStateTracker();
    window.__sessionIndicator=mountSessionState(root,window.__sessionModel,'synthetic-session','idle',()=>window.__sessionTime);
    window.__changeSession=(state,time)=>{window.__sessionTime=time;return window.__sessionIndicator.update(state);};
  });
}
test('two opacity steps, coalesced state transitions and a per-session cooldown without timers',async({page})=>{
  await mount(page);
  expect(await page.evaluate(()=>window.__changeSession('working',100).flash)).toBe(true);
  const timing=await page.evaluate(()=>{
    const root=document.getElementById('session-probe'),animation=root.getAnimations()[0];
    window.__firstSessionAnimation=animation;
    animation.pause(); // Hold a finite effect while checking burst coalescing.
    return {...animation.effect.getTiming(),easing:getComputedStyle(root).animationTimingFunction};
  });
  expect(timing.iterations).toBe(1);expect(timing.duration).toBe(160);expect(timing.easing).toMatch(/steps\(2/);
  expect(await page.evaluate(()=>window.__changeSession('done',101).flash)).toBe(false);
  expect(await page.evaluate(()=>document.getElementById('session-probe').getAnimations()[0]===window.__firstSessionAnimation)).toBe(true);
  await expect(page.locator('#session-probe')).toHaveAttribute('data-state','done');
  await page.evaluate(()=>window.__firstSessionAnimation.play());
  await page.evaluate(()=>Promise.all(document.getAnimations().map(a=>a.finished.catch(()=>{}))));
  expect(await page.evaluate(()=>document.getAnimations().length)).toBe(0);
  expect(await page.evaluate(()=>window.__changeSession('error',30_099).flash)).toBe(false);
  expect(await page.evaluate(()=>window.__changeSession('working',30_100).flash)).toBe(true);
  expect(await page.evaluate(()=>window.__sessionCounts)).toEqual({raf:0,timers:0});
  const declarations=await page.evaluate(()=>Array.from(document.querySelectorAll('*')).flatMap(e=>[null,'::before','::after'].map(p=>getComputedStyle(e,p).animationIterationCount)));
  expect(declarations.some(value=>value.includes('infinite'))).toBe(false);
});
test('hidden and reduced-motion states cancel; becoming visible never replays',async({page})=>{
  await mount(page);await page.evaluate(()=>window.__changeSession('working',100));
  await page.evaluate(()=>window.__sessionIndicator.setVisible(false));
  expect(await page.evaluate(()=>document.getAnimations().length)).toBe(0);
  await page.evaluate(()=>{window.__changeSession('done',30_100);window.__sessionIndicator.setVisible(true);});
  expect(await page.evaluate(()=>document.getAnimations().length)).toBe(0);
  await page.emulateMedia({reducedMotion:'reduce'});
  await expect.poll(()=>page.evaluate(()=>matchMedia('(prefers-reduced-motion: reduce)').matches)).toBe(true);
  await expect(page.locator('#session-probe')).not.toHaveClass(/is-flashing/);
  expect(await page.evaluate(()=>window.__changeSession('error',60_100).flash)).toBe(false);
  expect(await page.evaluate(()=>document.getAnimations().length)).toBe(0);
  await page.emulateMedia({reducedMotion:'no-preference'});
  await expect.poll(()=>page.evaluate(()=>matchMedia('(prefers-reduced-motion: reduce)').matches)).toBe(false);
  expect(await page.evaluate(()=>window.__changeSession('error',90_100).flash)).toBe(false);
  expect(await page.evaluate(()=>document.getAnimations().length)).toBe(0);
  expect(await page.evaluate(()=>window.__changeSession('working',120_100).flash)).toBe(true);
  await page.emulateMedia({reducedMotion:'reduce'});
  await expect.poll(()=>page.evaluate(()=>matchMedia('(prefers-reduced-motion: reduce)').matches)).toBe(true);
  await expect(page.locator('#session-probe')).not.toHaveClass(/is-flashing/);
  expect(await page.evaluate(()=>document.getAnimations().length)).toBe(0);
  await page.emulateMedia({reducedMotion:'no-preference'});
  await expect.poll(()=>page.evaluate(()=>matchMedia('(prefers-reduced-motion: reduce)').matches)).toBe(false);
  expect(await page.evaluate(()=>document.getAnimations().length)).toBe(0);
  await page.evaluate(()=>{window.__sessionIndicator.dispose();window.__sessionModel.clear();});
  await expect(page.locator('#session-probe')).not.toHaveAttribute('data-state');
});
test('official session colours are independent of quota tokens; shapes distinguish the states',async({page})=>{
  await mount(page);
  for(const [theme,expected,palette]of [
    ['night',['rgb(133, 141, 153)','rgb(127, 178, 255)','rgb(127, 178, 255)','rgb(239, 68, 68)']],
    ['day',['rgb(93, 99, 107)','rgb(47, 107, 216)','rgb(47, 107, 216)','rgb(196, 43, 43)']],
    ['day',['rgb(93, 99, 107)','rgb(42, 95, 196)','rgb(42, 95, 196)','rgb(196, 43, 43)'],'darker'],
  ]){
    await page.evaluate(({theme,palette})=>{document.documentElement.dataset.theme=theme;document.documentElement.dataset.sessionPalette=palette??'';},{theme,palette});
    for(const [i,state]of ['idle','working','done','error'].entries()){
      await page.evaluate(state=>window.__changeSession(state,0),state);
      const style=await page.evaluate(()=>{
        const root=document.getElementById('session-probe'),s=getComputedStyle(root),p=getComputedStyle(root,'::after');
        return {color:s.color,background:s.backgroundColor,mark:p.content,tick:p.borderBottomWidth};
      });
      expect(style.color).toBe(expected[i]);
      if(state==='idle')expect(style.background).toBe('rgba(0, 0, 0, 0)');
      if(state==='error')expect(style.mark).toBe('"!"');
      if(state==='done')expect(style.tick).toBe('1px');
    }
  }
});

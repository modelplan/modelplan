// SPDX-License-Identifier: MIT
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {setTimeout as delay} from 'node:timers/promises';
import {watch,timingVerdict} from '../walk-timing.mjs';

test('a timer mutation after the deadline fails and stays attributed to its originating Escape',async({page})=>{
 await page.addInitScript(watch);await page.goto('data:text/html,<body>timing</body>');
 await page.evaluate(()=>document.addEventListener('keydown',e=>{if(e.key==='Escape')setTimeout(()=>{document.body.dataset.delayed='yes';},300);}));
 await page.keyboard.press('Escape');await delay(200);
 let result=await page.evaluate(()=>window.__walk.results[0]);
 expect(timingVerdict(result)).toEqual({failure:'pending timers at 150 ms'});
 await delay(200);result=await page.evaluate(()=>window.__walk.results[0]);
 expect(await page.locator('body').getAttribute('data-delayed')).toBe('yes');
 expect(result.late.some(e=>e.kind==='mutation'&&e.attribute==='data-delayed')).toBe(true);
});

test('a prompt timer mutation settles before the deadline',async({page})=>{
 await page.addInitScript(watch);await page.goto('data:text/html,<body>timing</body>');
 await page.evaluate(()=>document.addEventListener('keydown',e=>{if(e.key==='Escape')setTimeout(()=>{document.body.dataset.prompt='yes';},10);}));
 await page.keyboard.press('Escape');await delay(200);
 expect(timingVerdict(await page.evaluate(()=>window.__walk.results[0]))).toEqual({});
 await expect(page.locator('body')).toHaveAttribute('data-prompt','yes');
});

test('a late lamp mutation fails the timing contract',()=>{
 const step={start:100,last:270,displayAt:50,pending:0,pendingTimers:0,late:[{kind:'mutation',type:'attributes',attribute:'class',target:'<i class="activity" aria-hidden="true"></i>'}]};
 expect(timingVerdict(step)).toEqual({failure:'last mutation or frame exceeded 150 ms'});
 expect(timingVerdict({...step,late:[...step.late,{kind:'mutation',type:'childList'}]})).toEqual({failure:'last mutation or frame exceeded 150 ms'});
});

test('an animation-end mutation is attributed to the interaction during the animation',async({page})=>{
 test.skip(process.env.COCKPIT_HEADED_MOTION!=='1','Natural WebKit animation events require headed rendering.');
 await page.addInitScript(watch);
 await page.goto('data:text/html,<style>@keyframes pulse { from { opacity: 1 } to { opacity: .5 } } .pulse { animation: pulse 5000ms }</style><div>lamp</div>');
 await page.evaluate(()=>{const el=document.querySelector('div');el.addEventListener('animationend',()=>{el.dataset.finished='yes';});el.className='pulse';});
 await page.waitForFunction(()=>document.querySelector('div').getAnimations().length>0);
 await page.keyboard.press('Escape');await delay(6000);
 const step=await page.evaluate(()=>window.__walk.results[0]);
 expect(await page.locator('div').getAttribute('data-finished')).toBe('yes');
 expect(step.late.some(e=>e.kind==='mutation'&&e.attribute==='data-finished')).toBe(true);
 expect(timingVerdict(step)).toEqual({failure:'last mutation or frame exceeded 150 ms'});
});

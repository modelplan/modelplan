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

test('only the identified display-pulse cleanup is an expected late mutation',()=>{
 const step={start:100,last:270,displayAt:50,pending:0,pendingTimers:0,late:[{kind:'mutation',type:'attributes',attribute:'class',target:'<i class="activity" aria-hidden="true"></i>'}]};
 expect(timingVerdict(step)).toEqual({expected:'display-pulse-cleanup'});
 expect(timingVerdict({...step,late:[...step.late,{kind:'mutation',type:'childList'}]})).toEqual({failure:'last mutation or frame exceeded 150 ms'});
});

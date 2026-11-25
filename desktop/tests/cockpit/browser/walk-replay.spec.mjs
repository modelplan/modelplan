// SPDX-License-Identifier: MIT
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {mkdir,readFile,writeFile} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {WALK_CLOCK,walkScenarios} from '../walk-fixtures.mjs';
import {replayTargetMatches} from '../walk-replay.mjs';

test.use({timezoneId:'UTC'});
test('a recorded calendar day replays after midnight using its recorded clock and logical identity',async({page},info)=>{
 test.setTimeout(90000);
 await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};});
 const fixture=walkScenarios(WALK_CLOCK).find(s=>s.name==='zcode-readable');
 const open=async()=>{const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
  await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
  expect(await receive(send('load',{appearance,shell,redBelow:25}))).toBe(true);
  expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
  expect(await receive(send('plugins',{plugins:fixture.plugins}))).toBe(true);
  expect(await receive(send('display',{data:fixture.data}))).toBe(true);
  const key=page.locator('.eng-keys .pl-key[data-plugin="calendar"]');
  const plugin=await key.evaluate(el=>({selector:'.eng-keys .pl-key',index:[...document.querySelectorAll('.eng-keys .pl-key')].indexOf(el),label:el.getAttribute('aria-label')||el.textContent.trim(),key:el.getAttribute('data-plugin'),choice:el.getAttribute('data-choice'),option:el.closest('[data-opt]')?.getAttribute('data-opt')}));
  await key.click();return plugin;
 };
 const action=async()=>{const e=page.locator('.pl-screen .wk-dh').nth(1);return {selector:'.pl-screen .wk-dh',index:1,label:await e.getAttribute('aria-label'),key:await e.getAttribute('data-focus'),choice:null};};
 await page.clock.setFixedTime(new Date(WALK_CLOCK));const plugin=await open();
 const recorded={scenario:fixture.name,seed:'0xc0c01123',clock:WALK_CLOCK,timezone:'UTC',operations:[{type:'boot',data:'display'},{type:'click',action:plugin},{type:'click',action:await action()}]};
 const file=info.outputPath('calendar-replay.json');await writeFile(file,JSON.stringify(recorded));
 const walkFile=fileURLToPath(new URL('../.tmp/walk/calendar-replay-regression.json',import.meta.url));await mkdir(fileURLToPath(new URL('../.tmp/walk/',import.meta.url)),{recursive:true});await writeFile(walkFile,JSON.stringify(recorded));
 await page.clock.setFixedTime(new Date('2026-11-24T12:00:00Z'));await open();
 const savedAction=recorded.operations.at(-1).action;
 const tomorrow=await action();expect(tomorrow.label).not.toBe(savedAction.label);expect(replayTargetMatches(savedAction,tomorrow)).toBe(true);
 const saved=JSON.parse(await readFile(file,'utf8'));await page.clock.setFixedTime(new Date(saved.clock));await open();
 const target=await action();expect(replayTargetMatches(saved.operations.at(-1).action,target)).toBe(true);expect(target.label).toBe(saved.operations.at(-1).action.label);
 await page.locator(target.selector).nth(target.index).click();
 await expect(page.locator(target.selector).nth(target.index)).toHaveAttribute('aria-pressed','true');
});

// SPDX-License-Identifier: MIT
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {walkScenarios,WALK_CLOCK} from '../walk-fixtures.mjs';
import {inspectPage} from '../walk-inspect.mjs';

test.use({timezoneId:'UTC'});
test('scrollable model rows are clipped by their viewport while an overflowing fixed control still fails',async({page})=>{
 test.setTimeout(90000);
 await page.clock.setFixedTime(new Date(WALK_CLOCK));
 await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};});
 const data=walkScenarios().find(s=>s.name==='one').data;
 for(let i=0;i<12;i++)data.details.publishedModels.push({...structuredClone(data.details.publishedModels[0]),id:`gpt-x${i}`,name:`GPT X${i}`});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance:{...appearance,locale:'zh-CN'},shell,redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data}))).toBe(true);
 await page.locator('[data-range-key="30d"]').click();
 await page.locator('[data-mfd="page:tune"]').click();
 const list=page.locator('.mfd-page .md-list');
 await expect(page.locator('.mfd-page .md-row')).toHaveCount(10);
 expect(await list.evaluate(e=>e.scrollHeight>e.clientHeight)).toBe(true);
 const scrollViolations=async()=>(await page.evaluate(inspectPage,false)).violations.filter(v=>v.startsWith('view overflow md-row')||v.startsWith('clipped text ')&&v.includes('class="md-list"'));
 expect(await scrollViolations()).toEqual([]);
 await list.evaluate(e=>{e.scrollTop=30;});
 expect(await scrollViolations()).toEqual([]);
 await list.evaluate(e=>{e.scrollTop=e.scrollHeight;});
 expect(await scrollViolations()).toEqual([]);
 await page.evaluate(()=>{const p=document.querySelector('.mfd-page'),r=p.getBoundingClientRect(),b=document.createElement('button');b.className='walk-overflow-probe';b.style.cssText=`position:fixed;left:${r.right-2}px;top:${r.top+10}px;width:18px;height:18px`;p.append(b);});
 expect((await page.evaluate(inspectPage,false)).violations).toContain('view overflow walk-overflow-probe');
 await page.evaluate(()=>{const d=document.createElement('div');d.className='walk-clip-probe';d.style.cssText='position:absolute;left:10px;top:20px;width:10px;height:20px;overflow:hidden;white-space:nowrap';d.textContent='A deliberately clipped control label';document.querySelector('.mfd-page').append(d);});
 expect((await page.evaluate(inspectPage,false)).violations.some(v=>v.startsWith('clipped text ')&&v.includes('walk-clip-probe'))).toBe(true);
});

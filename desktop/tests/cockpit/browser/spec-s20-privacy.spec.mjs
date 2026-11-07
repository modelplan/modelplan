// SPDX-License-Identifier: MIT
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';

// spec-cockpit C-20: page clear and stale-generation controls.
test('C-20 clear removes rendered private facts before acknowledgement and rejects stale delivery',async({page})=>{
 await page.addInitScript(()=>{window.__events=[];window.webkit={messageHandlers:{cockpit:{postMessage(raw){const msg=JSON.parse(raw);if(msg.type==='cleared')msg.observedHTML=document.querySelector('#cockpit')?.innerHTML;window.__events.push(msg);}}}};});
 await page.clock.setFixedTime(new Date('2026-11-03T12:00:00Z'));await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw),data=visualFixture().data;
 data.projection.rows[0].name.en='PRIVATE-ROW-CANARY';data.details.sessions[0].model='PRIVATE-MODEL-CANARY';data.details.sessions[0].projectLabel='PRIVATE-PROJECT-CANARY';
 for(const raw of [send('load',{appearance,shell,redBelow:25}),send('visibility',{visible:true,occluded:false,key:true}),send('display',{data})])expect(await receive(raw)).toBe(true);
 await expect(page.locator('#cockpit')).toContainText('PRIVATE-ROW-CANARY');await expect(page.locator('#cockpit')).toContainText('PRIVATE-MODEL-CANARY');await expect(page.locator('#cockpit')).toContainText('PRIVATE-PROJECT-CANARY');
 await page.getByRole('button',{name:'Subscription',exact:true}).click();const stale=send('display',{data});
 await page.evaluate(()=>{const b=document.createElement('button');b.id='outside-cockpit-focus';b.textContent='Outside';document.body.append(b);b.focus();});
 expect(await receive(send('clear',{generation:'42',viewRevision:'4'}))).toBe(true);await expect(page.locator('#outside-cockpit-focus')).toBeFocused();
 const result=await page.evaluate(()=>({html:document.querySelector('#cockpit').innerHTML,ack:window.__events.filter(e=>e.type==='cleared').at(-1)}));
 for(const marker of ['PRIVATE-ROW-CANARY','PRIVATE-MODEL-CANARY','PRIVATE-PROJECT-CANARY']){expect(result.html).not.toContain(marker);expect(result.ack.observedHTML).not.toContain(marker);}
 expect(await receive(stale)).toBe(false);
 // Fresh transport sequence and current revision isolate the older generation fence.
 const freshSequenceOldGeneration=send('display',{generation:'41',viewRevision:'4',data});
 expect(await receive(freshSequenceOldGeneration)).toBe(false);
 const after=await page.locator('#cockpit').innerHTML();
 for(const marker of ['PRIVATE-ROW-CANARY','PRIVATE-MODEL-CANARY','PRIVATE-PROJECT-CANARY'])expect(after).not.toContain(marker);
 await expect(page.locator('#outside-cockpit-focus')).toBeFocused();
});

// Salvaged from #494: only the admitted bridge can populate the page.
test('CKP-SHELL-22 ignores stored and URL data and renders only bridge delivery',async({page})=>{
 const probe=JSON.stringify({projection:{rows:[{id:'probe',name:{en:'INJECTED-ROW-CANARY',zh:'注入'}}]}});
 await page.addInitScript(source=>{localStorage.setItem('modelplan-cockpit-cache',source);sessionStorage.setItem('modelplan-cockpit-data',source);},probe);
 await page.goto('/?pageId='+pageId+'&data='+encodeURIComponent(probe));
 await page.waitForFunction(()=>!!window.modelPlanCockpit);
 expect(await page.evaluate(()=>({frozen:Object.isFrozen(window.modelPlanCockpit),keys:Object.keys(window.modelPlanCockpit)}))).toEqual({frozen:true,keys:['receive','clear','state']});
 await expect(page.locator('.ec-empty')).toBeVisible();
 await expect(page.locator('.eng-keys .ek[data-sub]')).toHaveCount(0);
 await expect(page.locator('body')).not.toContainText('INJECTED-ROW-CANARY');
 const data=visualFixture().data,send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 data.projection.rows[0].name.en='ADMITTED-ROW-CANARY';
 for(const raw of [send('load',{appearance,shell,redBelow:25}),send('visibility',{visible:true,occluded:false,key:true}),send('display',{data})])expect(await receive(raw)).toBe(true);
 await expect(page.locator('.eng-keys')).toContainText('ADMITTED-ROW-CANARY');
 await expect(page.locator('body')).not.toContainText('INJECTED-ROW-CANARY');
});

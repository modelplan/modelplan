// SPDX-License-Identifier: MIT
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';

test('S20 clear removes rendered private facts before acknowledgement and rejects stale delivery',async({page})=>{
 await page.addInitScript(()=>{window.__events=[];window.webkit={messageHandlers:{cockpit:{postMessage(raw){const msg=JSON.parse(raw);if(msg.type==='cleared')msg.observedHTML=document.querySelector('#cockpit')?.innerHTML;window.__events.push(msg);}}}};});
 await page.clock.setFixedTime(new Date('2026-11-03T12:00:00Z'));await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw),data=visualFixture().data;
 data.projection.rows[0].name.en='PRIVATE-ROW-CANARY';data.details.sessions[0].model='PRIVATE-MODEL-CANARY';data.details.sessions[0].projectLabel='PRIVATE-PROJECT-CANARY';
 for(const raw of [send('load',{appearance,shell,redBelow:25}),send('visibility',{visible:true,occluded:false,key:true}),send('display',{data})])expect(await receive(raw)).toBe(true);
 await expect(page.locator('#cockpit')).toContainText('PRIVATE-ROW-CANARY');await expect(page.locator('#cockpit')).toContainText('PRIVATE-MODEL-CANARY');
 await page.getByRole('button',{name:'Subscription',exact:true}).click();const stale=send('display',{data});
 await page.evaluate(()=>{const b=document.createElement('button');b.id='outside-cockpit-focus';b.textContent='Outside';document.body.append(b);b.focus();});
 expect(await receive(send('clear',{generation:'42',viewRevision:'4'}))).toBe(true);await expect(page.locator('#outside-cockpit-focus')).toBeFocused();
 const result=await page.evaluate(()=>({html:document.querySelector('#cockpit').innerHTML,ack:window.__events.filter(e=>e.type==='cleared').at(-1)}));
 for(const marker of ['PRIVATE-ROW-CANARY','PRIVATE-MODEL-CANARY','PRIVATE-PROJECT-CANARY']){expect(result.html).not.toContain(marker);expect(result.ack.observedHTML).not.toContain(marker);}
 expect(await receive(stale)).toBe(false);await expect(page.locator('#cockpit')).not.toContainText('PRIVATE-ROW-CANARY');await expect(page.locator('#outside-cockpit-focus')).toBeFocused();
});

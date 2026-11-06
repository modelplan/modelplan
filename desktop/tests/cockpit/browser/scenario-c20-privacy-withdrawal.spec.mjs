// SPDX-License-Identifier: MIT
// spec-cockpit.md C-20: "Admitted synthetic readings and an active control |
// Clear, change generation or close/reopen | Private text and stale actions are
// withdrawn; unrelated focus is not stolen | Packaged-app normal-entry privacy
// and lifecycle test". T1 (specs/scenario-tests.tsv) marks C-20 ABSENT.
// Failing-first: assertions that do not hold on the candidate head are expected
// failures recording the gap, not flakes.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';

const open=async(page)=>{
 await page.addInitScript(()=>{window.__messages=[];window.webkit={messageHandlers:{cockpit:{postMessage(raw){window.__messages.push(JSON.parse(raw));}}}};});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance,shell,redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 return {send,receive};
};
const privateTextVisible=page=>page.evaluate(()=>['Synthetic plan','75','CODEX'].filter(text=>document.querySelector('#cockpit').textContent.includes(text)));

test('C-20: clear withdraws private readings and gates stale actions',async({page})=>{
 const {send,receive}=await open(page);
 const fixture=visualFixture();
 expect(await receive(send('display',{data:fixture.data})),'C-20: admitted readings display').toBe(true);
 expect((await privateTextVisible(page)).length,'C-20: private figures are rendered before clear').toBeGreaterThan(0);
 expect(await receive(send('clear',{generation:'42',viewRevision:'4'})),'C-20: clear is accepted').toBe(true);
 expect(await privateTextVisible(page),'C-20: private text is withdrawn after clear').toEqual([]);
 expect(await page.evaluate(()=>document.querySelectorAll('.eng-cols .ec').length),'C-20: member columns are withdrawn').toBe(0);
 // Stale actions must not fire after clear.
 await page.evaluate(()=>document.querySelector('[aria-label=Detach]')?.click());
 await page.evaluate(()=>document.querySelector('[aria-label=Close]')?.click());
 const actions=await page.evaluate(()=>window.__messages.filter(message=>message.type==='action').map(message=>message.action));
 expect(actions,'C-20: no stale action fires after clear').toEqual([]);
});

test('C-20: replacing the member set does not carry the previous private figures',async({page})=>{
 const {send,receive}=await open(page);
 const fixture=visualFixture();
 expect(await receive(send('display',{data:fixture.data}))).toBe(true);
 // A different admitted member set: old identities and figures must not linger.
 const seed=fixture.data.projection.rows[0];
 const replacement=structuredClone(fixture.data);
 replacement.projection.rows=[seed];
 replacement.projection.rows[0].id='kiro';
 replacement.projection.rows[0].name={en:'KIRO',zh:'KIRO'};
 replacement.subscriptions=[];
 replacement.details={...replacement.details,sessions:[],subscriptions:[]};
 expect(await receive(send('display',{data:replacement})),'C-20: replacement set accepted').toBe(true);
 const lingering=await page.evaluate(()=>['CODEX','CLAUDE','CURSOR','GEMINI'].filter(text=>document.querySelector('#cockpit').textContent.includes(text)));
 expect(lingering,'C-20: previous member identities are withdrawn').toEqual([]);
});

test('C-20: clear does not steal focus from an unrelated surviving control',async({page})=>{
 const {send,receive}=await open(page);
 expect(await receive(send('display',{data:visualFixture().data}))).toBe(true);
 // The screen keys are cockpit chrome, unrelated to the withdrawn readings.
 const overviewKey=page.locator('.mfd-pk button',{hasText:'Overview'}).first();
 await overviewKey.focus();
 await expect(overviewKey).toBeFocused();
 expect(await receive(send('clear',{generation:'42',viewRevision:'4'})),'C-20: clear accepted').toBe(true);
 await expect(overviewKey,'C-20: unrelated focus is not stolen by clear').toBeFocused();
});

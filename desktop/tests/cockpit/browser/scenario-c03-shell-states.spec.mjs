// SPDX-License-Identifier: MIT
// spec-cockpit.md C-03 (was S3): "Attached and detached cockpit | Drag, put back,
// close and reopen | Position, shell state and controls follow the approved
// behavior". T1 (specs/scenario-tests.tsv) marks this ABSENT. Window position and
// dragging are native-owned (real-Mac evidence); the page-level slice is the
// shell-state contract: detach, put back, close and reopen each update the shell
// state and the controls that follow it. Failing-first: assertions that do not
// hold on the candidate head are expected failures recording the gap, not flakes.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,currentSample,pageId,shell} from '../fixture.mjs';

const open=async(page)=>{
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance,shell,redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data:currentSample()}))).toBe(true);
 return {send,receive};
};
const snap=page=>page.evaluate(()=>({
 shell:document.querySelector('#cockpit').getAttribute('data-shell'),
 detach:[...document.querySelectorAll('button')].find(b=>/^(Detach|Put back|分离|放回)$/i.test(b.getAttribute('aria-label')??''))?.getAttribute('aria-label')??null
}));

test('C-03: detach, put back, close and reopen each follow the approved shell state and controls',async({page})=>{
 const {send,receive}=await open(page);
 // Attached at rest: the Detach control is offered.
 await expect(page.locator('[aria-label=Detach]')).toBeVisible();
 // Detach: the control becomes Put back; the shell stays open.
 expect(await receive(send('shell',{...shell,attached:false})),'C-03: detach accepted').toBe(true);
 await expect(page.locator('[aria-label="Put back"]')).toBeVisible();
 expect((await snap(page)).shell).toBe('open');
 // Put back: the control returns to Detach.
 expect(await receive(send('shell',{...shell,attached:true})),'C-03: put back accepted').toBe(true);
 await expect(page.locator('[aria-label=Detach]')).toBeVisible();
 // Close: the shell state closes.
 expect(await receive(send('shell',{...shell,profile:'closed'})),'C-03: close accepted').toBe(true);
 expect((await snap(page)).shell).toBe('closed');
 // Reopen: back to open with the Detach control restored.
 expect(await receive(send('shell',{...shell,profile:'open'})),'C-03: reopen accepted').toBe(true);
 await expect(page.locator('[aria-label=Detach]')).toBeVisible();
 expect((await snap(page)).shell).toBe('open');
 // A detached cockpit that closes and reopens keeps the put-back control until put back.
 expect(await receive(send('shell',{...shell,attached:false}))).toBe(true);
 expect(await receive(send('shell',{...shell,attached:false,profile:'closed'}))).toBe(true);
 expect((await snap(page)).shell).toBe('closed');
 expect(await receive(send('shell',{...shell,attached:false,profile:'open'}))).toBe(true);
 await expect(page.locator('[aria-label="Put back"]')).toBeVisible();
});

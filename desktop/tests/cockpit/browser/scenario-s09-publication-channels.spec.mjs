// SPDX-License-Identifier: MIT
// spec-cockpit.md S9: "Admitted publication and bound session facts | Open
// cockpit and change fader banks | Real model channels, recommendation and
// available effort data appear; absent data stay unavailable | Packaged-app
// producer-to-page assertions". T1 (specs/scenario-tests.tsv) marks S9 ABSENT
// (S10's trial interactions are covered by the open PR #450).
//
// Assumed wire shape: publication reaches the page through the negotiated
// cockpit details (`details.publication`, `cockpitDetailsV1`), as proposed by
// the open PR #450; the producer side is #414/#450. Failing-first: on the
// current head the page rejects an unknown details field, so the populated
// assertions below fail — that failure records the scenario gap.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,currentSample,pageId,shell} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';

const open=async(page)=>{
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance,shell,redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 return {send,receive};
};
const channels=page=>page.evaluate(()=>[...document.querySelectorAll('.fd-ch')].map(ch=>({empty:ch.classList.contains('empty'),text:ch.textContent.trim().slice(0,24)})));

test('S9: absent publication keeps every fader channel unavailable',async({page})=>{
 const {send,receive}=await open(page);
 expect(await receive(send('display',{data:currentSample()}))).toBe(true);
 const state=await channels(page);
 expect(state.length,'S9: the approved three-bank channel frame exists').toBeGreaterThanOrEqual(3);
 for(const channel of state)expect(channel.empty,'S9: absent data stays unavailable').toBe(true);
});

test('S9: admitted publication populates real model channels with recommendation and efforts',async({page})=>{
 const {send,receive}=await open(page);
 const fixture=visualFixture();
 const data=structuredClone(fixture.data);
 data.details={...data.details,publication:fixture.publication};
 expect(await receive(send('display',{data})),'S9: details carrying publication are accepted').toBe(true);
 const state=await channels(page);
 const populated=state.filter(channel=>!channel.empty);
 expect(populated.length,'S9: real model channels appear from admitted publication').toBe(fixture.publication.faders.length);
 for(const channel of populated)expect(channel.text,'S9: channel shows its model').not.toBe('');
 expect((fixture.data.details?.sessions??[]).length>0,'S9: bound session facts exist in the admitted input').toBe(true);
});

test('S9: fader banks page when more models are published than fit a bank',async({page})=>{
 const {send,receive}=await open(page);
 const fixture=visualFixture();
 const data=structuredClone(fixture.data);
 const extra=structuredClone(fixture.publication.faders[0]);
 extra.id='extra';extra.name='Extra Model';extra.short='Extra';
 data.details={...data.details,publication:{...fixture.publication,faders:[...fixture.publication.faders,extra]}};
 expect(await receive(send('display',{data})),'S9: publication with four models is accepted').toBe(true);
 const visible=await channels(page);
 expect(visible.filter(channel=>!channel.empty).length,'S9: a bank holds three channels').toBe(3);
 const bankKeys=await page.evaluate(()=>[...document.querySelectorAll('.fd-bank button, [class*=bank] button')].map(b=>b.getAttribute('aria-label')??b.textContent.trim()));
 expect(bankKeys.length,'S9: bank paging controls exist').toBeGreaterThanOrEqual(2);
});

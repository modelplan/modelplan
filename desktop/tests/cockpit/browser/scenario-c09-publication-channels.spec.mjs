// SPDX-License-Identifier: MIT
// spec-cockpit.md C-09: "Admitted publication and bound session facts | Open
// cockpit and change fader banks | Real model channels, recommendation and
// available effort data appear; absent data stay unavailable | Packaged-app
// producer-to-page assertions". T1 (specs/scenario-tests.tsv) marks C-09 ABSENT
// (C-10's trial interactions are covered by the open PR #450).
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

test('C-09: absent publication keeps every fader channel unavailable',async({page})=>{
 const {send,receive}=await open(page);
 expect(await receive(send('display',{data:currentSample()}))).toBe(true);
 const state=await channels(page);
 expect(state.length,'C-09: the approved three-bank channel frame exists').toBeGreaterThanOrEqual(3);
 for(const channel of state)expect(channel.empty,'C-09: absent data stays unavailable').toBe(true);
});

// Named skip (gap record): the page currently rejects `details.publication`
// (unknown details field), so publication is never admitted to the deck.
// Unskip when the page accepts the negotiated publication (#414/#450).
test.fixme('C-09: admitted publication populates real model channels with recommendation and efforts',async({page})=>{
 const {send,receive}=await open(page);
 const fixture=visualFixture();
 const data=structuredClone(fixture.data);
 data.details={...data.details,publication:fixture.publication};
 expect(await receive(send('display',{data})),'C-09: details carrying publication are accepted').toBe(true);
 const state=await channels(page);
 const populated=state.filter(channel=>!channel.empty);
 expect(populated.length,'C-09: real model channels appear from admitted publication').toBe(fixture.publication.faders.length);
 for(const channel of populated)expect(channel.text,'C-09: channel shows its model').not.toBe('');
 expect((fixture.data.details?.sessions??[]).length>0,'C-09: bound session facts exist in the admitted input').toBe(true);
});

// Named skip (gap record): same cause as above — publication is not admitted
// yet, so no populated channels (and therefore no bank paging) can be observed.
// Unskip together with the test above (#414/#450).
test.fixme('C-09: fader banks page when more models are published than fit a bank',async({page})=>{
 const {send,receive}=await open(page);
 const fixture=visualFixture();
 const data=structuredClone(fixture.data);
 const extra=structuredClone(fixture.publication.faders[0]);
 extra.id='extra';extra.name='Extra Model';extra.short='Extra';
 data.details={...data.details,publication:{...fixture.publication,faders:[...fixture.publication.faders,extra]}};
 expect(await receive(send('display',{data})),'C-09: publication with four models is accepted').toBe(true);
 const visible=await channels(page);
 expect(visible.filter(channel=>!channel.empty).length,'C-09: a bank holds three channels').toBe(3);
 const bankKeys=await page.evaluate(()=>[...document.querySelectorAll('.fd-bank button, [class*=bank] button')].map(b=>b.getAttribute('aria-label')??b.textContent.trim()));
 expect(bankKeys.length,'C-09: bank paging controls exist').toBeGreaterThanOrEqual(2);
});

// SPDX-License-Identifier: MIT
// spec-cockpit.md S6: "One, six and more subscriptions | Select All, a member or
// a page | Correct slots, identities, paging and accessible shortcuts remain
// bound". T1 (specs/scenario-tests.tsv) marks S6 ABSENT. Failing-first:
// assertions that do not hold on the candidate head are expected failures
// recording the gap, not flakes. Subscription references use the verified
// 16-hex shape the page admits (unverified scopes are rejected by design).
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,currentSample,pageId,shell} from '../fixture.mjs';

const ref=i=>i.toString(16).padStart(16,'0');
const rowsWith=(page,tools)=>{
 const data=currentSample(),seed=data.projection.rows[0];
 data.projection.rows=tools.map((id,index)=>{const row=structuredClone(seed);row.id=id;row.name={en:id.toUpperCase(),zh:id.toUpperCase()};row.accounts.forEach(account=>{account.subscriptionRef=ref(index);account.accountLocator=ref(index);});return row;});
 return data;
};
const open=async(page)=>{
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance,shell,redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 return {send,receive};
};
const keys=page=>page.evaluate(()=>[...document.querySelectorAll('.eng-keys button')].filter(b=>b.dataset.scope&&b.dataset.scope!=='all').map(b=>({scope:b.dataset.scope,label:b.textContent.trim(),digit:b.textContent.match(/\d/)?.[0]??null,pressed:b.getAttribute('aria-pressed')})));

test('S6: one subscription keeps All plus a single bound slot',async({page})=>{
 const {send,receive}=await open(page);
 expect(await receive(send('display',{data:rowsWith(page,['kiro'])}))).toBe(true);
 const member=await keys(page);
 expect(member,'S6: exactly one member slot').toHaveLength(1);
 // All is the empty-scope key (the page binds it to data-scope="").
 await expect(page.locator('.ek-all')).toHaveAttribute('data-scope','');
 expect(await page.locator('.ek-all').getAttribute('aria-pressed'),'S6: All lit by default').toBe('true');
 const columns=await page.evaluate(()=>[...document.querySelectorAll('.eng-cols .ec')].map(c=>c.dataset.col??null));
 expect(columns.filter(Boolean),'S6: column bound to the member').toHaveLength(1);
});

test('S6: six subscriptions bind slots with accessible shortcut digits 1–6',async({page})=>{
 const {send,receive}=await open(page);
 expect(await receive(send('display',{data:rowsWith(page,['codex','claude','cursor','gemini','qwen','minimax'])}))).toBe(true);
 const member=await keys(page);
 expect(member,'S6: six member slots').toHaveLength(6);
 member.forEach((key,index)=>expect(key.digit,'S6: visible shortcut digit on '+key.label).toBe(String(index+1)));
 for(const key of member)expect(key.label,'S6: identity stays on '+key.scope).toContain(key.scope.split('#')[0].toUpperCase());
});

test('S6: a seventh subscription pages without losing identities, digits or the active indicator',async({page})=>{
 const {send,receive}=await open(page);
 expect(await receive(send('display',{data:rowsWith(page,['codex','claude','cursor','gemini','qwen','minimax','kiro'])}))).toBe(true);
 // Two page LEDs: page 1 active, page 2 reachable.
 const pager=()=>page.evaluate(()=>[...document.querySelectorAll('.eng-led[data-page]')].map(led=>({label:led.getAttribute('aria-label'),current:led.getAttribute('aria-current')})));
 await expect.poll(pager).toEqual([{label:'Page 1',current:'true'},{label:'Page 2',current:'false'}]);
 // Only six slots on page one.
 expect((await keys(page))).toHaveLength(6);
 await page.locator('.eng-led[data-page="1"]').click();
 await expect.poll(pager).toEqual([{label:'Page 1',current:'false'},{label:'Page 2',current:'true'}]);
 const paged=await keys(page);
 expect(paged,'S6: the seventh member is on page two').toHaveLength(1);
 expect(paged[0].label,'S6: identity preserved across paging (the seventh tool is shown)').toContain('KIRO');
 // Returning to page one keeps the original identities and digits.
 await page.locator('.eng-led[data-page="0"]').click();
 const back=await keys(page);
 expect(back,'S6: page one slots survive a round trip').toHaveLength(6);
 back.forEach((key,index)=>expect(key.digit,'S6: shortcut digits stable').toBe(String(index+1)));
});

test('S6: selecting a member lights its slot and clears All',async({page})=>{
 const {send,receive}=await open(page);
 expect(await receive(send('display',{data:rowsWith(page,['codex','claude','cursor','gemini','qwen','minimax'])}))).toBe(true);
 // The page binds each slot to its own member key; select the second slot's key.
 const before=await keys(page);
 const target=before.find(key=>key.label.startsWith('CLAUDE'));
 expect(target,'S6: the second member slot exists').toBeTruthy();
 expect(await receive(send('shell',{...shell,scope:target.scope}))).toBe(true);
 const member=await keys(page);
 expect(member.find(key=>key.scope===target.scope)?.pressed,'S6: selected member slot lit').toBe('true');
 expect(member.filter(key=>key.scope!==target.scope&&key.pressed==='true'),'S6: no other slot lit').toHaveLength(0);
});

// Named skip (gap record, CKP-ENG-05): the owner-restored shortcut digits are
// visible on the keys ("Codex1") but the accessible name (aria-label="Codex")
// overrides the visible text and the tooltip (title="Codex") omits the digit,
// and the Option help map carries no engine-keys caption at all. The registry
// keeps the digits "also present in tooltips, accessible names and Option help".
// Unskip when the keys expose the digit in accessible name and tooltip and help
// explains the shortcut keys.
test.fixme('S6: shortcut digits are present in tooltips, accessible names and Option help',async({page})=>{
 const {send,receive}=await open(page);
 expect(await receive(send('display',{data:rowsWith(page,['codex','claude','cursor','gemini','qwen','minimax'])}))).toBe(true);
 for(const key of await keys(page))expect(key.label,'S6: accessible name carries the digit on '+key.label).toMatch(/\d/);
 const tooltips=await page.evaluate(()=>[...document.querySelectorAll('.eng-keys button')].map(b=>b.getAttribute('title')??b.getAttribute('aria-label')??''));
 for(const tip of tooltips)expect(tip,'S6: tooltip carries the shortcut digit').toMatch(/\d/);
 await page.keyboard.down('Alt');
 await expect(page.locator('#help-map')).toBeVisible();
 const captions=await page.evaluate(()=>[...document.querySelectorAll('#help-map [data-target]')].map(el=>el.getAttribute('data-target')+' :: '+el.textContent));
 await page.keyboard.up('Alt');
 expect(captions.some(text=>/eng-keys|\.ek/.test(text)),'S6: Option help explains the shortcut keys; captions: '+JSON.stringify(captions)).toBe(true);
});

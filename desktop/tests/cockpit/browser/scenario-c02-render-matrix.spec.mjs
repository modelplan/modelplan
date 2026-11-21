// SPDX-License-Identifier: MIT
// spec-cockpit.md C-02 (was S2): "Test app with matched synthetic facts | Display
// tall and compact, day/night, English/Chinese | Accepted shell, controls and
// batch-035 details match the approved reference". T1 (specs/scenario-tests.tsv)
// marks this ABSENT. The pixel-level "matches the approved reference" half needs
// packaged screenshots and owner sign-off and is out of web-test scope; this test
// locks the render-matrix invariants the scenario requires: every tall/compact ×
// day/night × English/Chinese combination loads with the correct theme, the full
// shell structure, the right layout tier, and no overflow. Failing-first:
// assertions that do not hold on the candidate head are expected failures.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,currentSample,pageId,shell} from '../fixture.mjs';

const MATRIX=[{tier:'tall',height:890},{tier:'compact',height:640}];

for(const {tier,height} of MATRIX)for(const theme of ['night','day'])for(const locale of ['en','zh-CN'])
test(`C-02 (${tier}/${theme}/${locale}): the shell renders completely, themed, without overflow`,async({page})=>{
 await page.setViewportSize({width:636,height});await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance:{...appearance,theme,locale},shell:{...shell,tier},redBelow:25})),'C-02: load accepted').toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data:currentSample()})),'C-02: synthetic facts display').toBe(true);
 const state=await page.evaluate(()=>{
  const cockpit=document.querySelector('#cockpit');
  const rect=cockpit.getBoundingClientRect();
  return {
   theme:document.documentElement.getAttribute('data-theme'),
   layout:cockpit.getAttribute('data-layout'),
   parts:['.ck-shell','.ck-deck','.ck-eng','.ck-tape','.ck-head','.mfd-pk'].map(sel=>sel.replace(/[.#]/g,'')+':'+!!document.querySelector(sel)),
   fits:rect.width>0&&rect.height>0&&rect.right<=window.innerWidth+1&&rect.bottom<=window.innerHeight+1
  };
 });
 expect(state.theme,'C-02: theme attribute follows the appearance').toBe(theme);
 expect(state.layout,'C-02: layout tier follows the display ('+tier+' → '+height+')').toBe(String(height));
 for(const part of state.parts)expect(part.endsWith(':true'),'C-02: '+part+' present').toBe(true);
 expect(state.fits,'C-02: the silhouette fits the display').toBe(true);
 // The visible labels follow the locale (All key aria-label per engine i18n).
 const allLabel=await page.locator('.ek-all').getAttribute('aria-label');
 expect(allLabel,'C-02: locale applied to visible controls').toBe(locale==='en'?'All':'全部');
});

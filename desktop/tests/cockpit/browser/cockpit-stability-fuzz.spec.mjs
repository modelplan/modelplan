// SPDX-License-Identifier: MIT
// Deterministic malformed-data fuzzing from the checked-in Go capture. Invalid displays must be typed refusals, keep
// the last committed render and leave the bridge usable for the next good capture.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,capture,commands,pageId,shell,excludePortholeFlicker} from '../fixture.mjs';

test.beforeEach(async({page})=>excludePortholeFlicker(page));

async function open(page){
  await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};});
  await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
  const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
  expect(await receive(send('load',{appearance,shell}))).toBe(true);
  expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
  return {send,receive};
}

function seededChoices(seed){
  let state=seed>>>0;
  return ()=>{state=(Math.imul(state,1664525)+1013904223)>>>0;return state;};
}

test('seeded capture mutations are rejected without losing the last cockpit render',async({page})=>{
  const pageErrors=[];page.on('pageerror',error=>pageErrors.push(error.message));
  const {send,receive}=await open(page),seed=capture(),next=seededChoices(0xC0C01114);
  const counts={missing:0,truncated:0,wrongType:0,longField:0};

  for(let index=0;index<64;index++){
    const marker=`GOOD-${index.toString().padStart(3,'0')}`;
    const good=structuredClone(seed);good.projection.rows[0].name={en:marker,zh:marker};
    expect(await receive(send('display',{data:good}))).toBe(true);
    await expect(page.locator('#cockpit')).toContainText(marker);

    const damaged=structuredClone(good),choice=next()%4;
    let raw,reason;
    if(choice===0){delete damaged.projection.rows[0].id;raw=send('display',{data:damaged});reason='data.schema';counts.missing++;}
    else if(choice===1){raw=send('display',{data:damaged}).slice(0,-1);reason='msg.parse';counts.truncated++;}
    else if(choice===2){damaged.projection.rows='wrong-type';raw=send('display',{data:damaged});reason='data.schema';counts.wrongType++;}
    else {damaged.projection.rows[0].id='x'.repeat(129+index%32);raw=send('display',{data:damaged});reason='data.rowId';counts.longField++;}

    const rejection=await page.evaluate(raw=>{
      const accepted=window.modelPlanCockpit.receive(raw);
      return {accepted,reason:window.modelPlanCockpit.reject(),state:window.modelPlanCockpit.state()};
    },raw);
    expect(rejection).toEqual({accepted:false,reason,state:'ready'});
    await expect(page.locator('#cockpit')).toContainText(marker);
    await expect(page.locator('#cockpit')).not.toContainText(`BAD-${index}`);
  }

  const oversized=structuredClone(seed);
  oversized.projection.rows[0].name={en:'x'.repeat(1_050_000),zh:'too long'};
  const tooLarge=await page.evaluate(raw=>({accepted:window.modelPlanCockpit.receive(raw),reason:window.modelPlanCockpit.reject(),state:window.modelPlanCockpit.state()}),send('display',{data:oversized}));
  expect(tooLarge).toEqual({accepted:false,reason:'msg.size',state:'ready'});
  await expect(page.locator('#cockpit')).toContainText('GOOD-063');
  const recovered=structuredClone(seed);recovered.projection.rows[0].name={en:'GOOD-AFTER-FUZZ',zh:'GOOD-AFTER-FUZZ'};
  expect(await receive(send('display',{data:recovered}))).toBe(true);
  await expect(page.locator('#cockpit')).toContainText('GOOD-AFTER-FUZZ');
  expect(counts.missing).toBeGreaterThan(0);expect(counts.truncated).toBeGreaterThan(0);
  expect(counts.wrongType).toBeGreaterThan(0);expect(counts.longField).toBeGreaterThan(0);
  expect(pageErrors).toEqual([]);
  expect(await page.evaluate(()=>window.modelPlanCockpit.state())).toBe('ready');
});

// SPDX-License-Identifier: MIT
// Banking ([ / ]) during a fader drag must end the drag: no ghost is left mid-drag, the release starts no trial, and the
// next drag on the repainted channel is accepted. The built page through its normal bridge; synthetic data only.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell,excludePortholeFlicker} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';

test.beforeEach(async({page})=>excludePortholeFlicker(page));
const model=(id,developerId)=>({id,name:'Synthetic '+id,developerId,recommended:'medium',efforts:[{effort:'low',label:'Low',star:false,ability:30,cost:1,time:null},{effort:'medium',label:'Med',star:true,ability:40,cost:2,time:null}]});
function fixture(){
 const data=visualFixture().data;
 const publication=[model('used','openai'),model('lineup-1','openai'),model('lineup-2','anthropic')];
 data.details.publication={contractVersion:1,publicationId:'0123456789abcdef01234567',publishedAt:'2026-10-24T12:00:00Z',source:'client',truncated:true,models:publication};
 data.details.publishedModels=[...publication,model('more-1','openai'),model('xai-1','xai'),model('more-2','openai'),model('also-used','anthropic'),model('more-3','openai')];
 data.details.sessions=[{sessionRef:'00000000000000a1',source:'codex',subscriptionRef:null,model:'used',effort:'medium',projectLabel:null,lastObservedAt:new Date().toISOString(),state:'running',rate:null},
  {sessionRef:'00000000000000a2',source:'claude',subscriptionRef:null,model:'also-used',effort:'medium',projectLabel:null,lastObservedAt:new Date(Date.now()-60e3).toISOString(),state:'idle',rate:null}];
 return data;
}
async function open(page,data){
 await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance,shell,redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data}))).toBe(true);
}
const drag=async(page,slot,key)=>{
 const travel=page.locator('.fd-ch').nth(slot).locator('.fd-travel'),box=await travel.boundingBox(),x=box.x+box.width/2;
 await page.mouse.move(x,box.y+box.height/2);await page.mouse.down();await page.mouse.move(x,box.y+box.height*.95);
 await expect(page.locator('.fd-ch').nth(slot).locator('.fd-ghost.drag')).toHaveCount(1);
 if(key)await page.keyboard.press(key);
 return x;
};

test('banking during a fader drag ends the drag and the release starts no trial',async({page})=>{
 await open(page,fixture());
 const first=await page.locator('.fd-ch').first().getAttribute('data-model');
 await drag(page,0,']');
 await expect(page.locator('.bank-lcd')).toHaveText('Bank 2/3');
 expect(await page.locator('.fd-ch').first().getAttribute('data-model')).not.toBe(first);
 await expect(page.locator('.fd-ghost.drag')).toHaveCount(0);
 await page.mouse.up();
 await expect(page.locator('.fd-ch.trying')).toHaveCount(0);
 // A new drag on the repainted channel is accepted (a stale drag would reject the pointerdown).
 await drag(page,0);
 await page.mouse.up();
});

test('banking onto an empty slot during a drag leaves no drag behind',async({page})=>{
 await open(page,fixture());
 await page.keyboard.press(']');await expect(page.locator('.bank-lcd')).toHaveText('Bank 2/3');await page.keyboard.press(']');
 await expect(page.locator('.bank-lcd')).toHaveText('Bank 3/3');
 await page.keyboard.press('[');await expect(page.locator('.bank-lcd')).toHaveText('Bank 2/3');
 await drag(page,1,']');await expect(page.locator('.bank-lcd')).toHaveText('Bank 3/3');
 await expect(page.locator('.fd-ch').nth(1)).toHaveClass(/empty/);
 await page.mouse.up();
 await expect(page.locator('.fd-ch.trying')).toHaveCount(0);
 await drag(page,0);
 await page.mouse.up();
});

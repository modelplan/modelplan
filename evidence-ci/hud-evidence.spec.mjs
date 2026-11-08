// SPDX-License-Identifier: MIT
// Evidence only (G3-48): the compact porthole HUD with three long published names, in headless WebKit.
import {test} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';
test('hud evidence',async({page})=>{
 await page.setViewportSize({width:636,height:661});
 await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),rcv=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 const {data}=visualFixture();const eff=(k,a,c,s=false)=>({effort:k,label:k,star:s,ability:a,cost:c,time:30});
 data.details.publishedModels=[['astra','GPT-6 Astra',45,.4],['terra','GPT-6.1 Terra',52,.9],['luna','GPT-6 Luna',48,.2]].map(([id,name,a,c])=>({id,name,developerId:'openai',recommended:'high',efforts:[eff('med',a-5,c/2),eff('high',a,c,true)]}));
 await rcv(send('load',{appearance:{...appearance,locale:'zh-CN'},shell:{...shell,tier:'compact'}}));
 await rcv(send('visibility',{visible:true,occluded:false,key:true}));await rcv(send('display',{data}));
 await page.waitForTimeout(500);
 await page.screenshot({path:process.env.EVIDENCE_DIR+'/hud-compact.png',clip:{x:0,y:0,width:636,height:110}});
});

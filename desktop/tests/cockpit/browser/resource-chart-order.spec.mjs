// SPDX-License-Identifier: MIT
// D352 change 4 / D347: the resource plugin's big screen draws CPU, then Memory, then Disk, top to bottom, and its
// column reads CPU · Memory · Disk. The plugin is not on main yet (modelplan#1096), so this is fixme until it lands;
// the first run after #1096 merges must remove the fixme. Measured with the shared chart-order helper.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,sample,shell,excludePortholeFlicker} from '../fixture.mjs';
import {assertChartOrder} from '../chart-order.mjs';
test.beforeEach(async({page})=>excludePortholeFlicker(page));

const GB=1024**3,T0=Date.UTC(2026,10,19,12);
const reading=t=>({t,cpuUser:19,cpuSystem:3,load:2.4,memTotal:32*GB,memApp:Math.round(9.2*GB),memWired:Math.round(4.5*GB),memCompressed:Math.round(1.4*GB),memCached:Math.round(12.8*GB),memFree:Math.round(4.1*GB),swapUsed:0,pressure:'normal',diskTotal:494*GB,diskFree:120*GB});

test.fixme('D347 the resource column and big screen run CPU > Memory > Disk (fails on main: plugin lands with #1096)',async({page})=>{
 const data=sample();data.projection.rows=data.projection.rows.slice(0,2);
 await page.clock.setFixedTime(new Date('2026-11-19T12:00:00Z'));
 await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance:{...appearance,locale:'en'},shell,redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('plugins',{plugins:{version:1,entries:[],settings:{resources:{intervalSeconds:10}}}}))).toBe(true);
 expect(await receive(send('display',{data}))).toBe(true);
 expect(await receive(send('pluginData',{id:'resources',data:{samples:Array.from({length:60},(_,i)=>reading(T0+i*10000))}}))).toBe(true);
 // Column: the three cells, left to right.
 await expect(page.locator('.eng-cols .pl-col[data-plugin="resources"] .pl-tag')).toHaveText(['CPU','Memory','Disk']);
 // Big screen: the three charts, top to bottom.
 await page.locator('.eng-keys .pl-key[data-plugin="resources"]').click();
 const screen=page.locator('.mfd-screen .pl-screen[data-plugin="resources"]');
 await expect(screen).toBeVisible();
 const tops=await screen.evaluate(el=>Object.fromEntries([['cpu','[data-chart="cpu"]'],['memory','[data-chart="memory-used"]'],['disk','[data-chart="disk"]']].map(([id,s])=>[id,el.querySelector(s).getBoundingClientRect().top])));
 assertChartOrder(Object.entries(tops).map(([id,pos])=>({id,pos})),['cpu','memory','disk'],'resource big screen, top to bottom');
});

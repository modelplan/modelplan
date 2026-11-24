// SPDX-License-Identifier: MIT
// D352 change 4 / D347: the resource plugin reads CPU, then Memory, then Disk. D407 R1: in the column the radar's rows
// run top to bottom in that order and its arcs outer to inner; D413: the big screen's cards read in that order. Measured
// with the shared chart-order helper.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,sample,shell,excludePortholeFlicker} from '../fixture.mjs';
import {assertChartOrder} from '../chart-order.mjs';
test.beforeEach(async({page})=>excludePortholeFlicker(page));

const GB=1024**3,T0=Date.UTC(2026,10,19,12);
const reading=t=>({t,cpuUser:19,cpuSystem:3,load:2.4,memTotal:32*GB,memApp:Math.round(9.2*GB),memWired:Math.round(4.5*GB),memCompressed:Math.round(1.4*GB),memCached:Math.round(12.8*GB),memFree:Math.round(4.1*GB),swapUsed:0,pressure:'normal',diskTotal:494*GB,diskFree:120*GB});

test('D347 the resource column and big screen run CPU > Memory > Disk',async({page})=>{
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
 // Column and big screen: the radar rows, top to bottom; the arcs, outer (largest radius) to inner.
 const order=root=>page.locator(root).evaluate(el=>({rows:['cpu','memory','disk'].map(id=>({id,pos:el.querySelector(`[data-row="${id}"]`).getBoundingClientRect().top})),
  arcs:['cpu','memory','disk'].map(id=>({id,pos:-el.querySelector(`[data-track="${id}"]`).getBoundingClientRect().width}))}));
 const col=await order('.eng-cols .pl-col[data-plugin="resources"]');
 assertChartOrder(col.rows,['cpu','memory','disk'],'resource column rows, top to bottom');
 assertChartOrder(col.arcs,['cpu','memory','disk'],'resource column arcs, outer to inner');
 await page.locator('.eng-keys .pl-key[data-plugin="resources"]').click();
 const screen=page.locator('.mfd-screen .pl-screen[data-plugin="resources"]');
 await expect(screen).toBeVisible();
 // D413: the big screen's cards read CPU, Memory, Disk (left to right, then down).
 const cards=await screen.evaluate(el=>['cpu','memory','disk'].map(id=>{const r=el.querySelector(`[data-card="${id}"] rect`).getBoundingClientRect();return {id,pos:r.top*10000+r.left};}));
 assertChartOrder(cards,['cpu','memory','disk'],'resource big screen cards, reading order');
});

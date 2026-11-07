// SPDX-License-Identifier: MIT
// Forecast consumer (owner D38, CKP-STRIP-05) on the built page through its normal bridge, with synthetic data only.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';

const NOW=Date.parse('2026-11-04T12:00:00Z'),iso=minutes=>new Date(NOW+minutes*60000).toISOString();
async function open(page,data,locale='en') {
 await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};});
 await page.clock.setFixedTime(new Date(NOW));
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance:{...appearance,locale},shell,redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data}))).toBe(true);
}
// One member at 60% left with a reset in 5 h; every other window is left comfortably above the line.
function fixture(forecast={}) {
 const data=visualFixture().data,row=data.projection.rows[0],account=row.accounts[0],w=account.windows[0];
 for(const r of data.projection.rows)for(const a of r.accounts)for(const x of a.windows)if(x.remainingPercent!==null)x.remainingPercent=90;
 w.remainingPercent=60;w.resetsAt=iso(300);
 data.details.forecasts=[{source:row.id,subscriptionRef:account.subscriptionRef,windowId:w.id,runsOutAt:iso(40),pace:'tight',basis:'recent-rate',observedAt:iso(-2),...forecast}];
 return {data,row,account,w};
}
const lamp=page=>page.locator('[data-caution]');

test('D38 a forecast run-out lights the amber lamp and the won\'t-last row',async({page})=>{
 const {data,row,w}=fixture();
 await open(page,data);
 await expect(lamp(page)).toHaveClass(/\bamber\b/);await expect(lamp(page)).not.toHaveClass(/\bred\b/);
 await lamp(page).click();
 await expect(page.getByText(`${row.name.en} ${w.label.en} 60% · won't last 5h00`)).toBeVisible();
});

test('D38 the Chinese row reads 撑不到 and uses the same rule',async({page})=>{
 const {data,row,w}=fixture();
 await open(page,data,'zh-CN');
 await expect(lamp(page)).toHaveClass(/\bamber\b/);
 await lamp(page).click();
 await expect(page.getByText(`${row.name.zh} ${w.label.zh} 60% · 撑不到 5h00 后重置`)).toBeVisible();
});

test('D38 the engine cell and the Subscription page name the run-out',async({page})=>{
 await open(page,fixture().data);
 await expect(page.locator('.qcell').filter({hasText:'out ~40m'}).first()).toBeVisible();
 await page.keyboard.press('1');
 await page.getByRole('button',{name:'Subscription',exact:true}).click();
 await expect(page.locator('.sp-w em.amber').first()).toHaveText('out ~40m');
});

for(const [name,forecast] of [['no run-out in the forecast',{runsOutAt:null,basis:'none',pace:'on_track'}],['a run-out already passed',{runsOutAt:iso(-1)}],['a run-out after the reset',{runsOutAt:iso(301)}]])
 test(`D38 ${name} creates no amber`,async({page})=>{
  await open(page,fixture(forecast).data);
  await expect(lamp(page)).not.toHaveClass(/\bamber\b/);
  await expect(page.locator('.qcell').filter({hasText:'out ~'})).toHaveCount(0);
 });

test('D38 an older engine without forecasts creates no amber',async({page})=>{
 const {data}=fixture();delete data.details.forecasts;
 await open(page,data);
 await expect(lamp(page)).not.toHaveClass(/\bamber\b/);
});

test('D38 at or below the red line the window is red, not amber',async({page})=>{
 const {data,w}=fixture();w.remainingPercent=20;
 await open(page,data);
 await expect(lamp(page)).toHaveClass(/\bred\b/);await expect(lamp(page)).not.toHaveClass(/\bamber\b/);
});

test('D38 a retained reading never forecasts',async({page})=>{
 const {data,account}=fixture();account.valueState='retained';
 await open(page,data);
 await expect(lamp(page)).not.toHaveClass(/\bamber\b/);
});

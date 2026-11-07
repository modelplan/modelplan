// SPDX-License-Identifier: MIT
// G1 web checks use the built page and synthetic data through its normal bridge.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';

async function open(page,data=visualFixture().data) {
 await page.addInitScript(()=>{window.__g1Messages=[];window.webkit={messageHandlers:{cockpit:{postMessage(raw){window.__g1Messages.push(JSON.parse(raw));}}}};});
 await page.clock.setFixedTime(new Date('2026-11-04T12:00:00Z'));
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance,shell,redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data}))).toBe(true);
 return {send,receive,data};
}

test('CKP-ENG-02 one or two subscriptions keep three engine columns',async({page})=>{
 const data=visualFixture().data;data.projection.rows=data.projection.rows.slice(0,1);
 const {send,receive}=await open(page,data);
 for(const count of [1,2]){
  if(count===2){const row=structuredClone(data.projection.rows[0]);row.id='synthetic-second';row.accounts[0].subscriptionRef=null;row.accounts[0].accountLocator=null;data.projection.rows.push(row);expect(await receive(send('display',{data}))).toBe(true);}
  await expect(page.locator('.eng-keys')).toHaveAttribute('data-slots','3');
  await expect(page.locator('.eng-keys .ek[data-sub]')).toHaveCount(count);
  await expect(page.locator('.eng-keys .ek-bay')).toHaveCount(3-count);
 }
});

test('CKP-ENG-14 shared threshold includes the exact 51, 50, 26, 25 and zero boundaries (D22)',async({page})=>{
 const data=visualFixture().data,extra=structuredClone(data.projection.rows[0]);extra.id='synthetic-fifth';extra.accounts[0].subscriptionRef=null;extra.accounts[0].accountLocator=null;data.projection.rows.push(extra);
 for(const [i,row] of data.projection.rows.entries())for(const window of row.accounts[0].windows)window.remainingPercent=[51,50,26,25,0][i];
 await open(page,data);
 const cells=page.locator('.eng-cols .ec[data-col] .qcell[data-row="first"]');await expect(cells).toHaveCount(5);
 for(const [i,kind] of ['ok','mid','mid','low','low'].entries())await expect(cells.nth(i)).toHaveClass(new RegExp('\\blv-'+kind+'\\b'));
 await page.getByRole('button',{name:'Subscription',exact:true}).click();const values=page.locator('.sa-list .sa .v');
 for(const [i,kind] of ['ok','mid','mid','low','low'].entries())await expect(values.nth(i)).toHaveClass(new RegExp('\\blv-'+kind+'\\b'));
});

test('CKP-STRIP-04 ALERT stays English while its accessible label localizes',async({page})=>{
 const {send,receive}=await open(page);const lamp=page.locator('[data-caution]');
 await expect(lamp).toContainText('ALERT');await expect(lamp).toHaveAttribute('aria-label','Alert inactive');
 expect((await lamp.boundingBox()).height).toBeCloseTo((await page.locator('[data-settings]').boundingBox()).height,0);
 expect(await receive(send('appearance',{...appearance,locale:'zh-CN'}))).toBe(true);
 await expect(lamp).toContainText('ALERT');await expect(lamp).toHaveAttribute('aria-label','告警未激活');
});

test('CKP-STRIP-07 Option opens and dismisses the help map without a help key',async({page})=>{
 const {send,receive}=await open(page);const map=page.locator('#help-map'),detach=page.locator('[data-detach]');
 await expect(page.locator('[data-help],button[aria-label="Help"]')).toHaveCount(0);const before=await detach.boundingBox();
 await page.keyboard.down('Alt');await expect(map).toBeVisible();await expect(map.locator('[data-target="[data-detach]"]')).toContainText('Detach');
 const otherLabels=()=>map.locator('.an:not([data-target="[data-detach]"])').evaluateAll(nodes=>nodes.map(n=>({target:n.dataset.target,x:n.getBoundingClientRect().x,y:n.getBoundingClientRect().y})));
 const labelsBefore=await otherLabels();expect(await detach.boundingBox()).toEqual(before);await page.keyboard.up('Alt');await expect(map).toBeHidden();
 expect(await receive(send('shell',{...shell,attached:false}))).toBe(true);
 await page.keyboard.down('Alt');await expect(map.locator('[data-target="[data-detach]"]')).toContainText('Put back');expect(await otherLabels()).toEqual(labelsBefore);await page.keyboard.up('Alt');await expect(map).toBeHidden();
});

test('CKP-STRIP-08 record strip has five or three lines including the collapsed profile',async({page})=>{
 const {send,receive}=await open(page);await expect(page.locator('.ck-tape .tl')).toHaveCount(5);
 expect(await receive(send('shell',{...shell,tier:'tall',profile:'closed'}))).toBe(true);await expect(page.locator('.ck-tape .tl')).toHaveCount(5);
 expect(await receive(send('shell',{...shell,tier:'compact'}))).toBe(true);await expect(page.locator('.ck-tape .tl')).toHaveCount(3);
 expect(await receive(send('shell',{...shell,tier:'compact',profile:'closed'}))).toBe(true);await expect(page.locator('.ck-tape .tl')).toHaveCount(3);
});

test('CKP-STRIP-11 v1 session lines expose text without state-square or done indicators',async({page})=>{
 await open(page);const row=page.locator('.ck-tape .t-observed').first();
 await expect(row.locator('.t-tool')).toHaveText('Codex');await expect(row.locator('.t-proj')).toHaveText('modelPlans');
 await expect(row.locator('.t-time')).toHaveText('Running');await expect(row.locator('.session-state,.done,.error,[data-session-state]')).toHaveCount(0);
});

test('CKP-ENG-07 a monthly-only quota stays in Other and distinguishes unknown from absent',async({page})=>{
 const data=visualFixture().data;data.projection.rows=data.projection.rows.slice(0,1);
 const account=data.projection.rows[0].accounts[0],monthly={...structuredClone(account.windows[0]),id:'monthly:2592000:main:main',role:'monthly',durationSeconds:2592000,limitKey:'main',poolKey:'main',remainingPercent:42,label:{en:'Monthly',zh:'每月'}};
 account.windows=[monthly];const {send,receive}=await open(page,data);const col=page.locator('.eng-cols .ec[data-col]').first();
 await expect(col.locator('.qcell[data-row="first"]')).toBeEmpty();await expect(col.locator('.qcell[data-row="second"]')).toBeEmpty();
 await expect(col.locator('.qcell[data-row="other"] .qvalue')).toHaveText('42');await expect(col.locator('.qcell[data-row="other"]')).toHaveAttribute('data-kind','extra');await expect(col.locator('.qcell[data-row="other"]')).toHaveAttribute('data-tag',/mo/i);
 monthly.remainingPercent=null;expect(await receive(send('display',{data}))).toBe(true);
 await expect(col.locator('.qcell[data-row="other"] .qvalue')).toHaveText('--');await expect(col.locator('.qcell[data-row="first"]')).toBeEmpty();
});

test('CKP-ENG-08 Today uses today output and today average, with unknown left blank',async({page})=>{
 const data=visualFixture().data;const detail=data.details.subscriptions[0];detail.today[0].observedOutputTokens=12000;detail.today[0].generationTps=42;
 const {send,receive}=await open(page,data);const row=page.locator('.eng-cols .ec[data-col]').first().locator('.qrow-t');
 await expect(row.locator('.qtokens')).toHaveText('12k');await expect(row.locator('.qaverage')).toContainText('42');
 detail.today=[];expect(await receive(send('display',{data}))).toBe(true);
 await expect(row.locator('.qtokens')).toHaveCount(0);await expect(row.locator('.qaverage')).toHaveCount(0);
});

test('CKP-ENG-06 named general windows and the tightest Other quota stay separate',async({page})=>{
 const data=visualFixture().data;data.projection.rows=data.projection.rows.slice(0,1);const account=data.projection.rows[0].accounts[0];
 const first={...structuredClone(account.windows[0]),remainingPercent:75},week={...structuredClone(account.windows[1]),remainingPercent:65};
 const restricted={...structuredClone(first),id:'session:18000:code_review:code_review',limitKey:'code_review',poolKey:'code_review',remainingPercent:30,modelScope:{models:['opus']}};
 const monthly={...structuredClone(first),id:'monthly:2592000:main:main',role:'monthly',durationSeconds:2592000,remainingPercent:20};
 account.windows=[restricted,week,monthly,first];
 await open(page,data);const col=page.locator('.eng-cols .ec[data-col]').first();
 await expect(col.locator('.qcell[data-row="first"] .qvalue')).toHaveText('75');
 await expect(col.locator('.qcell[data-row="second"] .qvalue')).toHaveText('65');
 await expect(col.locator('.qcell[data-row="other"] .qvalue')).toHaveText('20');
 await expect(col.locator('.qcell[data-row="other"]')).toHaveAttribute('data-more','1');
 const other=col.locator('.qcell[data-row="other"]'),label=other.locator('.qtxt');
 await expect(label).toBeVisible();await expect(label).toHaveText('5h·mo reset ? +1');
 await expect(other).toHaveAccessibleName(/5h·5h · 30% left[\s\S]*5h·mo · 20% left/);
 await expect(col.locator('.qcell[data-row="other"]')).toHaveAttribute('data-kind','extra');
 await expect(col.locator('.qcell[data-row="other"]')).toHaveAttribute('data-tag',/mo/i);
});

test('CKP-ENG-12 quota bars have ten segments and only known remaining time has dots',async({page})=>{
 const data=visualFixture().data;data.projection.rows=data.projection.rows.slice(0,1);const window=data.projection.rows[0].accounts[0].windows[0];window.resetsAt='2026-11-04T12:00:01Z';
 const {send,receive}=await open(page,data);const cell=page.locator('.eng-cols .ec[data-col]').first().locator('.qcell[data-row="first"]');
 await expect(cell.locator('.qbar i')).toHaveCount(10);await expect(cell.locator('.qtime i')).toHaveCount(10);expect(await cell.locator('.qtime i.on').count()).toBeGreaterThanOrEqual(1);
 expect((await cell.locator('.qbar').boundingBox()).width).toBeGreaterThan((await cell.boundingBox()).width-10);
 window.resetsAt=null;expect(await receive(send('display',{data}))).toBe(true);await expect(cell.locator('.qtime')).toHaveCount(0);
 window.resetsAt='2026-11-04T13:00:00Z';window.role='other';window.durationSeconds=null;window.id='other:unknown:main:main';expect(await receive(send('display',{data}))).toBe(true);
 await expect(page.locator('.eng-cols .ec[data-col]').first().locator('.qcell[data-row="other"] .qtime')).toHaveCount(0);
});

test('CKP-MFD-01 the public screen stays beside the faders with no expand key',async({page})=>{
 await open(page);const mfd=page.locator('.dk-mfd'),faders=page.locator('.dk-fad');await expect(mfd).toBeVisible();await expect(faders).toBeVisible();
 const a=await mfd.boundingBox(),b=await faders.boundingBox();expect(a.width).toBeGreaterThan(b.width);expect(a.x).toBeGreaterThanOrEqual(b.x+b.width);
 await expect(page.locator('[data-expand],[aria-label*="Expand" i]')).toHaveCount(0);
});

test('CKP-STRIP-15 v1 session text is rendered safely from the admitted bridge',async({page})=>{
 const data=visualFixture().data,payload='<img src=x onerror="window.g1Injected=true">';Object.assign(data.details.sessions[0],{source:payload,model:payload,effort:payload,projectLabel:payload});await open(page,data);
 const row=page.locator('.ck-tape .t-observed').first();for(const selector of ['.t-tool','.t-model','.t-eff','.t-proj'])await expect(row.locator(selector)).toHaveText(payload);
 await expect(row.locator('img,svg,script')).toHaveCount(0);expect(await page.evaluate(()=>window.g1Injected)).toBeUndefined();
});

test('CKP-ENG-09 reserve uses reported reset counts and credits, not a public confirmation',async({page})=>{
 const data=visualFixture().data;data.projection.rows=data.projection.rows.slice(0,1);const detail=data.details.subscriptions[0];detail.resetCounts=[];detail.credits=null;
 data.details.resetEvents=[{version:1,id:'synthetic-reset',provider:'openai',rowId:'codex',status:'confirmed',publishedAt:'2026-11-04T11:00:00Z',expiresAt:'2026-11-05T12:00:00Z',source:{kind:'publication',publicationId:'0123456789abcdef01234567'}}];
 const {send,receive}=await open(page,data);const col=page.locator('.eng-cols .ec[data-col]').first();
 await expect(col.locator('.qrv-c,.qrv-p')).toHaveCount(0);
 detail.resetCounts=[{kind:'tokens',count:2,expiresAt:'2026-11-10T12:00:00Z'}];detail.credits={balance:19613.957,observedAt:'2026-11-04T12:00:00Z'};
 expect(await receive(send('display',{data}))).toBe(true);await expect(col.locator('.qrv-c')).toContainText('2');await expect(col.locator('.qrv-p')).toHaveText('19,614');
 for(const [value,expected] of [[0.2,'<1'],[0,'0']]){detail.credits.balance=value;expect(await receive(send('display',{data}))).toBe(true);await expect(col.locator('.qrv-p')).toHaveText(expected);}
});

test('CKP-SHELL-03 gear, detach and close share a strip key geometry and order',async({page})=>{
 await open(page);const controls=await Promise.all(['[data-settings]','[data-detach]','[data-close]'].map(s=>page.locator(s).boundingBox()));
 expect(controls.every(Boolean)).toBe(true);expect(controls[0].x).toBeLessThan(controls[1].x);expect(controls[1].x).toBeLessThan(controls[2].x);
 for(const r of controls.slice(1)){expect(r.width).toBeCloseTo(controls[0].width,0);expect(r.height).toBeCloseTo(controls[0].height,0);}
});

test('CKP-STRIP-01 cockpit strip exposes one ordered row of its required controls',async({page})=>{
 await open(page);const selectors=['.ck-brand','[data-shutter]','[data-caution]','[data-settings]','[data-detach]','[data-close]'];const rects=[];
 for(const selector of selectors){const element=page.locator('.ck-head '+selector);await expect(element).toBeVisible();rects.push(await element.boundingBox());}
 for(let i=1;i<rects.length;i++)expect(rects[i].x).toBeGreaterThan(rects[i-1].x);
 expect(Math.max(...rects.map(r=>r.y))-Math.min(...rects.map(r=>r.y))).toBeLessThan(26);
 const header=await page.locator('.ck-head').boundingBox();expect(rects[1].x+rects[1].width/2).toBeCloseTo(header.x+header.width/2,0);
 await expect(page.locator('.ck-head .wordmark')).toHaveText('ModelPlan');
 await expect(page.locator('.ck-head [data-help],.ck-head button[aria-label="Help"]')).toHaveCount(0);
});

test('CKP-ENG-04 All and vendor keys share scope and the neutral underline geometry',async({page})=>{
 await open(page);const all=page.locator('.ek-all'),vendor=page.locator('.eng-keys .ek[data-sub]').first();
 await expect(all).toHaveAttribute('aria-pressed','true');await expect(vendor).toHaveAttribute('aria-pressed','false');
 const underline=all.locator('.bl'),vendorLine=vendor.locator('.bl');const active=await underline.evaluate(e=>({opacity:Number(getComputedStyle(e).opacity),color:getComputedStyle(e).backgroundColor,height:e.getBoundingClientRect().height}));
 const rgb=active.color.match(/\d+/g).slice(0,3).map(Number);expect(Math.max(...rgb)-Math.min(...rgb)).toBeLessThan(30);
 expect(active.height).toBeCloseTo((await vendorLine.boundingBox()).height,0);
 await page.getByRole('button',{name:'Subscription',exact:true}).click();await vendor.click();
 await expect(all).toHaveAttribute('aria-pressed','false');await expect(vendor).toHaveAttribute('aria-pressed','true');await expect(page.locator('.sp-h')).toBeVisible();
 expect(Number(await underline.evaluate(e=>getComputedStyle(e).opacity))).toBeLessThan(active.opacity);
 await all.click();await expect(all).toHaveAttribute('aria-pressed','true');await expect(page.locator('.sa-list')).toBeVisible();
});


test('CKP-MFD-10 subscription header and quota windows use delivered reading and relative reset',async({page})=>{
 const data=visualFixture().data;data.projection.rows=data.projection.rows.slice(0,1);const account=data.projection.rows[0].accounts[0];account.observedAt='2026-11-04T11:55:00Z';account.windows[0].resetsAt='2026-11-04T13:00:00Z';
 await open(page,data);await page.getByRole('button',{name:'Subscription',exact:true}).click();await page.locator('.eng-keys .ek[data-sub]').first().click();
 await expect(page.locator('.sp-h .mg')).toHaveCount(1);await expect(page.locator('.sp-h b')).toHaveText(data.projection.rows[0].name.en);await expect(page.locator('.sp-sub .pl')).toContainText(account.plan.name.en);
 await expect(page.locator('.sp-sub .src')).toContainText('5');await expect(page.locator('.sp-sub .src')).toHaveAttribute('title','modelplan CLI');
 const w=page.locator('.sp-w').first();await expect(w.locator('.v')).toHaveText('75%');await expect(w.locator('.mb10 i')).toHaveCount(10);await expect(w.locator('em')).toContainText('1h');await expect(w).not.toContainText('2026');
});

test('CKP-MFD-03 screen option keys remain in one row with choices and active indicator',async({page})=>{
 await open(page);const keys=page.locator('.mfd-ok > *');await expect(keys).toHaveCount(3);const boxes=await Promise.all((await keys.all()).map(x=>x.boundingBox()));expect(Math.max(...boxes.map(x=>x.y))-Math.min(...boxes.map(x=>x.y))).toBeLessThan(2);
 const buttons=page.locator('.mfd-ok button');expect(await buttons.count()).toBeGreaterThan(0);
 for(const button of await buttons.all()){expect(await button.locator('[data-choice]').count()).toBeGreaterThanOrEqual(2);await expect(button.locator('[data-choice].on')).toHaveCount(1);const led=await button.locator('[data-choice].on').evaluate(e=>{const s=getComputedStyle(e,'::after');return {content:s.content,height:parseFloat(s.height)};});expect(led.content).not.toBe('none');expect(led.height).toBeGreaterThan(0);await expect(button).not.toContainText('◂');}
 const first=buttons.first(),other=first.locator('[data-choice]:not(.on)').first(),value=await other.getAttribute('data-choice');await other.click();await expect(page.locator('.mfd-ok button').first().locator('[data-choice].on')).toHaveAttribute('data-choice',value);
});

test('CKP-SHELL-22 missing bridge data stays empty and the page makes no external requests',async({page})=>{
 const requests=[];page.on('request',r=>requests.push(r.url()));const data=visualFixture().data;data.projection.rows=[];data.subscriptions=[];data.details=null;
 const {send,receive}=await open(page,data);await expect(page.locator('.eng-keys .ek[data-sub]')).toHaveCount(0);await expect(page.locator('.ck-tape .t-observed')).toHaveCount(0);await expect(page.locator('.qvalue')).toHaveCount(0);
 const supplied=visualFixture().data;expect(await receive(send('display',{data:supplied}))).toBe(true);await expect(page.locator('.eng-keys .ek[data-sub]')).toHaveCount(supplied.projection.rows.length);
 const origin=new URL(page.url()).origin;expect(requests.every(url=>new URL(url).origin===origin)).toBe(true);
});

test('CKP-ENG-10 quota numerals and bars use the LCD font and status inks',async({page})=>{
 const data=visualFixture().data;data.projection.rows=data.projection.rows.slice(0,3);for(const [i,row] of data.projection.rows.entries())row.accounts[0].windows[0].remainingPercent=[75,40,20][i];await open(page,data);
 const cells=page.locator('.eng-cols .ec[data-col] .qcell[data-row="first"]');await expect(cells).toHaveCount(3);const ink=[];
 for(const cell of await cells.all())ink.push(await cell.evaluate(e=>({font:getComputedStyle(e.querySelector('.qnum')).fontFamily,number:getComputedStyle(e.querySelector('.qnum')).color,bar:getComputedStyle(e.querySelector('.qbar i.on')).backgroundColor})));
 for(const x of ink)expect(x.font).toContain('JetBrains Mono');const rgb=ink[0].number.match(/\d+/g).slice(0,3).map(Number);expect(Math.max(...rgb)-Math.min(...rgb)).toBeLessThan(30);
 expect(ink[1].number).toBe(ink[1].bar);expect(ink[2].number).toBe(ink[2].bar);expect(ink[0].bar).not.toBe(ink[1].bar);expect(ink[1].bar).not.toBe(ink[2].bar);
});

test('CKP-STRIP-05 alert lamp selects the clear, amber and red art through bridge updates',async({page})=>{
 const data=visualFixture().data;data.projection.rows=data.projection.rows.slice(0,1);data.details=null;for(const w of data.projection.rows[0].accounts[0].windows)w.remainingPercent=75;
 const {send,receive}=await open(page,data),lamp=page.locator('[data-caution]');await expect(lamp).not.toHaveClass(/\blit\b/);await expect.poll(()=>lamp.evaluate(e=>getComputedStyle(e,'::after').backgroundImage)).toContain('lamp-off-body');
 // Owner D38: above the red line without a forecast is not a caution (amber needs the forecast producer).
 data.projection.rows[0].accounts[0].windows[0].remainingPercent=35;expect(await receive(send('display',{data}))).toBe(true);await expect(lamp).not.toHaveClass(/\b(lit|amber|red)\b/);
 data.projection.rows[0].accounts[0].windows[0].remainingPercent=20;expect(await receive(send('display',{data}))).toBe(true);await expect(lamp).toHaveClass(/\bred\b/);
 await expect.poll(()=>lamp.evaluate(e=>getComputedStyle(e,'::after').backgroundImage)).toContain('lamp-red-body');await expect.poll(()=>lamp.evaluate(e=>getComputedStyle(e,'::before').backgroundImage)).toContain('lamp-red-glow');
 // The red line is the Settings threshold T (25 here): exactly T and an exhausted window are red, T+1 is not.
 for(const [value,lit] of [[25,true],[26,false],[0,true]]){data.projection.rows[0].accounts[0].windows[0].remainingPercent=value;expect(await receive(send('display',{data}))).toBe(true);if(lit)await expect(lamp).toHaveClass(/\bred\b/);else await expect(lamp).not.toHaveClass(/\blit\b/);}
 // A stale (retained) reading never lights the lamp; it is listed as a blue line.
 data.projection.rows[0].accounts[0].valueState='retained';data.projection.rows[0].accounts[0].observedAt='2026-11-04T10:00:00Z';expect(await receive(send('display',{data}))).toBe(true);await expect(lamp).not.toHaveClass(/\blit\b/);
 await expect(page.locator('.pg-overview .mfd-alerts li.al-blue')).toContainText('Last reading 2h00 ago');await expect(page.locator('.pg-overview .mfd-alerts li.al-red')).toHaveCount(0);
});

test('CKP-ENG-11 alert washes a whole column without warning marks and missing cells stay blank',async({page})=>{
 const data=visualFixture().data;data.projection.rows=data.projection.rows.slice(0,1);data.details=null;const account=data.projection.rows[0].accounts[0];account.windows=[account.windows[0]];account.windows[0].remainingPercent=10;
 await open(page,data);const col=page.locator('.eng-cols .ec[data-col]').first(),table=page.locator('.eng-cols');await expect(col).toHaveClass(/\btint-red\b/);await expect(col.locator('.qcell[data-row="second"]')).toBeEmpty();
 await expect(table.locator('svg,img,canvas,[class*="hatch"],.warning-icon')).toHaveCount(0);expect(await table.innerText()).not.toMatch(/[▲!]/);
});

test('CKP-ENG-03 paged subscriptions keep empty bays blank and signal an off-page caution',async({page})=>{
 const data=visualFixture().data;data.details=null;for(const row of data.projection.rows)for(const w of row.accounts[0].windows)w.remainingPercent=75;
 for(let i=data.projection.rows.length;i<7;i++){const row=structuredClone(data.projection.rows[0]),ref=(i+1).toString(16).padStart(16,'0');row.id='synthetic-'+i;row.name={en:'Synthetic '+i,zh:'模拟 '+i};row.accounts[0].subscriptionRef=ref;row.accounts[0].accountLocator=ref;for(const w of row.accounts[0].windows)w.remainingPercent=i===6?20:75;data.projection.rows.push(row);data.subscriptions.push({subscriptionRef:ref,accounts:[{tool:row.id,account:structuredClone(row.accounts[0])}]});}
 await open(page,data);await expect(page.locator('.eng-keys .ek[data-sub]')).toHaveCount(6);await expect(page.locator('.eng-led[data-page="1"]')).toHaveClass(/\blv-red\b/);
 await page.locator('[data-bpage="1"]').click();await expect(page.locator('.eng-keys .ek[data-sub]')).toHaveCount(1);await expect(page.locator('.eng-keys .ek-bay')).toHaveCount(5);const bays=page.locator('.eng-cols .ec-bay');await expect(bays).toHaveCount(5);await expect(bays.locator('.qvalue,.qbar,.qtime')).toHaveCount(0);for(const bay of await bays.all())expect((await bay.innerText()).trim()).toBe('');
});

test('CKP-ENTRY-03 opens on usage with no comparison when publication is absent',async({page})=>{
 const {send,receive}=await open(page);await expect(page.getByRole('button',{name:'Overview',exact:true})).toHaveAttribute('aria-pressed','true');await expect(page.locator('.pg-overview')).toBeVisible();await expect(page.locator('.mfd-compare,[data-comparison]')).toHaveCount(0);await expect(page.locator('.fd-strip:not(:disabled)')).toHaveCount(0);
 await page.getByRole('button',{name:'Subscription',exact:true}).click();await expect(page.locator('.pg-sub')).toBeVisible();expect(await receive(send('clear',{generation:'42',viewRevision:'4'}))).toBe(true);await expect(page.locator('.mfd-compare,[data-comparison]')).toHaveCount(0);
});

test('CKP-MFD-02 four page keys select and light the current page in both languages',async({page})=>{
 const {send,receive}=await open(page);const buttons=page.locator('.mfd-pk .pk');await expect(buttons).toHaveCount(4);
 for(const labels of [['Overview','Subscription','Effort','Breakdown'],['总览','订阅','档位','去向']]){
  for(const [i,label] of labels.entries()){const key=buttons.nth(i);await expect(key).toHaveAttribute('aria-label',label);await key.click();await expect(key).toHaveAttribute('aria-pressed','true');await expect(key).toHaveClass(/\bon\b/);await expect(buttons.locator('.pk-led')).toHaveCount(4);const activeColor=await key.locator('.pk-led').evaluate(e=>getComputedStyle(e).backgroundColor);for(let j=0;j<4;j++)if(i!==j){await expect(buttons.nth(j)).toHaveAttribute('aria-pressed','false');expect(await buttons.nth(j).locator('.pk-led').evaluate(e=>getComputedStyle(e).backgroundColor)).not.toBe(activeColor);}}
  if(labels[0]==='Overview')expect(await receive(send('appearance',{...appearance,locale:'zh-CN'}))).toBe(true);
 }
});

test('CKP-MFD-04 the built page keys follow one read-only internal page registry',async({page})=>{
 await open(page);const inspection=await page.evaluate(async()=>{const m=await import('/src/prototype-deck.js');return {ids:m.cockpitPageIds,frozen:Object.isFrozen(m.cockpitPageIds)};});expect(inspection.frozen).toBe(true);const registry=inspection.ids;const keys=await page.locator('.mfd-pk .pk').evaluateAll(nodes=>nodes.map(n=>n.dataset.mfd));expect(keys).toEqual(registry.map(id=>'page:'+id));expect(registry).toEqual(['overview','sub','tune','where']);
});

test('CKP-MOT-05 day appearance lightens cockpit metal while LCDs remain dark',async({page})=>{
 const {send,receive}=await open(page),read=()=>page.evaluate(()=>{const get=q=>getComputedStyle(document.querySelector(q)).backgroundImage;return {hull:get('.ck-shell'),key:get('.ek-all'),engine:get('.eng-lcd'),screen:get('.mfd-screen')};});const night=await read();expect(await receive(send('appearance',{...appearance,theme:'day'}))).toBe(true);const day=await read();await expect(page.locator('.ck-port')).toBeVisible();await expect(page.locator('.dk-fad')).toBeVisible();
 const components=s=>[...s.matchAll(/rgb\((\d+),\s*(\d+),\s*(\d+)\)/g)].map(m=>m.slice(1).map(Number));const luminance=s=>components(s).flat().reduce((a,b)=>a+b,0)/Math.max(1,components(s).flat().length);expect(luminance(day.hull)).toBeGreaterThan(luminance(night.hull));expect(luminance(day.key)).toBeGreaterThan(luminance(night.key));for(const lcd of [day.engine,day.screen]){expect(components(lcd).length).toBeGreaterThan(0);expect(Math.max(...components(lcd).flat())).toBeLessThan(32);}
});

test('CKP-ENG-01 five and six subscription columns show names in user order',async({page})=>{
 const data=visualFixture().data;for(let i=data.projection.rows.length;i<6;i++){const row=structuredClone(data.projection.rows[0]),ref=(i+1).toString(16).padStart(16,'0');row.id='synthetic-'+i;row.name={en:'Synthetic '+i,zh:'模拟 '+i};row.accounts[0].subscriptionRef=ref;row.accounts[0].accountLocator=ref;data.projection.rows.push(row);data.subscriptions.push({subscriptionRef:ref,accounts:[{tool:row.id,account:structuredClone(row.accounts[0])}]});}
 for(const row of data.projection.rows)row.vendorKey='openai';const sixth=data.projection.rows.pop();const {send,receive}=await open(page,data);
 for(const count of [5,6]){if(count===6){data.projection.rows.push(sixth);expect(await receive(send('display',{data}))).toBe(true);}const keys=page.locator('.eng-keys .ek[data-sub]');await expect(keys).toHaveCount(count);await expect(keys.locator('img.lamp')).toHaveCount(count);await expect(keys.locator('.ek-name')).toHaveText(data.projection.rows.map(r=>r.name.en));for(const name of await keys.locator('.ek-name').all())await expect(name).toBeVisible();}
 const seventh=structuredClone(data.projection.rows[0]);seventh.id='synthetic-seventh';seventh.name={en:'Seventh',zh:'第七'};seventh.accounts[0].subscriptionRef='0000000000000007';seventh.accounts[0].accountLocator='0000000000000007';data.projection.rows.push(seventh);data.subscriptions.push({subscriptionRef:seventh.accounts[0].subscriptionRef,accounts:[{tool:seventh.id,account:structuredClone(seventh.accounts[0])}]});expect(await receive(send('display',{data}))).toBe(true);await expect(page.locator('.eng-keys .ek[data-sub]')).toHaveCount(6);await page.locator('[data-bpage="1"]').click();await expect(page.locator('.eng-keys .ek[data-sub] .ek-name')).toHaveText(['Seventh']);
});

test('CKP-ENG-05 shortcuts appear in tooltip, accessible name and Option help and visible subscription digits',async({page})=>{
 const {send,receive}=await open(page);const all=page.locator('.ek-all'),keys=page.locator('.eng-keys .ek[data-sub]');
 for(const [key,n] of [[all,0],...[...(await keys.all())].map((e,i)=>[e,i+1])]){
  if(n){await expect(key.locator('.ki')).toHaveText(String(n));await expect(key.locator('.ki')).toBeVisible();}else await expect(key.locator('.ki')).toHaveCount(0);await expect(key).toHaveAttribute('title',new RegExp(`\\b${n}\\b`));await expect(key).toHaveAccessibleName(new RegExp(`\\b${n}\\b`));if(n)await expect(key.locator('.ek-name')).toHaveAttribute('title',new RegExp(`\\b${n}\\b`));
  await key.focus();await expect(key).toBeFocused();
 }
 await page.keyboard.press('1');await expect(keys.first()).toHaveAttribute('aria-pressed','true');await page.keyboard.press('0');await expect(all).toHaveAttribute('aria-pressed','true');
 expect(await receive(send('visibility',{visible:true,occluded:false,key:false}))).toBe(true);const before=await page.evaluate(()=>window.__g1Messages.length);await page.keyboard.press('1');expect(await page.evaluate(()=>window.__g1Messages.length)).toBe(before);await expect(all).toHaveAttribute('aria-pressed','true');expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 await page.keyboard.down('Alt');await expect(page.locator('#help-map')).toContainText('0');await expect(page.locator('#help-map')).toContainText('1–6');await page.keyboard.up('Alt');
 expect(await receive(send('appearance',{...appearance,locale:'zh-CN'}))).toBe(true);for(const [key,n] of [[all,0],...[...(await keys.all())].map((e,i)=>[e,i+1])]){await expect(key).toHaveAccessibleName(new RegExp(`快捷键 ${n}`));await expect(key).toHaveAttribute('title',new RegExp(`快捷键 ${n}`));if(n){await expect(key.locator('.ki')).toHaveText(String(n));await expect(key.locator('.ki')).toBeVisible();}else await expect(key.locator('.ki')).toHaveCount(0);}
});

test('CKP-MFD-06 Overview shows delivered today total and puts threshold notices first',async({page})=>{
 const data=visualFixture().data;data.projection.rows=data.projection.rows.slice(0,1);data.details.subscriptions=data.details.subscriptions.slice(0,1);const row=data.projection.rows[0],account=row.accounts[0],detail=data.details.subscriptions[0];detail.today[0].observedOutputTokens=12000;
 data.details.alerts=[{severity:'warning',source:row.id,subscriptionRef:account.subscriptionRef,windowId:account.windows[1].id,remainingPercent:35},{severity:'critical',source:row.id,subscriptionRef:account.subscriptionRef,windowId:account.windows[0].id,remainingPercent:20}];account.windows[0].remainingPercent=20;account.windows[0].resetsAt='2026-11-04T15:30:00Z';account.windows[1].remainingPercent=35;data.details.resetEvents=[{version:1,id:'synthetic-reset',provider:'openai',rowId:row.id,status:'confirmed',publishedAt:'2026-11-04T11:00:00Z',expiresAt:'2026-11-05T12:00:00Z',source:{kind:'publication',publicationId:'0123456789abcdef01234567'}}];const {send,receive}=await open(page,data);
 await expect(page.locator('.pg-overview .mfd-alerts')).toBeVisible();await expect(page.locator('.pg-overview .mfd-alerts li').first()).toHaveClass(/\bal-red\b/);await expect(page.locator('.pg-overview .mfd-alerts li').first()).toContainText('5h 20% left · resets in 3h30');await expect(page.locator('.pg-overview .mfd-alerts li').nth(1)).toHaveClass(/\bal-blue\b/);await expect(page.locator('.pg-overview .mfd-alerts li.al-amber')).toHaveCount(0);await expect(page.locator('.pg-overview .mfd-alerts')).toContainText('Reset confirmed');await expect(page.locator('.pg-overview .ov-total')).toHaveText('12k');
 const positions=await page.locator('.pg-overview').evaluate(e=>[...e.children].map(n=>n.className));expect(positions.indexOf('mfd-alerts')).toBeLessThan(positions.indexOf('ov-top'));
 const second=visualFixture().data;data.projection.rows.push(second.projection.rows[1]);data.details.subscriptions.push({...second.details.subscriptions[1],today:[]});expect(await receive(send('display',{data}))).toBe(true);await expect(page.locator('.pg-overview .ov-total')).toHaveCount(0);await page.locator('.eng-keys .ek[data-sub]').first().click();await expect(page.locator('.pg-overview .ov-total')).toHaveText('12k');
 detail.today=[];expect(await receive(send('display',{data}))).toBe(true);await expect(page.locator('.pg-overview .ov-total')).toHaveCount(0);
});

test('CKP-MFD-11 reported reset count shows compact expiries and all expiries on hover',async({page})=>{
 const data=visualFixture().data;data.projection.rows=data.projection.rows.slice(0,1);const detail=data.details.subscriptions[0];detail.resetCards={state:'complete',count:5,truncated:false,sources:[],items:Array.from({length:5},(_,i)=>({id:(i+1).toString(16).padStart(64,'0'),expiresAt:`2026-11-${String(6+i).padStart(2,'0')}T12:00:00Z`}))};
 const {send,receive}=await open(page,data);await page.getByRole('button',{name:'Subscription',exact:true}).click();await page.locator('.eng-keys .ek[data-sub]').first().click();const cards=page.locator('.pg-sub .rc');await expect(cards).toContainText('5');await expect(cards.locator('.rc-exp i:not(.more)')).toHaveCount(4);await expect(cards.locator('.rc-exp .more')).toHaveText('+1');const title=await cards.getAttribute('title');expect(title.split('\n')).toHaveLength(5);detail.resetCards.count=null;detail.resetCards.items=[];expect(await receive(send('display',{data}))).toBe(true);await expect(cards.locator('b')).toHaveText('--');delete detail.resetCards;expect(await receive(send('display',{data}))).toBe(true);await expect(cards).toHaveCount(0);
});

test('CKP-MFD-12 scoped subscription shows reported credits and reading age without a fabricated history',async({page})=>{
 const data=visualFixture().data;data.projection.rows=data.projection.rows.slice(0,1);data.details.subscriptions[0].credits={balance:19613.957,observedAt:'2026-11-04T11:55:00Z'};
 const {send,receive}=await open(page,data);await page.getByRole('button',{name:'Subscription',exact:true}).click();await page.locator('.eng-keys .ek[data-sub]').first().click();
 const credits=page.locator('.cr-l').filter({has:page.locator('.cr-bal')});await expect(credits.locator('.cr-bal')).toHaveText('19,614');await expect(credits).toContainText('Read 5m ago');await expect(page.locator('.cr-30')).toHaveCount(0);
 for(const [balance,expected] of [[0.2,'<1'],[0,'0']]){data.details.subscriptions[0].credits.balance=balance;expect(await receive(send('display',{data}))).toBe(true);await expect(credits.locator('.cr-bal')).toHaveText(expected);}
 expect(await receive(send('appearance',{...appearance,locale:'zh-CN'}))).toBe(true);await expect(credits).toContainText('5m前读取');
});

test('CKP-STRIP-06 a new caution flashes at most ten seconds and a new condition retriggers',async({page})=>{
 const data=visualFixture().data;data.details=null;data.projection.rows=data.projection.rows.slice(0,1);const windows=data.projection.rows[0].accounts[0].windows;for(const w of windows)w.remainingPercent=75;
 const {send,receive}=await open(page,data),lamp=page.locator('[data-caution]');await expect(lamp).not.toHaveClass(/\bflash\b/);
 windows[0].remainingPercent=35;expect(await receive(send('display',{data}))).toBe(true);await expect(lamp).not.toHaveClass(/\b(flash|lit)\b/);
 windows[0].remainingPercent=20;expect(await receive(send('display',{data}))).toBe(true);await expect(lamp).toHaveClass(/\bflash\b/);await expect(lamp).toHaveClass(/\bred\b/);
 const animation=await lamp.evaluate(e=>{const s=getComputedStyle(e);window.__g1CautionAnimation=e.getAnimations()[0];return {name:s.animationName,duration:s.animationDuration,count:s.animationIterationCount};});expect(animation.name).not.toBe('none');expect(animation.duration).toBe('1s');expect(animation.count).toBe('10');
 // The same condition keeps its blink; a second red window is a new condition and blinks again.
 windows[0].remainingPercent=18;expect(await receive(send('display',{data}))).toBe(true);expect(await lamp.evaluate(e=>e.getAnimations().includes(window.__g1CautionAnimation))).toBe(true);
 windows[1].remainingPercent=10;expect(await receive(send('display',{data}))).toBe(true);await expect(lamp).toHaveClass(/\bred\b/);expect(await lamp.evaluate(e=>e.getAnimations().includes(window.__g1CautionAnimation))).toBe(false);windows[1].remainingPercent=75;

 await page.getByRole('button',{name:'Subscription',exact:true}).click();await lamp.click();await expect(page.locator('.pg-alerts .mfd-alerts.all.ack')).toBeVisible();await expect(lamp).not.toHaveClass(/\bflash\b/);await page.keyboard.press('Escape');windows[0].remainingPercent=19;expect(await receive(send('display',{data}))).toBe(true);await expect(lamp).not.toHaveClass(/\bflash\b/);
 for(const w of windows)w.remainingPercent=75;expect(await receive(send('display',{data}))).toBe(true);await expect(lamp).not.toHaveClass(/\blit|flash\b/);windows[0].remainingPercent=19;expect(await receive(send('display',{data}))).toBe(true);await expect(lamp).toHaveClass(/\bflash\b/);expect(await receive(send('appearance',{...appearance,reduceMotion:true}))).toBe(true);expect(await lamp.evaluate(e=>getComputedStyle(e).animationName)).toBe('none');expect(await receive(send('appearance',appearance))).toBe(true);await expect(lamp).not.toHaveClass(/\bflash\b/);windows[0].remainingPercent=75;expect(await receive(send('display',{data}))).toBe(true);windows[0].remainingPercent=19;expect(await receive(send('display',{data}))).toBe(true);await expect(lamp).toHaveClass(/\bflash\b/);await page.emulateMedia({reducedMotion:'reduce'});await expect(lamp).not.toHaveClass(/\bflash\b/);await page.emulateMedia({reducedMotion:'no-preference'});await expect(lamp).not.toHaveClass(/\bflash\b/);expect(await receive(send('visibility',{visible:false,occluded:false,key:false}))).toBe(true);expect(await lamp.evaluate(e=>getComputedStyle(e).animationName)).toBe('none');expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);data.details=visualFixture().data.details;data.details.alerts=[{severity:'blue',source:data.projection.rows[0].id,subscriptionRef:data.projection.rows[0].accounts[0].subscriptionRef,windowId:windows[0].id,remainingPercent:19}];expect(await receive(send('display',{data}))).toBe(true);/* D38: the lamp follows the reading against T, not the producer's alert severity. */await expect(lamp).toHaveClass(/\bred\b/);data.details=null;windows[0].remainingPercent=75;expect(await receive(send('display',{data}))).toBe(true);expect(await receive(send('appearance',{...appearance,reduceMotion:true}))).toBe(true);windows[0].remainingPercent=19;expect(await receive(send('display',{data}))).toBe(true);await expect(lamp).not.toHaveClass(/\bflash\b/);expect(await receive(send('appearance',appearance))).toBe(true);await expect(lamp).not.toHaveClass(/\bflash\b/);
});

test('CKP-STRIP-09 last-seen records follow running sessions without claiming they ended',async({page})=>{
 const data=visualFixture().data;data.details.sessions[0].rate=58;data.details.sessions[2].rate=58;data.details.sessions.reverse();const {send,receive}=await open(page,data);const rows=page.locator('.ck-tape .t-observed');await expect(rows).toHaveCount(3);await expect(rows.nth(0).locator('.t-time')).toHaveText('Running');await expect(rows.nth(1).locator('.t-time')).toHaveText('Running');await expect(rows.nth(1).locator('.t-live')).toContainText('58');await expect(rows.nth(2).locator('.t-model')).toHaveText('GLM-5.3');await expect(rows.nth(2).locator('.t-time')).toHaveText('Last seen');await expect(rows.nth(2).locator('.t-live')).toHaveText('--');await expect(rows.nth(2)).not.toContainText(/ended|stopped/i);expect(await receive(send('appearance',{...appearance,locale:'zh-CN'}))).toBe(true);await expect(rows.nth(2).locator('.t-time')).toHaveText('最近读数');const template=data.details.sessions.find(s=>s.state==='running');data.details.sessions=Array.from({length:7},(_,i)=>({...template,sessionRef:(i+1).toString(16).padStart(16,'0')}));expect(await receive(send('display',{data}))).toBe(true);await expect(rows).toHaveCount(4);await expect(page.locator('.ck-tape .t-overflow')).toContainText('3');await expect(page.locator('.ck-tape .t-overflow')).toContainText('运行中');data.details.sessionCoverage='unavailable';expect(await receive(send('display',{data}))).toBe(true);await expect(rows).toHaveCount(0);
});

test('CKP-STRIP-10 running session cursors blink, stop when hidden, and stay static under Reduce Motion',async({page})=>{
 const data=visualFixture().data,{send,receive}=await open(page,data),cursors=page.locator('.ck-tape .t-cur');await expect(cursors).toHaveCount(2);await expect(page.locator('.ck-tape .t-observed').last().locator('.t-cur')).toHaveCount(0);
 const style=await cursors.first().evaluate(e=>{const s=getComputedStyle(e);return {width:s.width,height:s.height,duration:s.animationDuration,iterations:s.animationIterationCount,name:s.animationName};});expect(style.width).toBe('6px');expect(style.height).toBe('11px');expect(style.duration).toBe('1.06s');expect(style.iterations).toBe('infinite');expect(style.name).not.toBe('none');
 expect(await receive(send('appearance',{...appearance,reduceMotion:true}))).toBe(true);expect(await cursors.first().evaluate(e=>getComputedStyle(e).animationName)).toBe('none');
 expect(await receive(send('appearance',appearance))).toBe(true);await page.emulateMedia({reducedMotion:'reduce'});expect(await cursors.first().evaluate(e=>getComputedStyle(e).animationName)).toBe('none');await page.emulateMedia({reducedMotion:'no-preference'});expect(await receive(send('shell',{...shell,profile:'closed'}))).toBe(true);expect(await cursors.first().evaluate(e=>getComputedStyle(e).animationName)).toBe('none');expect(await receive(send('shell',shell))).toBe(true);expect(await receive(send('visibility',{visible:false,occluded:false,key:false}))).toBe(true);expect(await cursors.first().evaluate(e=>getComputedStyle(e).animationName)).toBe('none');
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);for(const s of data.details.sessions)s.state='idle';expect(await receive(send('display',{data}))).toBe(true);await expect(cursors).toHaveCount(0);
});

test('CKP-MOT-03 Reduce Motion keeps running cursors static without shifting controls',async({page})=>{
 const data=visualFixture().data,row=data.projection.rows[0],account=row.accounts[0];data.details.alerts=[{severity:'critical',source:row.id,subscriptionRef:account.subscriptionRef,windowId:account.windows[0].id,remainingPercent:20}];account.windows[0].remainingPercent=20;const {send,receive}=await open(page,data);const cursor=page.locator('.ck-tape .t-cur').first(),lamp=page.locator('[data-caution]'),shutter=page.locator('[data-shutter]'),before=await shutter.boundingBox(),cursorBefore=await cursor.boundingBox();await expect(lamp).toHaveClass(/\blit\b/);expect(await receive(send('appearance',{...appearance,reduceMotion:true}))).toBe(true);expect(await cursor.evaluate(e=>getComputedStyle(e).animationName)).toBe('none');expect(await lamp.evaluate(e=>getComputedStyle(e).animationName)).toBe('none');expect(await shutter.boundingBox()).toEqual(before);expect(await cursor.boundingBox()).toEqual(cursorBefore);expect(await receive(send('shell',{...shell,attached:false}))).toBe(true);const putBack=page.locator('[data-detach]');expect(await putBack.evaluate(e=>getComputedStyle(e).transitionDuration)).toBe('0s');await putBack.click();expect(await page.evaluate(()=>window.__g1Messages.filter(m=>m.type==='action').at(-1)?.action)).toBe('putBack');await page.emulateMedia({reducedMotion:'reduce'});expect(await receive(send('appearance',appearance))).toBe(true);expect(await cursor.evaluate(e=>getComputedStyle(e).animationName)).toBe('none');expect(await shutter.boundingBox()).toEqual(before);
});

test('CKP-MOT-06 visible text and well nesting respect the v1 budget',async({page})=>{
 const {send,receive}=await open(page);const inspect=()=>page.locator('#cockpit').evaluate(root=>{const nodes=[...root.querySelectorAll('*')];const small=nodes.filter(e=>!e.children.length&&e.textContent.trim()&&e.getClientRects().length&&!e.matches('.eng-keys .ek[data-sub] .ki')).map(e=>({text:e.textContent.trim(),size:parseFloat(getComputedStyle(e).fontSize)})).filter(x=>x.size>0&&x.size<10);const depths=nodes.filter(e=>e.getAttribute('data-mat')==='well').map(e=>{let depth=1;for(let p=e.parentElement;p&&p!==root;p=p.parentElement)if(p.getAttribute('data-mat')==='well')depth++;return depth;});return {small,depths,legends:root.querySelectorAll('legend').length};});for(const tier of ['tall','compact'])for(const locale of ['en','zh-CN']){expect(await receive(send('shell',{...shell,tier}))).toBe(true);expect(await receive(send('appearance',{...appearance,locale}))).toBe(true);for(const scope of ['all','member']){if(scope==='member')await page.locator('.eng-keys .ek[data-sub]').first().click();else await page.locator('.ek-all').click();for(let i=0;i<4;i++){await page.locator('.mfd-pk .pk').nth(i).click();const audit=await inspect();expect(audit.small).toEqual([]);expect(Math.max(0,...audit.depths)).toBeLessThanOrEqual(2);expect(audit.legends).toBe(0);}}}
});

test('CKP-MOT-07 active key text and quota bars meet contrast thresholds in both themes',async({page})=>{
 const data=visualFixture().data;data.projection.rows=data.projection.rows.slice(0,3);for(const [i,row] of data.projection.rows.entries())row.accounts[0].windows[0].remainingPercent=[75,35,20][i];const {send,receive}=await open(page,data);await page.locator('.eng-keys .ek[data-sub]').first().click();
 const audit=()=>page.evaluate(()=>{const rgb=s=>[...s.matchAll(/rgb\((\d+),\s*(\d+),\s*(\d+)\)/g)].map(m=>m.slice(1).map(Number)),lum=c=>c.map(x=>x/255).map(x=>x<=.04045?x/12.92:((x+.055)/1.055)**2.4).reduce((s,x,i)=>s+x*[.2126,.7152,.0722][i],0),ratio=(a,b)=>{const x=lum(a),y=lum(b);return (Math.max(x,y)+.05)/(Math.min(x,y)+.05)},color=e=>rgb(getComputedStyle(e).color)[0],stops=e=>rgb(getComputedStyle(e).backgroundImage),lcd=stops(document.querySelector('.eng-lcd'));const keys=[...document.querySelectorAll('.mfd-pk .pk'),document.querySelector('.ek-all'),document.querySelector('.eng-keys .ek[data-sub].on')].map(k=>({fg:color(k.querySelector('.ek-name')??k.querySelector('span')),bg:stops(k)}));const bars=[...document.querySelectorAll('.eng-cols .ec[data-col] .qcell[data-row="first"] .qbar i.on:first-child')].map(e=>rgb(getComputedStyle(e).backgroundColor)[0]);return {keys:keys.map(k=>k.bg.length?Math.min(...k.bg.map(bg=>ratio(k.fg,bg))):0),bars:bars.map(c=>Math.min(...lcd.map(bg=>ratio(c,bg))))};});
 for(const theme of ['night','day']){if(theme==='day')expect(await receive(send('appearance',{...appearance,theme}))).toBe(true);const result=await audit();expect(result.keys).toHaveLength(6);for(const n of result.keys)expect(n).toBeGreaterThanOrEqual(4.5);expect(result.bars).toHaveLength(3);for(const n of result.bars)expect(n).toBeGreaterThanOrEqual(3);}
});

test('Record strip (requirement ID pending) session status text fits without ellipsis in both locales and tiers',async({page})=>{
 const {send,receive}=await open(page);
 for(const tier of ['tall','compact']){
  expect(await receive(send('shell',{...shell,tier}))).toBe(true);
  for(const locale of ['en','zh-CN']){
   expect(await receive(send('appearance',{...appearance,locale}))).toBe(true);
   const labels=page.locator('.ck-tape .t-observed .t-time');await expect(labels).toHaveCount(3);
   await expect(labels.nth(2)).toHaveText(locale==='en'?'Last seen':'最近读数');
   for(const label of await labels.all()){const size=await label.evaluate(e=>({scroll:e.scrollWidth,client:e.clientWidth,text:e.textContent}));expect(size.text).not.toMatch(/[\u2026]/);expect(size.scroll).toBeLessThanOrEqual(size.client);}
  }
 }
});

// macrev2-478-1 and the D38 press clause: the lamp is global, so its list is too, whatever subscription is selected;
// prototype mfd.js:39-58,75,121,170 returns with "‹ Back to <page>", Esc, a page key or a second lamp press.
async function alertScope(page,slots){
 const data=visualFixture().data;data.details=null;data.projection.rows=data.projection.rows.slice(0,2);data.subscriptions=data.subscriptions.slice(0,2);
 for(let i=2;i<slots;i++){const row=structuredClone(data.projection.rows[0]),ref=(i+1).toString(16).padStart(16,'0');row.id='tool'+i;row.name={en:'Synthetic '+i,zh:'合成 '+i};row.accounts[0].subscriptionRef=ref;row.accounts[0].accountLocator=ref;data.projection.rows.push(row);data.subscriptions.push({subscriptionRef:ref,accounts:[{tool:row.id,account:structuredClone(row.accounts[0])}]});}
 for(const r of data.projection.rows)for(const w of r.accounts[0].windows){w.remainingPercent=75;w.resetsAt='2026-11-04T15:30:00Z';}
 data.projection.rows[slots-1===1?0:slots-1].accounts[0].windows[0].remainingPercent=20;
 const opened=await open(page,data);return {...opened,lamp:page.locator('[data-caution]')};
}
test('CKP-STRIP-06 ALERT under a healthy selected subscription lists the other subscription and returns',async({page})=>{
 const {lamp}=await alertScope(page,2);await expect(lamp).toHaveClass(/\bred\b/);
 await page.locator('.eng-keys .ek[data-sub]').nth(1).click();await page.getByRole('button',{name:'Subscription',exact:true}).click();
 await lamp.click();
 const list=page.locator('.pg-alerts .mfd-alerts.all');await expect(list).toBeVisible();await expect(list).toContainText('Codex');
 await expect(lamp).toHaveClass(/\bmfd-src\b/);await expect(page.locator('.mfd-back')).toHaveText('‹ Back to Subscription');
 // Back returns to the page it came from, with its scope intact.
 await page.locator('.mfd-back').click();await expect(page.locator('.pg-sub')).toBeVisible();await expect(lamp).not.toHaveClass(/\bmfd-src\b/);
 // Esc returns; a second lamp press returns; a page key leaves the view for that page.
 await lamp.click();await expect(list).toBeVisible();await page.keyboard.press('Escape');await expect(page.locator('.pg-sub')).toBeVisible();
 await lamp.click();await expect(list).toBeVisible();await lamp.click();await expect(page.locator('.pg-sub')).toBeVisible();
 await lamp.click();await expect(list).toBeVisible();await page.getByRole('button',{name:'Effort',exact:true}).click();await expect(page.locator('.pg-tune')).toBeVisible();
});
test('CKP-STRIP-06 ALERT reveals a critical subscription on another engine page',async({page})=>{
 const {lamp}=await alertScope(page,7);await expect(lamp).toHaveClass(/\bred\b/);await expect(page.locator('.eng-keys')).not.toContainText('Synthetic 6');
 await page.locator('.eng-keys .ek[data-sub]').nth(1).click();await lamp.click();
 await expect(page.locator('.pg-alerts .mfd-alerts.all')).toContainText('Synthetic 6');
});
test('CKP-STRIP-06 ALERT under All keeps the overview control and opens the same full list',async({page})=>{
 const {lamp}=await alertScope(page,2);await expect(page.locator('.pg-overview .mfd-alerts')).toContainText('Codex');
 await lamp.click();await expect(page.locator('.pg-alerts .mfd-alerts.all')).toContainText('Codex');await expect(page.locator('.mfd-back')).toHaveText('‹ Back to Overview');
});

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

test('CKP-ENG-14 shared threshold includes the exact 41, 40, 26, 25 and zero boundaries',async({page})=>{
 const data=visualFixture().data,extra=structuredClone(data.projection.rows[0]);extra.id='synthetic-fifth';extra.accounts[0].subscriptionRef=null;extra.accounts[0].accountLocator=null;data.projection.rows.push(extra);
 for(const [i,row] of data.projection.rows.entries())for(const window of row.accounts[0].windows)window.remainingPercent=[41,40,26,25,0][i];
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
 data.projection.rows[0].accounts[0].windows[0].remainingPercent=35;expect(await receive(send('display',{data}))).toBe(true);await expect(lamp).toHaveClass(/\bamber\b/);await expect.poll(()=>lamp.evaluate(e=>getComputedStyle(e,'::after').backgroundImage)).toContain('lamp-amber-body');await expect.poll(()=>lamp.evaluate(e=>getComputedStyle(e,'::before').backgroundImage)).toContain('lamp-amber-glow');
 data.projection.rows[0].accounts[0].windows[0].remainingPercent=20;expect(await receive(send('display',{data}))).toBe(true);await expect(lamp).toHaveClass(/\bred\b/);
 await expect.poll(()=>lamp.evaluate(e=>getComputedStyle(e,'::after').backgroundImage)).toContain('lamp-red-body');await expect.poll(()=>lamp.evaluate(e=>getComputedStyle(e,'::before').backgroundImage)).toContain('lamp-red-glow');
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

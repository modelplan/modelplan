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
 const data=visualFixture().data;data.details.sessions[0].projectLabel='<img src=x onerror="window.g1Injected=true">';await open(page,data);
 const row=page.locator('.ck-tape .t-observed').first();await expect(row.locator('.t-proj')).toHaveText(data.details.sessions[0].projectLabel);
 await expect(row.locator('img')).toHaveCount(0);expect(await page.evaluate(()=>window.g1Injected)).toBeUndefined();
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


test('CKP-ENG-05 shortcut digits are visible and described for hover, focus, and Option help',async({page})=>{
 const {send,receive}=await open(page);const all=page.locator('.ek-all'),keys=page.locator('.eng-keys .ek[data-sub]');
 for(const [key,n] of [[all,0],...[...(await keys.all())].map((e,i)=>[e,i+1])]){
  await expect(key.locator('.ki')).toHaveText(String(n));await expect(key).toHaveAttribute('title',new RegExp(`\\b${n}\\b`));await expect(key).toHaveAttribute('aria-description',new RegExp(`\\b${n}\\b`));
  await key.focus();await expect(key).toBeFocused();
 }
 await page.keyboard.press('1');await expect(keys.first()).toHaveAttribute('aria-pressed','true');await page.keyboard.press('0');await expect(all).toHaveAttribute('aria-pressed','true');
 expect(await receive(send('visibility',{visible:true,occluded:false,key:false}))).toBe(true);const before=await page.evaluate(()=>window.__g1Messages.length);await page.keyboard.press('1');expect(await page.evaluate(()=>window.__g1Messages.length)).toBe(before);await expect(all).toHaveAttribute('aria-pressed','true');expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 await page.keyboard.down('Alt');await expect(page.locator('#help-map')).toContainText('0');await expect(page.locator('#help-map')).toContainText('1–6');await page.keyboard.up('Alt');
 expect(await receive(send('appearance',{...appearance,locale:'zh-CN'}))).toBe(true);await expect(all).toHaveAttribute('aria-description',/0/);await expect(keys.first()).toHaveAttribute('aria-description',/1/);
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

test('CKP-MFD-12 scoped subscription shows reported credits and reading age without a fabricated history',async({page})=>{
 const data=visualFixture().data;data.projection.rows=data.projection.rows.slice(0,1);data.details.subscriptions[0].credits={balance:19613.957,observedAt:'2026-11-04T11:55:00Z'};
 const {send,receive}=await open(page,data);await page.getByRole('button',{name:'Subscription',exact:true}).click();await page.locator('.eng-keys .ek[data-sub]').first().click();
 const credits=page.locator('.cr-l').filter({has:page.locator('.cr-bal')});await expect(credits.locator('.cr-bal')).toHaveText('19,614');await expect(credits).toContainText('Read 5m ago');await expect(page.locator('.cr-30')).toHaveCount(0);
 for(const [balance,expected] of [[0.2,'<1'],[0,'0']]){data.details.subscriptions[0].credits.balance=balance;expect(await receive(send('display',{data}))).toBe(true);await expect(credits.locator('.cr-bal')).toHaveText(expected);}
 expect(await receive(send('appearance',{...appearance,locale:'zh-CN'}))).toBe(true);await expect(credits).toContainText('5m前读取');
});

test('CKP-STRIP-05 alert lamp selects the clear, amber and red art through bridge updates',async({page})=>{
 const data=visualFixture().data;data.projection.rows=data.projection.rows.slice(0,1);data.details=null;for(const w of data.projection.rows[0].accounts[0].windows)w.remainingPercent=75;
 const {send,receive}=await open(page,data),lamp=page.locator('[data-caution]');await expect(lamp).not.toHaveClass(/\blit\b/);await expect.poll(()=>lamp.evaluate(e=>getComputedStyle(e,'::after').backgroundImage)).toContain('lamp-off-body');
 data.projection.rows[0].accounts[0].windows[0].remainingPercent=35;expect(await receive(send('display',{data}))).toBe(true);await expect(lamp).toHaveClass(/\bamber\b/);await expect.poll(()=>lamp.evaluate(e=>getComputedStyle(e,'::after').backgroundImage)).toContain('lamp-amber-body');
 data.projection.rows[0].accounts[0].windows[0].remainingPercent=20;expect(await receive(send('display',{data}))).toBe(true);await expect(lamp).toHaveClass(/\bred\b/);
 await expect.poll(()=>lamp.evaluate(e=>getComputedStyle(e,'::after').backgroundImage)).toContain('lamp-red-body');
});

test('CKP-ENG-01 five and six subscription columns show names in user order',async({page})=>{
 const data=visualFixture().data;for(let i=data.projection.rows.length;i<6;i++){const row=structuredClone(data.projection.rows[0]),ref=(i+1).toString(16).padStart(16,'0');row.id='synthetic-'+i;row.name={en:'Synthetic '+i,zh:'模拟 '+i};row.accounts[0].subscriptionRef=ref;row.accounts[0].accountLocator=ref;data.projection.rows.push(row);data.subscriptions.push({subscriptionRef:ref,accounts:[{tool:row.id,account:structuredClone(row.accounts[0])}]});}
 for(const row of data.projection.rows)row.vendorKey='openai';const sixth=data.projection.rows.pop();const {send,receive}=await open(page,data);
 for(const count of [5,6]){if(count===6){data.projection.rows.push(sixth);expect(await receive(send('display',{data}))).toBe(true);}const keys=page.locator('.eng-keys .ek[data-sub]');await expect(keys).toHaveCount(count);await expect(keys.locator('img.lamp')).toHaveCount(count);await expect(keys.locator('.ek-name')).toHaveText(data.projection.rows.map(r=>r.name.en));for(const name of await keys.locator('.ek-name').all())await expect(name).toBeVisible();}
 const seventh=structuredClone(data.projection.rows[0]);seventh.id='synthetic-seventh';seventh.name={en:'Seventh',zh:'第七'};seventh.accounts[0].subscriptionRef='0000000000000007';seventh.accounts[0].accountLocator='0000000000000007';data.projection.rows.push(seventh);data.subscriptions.push({subscriptionRef:seventh.accounts[0].subscriptionRef,accounts:[{tool:seventh.id,account:structuredClone(seventh.accounts[0])}]});expect(await receive(send('display',{data}))).toBe(true);await expect(page.locator('.eng-keys .ek[data-sub]')).toHaveCount(6);await page.locator('[data-bpage="1"]').click();await expect(page.locator('.eng-keys .ek[data-sub] .ek-name')).toHaveText(['Seventh']);
});

test('CKP-MFD-06 Overview shows delivered today total and puts threshold notices first',async({page})=>{
 const data=visualFixture().data;data.projection.rows=data.projection.rows.slice(0,1);data.details.subscriptions=data.details.subscriptions.slice(0,1);const row=data.projection.rows[0],account=row.accounts[0],detail=data.details.subscriptions[0];detail.today[0].observedOutputTokens=12000;
 data.details.alerts=[{severity:'warning',source:row.id,subscriptionRef:account.subscriptionRef,windowId:account.windows[1].id,remainingPercent:35},{severity:'critical',source:row.id,subscriptionRef:account.subscriptionRef,windowId:account.windows[0].id,remainingPercent:20}];data.details.resetEvents=[{version:1,id:'synthetic-reset',provider:'openai',rowId:row.id,status:'confirmed',publishedAt:'2026-11-04T11:00:00Z',expiresAt:'2026-11-05T12:00:00Z',source:{kind:'publication',publicationId:'0123456789abcdef01234567'}}];const {send,receive}=await open(page,data);
 await expect(page.locator('.pg-overview .mfd-alerts')).toBeVisible();await expect(page.locator('.pg-overview .mfd-alerts li').first()).toHaveClass(/\bal-red\b/);await expect(page.locator('.pg-overview .mfd-alerts li').nth(1)).toHaveClass(/\bal-amber\b/);await expect(page.locator('.pg-overview .mfd-alerts')).toContainText('Reset confirmed');await expect(page.locator('.pg-overview .ov-total')).toHaveText('12k');
 const positions=await page.locator('.pg-overview').evaluate(e=>[...e.children].map(n=>n.className));expect(positions.indexOf('mfd-alerts')).toBeLessThan(positions.indexOf('ov-top'));
 const second=visualFixture().data;data.projection.rows.push(second.projection.rows[1]);data.details.subscriptions.push({...second.details.subscriptions[1],today:[]});expect(await receive(send('display',{data}))).toBe(true);await expect(page.locator('.pg-overview .ov-total')).toHaveCount(0);await page.locator('.eng-keys .ek[data-sub]').first().click();await expect(page.locator('.pg-overview .ov-total')).toHaveText('12k');
 detail.today=[];expect(await receive(send('display',{data}))).toBe(true);await expect(page.locator('.pg-overview .ov-total')).toHaveCount(0);
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
 await page.locator('[data-bpage="1"]').click();await expect(page.locator('.eng-keys .ek[data-sub]')).toHaveCount(1);await expect(page.locator('.eng-keys .ek-bay')).toHaveCount(5);await expect(page.locator('.eng-cols .ec-bay')).toHaveCount(5);await expect(page.locator('.eng-cols .ec-bay .qvalue')).toHaveCount(0);
});

test('CKP-STRIP-09 last-seen records follow running sessions without claiming they ended',async({page})=>{
 const data=visualFixture().data;data.details.sessions[0].rate=58;data.details.sessions[2].rate=58;data.details.sessions.reverse();const {send,receive}=await open(page,data);const rows=page.locator('.ck-tape .t-observed');await expect(rows).toHaveCount(3);await expect(rows.nth(0).locator('.t-time')).toHaveText('Running');await expect(rows.nth(1).locator('.t-time')).toHaveText('Running');await expect(rows.nth(1).locator('.t-live')).toContainText('58');await expect(rows.nth(2).locator('.t-model')).toHaveText('GLM-5.3');await expect(rows.nth(2).locator('.t-time')).toHaveText('Last seen');await expect(rows.nth(2).locator('.t-live')).toHaveText('--');await expect(rows.nth(2)).not.toContainText(/ended|stopped/i);expect(await receive(send('appearance',{...appearance,locale:'zh-CN'}))).toBe(true);await expect(rows.nth(2).locator('.t-time')).toHaveText('最近观察');const template=data.details.sessions.find(s=>s.state==='running');data.details.sessions=Array.from({length:7},(_,i)=>({...template,sessionRef:(i+1).toString(16).padStart(16,'0')}));expect(await receive(send('display',{data}))).toBe(true);await expect(rows).toHaveCount(4);await expect(page.locator('.ck-tape .t-overflow')).toContainText('3');await expect(page.locator('.ck-tape .t-overflow')).toContainText('运行中');data.details.sessionCoverage='unavailable';expect(await receive(send('display',{data}))).toBe(true);await expect(rows).toHaveCount(0);
});

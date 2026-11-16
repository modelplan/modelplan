// SPDX-License-Identifier: MIT
// Owner-review candidates at browser zoom levels 85/100/125. Captures assert real layout; pixel comparison remains an
// expected failure until the owner confirms each new golden. Run locally with --update-snapshots=none while pending.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {createHash} from 'node:crypto';
import {mkdir,writeFile} from 'node:fs/promises';
import {join} from 'node:path';
import {readFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import {appearance,commands,pageId,shell,excludePortholeFlicker} from '../fixture.mjs';
import {renderVisualDeck,visualFixture} from '../visual-fixture.mjs';

test.beforeEach(async({page})=>excludePortholeFlicker(page));
const OUT=fileURLToPath(new URL('../../../cockpit/.tmp/test-results/visual-capture/',import.meta.url));
const PENDING=JSON.parse(readFileSync(new URL('../cockpit-zoom-baselines.pending.json',import.meta.url),'utf8'));

async function renderAtZoom(page,percent){
  await page.setViewportSize({width:636,height:939});await page.emulateMedia({reducedMotion:'reduce'});
  await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
  const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw),fixture=visualFixture();
  expect(await receive(send('load',{appearance,shell}))).toBe(true);
  expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
  expect(await receive(send('display',{data:fixture.data}))).toBe(true);
  await renderVisualDeck(page,fixture,'en');
  await page.evaluate(async zoom=>{document.documentElement.style.zoom=`${zoom}%`;await document.fonts.ready;},percent);
  return page.evaluate(()=>{
    const cockpit=document.querySelector('.ck'),port=document.querySelector('.ck-portrow'),deck=document.querySelector('.ck-deck');
    const rect=element=>{const r=element.getBoundingClientRect();return {x:r.x,y:r.y,width:r.width,height:r.height};};
    return {zoom:document.documentElement.style.zoom,cockpit:cockpit?rect(cockpit):null,port:port?rect(port):null,deck:deck?rect(deck):null,
      visibleText:document.querySelector('#cockpit')?.innerText?.length??0};
  });
}

for(const percent of [85,100,125]){
  test(`cockpit shell zoom capture ${percent}% is laid out and exported for review`,async({page},info)=>{
    const baseline=PENDING.candidates.find(candidate=>candidate.zoomPercent===percent);
    expect(baseline).toBeTruthy();expect(baseline.status).toBe('pending-owner-confirmation');
    const geometry=await renderAtZoom(page,percent);
    expect(geometry.zoom).toBe(`${percent}%`);
    expect(geometry.cockpit?.width).toBeGreaterThan(100);
    expect(geometry.cockpit?.height).toBeGreaterThan(100);
    expect(geometry.port?.width).toBeGreaterThan(0);
    expect(geometry.deck?.height).toBeGreaterThan(0);
    expect(geometry.visibleText).toBeGreaterThan(0);

    const image=await page.screenshot({omitBackground:true,animations:'disabled'});
    const hash=createHash('sha256').update(image).digest('hex');
    await mkdir(OUT,{recursive:true});
    const name=`cockpit-zoom-${percent}-pending-owner-confirmation.png`;
    const metadata={status:'pending-owner-confirmation',ownerConfirmed:false,zoomPercent:percent,sha256:hash,geometry,snapshot:baseline.snapshot};
    await writeFile(join(OUT,name),image);
    await writeFile(join(OUT,name.replace(/\.png$/,'.json')),JSON.stringify(metadata,null,2)+'\n');
    await info.attach(name,{body:image,contentType:'image/png'});
    await info.attach(name.replace(/\.png$/,'.json'),{body:Buffer.from(JSON.stringify(metadata,null,2)),contentType:'application/json'});
  });

  test(`cockpit shell zoom pixel baseline ${percent}% awaits owner confirmation`,async({page})=>{
    const baseline=PENDING.candidates.find(candidate=>candidate.zoomPercent===percent);
    expect(baseline).toBeTruthy();expect(baseline.status).toBe('pending-owner-confirmation');
    test.fail(true,'The owner has not confirmed this screenshot baseline.');
    await renderAtZoom(page,percent);
    await expect(page).toHaveScreenshot(`cockpit-zoom-${percent}-pending-owner-confirmation.png`,{animations:'disabled',maxDiffPixels:0});
  });
}

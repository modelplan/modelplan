// SPDX-License-Identifier: MIT
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {pageId} from '../fixture.mjs';

test('cockpit permits embedded image art but still blocks network connections',async({page})=>{
 await page.goto('/?pageId='+pageId);
 const result=await page.evaluate(async()=>{
  const image=new Image();image.src='data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///ywAAAAAAQABAAACAUwAOw==';
  const loaded=await new Promise(resolve=>{image.onload=()=>resolve(true);image.onerror=()=>resolve(false);});
  let connected=true;try{await fetch('/index.html');}catch{connected=false;}
  return {loaded,connected,policy:document.querySelector('meta[http-equiv="Content-Security-Policy"]').content};
 });
 expect(result.loaded).toBe(true);expect(result.connected).toBe(false);
 expect(result.policy).toContain("script-src 'self'");expect(result.policy).toContain("connect-src 'none'");
});

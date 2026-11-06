// THROWAWAY SPIKE: local WebKit render + relative frame probe (Linux; not a Mac measurement).
import {webkit} from '@playwright/test';import {readFileSync} from 'node:fs';
const [,,url,messages,out]=process.argv;const raws=JSON.parse(readFileSync(messages,'utf8'));
const b=await webkit.launch();const p=await b.newPage({viewport:{width:1040,height:900},deviceScaleFactor:2});
p.on('pageerror',e=>console.log('pageerror:',e.message));
await p.goto(url);await p.waitForFunction(()=>!!window.modelPlanCockpit);
for(const raw of raws)console.log('receive',await p.evaluate(r=>window.modelPlanCockpit.receive(r),raw));
await p.waitForTimeout(2500);
console.log(JSON.stringify(await p.evaluate(()=>({stats:window.__porthole?.stats?.()??null,field:document.querySelector('.ck-field')?.getBoundingClientRect().toJSON(),anims:document.getAnimations().length,an:(()=>{const e=document.querySelector('.ph-flicker');if(!e)return null;const c=getComputedStyle(e);return [c.animationName,c.animationDuration,c.animationPlayState,matchMedia('(prefers-reduced-motion: reduce)').matches]})()}))));
await p.locator('.ck-port').screenshot({path:out});
await p.screenshot({path:out.replace('.png','-full.png')});await b.close();

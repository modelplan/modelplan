// SPDX-License-Identifier: MIT
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
const callbacks=[];
class Element { closest(s){return s==='[data-group]' ? this:null} getBoundingClientRect(){return {width:10,height:10}} }
const animation={effect:{target:new Element()},currentTime:0,playState:'running'};
const document={hidden:false,getAnimations:()=>[animation]};
const ctx={Element,document,getComputedStyle:()=>({visibility:'visible',display:'block'}),requestAnimationFrame:f=>(callbacks.push(f),callbacks.length),cancelAnimationFrame:()=>{}};
vm.createContext(ctx);vm.runInContext(readFileSync(new URL('./animation-observer.js',import.meta.url),'utf8'),ctx);
const o=ctx.installVerificationAnimationObserver({indicator:'[data-group]'});
const tick=()=>callbacks.shift()();
tick();animation.currentTime=10;tick();assert.equal(o.snapshot().groups.indicator.advancingFrames,1);
tick();assert.equal(o.snapshot().groups.indicator.advancingFrames,1); // RAF alone is insufficient.
animation.playState='paused';animation.currentTime=20;tick();assert.equal(o.snapshot().groups.indicator.advancingFrames,1);
animation.playState='running';document.hidden=true;animation.currentTime=30;tick();assert.equal(o.snapshot().groups.indicator.advancingFrames,1);
document.hidden=false;animation.currentTime=40;tick();assert.equal(o.snapshot().groups.indicator.advancingFrames,2);
o.stop();tick();assert.equal(o.snapshot().groups.indicator.advancingFrames,2);
console.log('Animation progress/paused/hidden/teardown controls pass');
const received=[];ctx.webkit={messageHandlers:{testFrames:{postMessage:x=>received.push(x)}}};
const stopTicks=ctx.installVerificationRAFTicks('testFrames');tick();tick();
assert.deepEqual(received.map(x=>x.frames),[1,2]);stopTicks();tick();
assert.equal(received.length,2);
console.log('Test-only message frame counter advances and stops');

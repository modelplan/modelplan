// SPDX-License-Identifier: MIT
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
let callback,disconnected=false;
class Host {constructor(){this.children=[]}replaceChildren(...children){for(const x of this.children)x.parentNode=null;this.children=children;for(const x of children)x.parentNode=this}}
let host=new Host();const layer={parentNode:null};
class MutationObserver {constructor(f){callback=f}observe(){}disconnect(){disconnected=true}}
const ctx={MutationObserver,document:{body:{}}};vm.createContext(ctx);vm.runInContext(readFileSync(new URL('./stable-layer.js',import.meta.url),'utf8'),ctx);
const stop=ctx.keepVerificationLayer(()=>host,layer);
assert.equal(layer.parentNode,host);
host.replaceChildren();callback();assert.equal(layer.parentNode,host); // observed subject redraw regression
host=new Host();callback();assert.equal(layer.parentNode,host); // host node itself replaced
callback();assert.equal(host.children.length,1); // no recursive duplicate
stop();host.replaceChildren();callback();assert.equal(layer.parentNode,null);assert.equal(disconnected,true);
console.log('Measurement layer redraw/replacement/teardown checks pass');

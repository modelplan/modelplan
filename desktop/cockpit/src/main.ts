// SPDX-License-Identifier: MIT
import { CockpitBridge,type BridgeSource } from './bridge.js';
import { mountCockpit } from './view.js';
import { newsClock } from './news-clock.js';
import { mountPortholeStill } from './porthole-still.js';
import portholeStills from './porthole-stills-data.js';
declare global {interface Window {modelPlanCockpit?:{receive(raw:string):boolean;clear(raw:string):boolean;state(pageId?:string):string;reject():string};webkit?:{messageHandlers?:{cockpit?:{postMessage(message:string):void}}}}}
const url=new URL(location.href),pageId=url.searchParams.get('pageId');
const origin=url.protocol==='modelplan-cockpit:'&&url.hostname==='bundle'?'modelplan-cockpit://bundle':url.protocol==='http:'&&url.hostname==='127.0.0.1'?url.origin:null;
const root=document.getElementById('cockpit');
if(pageId&&origin&&root&&window.top===window) {
  let bridge:CockpitBridge;
  const view=mountCockpit(root,(action,tool)=>bridge.action(action,tool),ids=>bridge.acknowledgeCautions(ids),ids=>bridge.pinModels(ids),{state:state=>bridge.pluginsEdit(state),running:ids=>bridge.pluginsRunning(ids),close:id=>bridge.pluginClose(id)});
  const field=root.querySelector<HTMLElement>('.ck-field');const still=field?mountPortholeStill(field,root,portholeStills,focus=>bridge.action('openField',focus)):null;
  const post=(message:string)=>window.webkit?.messageHandlers?.cockpit?.postMessage(message);
  bridge=new CockpitBridge(pageId,origin,post,view,()=>crypto.randomUUID());
  // D466: first looks go to the host's shared news clock (#1289), when the host keeps one.
  newsClock.onLook(events=>{bridge.newsLook(events);});
  const source:BridgeSource=Object.freeze({origin,isMainFrame:true});
  const listeners=new AbortController();
  const dispose=()=>{listeners.abort();newsClock.onLook(null);still?.dispose();bridge.unload();delete window.modelPlanCockpit;};
  window.modelPlanCockpit=Object.freeze({
    receive(raw:string){try{return bridge.receive(raw,source);}finally{if(bridge.disposed)dispose();}},
    clear(raw:string){try{return bridge.clear(raw,source);}finally{if(bridge.disposed)dispose();}},
    // Recovery contract: the host's correlated health probe names its page; another page (a replaced one) never
    // answers for it. Without an argument the state is reported as before.
    state(expected?:string){return expected!==undefined&&(typeof expected!=='string'||expected.toLowerCase()!==pageId.toLowerCase())?'mismatch':bridge.state;},
    reject(){return bridge.lastReject;},
  });
  document.addEventListener('visibilitychange',()=>bridge.documentHidden(document.hidden),{signal:listeners.signal});
  window.addEventListener('pagehide',dispose,{signal:listeners.signal});
  // No URL or file navigation can be requested by page controls.
  document.addEventListener('click',event=>{if((event.target as Element).closest('a'))event.preventDefault();},{signal:listeners.signal});
  document.addEventListener('submit',event=>event.preventDefault(),{signal:listeners.signal});
  bridge.documentHidden(document.hidden);bridge.ready();
}

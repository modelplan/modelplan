// SPDX-License-Identifier: MIT
import { CockpitBridge,type BridgeSource } from './bridge.js';
import { mountCockpit } from './view.js';
declare global {interface Window {modelPlanCockpit?:{receive(raw:string):boolean;clear(raw:string):boolean;state():string};webkit?:{messageHandlers?:{cockpit?:{postMessage(message:string):void}}}}}
const url=new URL(location.href),pageId=url.searchParams.get('pageId');
const origin=url.protocol==='modelplan-cockpit:'&&url.hostname==='bundle'?'modelplan-cockpit://bundle':url.protocol==='http:'&&url.hostname==='127.0.0.1'?url.origin:null;
const root=document.getElementById('cockpit');
if(pageId&&origin&&root&&window.top===window) {
  let bridge:CockpitBridge;
  const view=mountCockpit(root,(action,tool)=>bridge.action(action,tool));
  const post=(message:string)=>window.webkit?.messageHandlers?.cockpit?.postMessage(message);
  bridge=new CockpitBridge(pageId,origin,post,view,()=>crypto.randomUUID());
  const source:BridgeSource=Object.freeze({origin,isMainFrame:true});
  const listeners=new AbortController();
  const dispose=()=>{listeners.abort();bridge.unload();delete window.modelPlanCockpit;};
  window.modelPlanCockpit=Object.freeze({
    receive(raw:string){try{return bridge.receive(raw,source);}finally{if(bridge.disposed)dispose();}},
    clear(raw:string){try{return bridge.clear(raw,source);}finally{if(bridge.disposed)dispose();}},
    state(){return bridge.state;},
  });
  document.addEventListener('visibilitychange',()=>bridge.documentHidden(document.hidden),{signal:listeners.signal});
  window.addEventListener('pagehide',dispose,{signal:listeners.signal});
  // No URL or file navigation can be requested by page controls.
  document.addEventListener('click',event=>{if((event.target as Element).closest('a'))event.preventDefault();},{signal:listeners.signal});
  document.addEventListener('submit',event=>event.preventDefault(),{signal:listeners.signal});
  bridge.documentHidden(document.hidden);bridge.ready();
}

// SPDX-License-Identifier: MIT
// Keep a caller-supplied measurement-only layer attached through subject redraws.
// Contains no artwork, geometry, styling or subject-specific selectors.
globalThis.keepVerificationLayer = function(resolveHost,layer,root=document.body) {
  let stopped=false;
  function restore(){
    if(stopped)return;
    const host=resolveHost();
    if(host && layer.parentNode!==host)host.replaceChildren(layer);
  }
  const observer=new MutationObserver(restore);
  observer.observe(root,{subtree:true,childList:true});restore();
  return ()=>{stopped=true;observer.disconnect()};
};

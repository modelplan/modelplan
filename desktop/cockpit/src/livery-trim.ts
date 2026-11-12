// SPDX-License-Identifier: MIT
// D131 two-tone marks: the colour-only marks (engine tab underline, fader vendor strip, record-strip chip) of makers
// whose brand is black-and-white, or too close to a reserved UI colour, are drawn the way the website's rockets draw
// them: the brand colour with a trim of the maker's ink (CSS in prototype-theme.css reads data-tt, --vi, --vb).
// The marks are filled from many render paths, so one observer tags them after any change; tagging is idempotent.
import {trimForColour} from './livery.js';
const MARKS='.ck-eng .ek .bl,.dk-fad .st-vend b,.chip';
export function tagTwoTone(root:ParentNode):void {
 for(const el of root.querySelectorAll<HTMLElement>(MARKS)){
  const v=el.style.getPropertyValue('--v').trim(),trim=/^#[0-9a-f]{6}$/i.test(v)?trimForColour(v):null;
  if(!trim){if(el.hasAttribute('data-tt'))el.removeAttribute('data-tt');continue;}
  if(el.getAttribute('data-tt')!==trim.kind)el.setAttribute('data-tt',trim.kind);
  if(el.style.getPropertyValue('--vi')!==trim.ink)el.style.setProperty('--vi',trim.ink);
  if(el.style.getPropertyValue('--vb')!==trim.base)el.style.setProperty('--vb',trim.base);
 }
}
export function watchTwoTone(root:HTMLElement):void {
 let queued=false;
 new MutationObserver(()=>{if(queued)return;queued=true;queueMicrotask(()=>{queued=false;tagTwoTone(root);});})
  .observe(root,{subtree:true,childList:true,attributes:true,attributeFilter:['style']});
 tagTwoTone(root);
}

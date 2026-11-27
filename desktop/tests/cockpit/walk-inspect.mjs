// SPDX-License-Identifier: MIT
// The same rendered-state inspector is used by the walk and its geometry regressions.
export function inspectPage(checkPointer){
  const p=document.querySelector('.mfd-page'),overlay=[...document.querySelectorAll('.mfd-screen .pl-screen')],selected=[...document.querySelectorAll('.mfd-pk .pk[aria-pressed="true"]')],header=[...document.querySelectorAll('[data-range-key][aria-checked="true"]')];
  const range=header[0]?.getAttribute('data-range-key'),opt=document.querySelector('.mfd-ok [data-opt="range"] b.on')?.getAttribute('data-choice');
  const violations=[];
  if(!p||overlay.length>1)violations.push('one lower-panel view');
  if(header.length!==1)violations.push('one header range');
  if(!overlay.length&&!p?.classList.contains('pg-compare')&&!p?.classList.contains('pg-alerts')){
   if(selected.length!==1||!p?.classList.contains('pg-'+selected[0]?.getAttribute('data-mfd')?.split(':')[1]))violations.push('page key matches view');
  }
  if(overlay.length&&document.querySelector(`.eng-keys .pl-key[data-plugin="${overlay[0].dataset.plugin}"]`)?.getAttribute('aria-expanded')!=='true')violations.push('plugin key matches view');
  if(p?.querySelector('.cal-wk,.pl-screen'))violations.push('plugin content in page');
  // D401 invariant: a lit key always matches the visible view, and a plugin never leaves a subscription lit.
  const lit=[...document.querySelectorAll('.eng-keys .ek,.ek[data-all]')].filter(k=>k.getAttribute('aria-pressed')==='true'||k.classList.contains('on'));
  for(const k of document.querySelectorAll('.eng-keys .ek,.ek[data-all]'))if(k.classList.contains('on')!==(k.getAttribute('aria-pressed')==='true'))violations.push('key look matches its state');
  const litPlugins=lit.filter(k=>k.classList.contains('pl-key')).map(k=>k.dataset.plugin);
  if(overlay.length){if(lit.length!==1||litPlugins.join()!==overlay[0].dataset.plugin)violations.push('only the open plugin key is lit');}
  else if(litPlugins.length)violations.push('a plugin key is lit without its screen');
  else if(lit.length!==1&&document.querySelector('.eng-keys .ek,.ek[data-all]'))violations.push('one subscription or All key is lit');
  const foreign={overview:'.sp-now,.sa-list,.md-list,.cmp-lad',sub:'.ov-top,.ov-chart,.md-list,.cmp-lad',tune:'.ov-top,.ov-chart,.sp-now,.sa-list,.cmp-lad',where:'.ov-top,.ov-chart,.sp-now,.sa-list,.md-list,.cmp-lad',compare:'.ov-top,.ov-chart,.sp-now,.sa-list,.md-list'};
  for(const [id,selector] of Object.entries(foreign))if(p?.classList.contains('pg-'+id)&&p.querySelector(selector))violations.push(`foreign content in ${id}`);
  if(opt&&opt!==range)violations.push(`range mismatch ${range}/${opt}`);
  const stats=p?.querySelector('.sp-stats[data-days]')?.getAttribute('data-days');
  if(stats&&stats!==({today:'today','7d':'7','30d':'30'})[range])violations.push(`statistics range mismatch ${range}/${stats}`);
  const chart=p?.querySelector('.ov-chart[data-buckets]')?.getAttribute('data-buckets');
  if(chart&&Number(chart)!==({today:24,'7d':7,'30d':30})[range])violations.push(`chart range mismatch ${range}/${chart}`);
  const overviewLabel=p?.classList.contains('pg-overview')&&!overlay.length?p.querySelector('.ov-top .lbl')?.textContent?.trim():null;
  if(overviewLabel&&['今天','7天','30天'].includes(overviewLabel)&&overviewLabel!==({today:'今天','7d':'7天','30d':'30天'})[range])violations.push(`overview range mismatch ${range}/${overviewLabel}`);
  const ring=[...document.querySelectorAll('body *')].filter(e=>{if(!e.matches(':focus-visible'))return false;const s=getComputedStyle(e),b=getComputedStyle(e,'::before');return s.outlineStyle!=='none'&&parseFloat(s.outlineWidth)>0||b.content!=='none'&&parseFloat(b.borderTopWidth)>0;});
  if(checkPointer&&ring.length)violations.push('focus ring after pointer');
  // Scrollable viewports legitimately hide parts of their content. Intersect with each real scrollport before
  // comparing visible pixels with the outer view; fixed controls must still fit in that view.
  const scrolls=(e,s,axis)=>/^(auto|scroll)$/.test(axis==='x'?s.overflowX:s.overflowY)&&(axis==='x'?e.scrollWidth>e.clientWidth:e.scrollHeight>e.clientHeight);
  const scrollBounds=e=>{const r=e.getBoundingClientRect(),left=r.left+e.clientLeft,top=r.top+e.clientTop;return {left,top,right:left+e.clientWidth,bottom:top+e.clientHeight};};
  const intersectScroll=(e,rect,stop)=>{const a={left:rect.left,right:rect.right,top:rect.top,bottom:rect.bottom};if(getComputedStyle(e).position==='fixed')return a;
   for(let parent=e.parentElement;parent&&parent!==stop;parent=parent.parentElement){const s=getComputedStyle(parent),x=scrolls(parent,s,'x'),y=scrolls(parent,s,'y');if(!x&&!y)continue;const b=scrollBounds(parent);
    if(x){a.left=Math.max(a.left,b.left);a.right=Math.min(a.right,b.right);}if(y){a.top=Math.max(a.top,b.top);a.bottom=Math.min(a.bottom,b.bottom);}if(a.right<=a.left||a.bottom<=a.top)return null;
   }return a;};
  const view=overlay[0]||p,box=view?.getBoundingClientRect();
  if(view&&box)for(const e of view.querySelectorAll('button,svg')){const r=e.getBoundingClientRect(),s=getComputedStyle(e),visible=intersectScroll(e,r,view);if(r.width&&r.height&&s.visibility!=='hidden'&&visible&&(visible.left<box.left-1||visible.right>box.right+1||visible.top<box.top-1||visible.bottom>box.bottom+1))violations.push(`view overflow ${e.className?.baseVal||e.className}`);}
  // Measure the rendered text itself, including descendants of overflow containers; fully offscreen scroll rows are not visible.
  const root=document.querySelector('#cockpit'),walker=document.createTreeWalker(root,NodeFilter.SHOW_TEXT);
  while(walker.nextNode()){
   const node=walker.currentNode,e=node.parentElement;if(!node.textContent.trim()||!e||overlay.length&&p?.contains(e))continue;
   const style=getComputedStyle(e),elementBox=e.getBoundingClientRect();if(style.visibility==='hidden'||style.display==='none'||elementBox.width<=1&&elementBox.height<=1&&style.clipPath==='inset(50%)')continue;
   const text=document.createRange();text.selectNodeContents(node);
   for(const textRect of text.getClientRects()){
    if(!textRect.width||!textRect.height)continue;
    const rect={left:textRect.left,right:textRect.right,top:textRect.top,bottom:textRect.bottom};
    for(let parent=e;parent&&parent!==root;parent=parent.parentElement){const s=getComputedStyle(parent),r=parent.getBoundingClientRect(),clipX=s.display!=='inline'&&/^(hidden|clip|auto|scroll)$/.test(s.overflowX),clipY=s.display!=='inline'&&/^(hidden|clip|auto|scroll)$/.test(s.overflowY);if(!clipX&&!clipY)continue;
     if(rect.right<=r.left||rect.left>=r.right||rect.bottom<=r.top||rect.top>=r.bottom)break;
     const scrollX=clipX&&scrolls(parent,s,'x'),scrollY=clipY&&scrolls(parent,s,'y');if(scrollX||scrollY){const b=scrollBounds(parent);if(scrollX){rect.left=Math.max(rect.left,b.left);rect.right=Math.min(rect.right,b.right);}if(scrollY){rect.top=Math.max(rect.top,b.top);rect.bottom=Math.min(rect.bottom,b.bottom);}if(rect.right<=rect.left||rect.bottom<=rect.top)break;}
     if(clipX&&!scrollX&&(rect.left<r.left-1||rect.right>r.right+1)||clipY&&!scrollY&&(rect.top<r.top-1||rect.bottom>r.bottom+1)){const fontBoxOnly=rect.left>=r.left-1&&rect.right<=r.right+1&&rect.top>=r.top-2.5&&rect.bottom<=r.bottom+1.5;const named=parent.matches('.pk-seg .pk-tab')?'.pk-seg .pk-tab':fontBoxOnly&&parent.matches('.mfd-pk .pk > span')?'.mfd-pk .pk > span':fontBoxOnly&&parent.matches('.pl-foot .pl-fit')?'.pl-foot .pl-fit':fontBoxOnly&&parent.matches('.mfd-ok .ok-l')?'.mfd-ok .ok-l':fontBoxOnly&&parent.matches('.sp-h b')?'.sp-h b':parent.matches('.eng-keys[data-slots="6"] .ek-name')&&e.textContent==='Claude Code'&&rect.right-r.right<=9&&rect.left>=r.left-1&&rect.top>=r.top-1&&rect.bottom<=r.bottom+1?'.eng-keys .ek-name Claude Code':null;violations.push(named?`clipped text ${named}`:`clipped text ${e.outerHTML.slice(0,140)} in ${parent.outerHTML.slice(0,150)} (${s.display} ${s.overflowX}/${s.overflowY}, ${r.width}x${r.height}): ${Math.round(rect.left-r.left)},${Math.round(rect.right-r.right)},${Math.round(rect.top-r.top)},${Math.round(rect.bottom-r.bottom)}`);break;}
    }
   }
  }
  return {violations,range,page:p?.className,content:(overlay[0]||p)?.textContent,overviewTotal:p?.querySelector('.ov-top .ov-total')?.textContent??null,plugin:overlay[0]?.dataset.plugin??null,selected:selected.map(e=>e.getAttribute('data-mfd')),choices:[...document.querySelectorAll('.mfd-ok [data-opt]')].map(e=>[e.getAttribute('data-opt'),e.querySelector('b.on')?.getAttribute('data-choice')]),scope:document.querySelector('.eng-keys .ek[aria-pressed="true"]')?.getAttribute('data-sub')??'all',hud:document.querySelector('.hud .hp.selected')?.getAttribute('data-hud-model')??null,pager:document.querySelector('.eng-pgn')?.textContent??null,faders:[...document.querySelectorAll('.fd-ch:not(.empty)')].map(e=>[e.className,e.querySelector('.fd-strip')?.textContent]),picks:[...document.querySelectorAll('.mfd-screen .sel,.mfd-screen .trial')].map(e=>[e.className?.baseVal||e.className,e.getAttribute('data-mfd'),e.textContent])};
}

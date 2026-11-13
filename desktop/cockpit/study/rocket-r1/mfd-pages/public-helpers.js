// SPDX-License-Identifier: MIT
// Presentation-only adapters. Selection is supplied by the public projection;
// never infer model succession or import private curation rules.
export const scopeSelection=({models=[]})=>({field:models});
export const withOlderLabel=(model,label)=>model.older?{...model,name:`${model.name} · ${label}`,short:`${model.short} · ${label}`}:model;
export const statusItems=alerts=>alerts;
export const statusRow=()=>'';
export const websiteWords=lang=>lang==='en'?{plans:'Plan details',compare:'Compare on the website',how:"How it’s worked out"}:{plans:'套餐详情',compare:'在网站上对比',how:'怎么算的'};
const base='https://modelplan.ai';
export const planUrl=vendor=>base+'/plans?'+new URLSearchParams({seller:vendor});
export const modelUrl=id=>base+'/effort?'+new URLSearchParams({model:id});
export const methodologyUrl=anchor=>base+'/methodology#'+encodeURIComponent(anchor);
export const secondaryLink=(href,label)=>`<a class="website-link" href="${href}" target="_blank" rel="noopener noreferrer">${label} ↗</a>`;

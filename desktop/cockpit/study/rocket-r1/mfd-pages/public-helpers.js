// SPDX-License-Identifier: MIT
// Presentation-only adapters. Selection is supplied by the public projection;
// never infer model succession or import private curation rules.
import {tables} from '../i18n.js';
import '../strings/host.js';
export const scopeSelection=({models=[]})=>({field:models});
export const withOlderLabel=(model,label)=>model.older?{...model,name:`${model.name} · ${label}`,short:`${model.short} · ${label}`}:model;
export const statusItems=alerts=>alerts;
export const statusRow=()=>'';
export const websiteWords=lang=>{const table=tables[lang==='en'?'en':'zh-CN'];return {plans:table['host.webPlans'],compare:table['host.webCompare'],how:table['host.webHow']};};
const base='https://modelplan.ai';
export const planUrl=vendor=>base+'/plans?'+new URLSearchParams({seller:vendor});
export const modelUrl=id=>base+'/effort?'+new URLSearchParams({model:id});
export const methodologyUrl=anchor=>base+'/methodology#'+encodeURIComponent(anchor);
export const secondaryLink=(href,label)=>`<a class="website-link" href="${href}" target="_blank" rel="noopener noreferrer">${label} ↗</a>`;

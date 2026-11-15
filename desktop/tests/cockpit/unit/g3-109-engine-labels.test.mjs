// SPDX-License-Identifier: MIT
// G3-109: an extra quota whose period has no copy (role "other", e.g. Grok Build's additional usage) never shows a
// raw string-table key such as "extra.per.other"; every rendered label comes from the copy table. Synthetic data only.
import test from 'node:test';
import assert from 'node:assert/strict';
import {engineModel} from '../../../cockpit/study/rocket-r1/engine-model.js';
import {engineView} from '../../../cockpit/study/rocket-r1/engine-view.js';
import {setLanguage,checkTables} from '../../../cockpit/study/rocket-r1/i18n.js';

globalThis.document??={documentElement:{}};
const NOW=Date.UTC(2026,10,13,12);
const account=(id,name,extras)=>({id,name,short:name,alias:name,colour:'#888888',logo:'x.svg',state:'ok',support:'quota-only',todayTokens:null,windows:[],extras});
const extra=(period,name)=>({kind:period,period,name,label:name,scope:{label:name},remaining:null,resetIn:null});
const KEYLIKE=/\b(?:extra|eng|mfd|age|rev49)\.[A-Za-z0-9.]+/;
const text=html=>html.replace(/<[^>]+>/g,' ').replace(/&#39;|&quot;|&amp;/g,' ');
const attrs=html=>[...html.matchAll(/data-(?:full|short|small|tag|tip)="([^"]*)"|aria-label="([^"]*)"/g)].map(m=>m[1]??m[2]);

for(const lang of ['zh-CN','en'])for(const columns of [1,3,6])test(`G3-109 no raw copy key in ${columns}-column ${lang} engine text`,()=>{
 setLanguage(lang);
 const accounts=Array.from({length:columns},(_,i)=>account('a'+i,i?'Codex':'Grok Build',[extra('other',lang==='en'?'Other limit':'其他限额'),extra('weekly','Fable'),extra('mystery','')]));
 const html=engineView(engineModel({accounts,alerts:[],now:NOW},{few:'c3',page:0,scope:null,tint:true,pctMode:'left',redAt:25,ack:null,lang,now:NOW}),{changed:new Set(),lang,now:NOW});
 for(const s of [text(html),...attrs(html)])assert.doesNotMatch(s,KEYLIKE,s);
 assert.deepEqual(checkTables().missing.filter(k=>/extra\.|eng\./.test(k)),[]);
});

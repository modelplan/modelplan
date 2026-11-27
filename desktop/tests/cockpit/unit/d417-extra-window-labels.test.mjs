// SPDX-License-Identifier: MIT
// D417: an extra window is named by what it is (MCP, Opus, Fable), never a bare "其他"/"Other"; the name shows in full.
import test from 'node:test';
import assert from 'node:assert/strict';
import {engineModel} from '../../../cockpit/study/rocket-r1/engine-model.js';
import {engineView} from '../../../cockpit/study/rocket-r1/engine-view.js';
import {setLanguage,checkTables} from '../../../cockpit/study/rocket-r1/i18n.js';

globalThis.document??={documentElement:{}};
const NOW=Date.UTC(2026,10,24,12);
const extra=(period,name,named=true)=>({kind:period,period,name,named,label:name,scope:{label:name},remaining:60,resetIn:600});
const account=(id,name,extras)=>({id,name,short:name,alias:name,colour:'#888888',logo:'x.svg',state:'ok',support:'quota-only',todayTokens:null,windows:[],extras});
const render=(lang,accounts)=>engineView(engineModel({accounts,alerts:[],now:NOW},{few:'c3',page:0,scope:null,tint:true,pctMode:'left',redAt:25,ack:null,lang,now:NOW}),{changed:new Set(),lang,now:NOW});
const headings=html=>[...html.matchAll(/<span class="lb lb-other">([^<]*)<\/span>/g)].map(m=>m[1]);
const cellTags=html=>[...html.matchAll(/data-kind="extra" data-tag="([^"]*)"/g)].map(m=>m[1]);

for(const lang of ['zh-CN','en'])test(`D417 ZCode MCP names itself in the row heading and the cell (${lang})`,()=>{
 setLanguage(lang);
 const html=render(lang,[account('z','ZCode',[extra('month','MCP')])]);
 assert.deepEqual(headings(html),['MCP']);
 assert.match(cellTags(html)[0],/^MCP/);
 assert.doesNotMatch(html,/>其他<|>Other</);
 assert.deepEqual(checkTables().missing.filter(k=>/extra\.|eng\./.test(k)),[]);
});

for(const lang of ['zh-CN','en'])test(`D417 mixed extra windows keep their own names; heading is not "Other" (${lang})`,()=>{
 setLanguage(lang);
 const html=render(lang,[account('z','ZCode',[extra('month','MCP')]),account('c','Claude',[extra('week','Opus')]),account('f','Fable',[extra('week','Fable')])]);
 assert.deepEqual(headings(html),[lang==='en'?'Extra':'额外']);
 const tags=cellTags(html).join('|');
 for(const name of ['MCP','Opus','Fable'])assert.ok(tags.includes(name),name+' in '+tags);
 const attrs=[...html.matchAll(/data-(?:short|small)="([^"]*)"/g)].map(m=>m[1]);
 for(const name of ['MCP','Opus','Fable'])assert.ok(attrs.some(a=>a.includes(name)),'the narrow text variants keep '+name);
});

test('D417 a truly unknown window still reads Other',()=>{
 setLanguage('en');
 const html=render('en',[account('g','Grok',[extra('other','')])]);
 assert.deepEqual(headings(html),['Extra']);
 assert.match(html,/Other/);
});

for(const [lang,label] of [['zh-CN','其他限额'],['en','Other limit']])test(`D417 an unnamed window's generic label keeps the compact fallback (${lang})`,()=>{
 setLanguage(lang);
 const html=render(lang,[account('g','Grok',[extra('other',label,false)])]);
 const attrs=[...html.matchAll(/data-(?:short|small)="([^"]*)"/g)].map(m=>m[1]).filter(a=>a.includes(label[0]));
 assert.ok(attrs.length>0);
 for(const a of attrs)assert.ok(!a.includes(label),'the narrow variants do not repeat the full generic label: '+a);
 assert.deepEqual(headings(html),[lang==='en'?'Extra':'额外']);
});

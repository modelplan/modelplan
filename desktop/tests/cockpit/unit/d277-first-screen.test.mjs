// SPDX-License-Identifier: MIT
// Owner decision D277 (2026-11-16), cockpit first screen batch A. Synthetic data only.
// CKP-ENG-26: an unknown reset time no longer repeats "reset ?" in every cell; the cell that will run out says
// "out ~40m" in its alert's colour, also when its reset time is unknown.
// CKP-ENG-27: the subscription key carries the plan the reader knows; one quiet "updated" line has a refresh action
// that crosses the bridge as a typed member key.
import test from 'node:test';
import assert from 'node:assert/strict';
import {engineModel} from '../../../cockpit/study/rocket-r1/engine-model.js';
import {engineView} from '../../../cockpit/study/rocket-r1/engine-view.js';
import {setLanguage,checkTables} from '../../../cockpit/study/rocket-r1/i18n.js';
import {runOutMinutes} from '../../../cockpit/.tmp/compiled/src/prototype-data-adapter.js';
import {accountLabel,updatedCopy} from '../../../cockpit/.tmp/compiled/src/account-line.js';
import {tables} from '../../../cockpit/study/rocket-r1/i18n.js';
import '../../../cockpit/study/rocket-r1/strings/host.js';
import {CockpitBridge} from '../../../cockpit/.tmp/compiled/src/bridge.js';
import {appearance,capture,commands,pageId,source,shell} from '../fixture.mjs';

globalThis.document??={documentElement:{}};
const NOW=Date.UTC(2026,10,16,12);
const win=(kind,remaining,resetIn,extra={})=>({kind,remaining,resetIn,resetAt:null,resetText:null,elapsed:null,trend:null,runOutMin:null,durationMinutes:null,...extra});
const account=(id,windows,forecast=null)=>({id,name:id,short:id,alias:id,colour:'#888888',logo:'x.svg',state:'ok',support:'quota-only',todayTokens:null,windows,extras:[],forecast});
const view=(accounts,lang)=>{setLanguage(lang);return engineView(engineModel({accounts,alerts:[],now:NOW},{few:'c3',page:0,scope:null,tint:true,pctMode:'left',redAt:25,ack:null,lang,now:NOW}),{changed:new Set(),lang,now:NOW});};
const updatedText=(at,now,lang)=>{const c=updatedCopy(at,now);return tables[lang][c.key].replace('{n}',String(c.n));};
const lines=html=>[...html.matchAll(/<em class="qtxt([^"]*)" data-full="([^"]*)" data-short="([^"]*)"/g)].map(m=>({cls:m[1].trim(),full:m[2],short:m[3]}));

for(const [lang,unknown] of [['en','reset ?'],['zh-CN','重置未知']])test(`CKP-ENG-26 an unknown reset leaves the cell line empty, hover still says it (${lang})`,()=>{
 const html=view([account('a',[win('5h',75,null),win('week',40,null)]),account('b',[win('5h',60,null),win('week',30,null)])],lang);
 for(const line of lines(html)){assert.equal(line.full,'');assert.equal(line.short,'');}
 assert.equal(lines(html).length,4);
 assert.ok(html.includes(`· ${unknown}`),'the cell hover and accessible name keep the unknown reset');
 assert.equal(html.split(`data-full="${unknown}"`).length,1);
});

for(const [lang,text] of [['en','out ~40m'],['zh-CN','约40m用完']])test(`CKP-ENG-26 the cell that will run out names it in its alert colour (${lang})`,()=>{
 const amber=view([account('a',[win('5h',60,null,{trend:-1,runOutMin:40}),win('week',80,null)],{runOutMin:40})],lang);
 const [first,second]=lines(amber);
 assert.equal(first.full,text);assert.match(first.cls,/\bwarn\b/);assert.doesNotMatch(first.cls,/\bcrit\b/);
 assert.equal(second.full,'','only the window that runs out speaks');
 const red=view([account('a',[win('5h',20,null,{trend:-1,runOutMin:40}),win('week',80,null)],{runOutMin:40})],lang);
 assert.equal(lines(red)[0].full,text);assert.match(lines(red)[0].cls,/\bcrit\b/);assert.doesNotMatch(lines(red)[0].cls,/\bwarn\b/);
 assert.deepEqual(checkTables().missing.filter(k=>/^eng\.|^host\./.test(k)),[]);
});

test('CKP-ENG-26 a forecast run-out counts when the window has no reset time; a known later reset still bounds it',()=>{
 const data=capture(),row=data.projection.rows[0],acct=row.accounts[0],w=acct.windows[0],iso=m=>new Date(NOW+m*60000).toISOString();
 acct.valueState='current';Object.assign(w,{current:true,remainingPercent:60,validUntil:iso(30),resetsAt:null});
 data.details={...(data.details??{}),forecasts:[{source:row.id,subscriptionRef:acct.subscriptionRef,windowId:w.id,runsOutAt:iso(40),pace:'tight',basis:'recent-rate',observedAt:iso(-1)}]};
 // WP-03 merge: the table passes unknownReset=true (the alert model does too); the default stays strict for other callers.
 assert.equal(runOutMinutes(data,row.id,acct,w,NOW,true),40);
 w.resetsAt=iso(30);assert.equal(runOutMinutes(data,row.id,acct,w,NOW,true),null);
 w.resetsAt=iso(300);assert.equal(runOutMinutes(data,row.id,acct,w,NOW,true),40);
});

test('CKP-ENG-27 the key label carries the plan the reader knows',()=>{
 const a=plan=>({plan:{id:'x',name:plan}});
 assert.equal(accountLabel('Codex',a({en:'Pro 200',zh:'Pro 200'}),'en'),'Codex Pro 200');
 assert.equal(accountLabel('Claude Code',a({en:'Max',zh:'Max'}),'zh-CN'),'Claude Code Max');
 assert.equal(accountLabel('Codex',a(null),'en'),'Codex');
 assert.equal(accountLabel('Codex',a({en:' ',zh:' '}),'en'),'Codex');
 assert.equal(accountLabel('Kimi Code',a({en:'Kimi',zh:'Kimi'}),'en'),'Kimi Code','a plan that repeats the name adds nothing');
});

test('CKP-ENG-27 the updated line is quiet relative time in both languages',()=>{
 const at=m=>NOW-m*60000;
 assert.equal(updatedText(at(0.5),NOW,'en'),'Updated just now');assert.equal(updatedText(at(3),NOW,'en'),'Updated 3 min ago');
 assert.equal(updatedText(at(125),NOW,'en'),'Updated 2 h ago');assert.equal(updatedText(at(60*24*6),NOW,'en'),'Updated 6 d ago');
 assert.equal(updatedText(at(3),NOW,'zh-CN'),'3 分钟前更新');assert.equal(updatedText(at(0),NOW,'zh-CN'),'刚刚更新');
 assert.equal(updatedText(at(-5),NOW,'en'),'Updated just now','a clock ahead of the reading never goes negative');
});

test('CKP-ENG-27 refresh crosses the bridge only as a displayed member key or all',()=>{
 const events=[];let id=500;
 const sink={clear(){},render(){},nextDeadline(){return null;},tick(){},configure(){},updateAppearance(){},updateShell(){},active(){},dispose(){},scope(){},order(){},acked(){},pins(){}};
 const bridge=new CockpitBridge(pageId,source.origin,v=>events.push(JSON.parse(v)),new Proxy(sink,{get:(t,k)=>t[k]??(()=>{})}),()=>`00000000-0000-4000-8000-${String(++id).padStart(12,'0')}`);
 const send=commands();bridge.documentHidden(false);bridge.ready();
 assert.equal(bridge.receive(send('load',{appearance,shell}),source),true);
 assert.equal(bridge.receive(send('visibility',{visible:true,occluded:false,key:true}),source),true);
 assert.equal(bridge.action('refreshMember','all'),false,'nothing is displayed yet');
 const data=capture(),ref=data.projection.rows[0].accounts[0].subscriptionRef;
 assert.equal(bridge.receive(send('display',{data}),source),true);
 assert.equal(bridge.action('refreshMember',ref),true);assert.deepEqual([events.at(-1).action,events.at(-1).key],['refreshMember',ref]);
 assert.equal('tool' in events.at(-1),false);
 assert.equal(bridge.action('refreshMember','all'),true);assert.equal(events.at(-1).key,'all');
 for(const bad of [undefined,'','/secret','0000000000000999'])assert.equal(bridge.action('refreshMember',bad),false,String(bad));
});

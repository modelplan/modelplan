// SPDX-License-Identifier: MIT
// D470 去向 on `history.usage` (master spec S13, §2.3, §7.1, §7.2): projects and sessions ranked by total tokens in the
// header range, tokens the big figure and ≈$ small (D464), a 2 pt share bar, the Auto Review and "other" rows, the
// project filter and the scope filter. The real Go capture goes through the same adapter the deck uses.
process.env.TZ='America/Los_Angeles';
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,existsSync,symlinkSync} from 'node:fs';
import {assertChartOrder} from '../chart-order.mjs';
import {where} from '../../../cockpit/study/rocket-r1/mfd-pages/where.js';
import {setLanguage} from '../../../cockpit/study/rocket-r1/i18n.js';
import '../../../cockpit/study/rocket-r1/strings/mfd.js';

globalThis.document??={documentElement:{}};
setLanguage('en');
// The compiled adapter imports the study's i18n by a relative path that tsc does not emit (as d390-fractional-hour).
const compiled=new URL('../../../cockpit/.tmp/compiled/',import.meta.url);
if(!existsSync(new URL('study',compiled)))symlinkSync('../../study',new URL('study',compiled).pathname);
const {usageView}=await import('../../../cockpit/.tmp/compiled/src/prototype-history.js');

const now=Date.parse('2026-11-26T20:00:00Z');
const tokens=(total,extra={})=>({total,input:total/2,output:total/4,cacheRead:total/8,cacheWrite:total/8,complete:true,...extra});
const project=(ref,label,kind,total,share,more={})=>({ref,kind,label,sessions:1,sources:['codex'],subscriptionRefs:['aaaaaaaaaaaaaaaa'],firstObservedAt:'2026-11-20T10:00:00Z',lastObservedAt:'2026-11-26T19:00:00Z',running:false,tokens:tokens(total),share,costUsd:null,costState:'unpriced',model:'gpt-x',modelApprox:false,effort:'high',...more});
const session=(ref,title,projectRef,total,share,more={})=>({sessionRef:ref,source:'codex',subscriptionRef:'aaaaaaaaaaaaaaaa',projectRef,projectKind:'repo',projectLabel:'alpha',projectState:'named',title,firstObservedAt:'2026-11-26T10:00:00Z',lastObservedAt:'2026-11-26T19:00:00Z',running:false,tokens:tokens(total),share,costUsd:null,costState:'unpriced',model:'gpt-x',modelApprox:false,effort:'high',...more});
const other=(count,total,share)=>({count,tokens:tokens(total),share,costUsd:null,costState:'unpriced'});
const window=()=>({tokens:tokens(10000),costUsd:12,costState:'partial',projectCount:3,sessionCount:3,
 projects:[project('p1','alpha','repo',6000,.6,{costUsd:9.5,costState:'priced',running:true}),project('p2',null,'independent',1000,.1),project('p3','gamma','workspace',500,.05,{subscriptionRefs:['bbbbbbbbbbbbbbbb']})],
 sessions:[session('1111111111111111','Fix the tape','p1',6000,.6,{costUsd:9.5,costState:'priced'}),session('2222222222222222',null,null,1000,.1,{projectKind:'independent',projectState:'none',projectLabel:null}),session('3333333333333333','Docs','p3',500,.05,{subscriptionRef:'bbbbbbbbbbbbbbbb',running:true})],
 otherProjects:other(4,500,.05),otherSessions:other(4,500,.05),
 backgroundReview:{runs:2,tokens:tokens(2000),share:.2,costUsd:1.5,costState:'priced',model:'gpt-5.6-luna',modelApprox:true,lastObservedAt:'2026-11-26T18:00:00Z'}});
const wire=()=>({measure:'total-tokens',today:window(),recent7d:window(),recent30d:window()});
const ids=new Map([['aaaaaaaaaaaaaaaa','acc-a'],['bbbbbbbbbbbbbbbb','acc-b']]);
const data=(u=wire())=>({now,usage:usageView(u,ids),accounts:[{id:'acc-a',colour:'#111'},{id:'acc-b',colour:'#222'}],models:[{id:'gpt-x',short:'GPT X'}],sessionRanking:[],projectRanking:{recent7d:[],recent30d:[]}});
const ui=(more={})=>({range:'7d',where:'proj',project:null,scope:null,now,lang:'en',...more});
const rows=html=>[...html.matchAll(/<(?:button|div) class="wd wu[^"]*"([^>]*)>.*?<span class="wd-n">(.*?)<\/span><span class="wu-t">([^<]*)<\/span><span class="wd-m">([^<]*)<\/span><span class="wd-s">([^<]*)<\/span><i class="wu-bar" data-p="(\d+)"/g)]
 .map(m=>({ref:/data-(?:mfd="proj:|session=")([^"]+)"/.exec(m[1])?.[1]??null,name:m[2].replace(/<small.*?<\/small>/g,'').replace(/<[^>]+>/g,''),tokens:m[3],cost:m[4],share:m[5],bar:m[6]}));

test('CKP-MFD-67 D470: projects rank by total tokens with the Auto Review row folded in and "other" last',()=>{
 const html=where.render(data(),ui()),r=rows(html);
 assert.match(html,/7d · 3 projects/);
 assertChartOrder(r.map((x,i)=>({id:x.name,pos:i})),['▶alpha','Auto Review 2 runs','Independent chats','gamma','Other 4'],'去向 projects, largest first');
 assert.deepEqual(r.map(x=>x.tokens),['6k','2k','1k','500','500']);
 // D464: tokens are the big figure; ≈$ is small and only where priced, never $0.
 assert.deepEqual(r.map(x=>x.cost),['≈$9.5','≈$1.5','','','']);
 assert.deepEqual(r.map(x=>x.bar),['60','20','10','5','5']);
 assert.equal(r.reduce((s,x)=>s+Number(x.bar),0),100,'shares cover the range total');
 assert.equal(r[0].ref,'p1','a project row is a click target that filters the sessions');
});

test('§7.1 the project hover names it fully with the token split, last and first active',()=>{
 const tip=where.render(data(),ui()).match(/data-mfd="proj:p1" data-tip="([^"]*)"/)[1];
 for(const part of ['alpha','6k tokens: input 3k · output 2k · cache read 750 · cache write 750','60% of the tokens','Estimated cost ≈$9.5','Last active','First active'])assert.ok(tip.includes(part),`${part} in ${tip}`);
});

test('§7.2 a project row opens its sessions; running sessions come first, then by tokens',()=>{
 const all=rows(where.render(data(),ui({where:'time'})));
 assert.deepEqual(all.map(x=>x.ref??x.name),['3333333333333333','1111111111111111','Auto Review 2 runs','2222222222222222','Other 4']);
 const html=where.render(data(),ui({where:'time',project:'p1'})),one=rows(html);
 assert.deepEqual(one.map(x=>x.ref),['1111111111111111']);
 assert.match(html,/data-mfd="where:all"/);assert.match(html,/alpha · 1 session/);
 // A project with no reference is the "no project" bucket.
 assert.deepEqual(rows(where.render(data(),ui({where:'time',project:'unattributed'}))).map(x=>x.ref),['2222222222222222']);
});

test('a session without a title or project reads its bucket, never a path',()=>{
 const html=where.render(data(),ui({where:'time'}));
 assert.match(html,/Untitled session/);assert.match(html,/codex · Independent chats/);
});

test('a subscription scope keeps its own rows and drops the global Auto Review and other rows',()=>{
 const r=rows(where.render(data(),ui({scope:'acc-b'})));
 assert.deepEqual(r.map(x=>x.name),['gamma']);
 assert.deepEqual(rows(where.render(data(),ui({scope:'acc-b',where:'time'}))).map(x=>x.ref),['3333333333333333']);
});

test('the range key picks the window; an older producer without usage keeps the earlier page',()=>{
 const u=wire();u.today={...window(),projects:[project('t1','today-only','repo',10,1)],projectCount:1,backgroundReview:null,otherProjects:other(0,0,0)};
 assert.deepEqual(rows(where.render(data(u),ui({range:'today'}))).map(x=>x.name),['today-only']);
 const old=where.render({...data(),usage:null},ui({range:'today'}));
 assert.match(old,/No statistics for today yet/);
});

test('the real Go capture maps through the adapter: every window, bounded shares, a first active for projects',()=>{
 const capture=JSON.parse(readFileSync(new URL('../../../../schema/app-cli/captures/WireCockpitHistory.json',import.meta.url),'utf8'));
 // The capture seeds every string "synthetic"; the producer's measure is fixed, so only that field is set here.
 const v=usageView({...capture.usage,measure:'total-tokens'},ids);
 assert.ok(v);
 for(const w of [v.today,v.recent7d,v.recent30d]){
  for(const p of w.projects){assert.ok(p.share>=0&&p.share<=1);assert.equal(typeof p.firstAt,'number');}
  for(const s of w.sessions)assert.ok(s.share>=0&&s.share<=1);
 }
 assert.ok(rows(where.render({...data(),usage:v},ui())).length>0);
});

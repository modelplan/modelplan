// SPDX-License-Identifier: MIT
// Test-only synthetic profile shaped like owner build 13: one Codex subscription (verified) and one Claude Code
// subscription the producer could not verify, a running Codex session the producer left unbound, and an engine
// publication that does not carry the model in use. Never loaded by the production entry.
import {currentSample} from './fixture.mjs';

const efforts=(rec,rows)=>rows.map(([effort,ability,cost,time])=>({effort,label:{low:'Low',medium:'Med',high:'High',xhigh:'XHigh',max:'Max'}[effort],star:effort===rec,ability,cost,time}));
export const build13Models=[
 {id:'gpt-6-astra',name:'GPT-6 Astra',developerId:'openai',recommended:'medium',efforts:efforts('medium',[['low',28,.05,20],['medium',32,.09,35],['high',35,.14,50]])},
 {id:'gpt-6.1-terra',name:'GPT-6.1 Terra',developerId:'openai',recommended:'high',efforts:efforts('high',[['low',30,.06,25],['medium',34,.1,40],['high',37,.16,60],['xhigh',39,.27,90]])},
 {id:'gpt-6-luna',name:'GPT-6 Luna',developerId:'openai',recommended:'high',efforts:efforts('high',[['low',25,.03,15],['medium',29,.05,25],['high',31,.08,35],['xhigh',33,.13,55]])},
 {id:'gpt-6.1-sol',name:'GPT-6.1 Sol',developerId:'openai',recommended:'medium',efforts:efforts('medium',[['low',33.9,.132,38],['medium',39.8,.248,70],['high',42.8,.375,104],['xhigh',46,.63,162],['max',47.5,1.056,221]])},
 {id:'claude-opus-5.5',name:'Claude Opus 5.5',developerId:'anthropic',recommended:'medium',efforts:efforts('medium',[['low',45.6,1.2,94],['medium',55.4,2.9,228],['high',58.1,3.95,310]])},
];
export const CODEX_REF='0123456789abcdef',SESSION_REF='00000000000000c1';
export function build13Profile(now=Date.now()){
 const data=currentSample();
 const [codex,claude]=data.projection.rows;
 codex.vendorKey='openai';claude.vendorKey='claude';
 data.projection.rows=data.projection.rows.slice(0,2);
 for(const row of data.projection.rows)for(const a of row.accounts){a.plan={id:'pro',name:{en:'Pro',zh:'Pro'}};a.observedAt=new Date(now-220500).toISOString();}
 codex.accounts[0].subscriptionRef=CODEX_REF;codex.accounts[0].accountLocator=CODEX_REF;
 data.subscriptions=[{subscriptionRef:CODEX_REF,accounts:[{tool:'codex',account:structuredClone(codex.accounts[0])}]}];
 data.details={version:1,sources:['local-history','quota-reserve','quota-thresholds'],subscriptions:[],sessionCoverage:'local-last-seen',resetEvents:[],alerts:[],
  sessions:[{sessionRef:SESSION_REF,source:'codex',subscriptionRef:null,model:'gpt-6.1-sol',effort:'high',projectLabel:'modelPlans',lastObservedAt:new Date(now-20000).toISOString(),state:'running',rate:null}],
  publication:{contractVersion:1,publicationId:'0123456789abcdef01234567',publishedAt:'2026-11-01T12:00:00Z',source:'client',truncated:true,models:build13Models.slice(0,3)},
  publishedModels:build13Models};
 return data;
}

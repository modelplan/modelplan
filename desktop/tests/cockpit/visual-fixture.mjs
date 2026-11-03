// SPDX-License-Identifier: MIT
// Test-only synthetic inputs for the fader and last-seen study comparisons.
// These are never loaded by the production entry or included in the bundle.
import {sample} from './fixture.mjs';

export function visualFixture(){
 const data=sample();
 const sessions=[
  {sessionRef:'0000000000000001',source:'Codex',subscriptionRef:null,model:'Sol 6.1',effort:'High',projectLabel:'modelPlans',lastObservedAt:'2026-10-20T14:05:00Z',state:'running',rate:null},
  {sessionRef:'0000000000000002',source:'Claude',subscriptionRef:null,model:'Opus 5.5',effort:'High',projectLabel:'desktop',lastObservedAt:'2026-10-20T14:05:00Z',state:'running',rate:null},
  {sessionRef:'0000000000000003',source:'Claude',subscriptionRef:null,model:'GLM-5.3',effort:'Max',projectLabel:'modelPlans',lastObservedAt:'2026-10-20T14:05:00Z',state:'observed',rate:null},
 ];
 data.details={version:1,sources:['local-history'],subscriptions:[],sessions,sessionCoverage:'local-last-seen',resetEvents:[],alerts:[]};
 const faders=[
  {id:'sol',name:'GPT-6.1 Sol',short:'Sol 6.1',rec:'Med',e:[['Low',33.9,.132,38],['Med',39.8,.248,70],['High',42.8,.375,104],['XHigh',46,.63,162],['Max',47.5,1.056,221]],accounts:['study-codex'],sessions:[{ref:sessions[0].sessionRef}]},
  {id:'opus',name:'Claude Opus 5.5',short:'Opus 5.5',rec:'Med',e:[['Low',45.6,1.2,94],['Med',55.4,2.9,228],['High',58.1,3.95,310],['XHigh',60.1,7.5,515],['Max',62.4,13,891]],accounts:['study-claude'],sessions:[{ref:sessions[1].sessionRef}]},
  {id:'glm',name:'GLM-5.3',short:'GLM-5.3',rec:'Max',e:[['Max',49.4,4.2,424]],accounts:['study-glm'],sessions:[{ref:sessions[2].sessionRef}]},
 ];
 const accounts=[{id:'study-codex',colour:'#6aa8ff'},{id:'study-claude',colour:'#ff9a6a'},{id:'study-glm',colour:'#8f7dff'}];
 return {data,publication:{accounts,faders,selectedModel:'glm'}};
}

// Batch 027 used this test-only direct deck adapter; the normal entry still
// mounts its unavailable fixture and never reads publication from a global.
export async function renderVisualDeck(page,fixture,locale){
 await page.evaluate(async({data,publication,locale})=>{
  const {mountPrototypeDeck}=await import('/src/prototype-deck.js');
  const deck=mountPrototypeDeck(document.querySelector('#cockpit'),undefined,{publication,liveSessions:data.details.sessions,resetEvents:null,history:null});
  deck.locale(locale);deck.render(data,Date.parse('2026-10-20T14:05:00Z'));
 },{...fixture,locale});
}

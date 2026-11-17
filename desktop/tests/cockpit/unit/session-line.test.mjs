// SPDX-License-Identifier: MIT
// Owner decision D277 (2026-11-16), CKP-STRIP-09 / CKP-STRIP-16 / CKP-STRIP-17: one session-strip line says tool (display
// name), project, model + effort, elapsed, tokens and, at the right end, "● 58 t/s" while running or "6m ago" when idle.
// The page path is tests/cockpit/browser/ckp-strip-16.spec.mjs.
import test from 'node:test';
import assert from 'node:assert/strict';
import {sessionLine as stripLine,toolName,effortName} from '../../../cockpit/study/rocket-r1/session-line.js';

const NOW=Date.parse('2026-11-16T12:00:00Z'),min=n=>new Date(NOW-n*60000).toISOString();
const base={sessionRef:'0000000000000001',source:'codex',subscriptionRef:null,model:'sol',effort:'medium',projectLabel:'desktop',projectState:'named',lastObservedAt:min(0),state:'running',rate:58.4,startedAt:min(12),observedOutputTokens:58000};

test('CKP-STRIP-16 a running line: display names, elapsed since start, tokens, live speed and no age',()=>{
 const line=stripLine(base,NOW,'en',id=>id==='sol'?'Sol 6.1':id);
 assert.deepEqual(line,{tool:'Codex',unknownModel:false,model:'Sol 6.1',effort:'Med',elapsed:'12m',tokens:'58k',running:true,rate:58.4,ago:null});
 assert.equal(stripLine({...base,startedAt:min(65),observedOutputTokens:310000},NOW,'en').elapsed,'1h05');
 assert.equal(stripLine({...base,observedOutputTokens:1234567},NOW,'en').tokens,'1.2M');
});

test('CKP-STRIP-09 an idle line ends in its age, with elapsed between start and last reading',()=>{
 const line=stripLine({...base,state:'idle',lastObservedAt:min(6),startedAt:min(31)},NOW,'en');
 assert.equal(line.running,false);assert.equal(line.rate,null);assert.equal(line.ago,'6m ago');assert.equal(line.elapsed,'25m');
 assert.equal(stripLine({...base,state:'idle',lastObservedAt:min(15)},NOW,'zh-CN').ago,'15m前');
});

test('CKP-STRIP-16 unknown start, tokens or speed read "--" or stay null, never zero',()=>{
 const {startedAt,observedOutputTokens,...old}=base;
 const line=stripLine({...old,rate:null},NOW,'en');
 assert.equal(line.elapsed,'--');assert.equal(line.tokens,'--');assert.equal(line.rate,null);
 assert.equal(stripLine({...base,startedAt:min(-5)},NOW,'en').elapsed,'--');
 assert.equal(stripLine({...base,observedOutputTokens:0},NOW,'en').tokens,'0');
});

test('CKP-STRIP-17 tool display names and an unknown model',()=>{
 assert.equal(toolName('codex'),'Codex');assert.equal(toolName('claude-code'),'Claude');assert.equal(toolName('opencode'),'OpenCode');assert.equal(toolName('something-new'),'something-new');
 assert.equal(effortName('xhigh'),'XHigh');assert.equal(effortName(null),null);assert.equal(effortName('custom'),'custom');
 const line=stripLine({...base,model:'unknown'},NOW,'en');assert.equal(line.unknownModel,true);assert.equal(line.model,'');assert.equal(line.effort,'Med');
});

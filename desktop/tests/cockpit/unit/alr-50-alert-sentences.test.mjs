// SPDX-License-Identifier: MIT
// ALR-50 (WP-11, V1-FINAL §11): one sentence per alert, used identically by the ALERT tooltip, the column wash, the
// overview line, the alert list, the menu line and the widget-card footer. The page's table and the native table
// (ModelPlanSettings AlertSentence, AlertSentenceTableTests) are both held to one shared fixture so they cannot drift.
// The caution model's use of it is checked on the built page (ckp-mfd-55-alert-list.spec.mjs).
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {alertSentence,resetsAvailable,unreadableCause} from '../../../cockpit/study/rocket-r1/alert-sentence.js';

const fixture=JSON.parse(readFileSync(new URL('../../shared/alert-sentences.json',import.meta.url),'utf8'));

for(const c of fixture.cases)test(`ALR-50 shared sentence: ${c.name}`,()=>{
 const s=alertSentence(c.input);
 assert.deepEqual({text:s.text.en,short:s.short.en},c.en);
 assert.deepEqual({text:s.text.zh,short:s.short.zh},c.zh);
});

test('ALR-50 cause phrases come from the shared table',()=>{
 for(const [code,phrase] of Object.entries(fixture.causes))assert.deepEqual(unreadableCause(code),phrase,code);
 for(const code of ['other','parse_error','no_plan',...fixture.notUnreadable])assert.equal(unreadableCause(code),null,code);
});

test('ALR-50 available resets: singular and plural',()=>{
 assert.deepEqual(resetsAvailable(1),{en:'1 reset available',zh:'可用重置 1 次'});
 assert.deepEqual(resetsAvailable(2),{en:'2 resets available',zh:'可用重置 2 次'});
});

test('G3-218 Antigravity runtime_missing reads not running; other tools keep not installed',()=>{
 assert.deepEqual(unreadableCause('runtime_missing','antigravity'),{en:'not running',zh:'未运行'});
 assert.deepEqual(unreadableCause('runtime_missing','Antigravity'),{en:'not running',zh:'未运行'});
 assert.deepEqual(unreadableCause('runtime_missing','codex'),{en:'not installed',zh:'未安装'});
 assert.deepEqual(unreadableCause('runtime_missing'),{en:'not installed',zh:'未安装'});
 assert.deepEqual(unreadableCause('not_signed_in','antigravity'),{en:'not signed in',zh:'未登录'});
});

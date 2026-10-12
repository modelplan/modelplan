import test from 'node:test';import assert from 'node:assert/strict';import {readFile} from 'node:fs/promises';
import {projectClient,filterDashboard} from '../data.mjs';import {renderLineup,renderEffort,ratio} from '../render.mjs';
import {publishedLineupView} from '../ui/lineup.js';import {timeRatio} from '../ui/comparison.js';
const fixture=JSON.parse(await readFile(new URL('./fixtures/client-publication.json',import.meta.url)));
const labels={a:'能力',c:'成本',base:'成本以 %s 为 ×1',skip:'跳过',no:'暂无数据',strongest:'高能力优选',best_value:'最划算',cheapest:'最省',dominated:'不如 %s',equivalent_costlier:'≈ %s 但更贵'};
test('all runtime values, resets and windows are direct published client fields in exact OpenAI scope',()=>{
 const d=projectClient(fixture),c=fixture.component.data;assert.deepEqual(d.units,c.units);assert.strictEqual(d.lineup,c.lineups.find(l=>l.developerId==='openai'));
 for(const m of d.models){const raw=c.models.find(r=>r.id===m.id);assert.strictEqual(m.configurations,raw.efforts);assert.deepEqual(m.harnessIds,raw.harnessIds);assert.equal(m.developerId,'openai');}
 assert.deepEqual(d.resetFeed.events,c.resets.filter(r=>r.provider==='openai'));assert.deepEqual(d.windows,c.windows.filter(r=>r.provider==='openai'));assert.equal(d.resetFeed.personalEligibility,'unknown');
});
test('UI rows, step verdict, skip line and terminal values render the published fixture lineup',()=>{
 const d=projectClient(fixture),l=d.lineup,view=publishedLineupView(d,{labels});assert.strictEqual(view.source,l);
 assert.deepEqual(view.rows.map(r=>r.id),['sol-6.1','luna','astra','sol-5.6','terra-5.6']);
 assert.ok(view.html.includes('距最高分不超过 1 分'));assert.ok(view.html.includes('不代表最高档上限'));
 const text=renderLineup(d);for(const r of l.members){const m=d.models.find(m=>m.id===r.id);assert.ok(view.html.includes('data-model="'+r.id+'"'));assert.ok(text.includes(m.name));
  for(const tag of r.tags)assert.ok(view.html.includes('mp-tag '+tag));if(r.status!=='incomplete'){assert.ok(view.html.includes(r.ability.toFixed(1)));assert.ok(text.includes(ratio(r.costRelative)));}}
 for(const s of l.steps){assert.ok(view.verdict.includes(s.abilityDelta.toFixed(1)));assert.ok(view.verdict.includes(ratio(s.costRatio)));}
 const skipped=l.members.filter(r=>r.dominatedBy).map(r=>d.modelNames[r.id]);assert.ok(view.verdict.includes('跳过：'+skipped.join('、')));assert.ok(text.includes('跳过：'+skipped.join('、')));
});
test('published verdicts are not replaced by local value heuristics; absence stays absent',()=>{
 const d=projectClient(structuredClone(fixture));d.lineup.members[0].tags=['best_value'];d.lineup.members[0].dominatedBy=null;
 assert.equal(publishedLineupView(d,{labels}).rows[0].id,'astra');assert.ok(publishedLineupView(d,{labels}).html.includes('mp-tag best_value'));assert.ok(renderLineup(d).split('\n').find(s=>s.startsWith('  GPT-6 Astra ')).includes('最划算'));
 const empty={...d,lineup:null};assert.equal(publishedLineupView(empty,{labels}).source,null);assert.match(renderLineup(empty),/no published lineup/);
});
test('exact model ID filtering retains the original published lineup/baseline and refuses fuzzy IDs',()=>{
 const d=projectClient(fixture),one=filterDashboard(d,['astra']);assert.equal(one.models.length,1);assert.strictEqual(one.lineup,d.lineup);assert.throws(()=>filterDashboard(d,['GPT-6']),/unknown_model_ids/);
});
test('effort text and UI curves abstain on differing/missing time bases; zero and unknown remain distinct',()=>{
 const base={time:2,timeBasis:{source:'aa-agent',cohort:'test',boundary:'wall',referenceSeconds:100}};
 assert.equal(timeRatio({...base,time:0},base),0);assert.equal(timeRatio({...base,time:null},base),null);assert.equal(timeRatio({...base,timeBasis:null},base),null);assert.equal(timeRatio({...base,timeBasis:{...base.timeBasis,cohort:'other'}},base),null);
 const d=projectClient(structuredClone(fixture)),m=d.models.find(m=>m.id==='sol-6.1'),rec=m.configurations.find(e=>e.effort===m.recommended),other=m.configurations[0];other.timeBasis={...rec.timeBasis,cohort:'other'};
 const row=renderEffort(m).split('\n').find(s=>s.includes(other.label));assert.match(row,/耗时 —$/);
});

test('compatible v1.1 multiplier scope is passed through without picking an entitlement or faking absence',()=>{const v=structuredClone(fixture);v.component.data.projectionVersion='client-v1.1';const h={from:'2026-10-11T00:00:00Z',to:'2026-10-13T00:00:00Z',selection:'highest-priority-no-stacking'};v.component.data.multiplierHorizon=h;v.component.data.multipliers=[{provider:'openai',multiplier:null},{provider:'zhipu',multiplier:0}];const d=projectClient(v);assert.deepEqual(d.multipliers,[v.component.data.multipliers[0]]);assert.strictEqual(d.multiplierHorizon,h);assert.equal(d.multipliers[0].multiplier,null);assert.equal(projectClient(fixture).multipliers,undefined);});

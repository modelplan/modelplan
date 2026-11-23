// G3-168 (CKP-MFD-66 amended): every model plotted on the Models chart carries a readable name without hover.
import test from 'node:test';
import assert from 'node:assert/strict';
import {frontierSvg,labelWidth} from '../../../cockpit/study/rocket-r1/mfd-pages/frontier.js';
import {setLanguage} from '../../../cockpit/study/rocket-r1/i18n.js';
import '../../../cockpit/study/rocket-r1/strings/mfd.js';

globalThis.document??={documentElement:{}};
const m=(id,short,a,c)=>({id,name:short,short,rec:'Med',e:[['Low',a-4,c/2,1],['Med',a,c,1],['High',a+2,c*2,1]]});
const models=[m('a','Astra 6.2',62,.9),m('t','Terra 6.1',61,.8),m('l','Luna 6',60,.3),m('s','Sol 6.2',62,.85),m('a0','Astra 6',60,.31),m('s0','Sol 5.6',56,.32),m('x','Sol 5.5',55,.33),m('y','Luna 5.9',60,.3),m('z','Terra 6',61,.8),m('q','Astra 5.8',60,.3),m('r','Sol 5.8',60,.3)];
test('G3-168: all crowded models get a visible name at the default size, nothing overlapping', () => {
  setLanguage('en');
  for (const [w,h] of [[260,180],[200,120]]) {
    const svg=frontierSvg(models,{w,h,axis:{ability:'A',cost:'C'}});
    const names=[...svg.matchAll(/<text class="fc-l[^"]*" x="([\d.]+)" y="([\d.]+)">([^<]+)<\/text>/g)];
    assert.deepEqual(names.map(x=>x[3]).sort(),models.map(x=>x.short).sort());
    for (const [,x,y] of names) assert.ok(x>=0&&x<w&&y>=0&&y<=h,`${x},${y} inside ${w}x${h}`);
    const boxes=names.map(([,x,y,t])=>({x:+x,y:+y,w:t.length*5.6}));
    for (const [i,a] of boxes.entries()) for (const b of boxes.slice(i+1)) assert.ok(a.x+a.w<=b.x||b.x+b.w<=a.x||Math.abs(a.y-b.y)>=9,'labels overlap');
  }
});

// Sampling 11-22 (PR 1165): the placement never checked the viewport, never fitted an overlong published name, and
// the forced edge fallback overlapped existing names. A label counts as readable only when its full estimated box
// (baseline y, ±8/+2, 5.6 px per glyph — the renderer's own estimate) is inside the chart and clear of every other.
const NAME_RE=/<text class="fc-l[^"]*" x="(-?[\d.]+)" y="(-?[\d.]+)"[^>]*>(?:<title>([^<]*)<\/title>)?([^<]*)<\/text>/g;
const nameBoxes=(svg,{w,h})=>{
  const names=[...svg.matchAll(NAME_RE)];
  assert.equal(names.length,(svg.match(/class="fc-l /g)||[]).length,'every label parsed');
  return {names,boxes:names.map(([,x,y,,t])=>({x:+x,y:+y,w:t.length*5.6+2,t}))};
};
const inBounds=(b,w,h)=>b.x>=1&&b.x+b.w<=w-1&&b.y-8>=0&&b.y+2<=h;
const disjoint=(a,b)=>a.x+a.w<=b.x||b.x+b.w<=a.x||Math.abs(a.y-b.y)>=10;
test('sampling 11-22 F1: a same-ability cluster keeps every full label box inside the chart', () => {
  setLanguage('en');
  const cluster=[m('a','Astra 6',75,2),m('b','Sol 6.1',75,2),m('c','Terra 6.1',75,2),m('d','Opus 5.5',75,2),m('e','Sonnet 5.5',75,2),m('f','Pico 3',25,.05)];
  const {names,boxes}=nameBoxes(frontierSvg(cluster,{w:260,h:180}),{w:260,h:180});
  assert.equal(names.length,cluster.length);
  for (const b of boxes) assert.ok(inBounds(b,260,180),`${b.t} at ${b.x},${b.y} fully inside`);
});
test('sampling 11-22 ghglm-1165-1: nine models with current efforts place pairwise disjoint, in-bounds names', () => {
  setLanguage('en');
  const mk=(id,name,la,ca,lh,ch)=>({id,name,short:name,rec:'Med',e:[['Low',15,.01,1],['Med',la,ca,1],['High',lh,ch,1]]});
  const nine=[mk('n1','Sonnet 5.5',25,2,45,2.2),mk('n2','GLM Flash',70,2,90,2.3),mk('n3','Astra 6.1',75,2,90,2.2),
    mk('n4','Luna 5.6',25,3,40,3.1),mk('n5','Haiku 4.5',75,2,95,2.1),mk('n6','Opus 5.5',70,1,80,1),
    mk('n7','Fable 5.1',85,3,110,3),mk('n8','Sol 6.1',75,1,100,1.1),mk('n9','Haiku 5.5',75,3,100,3.1)];
  const current=Object.fromEntries(nine.map(x=>[x.id,'High']));
  const {names,boxes}=nameBoxes(frontierSvg(nine,{w:260,h:180,current}),{w:260,h:180});
  assert.equal(names.length,nine.length);
  for (const b of boxes) assert.ok(inBounds(b,260,180),`${b.t} at ${b.x},${b.y} fully inside`);
  for (const [i,a] of boxes.entries()) for (const b of boxes.slice(i+1))
    assert.ok(disjoint(a,b),`${a.t} at ${a.x},${a.y} overlaps ${b.t} at ${b.x},${b.y}`);
});
test('sampling 11-22 F3: an overlong published name is fitted inside and keeps its full name for hover', () => {
  setLanguage('en');
  const long='Qwen-Long-Context-Instruct-Preview-2026-11-22-Experimental';
  const svg=frontierSvg([m('a','Astra 6',62,.9),{id:'q',name:long,short:long,rec:'Med',e:[['Low',21,.2,1],['Med',25,.3,1],['High',30,.5,1]]}],{w:260,h:180});
  const {boxes}=nameBoxes(svg,{w:260,h:180});
  assert.equal(boxes.length,2);
  for (const b of boxes) assert.ok(inBounds(b,260,180),`${b.t} at ${b.x},${b.y} fully inside`);
  const fitted=boxes.find(b=>b.t.endsWith('…'));
  assert.ok(fitted,'the overlong name is fitted with an ellipsis');
  assert.ok(fitted.t.length<long.length,'the fitted label is shorter than the published name');
  assert.ok(svg.includes(`<title>${long}</title>`),'the label carries the full name as its hover title');
  assert.ok(svg.includes(`data-tip="${long}`),'the point tooltip keeps the full name');
});
test('sampling 11-22 macrevb-1179-2: a full-width published name is fitted by its real glyph width, full name kept for hover', () => {
  setLanguage('en');
  const wide='Ｑｗｅｎ－Ｌｏｎｇ－Ｃｏｎｔｅｘｔ－Ｉｎｓｔｒｕｃｔ－Ｐｒｅｖｉｅｗ－２０２６－１１－２２';
  const svg=frontierSvg([m('a','Astra 6',62,.9),{id:'q',name:wide,short:wide,rec:'Med',e:[['Low',21,.2,1],['Med',25,.3,1],['High',30,.5,1]]}],{w:260,h:180});
  const fitted=[...svg.matchAll(NAME_RE)].find(n=>n[4].endsWith('…'));
  assert.ok(fitted,'the wide name is truncated');
  assert.ok(+fitted[1]>=1&&+fitted[1]+labelWidth(fitted[4])<=259,'estimated box inside the chart');
  assert.ok(svg.includes(`<title>${wide}</title>`),'label title keeps the full name');
  assert.ok(svg.includes(`data-tip="${wide}`),'point tooltip keeps the full name');
});

// G3-168 (CKP-MFD-66 amended): every model plotted on the Models chart carries a readable name without hover.
import test from 'node:test';
import assert from 'node:assert/strict';
import {frontierSvg} from '../../../cockpit/study/rocket-r1/mfd-pages/frontier.js';
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

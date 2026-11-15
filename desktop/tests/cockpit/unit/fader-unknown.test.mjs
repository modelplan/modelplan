// SPDX-License-Identifier: MIT
import test from 'node:test';
import assert from 'node:assert/strict';
import {delta,faderModel} from '../../../cockpit/study/rocket-r1/fader-view.js';

test('missing published ability stays unknown in trial comparisons',()=>{
 const f={id:'a',name:'Synthetic',short:'Synthetic',rec:'Med',e:[['Med',null,2,null],['High',40,null,null]],current:null,currentFast:false,tier:null,live:false,pinned:false,others:{},accounts:[],sessions:[]};
 const channel=faderModel({faders:[f],accounts:[]},{bank:0,bankSize:3,selModel:'a',previews:{a:'High'},view:null}).channels[0];
 assert.equal(channel.trial.abl,null);assert.equal(channel.trial.cost,null);assert.equal(delta(channel.trial.abl),'--');
});

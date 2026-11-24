// SPDX-License-Identifier: MIT
// Each entry is an observed failure of an invariant, not a general console filter.
export const expectedWalkFailures=[
 {name:'page-key text extends outside its clipping box',kind:'geometry',message:'clipped text .mfd-pk .pk > span'},
 {name:'plugin footer text extends outside its clipping box',kind:'geometry',message:'clipped text .pl-foot .pl-fit'},
 {name:'option-key text extends outside its clipping box',kind:'geometry',message:'clipped text .mfd-ok .ok-l'},
 {name:'subscription title text extends outside its clipping box',kind:'geometry',message:'clipped text .sp-h b'},
 {name:'Claude Code subscription label truncates on a six-column page',kind:'geometry',message:'clipped text .eng-keys .ek-name Claude Code'},
];

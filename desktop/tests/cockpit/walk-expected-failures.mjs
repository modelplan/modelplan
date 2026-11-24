// SPDX-License-Identifier: MIT
// Each entry is an observed failure of an invariant, not a general console filter.
// The prototype emits CSP errors when its inline style attributes are parsed before CSSOM repairs them.
export const expectedWalkFailures=[
 {name:'page-key text extends outside its clipping box',kind:'geometry',message:'clipped text .mfd-pk .pk > span'},
 // D387's Overview | <screen> switch: a long tab (资源占用) is cut by an ellipsis in its one page-key column. Known, owner-visible, not part of D400/D401.
 {name:'switch tab text extends outside its clipping box',kind:'geometry',message:'clipped text .pk-seg .pk-tab'},
 {name:'plugin footer text extends outside its clipping box',kind:'geometry',message:'clipped text .pl-foot .pl-fit'},
 {name:'option-key text extends outside its clipping box',kind:'geometry',message:'clipped text .mfd-ok .ok-l'},
 {name:'subscription title text extends outside its clipping box',kind:'geometry',message:'clipped text .sp-h b'},
{
 name:'prototype inline styles trigger CSP console errors',
 kind:'console',
 message:"Refused to apply a stylesheet because its hash, its nonce, or 'unsafe-inline' does not appear in the style-src directive of the Content Security Policy.",
}
];

// SPDX-License-Identifier: MIT
// Each entry is an observed failure of an invariant, not a general console filter.
// The prototype emits CSP errors when its inline style attributes are parsed before CSSOM repairs them.
export const expectedWalkFailures=[
 {name:'page-key text extends outside its clipping box',kind:'geometry',message:'clipped text .mfd-pk .pk > span'},
 {name:'plugin footer text extends outside its clipping box',kind:'geometry',message:'clipped text .pl-foot .pl-fit'},
 {name:'option-key text extends outside its clipping box',kind:'geometry',message:'clipped text .mfd-ok .ok-l'},
 {name:'subscription title text extends outside its clipping box',kind:'geometry',message:'clipped text .sp-h b'},
 {name:'Claude Code subscription label truncates on a six-column page',kind:'geometry',message:'clipped text .eng-keys .ek-name Claude Code'},
 {name:'initial display pulse may finish after a click deadline',kind:'timing',message:'display-pulse-cleanup'},
{
 name:'prototype inline styles trigger CSP console errors',
 kind:'console',
 message:"Refused to apply a stylesheet because its hash, its nonce, or 'unsafe-inline' does not appear in the style-src directive of the Content Security Policy.",
},...['gear','detach'].flatMap(asset=>[
 {name:'header images trigger CSP errors on reload',kind:'console',message:`Refused to connect to http://127.0.0.1:41783/assets/${asset}-normal@3x.png because it does not appear in the connect-src directive of the Content Security Policy.`},
 {name:'header images trigger CSP errors on reload',kind:'console',message:'Failed to load resource: Blocked by Content Security Policy.',url:`http://127.0.0.1:41783/assets/${asset}-normal@3x.png`},
]),...['lamp-off-glow','lamp-off-body'].flatMap(asset=>[
 {name:'lamp images trigger CSP errors on reload',kind:'console',message:`Refused to connect to http://127.0.0.1:41783/assets/${asset}@3x.png because it does not appear in the connect-src directive of the Content Security Policy.`},
 {name:'lamp images trigger CSP errors on reload',kind:'console',message:'Failed to load resource: Blocked by Content Security Policy.',url:`http://127.0.0.1:41783/assets/${asset}@3x.png`},
])];

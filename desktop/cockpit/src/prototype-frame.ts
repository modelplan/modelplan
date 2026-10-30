// SPDX-License-Identifier: MIT
// Copyright (c) 2026 ModelPlan.
// Owner-released G/P6 buildCockpit skeleton, source 1d3f82429f1b853314ee120d4bd0007f84fc051d.
// Keep the plate/port/engine/deck/tape hierarchy. Native-only controls, logos,
// study bootstrap, private scene imports and unbacked interactive instruments are omitted.
export function prototypeFrame(root:HTMLElement) {
  root.className='ck private-content';
  // Static trusted source markup only. Display values never enter innerHTML.
  root.innerHTML=`<div class="ck-shell" aria-hidden="true"><i class="hull-crown"></i><i class="hull-upper"></i><i class="hull-cone"></i><i class="hull-lower"></i><i class="hull-record"></i><i class="ck-booster l"></i><i class="ck-booster r"></i></div>
  <header class="ck-head"><span class="ck-brand"><span class="silk wordmark">Model<b>Plan</b></span></span><span class="sp"></span><span class="ck-lamp"><i class="activity" aria-hidden="true"></i></span><button class="key" data-settings type="button"></button></header>
  <section class="ck-portrow"><div class="ck-port" data-mat="well"><div class="ck-field" aria-hidden="true"></div><div class="hud" data-mat="glass"></div></div></section>
  <section class="ck-eng"></section>
  <section class="ck-deck"><div class="dk-fad"><div class="fd-scale" aria-hidden="true"></div><div class="fd-chs" aria-hidden="true"><div class="u11-fader"><i></i></div><div class="u11-fader"><i></i></div><div class="u11-fader"><i></i></div></div><div class="fd-bank"><button class="key" data-setup type="button"></button></div></div><div class="dk-mfd"></div></section>
  <section class="ck-tape" data-mat="well"></section>`;
  const get=<T extends HTMLElement>(selector:string)=>root.querySelector<T>(selector)!;
  return {engine:get<HTMLElement>('.ck-eng'),mfd:get<HTMLElement>('.dk-mfd'),hud:get<HTMLElement>('.hud'),tape:get<HTMLElement>('.ck-tape'),lamp:get<HTMLElement>('.activity'),settings:get<HTMLButtonElement>('[data-settings]'),setup:get<HTMLButtonElement>('[data-setup]')};
}

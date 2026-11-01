// SPDX-License-Identifier: MIT
// Copyright (c) 2026 ModelPlan.
// Study buildCockpit hierarchy, adapted from e7d29f84 for the authenticated native bridge.
// Only static markup enters this template; user data is rendered as text nodes.
export function prototypeFrame(root:HTMLElement) {
  root.className='ck private-content';
  // Static trusted source markup only. Display values never enter innerHTML.
  root.innerHTML=`<div class="ck-shell" aria-hidden="true"><i class="hull-crown"></i><i class="hull-upper"></i><i class="hull-cone"></i><i class="hull-lower"></i><i class="hull-record"></i><i class="ck-booster l"></i><i class="ck-booster r"></i></div>
  <header class="ck-head"><span class="ck-brand"><span class="s6-brand-mark brand-mark" aria-hidden="true"></span><span class="silk wordmark">Model<b>Plan</b></span></span><button class="shutter-slider" data-shutter type="button" aria-pressed="false"><span class="shutter-blind" aria-hidden="true"></span><i class="shutter-thumb" aria-hidden="true"></i></button><span class="sp"></span><span class="ck-lamp"><span class="s6-alert caution" aria-label="Alert inactive"><span>ALERT</span><i class="activity" aria-hidden="true"></i></span></span><button class="key" data-settings type="button"></button></header>
  <section class="ck-portrow"><div class="ck-port" data-mat="well"><div class="ck-field" aria-hidden="true"></div><div class="hud" data-mat="glass"></div></div></section>
  <section class="ck-eng"></section>
  <section class="ck-deck"><div class="dk-fad"><div class="fd-scale" aria-hidden="true"></div><div class="fd-chs"></div><div class="fd-bank"></div></div><div class="dk-mfd"></div></section>
  <section class="ck-tape" data-mat="well"></section><div class="ck-afterglow" aria-hidden="true"></div><div class="ck-bells" aria-hidden="true"></div>`;
  const get=<T extends HTMLElement>(selector:string)=>root.querySelector<T>(selector)!;
  return {engine:get<HTMLElement>('.ck-eng'),mfd:get<HTMLElement>('.dk-mfd'),hud:get<HTMLElement>('.hud'),tape:get<HTMLElement>('.ck-tape'),lamp:get<HTMLElement>('.activity'),settings:get<HTMLButtonElement>('[data-settings]')};
}

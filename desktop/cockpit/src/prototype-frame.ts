// SPDX-License-Identifier: MIT
// Copyright (c) 2026 ModelPlan.
// Prototype buildCockpit markup; the fixed brand image is a CSS background so
// the private-content subtree retains its no-image privacy invariant.
export function prototypeFrame(root:HTMLElement) {
  root.className='ck private-content';
  const t=(key:string):string=>({'port.shutterAria':'Porthole shutter','ck.settingsAria':'Settings','ck.detachAria':'Detach','ck.closeAria':'Close','ck.tapeAria':'Record strip'}[key]??'');
  root.innerHTML=`<div class="ck-shell" aria-hidden="true"><i class="hull-crown"></i><i class="hull-upper"></i><i class="hull-cone"></i><i class="hull-lower"></i><i class="hull-record"></i><i class="ck-booster l"></i><i class="ck-booster r"></i></div>
  <header class="ck-head">
    <span class="ck-brand"><span class="s6-brand-mark brand-mark" role="img" aria-label="ModelPlan"></span><span class="silk wordmark">Model<b>Plan</b></span></span>
    <button type="button" class="shutter-slider" data-shutter data-mat="part" aria-label="${t('port.shutterAria')}" aria-pressed="false"><span class="shutter-blind" aria-hidden="true"></span><i class="shutter-thumb" aria-hidden="true"></i></button>
    <span class="ck-lamp"></span>
    <button type="button" class="key" data-settings data-mat="part" aria-label="${t('ck.settingsAria')}"></button>
    <button type="button" class="key detach-toggle" data-detach data-mat="part" aria-label="${t('ck.detachAria')}" aria-pressed="false"><span class="detach-glyph" aria-hidden="true"></span></button>
    <button type="button" class="key key-x" data-close data-mat="part" aria-label="${t('ck.closeAria')}"></button></header>
  <section class="ck-portrow">
    <div class="ck-port" data-mat="well"><div class="ck-field"></div><div class="hud" data-mat="glass"></div></div>
  </section>
  <section class="ck-eng"></section>
  <section class="ck-deck"><div class="dk-fad"><div class="fd-scale" aria-hidden="true"></div><div class="fd-chs"></div><div class="fd-bank"></div></div><div class="dk-mfd"></div></section>
  <section class="ck-tape" data-mat="well" aria-label="${t('ck.tapeAria')}"></section>
  <div class="ck-afterglow" aria-hidden="true"></div><div class="ck-bells" aria-hidden="true"></div>`;
  const get=<T extends HTMLElement>(selector:string)=>root.querySelector<T>(selector)!;
  // The study fills ck-lamp separately with cautionView; no wire text enters it.
  const caution=document.createElement('button');caution.className='s6-alert caution';caution.dataset.caution='';caution.dataset.mat='part';caution.setAttribute('aria-label','Alert inactive');
  const label=document.createElement('span');label.textContent='ALERT';const lamp=document.createElement('i');lamp.className='activity';lamp.setAttribute('aria-hidden','true');caution.append(label,lamp);get('.ck-lamp').append(caution);
  return {engine:get<HTMLElement>('.ck-eng'),mfd:get<HTMLElement>('.dk-mfd'),hud:get<HTMLElement>('.hud'),tape:get<HTMLElement>('.ck-tape'),lamp,settings:get<HTMLButtonElement>('[data-settings]')};
}

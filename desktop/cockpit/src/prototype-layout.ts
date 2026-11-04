// SPDX-License-Identifier: MIT
// Copyright (c) 2026 ModelPlan. Ported from cockpit-fit.js at 1d3f82429f1b853314ee120d4bd0007f84fc051d.
const clamp = (n:number,a:number,b:number) => Math.max(a,Math.min(b,n));
export function cockpitLayout(h = 890) {
  const e = Math.max(0,h-760), tapeLines = e-88>=36 ? 5 : 3;
  return {h,console:217+clamp(e-48,0,40),tapeLines,tapeH:tapeLines===5?94:58,eng:220+clamp(e-124,0,6)};
}

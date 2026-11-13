// SPDX-License-Identifier: MIT
export interface Point {x:number;y:number}
export interface Rect {x:number;y:number;width:number;height:number}
export function routeLeader(start:Point,end:Point,rects:Rect[],viewport:{width:number;height:number}):Point[];
export function leaderAnchor(target:Rect,preferred:Point,rects:Rect[],viewport:{width:number;height:number}):Point|null;

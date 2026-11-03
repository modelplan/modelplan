// SPDX-License-Identifier: MIT
// Routing extracted from the owner-released opus-r7 help model.
const inside=(p,r)=>p.x>r.x&&p.x<r.x+r.width&&p.y>r.y&&p.y<r.y+r.height;
export function segmentClear(a,b,rects) {
  return !rects.some(r=>a.x===b.x ? a.x>r.x&&a.x<r.x+r.width&&Math.max(a.y,b.y)>r.y&&Math.min(a.y,b.y)<r.y+r.height
    : a.y>r.y&&a.y<r.y+r.height&&Math.max(a.x,b.x)>r.x&&Math.min(a.x,b.x)<r.x+r.width);
}
// Shortest orthogonal leader through gutters. No fallback is allowed to cross a live reading.
export function routeLeader(start,end,rects,viewport) {
  const xs=[...new Set([start.x,end.x,4,viewport.width-4,...rects.flatMap(r=>[r.x-3,r.x+r.width+3])])].filter(x=>x>=0&&x<=viewport.width).sort((a,b)=>a-b);
  const ys=[...new Set([start.y,end.y,28,viewport.height-4,...rects.flatMap(r=>[r.y-3,r.y+r.height+3])])].filter(y=>y>=26&&y<=viewport.height).sort((a,b)=>a-b);
  const points=ys.flatMap((y,j)=>xs.map((x,i)=>({x,y,i,j}))),valid=points.map(p=>!rects.some(r=>inside(p,r)));
  const index=p=>points.findIndex(q=>q.x===p.x&&q.y===p.y),s=index(start),e=index(end);
  if(s<0||e<0||!valid[s]||!valid[e])return [];
  const cost=new Map([[s,0]]),prev=new Map(),open=[s],done=new Set();
  while(open.length){open.sort((a,b)=>cost.get(b)-cost.get(a));const n=open.pop();if(done.has(n))continue;if(n===e)break;done.add(n);
    const p=points[n],near=[[p.i-1,p.j],[p.i+1,p.j],[p.i,p.j-1],[p.i,p.j+1]].filter(([i,j])=>i>=0&&i<xs.length&&j>=0&&j<ys.length).map(([i,j])=>j*xs.length+i);
    for(const k of near){if(!valid[k]||done.has(k)||!segmentClear(p,points[k],rects))continue;const value=cost.get(n)+Math.abs(p.x-points[k].x)+Math.abs(p.y-points[k].y);
      if(value<(cost.get(k)??Infinity)){cost.set(k,value);prev.set(k,n);open.push(k);}}
  }
  if(!cost.has(e))return [];
  const result=[];for(let n=e;n!=null;n=prev.get(n))result.unshift({x:points[n].x,y:points[n].y});
  return result.filter((p,i)=>!i||i===result.length-1||!((result[i-1].x===p.x&&p.x===result[i+1].x)||(result[i-1].y===p.y&&p.y===result[i+1].y)));
}

export function leaderAnchor(target,preferred,rects,viewport){
 const gap=4,point=(x,y)=>({x,y}),inside=(p,r)=>p.x>r.x-3&&p.x<r.x+r.width+3&&p.y>r.y-3&&p.y<r.y+r.height+3;
 const valid=p=>p.x>=4&&p.x<=viewport.width-4&&p.y>=28&&p.y<=viewport.height-4&&!rects.some(r=>inside(p,r));
 const closest=points=>points.filter(valid).sort((a,b)=>Math.hypot(a.x-preferred.x,a.y-preferred.y)-Math.hypot(b.x-preferred.x,b.y-preferred.y))[0];
 if(valid(preferred))return preferred;
 const x=target.x+target.width/2,y=target.y+target.height/2;
 return closest([point(target.x-gap,y),point(target.x+target.width+gap,y),point(x,target.y-gap),point(x,target.y+target.height+gap)])||
  closest(rects.flatMap(r=>[point(r.x-gap,preferred.y),point(r.x+r.width+gap,preferred.y),point(preferred.x,r.y-gap),point(preferred.x,r.y+r.height+gap)]))||null;
}

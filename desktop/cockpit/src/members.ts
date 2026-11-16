// SPDX-License-Identifier: MIT
import type { WireCockpitData,WireRow,WireAccount } from '../generated/wire.js';

// Verified refs identify one subscription. Fallback identities are session-only:
// a shared row/route is numbered in the CLI's emitted account order.
//
// Build 14c (owner): the cockpit shows exactly the subscriptions the widget shows. The Dock reads only rows whose
// surfaces include "dock" (native DockContentProvider dockRows -> EngineAccountMemberCatalogue); the producer drops
// "dock" from a row that is signed out, unreadable or not permitted (cli/internal/rows/build.go, G3-38 D52/D76), but
// keeps it on the menu and settings surfaces. Those rows are not cockpit members either, so they get no tab, column,
// HUD row or caution. Fallback keys are numbered over the same rows as the native catalogue.
export const dockRows=(data:WireCockpitData):readonly WireRow[]=>data.projection.rows.filter(row=>row.surfaces.includes('dock'));
// D244 (owner 2026-11-13): one saved order for the widget, the cockpit and Settings (Settings › Subscriptions).
// Members the saved order names come first, in that order; the rest keep the emitted order after them — the same
// rule as the native DockSubscriptionPreferences.orderedIDs. A refresh never re-sorts: every paint reads this order.
let savedOrder:readonly string[]=[];
export function memberOrder():readonly string[]{return savedOrder;}
/** Replaces the saved order; returns whether it changed. */
export function setMemberOrder(order:readonly string[]):boolean{
 const seen=new Set<string>(),next=order.filter(key=>!seen.has(key)&&!!seen.add(key));
 if(next.length===savedOrder.length&&next.every((key,i)=>key===savedOrder[i]))return false;
 savedOrder=next;return true;
}
export function cockpitMembers(data:WireCockpitData):{key:string;row:WireRow;account:WireAccount;unstable:boolean}[] {
 const members=emittedMembers(data);if(!savedOrder.length)return members;
 const rank=new Map(savedOrder.map((key,i)=>[key,i] as const));
 return members.map((member,i)=>({member,i,r:rank.get(member.key)??savedOrder.length})).sort((a,b)=>a.r-b.r||a.i-b.i).map(x=>x.member);
}
function emittedMembers(data:WireCockpitData):{key:string;row:WireRow;account:WireAccount;unstable:boolean}[] {
  const verified=new Set(data.subscriptions.map(s=>s.subscriptionRef)),rows=dockRows(data);
  const fallbackCounts=new Map<string,number>();
  for(const row of rows)for(const account of row.accounts){
    if(account.subscriptionRef&&verified.has(account.subscriptionRef))continue;
    const base=`${row.id}#${account.route}`;fallbackCounts.set(base,(fallbackCounts.get(base)??0)+1);
  }
  const positions=new Map<string,number>(),seenVerified=new Set<string>();
  const members:{key:string;row:WireRow;account:WireAccount;unstable:boolean}[]=[];
  for(const row of rows)for(const account of row.accounts){
    const ref=account.subscriptionRef;
    if(ref&&verified.has(ref)){
      if(!seenVerified.has(ref)){seenVerified.add(ref);members.push({key:ref,row,account,unstable:false});}
      continue;
    }
    const base=`${row.id}#${account.route}`,position=(positions.get(base)??0)+1;
    positions.set(base,position);
    const collision=(fallbackCounts.get(base)??0)>1;
    // A row/route key is never proof of account identity, even for one member.
    members.push({key:collision?`${base}#${position}`:base,row,account,unstable:true});
  }
  return members;
}

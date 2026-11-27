// SPDX-License-Identifier: MIT
import type { WireCockpitData,WireRow,WireAccount } from '../generated/wire.js';

// Verified refs identify one subscription. Fallback identities are session-only:
// a shared row/route is numbered in the CLI's emitted account order.
//
// Build 14c (owner): the cockpit shows exactly the subscriptions the widget shows. The Dock reads only rows whose
// surfaces include "dock" (native DockContentProvider dockRows -> EngineAccountMemberCatalogue); the producer decides
// membership even when a reading is unavailable (cli/internal/rows/build.go). Rows without this surface get no tab, column,
// HUD row or caution. Fallback keys are numbered over the same rows as the native catalogue.
export const dockRows=(data:WireCockpitData):readonly WireRow[]=>data.projection.rows.filter(row=>row.surfaces.includes('dock'));
/** The engine's unavailable ZCode station carries only tool membership. */
export function unavailableZCodeMember(row:WireRow,account:WireAccount):boolean{
 return row.id==='zai'&&account.route==='unknown'&&account.valueState==='none'&&!account.subscriptionRef;
}
// D244 (owner 2026-11-13): one saved order for the widget, the cockpit and Settings (Settings › Subscriptions).
// Members the saved order names come first, in that order; the rest keep the emitted order after them — the same
// rule as the native DockSubscriptionPreferences.orderedIDs. A refresh never re-sorts: every paint reads this order.
let savedOrder:readonly string[]=[];
let hiddenMembers:ReadonlySet<string>=new Set();
export function memberOrder():readonly string[]{return savedOrder;}
/** Replaces the saved order; returns whether it changed. */
export function setMemberOrder(order:readonly string[]):boolean{
 const seen=new Set<string>(),next=order.filter(key=>!seen.has(key)&&!!seen.add(key));
 if(next.length===savedOrder.length&&next.every((key,i)=>key===savedOrder[i]))return false;
 savedOrder=next;return true;
}
/** Visibility is a display preference; it never removes sessions from the wire payload. */
export function setHiddenMembers(ids:readonly string[]):boolean {
 const next=new Set(ids),changed=next.size!==hiddenMembers.size||[...next].some(id=>!hiddenMembers.has(id));
 hiddenMembers=next;return changed;
}
// D474 decision 3 (C13, C45): a subscription gets a column only after its first good reading on this Mac. The host keeps
// that memory (seen-subscriptions.json, #1289) and sends `seen {ids}`; until a host has sent it (older app, tests) every
// member shows as before. With it, a member shows when its key is in the set or it has a good reading now (current or
// retained: ok, stale, 失败·2h). A member that was never read lives in Settings and the grey line only.
let seenSubscriptions:ReadonlySet<string>|null=null;
/** Replaces the host's seen set (null: no host memory, today's rule); returns whether it changed. */
export function setSeenSubscriptions(ids:readonly string[]|null):boolean{
 const next=ids===null?null:new Set(ids),prev=seenSubscriptions;
 const changed=next===null||prev===null?next!==prev:next.size!==prev.size||[...next].some(id=>!prev.has(id));
 seenSubscriptions=next;return changed;
}
/** macrevb-1290-6: a privacy clear drops the host's seen set (and everything derived from it: the columns and the grey
 *  lines are recomputed from it on the next paint). A page whose host negotiated `seen` keeps the never-read rule with an
 *  empty set until fresh seen state arrives; a page that never got one keeps today's rule. */
export function forgetSeenSubscriptions():boolean{return seenSubscriptions!==null&&seenSubscriptions.size>0?setSeenSubscriptions([]):false;}
const goodReading=(account:WireAccount)=>account.valueState==='current'||account.valueState==='retained';
/** Whether decision 3 lets this member have a column (and a ring); always true without a host seen set. */
export const seenMember=(member:{key:string;account:WireAccount}):boolean=>seenSubscriptions===null||seenSubscriptions.has(member.key)||goodReading(member.account);
/** Members kept out by decision 3 (never read on this Mac): the alert list still gives them their grey line. */
export function unseenMembers(data:WireCockpitData):{key:string;row:WireRow;account:WireAccount;unstable:boolean}[]{
 return seenSubscriptions===null?[]:emittedMembers(data).filter(m=>!hiddenMembers.has(m.key)&&!seenMember(m));
}
export function hasHiddenMembers(data:WireCockpitData):boolean {
 return emittedMembers(data).some(member=>hiddenMembers.has(member.key));
}
export function cockpitMembers(data:WireCockpitData,includeHidden=false):{key:string;row:WireRow;account:WireAccount;unstable:boolean}[] {
 const members=emittedMembers(data).filter(m=>(includeHidden||!hiddenMembers.has(m.key))&&seenMember(m));if(!savedOrder.length)return members;
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

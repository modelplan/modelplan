// SPDX-License-Identifier: MIT
import type { WireCockpitData,WireRow,WireAccount } from '../generated/wire.js';

// Verified refs identify one subscription. Fallback identities are session-only:
// a shared row/route is numbered in the CLI's emitted account order.
export function cockpitMembers(data:WireCockpitData):{key:string;row:WireRow;account:WireAccount;unstable:boolean}[] {
  const verified=new Set(data.subscriptions.map(s=>s.subscriptionRef));
  const fallbackCounts=new Map<string,number>();
  for(const row of data.projection.rows)for(const account of row.accounts){
    if(account.subscriptionRef&&verified.has(account.subscriptionRef))continue;
    const base=`${row.id}#${account.route}`;fallbackCounts.set(base,(fallbackCounts.get(base)??0)+1);
  }
  const positions=new Map<string,number>(),seenVerified=new Set<string>();
  const members:{key:string;row:WireRow;account:WireAccount;unstable:boolean}[]=[];
  for(const row of data.projection.rows)for(const account of row.accounts){
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

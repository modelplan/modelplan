// SPDX-License-Identifier: MIT
import { readFileSync } from 'node:fs';
export const pageId='00000000-0000-4000-8000-000000000001';
export const sessionId='00000000-0000-4000-8000-000000000002';
export const source={origin:'http://127.0.0.1:41783',isMainFrame:true};
export const capture=()=>JSON.parse(readFileSync(new URL('../../../schema/app-cli/captures/WireCockpitData.json',import.meta.url)));
export function commands() {
  let sequence=0;
  return (type,extra={})=>JSON.stringify({version:1,pageId,sessionId,requestId:`00000000-0000-4000-8000-${String(++sequence).padStart(12,'0')}`,sequence:String(sequence),storeEpoch:'epoch-z',generation:'41',viewRevision:'3',type,...extra});
}
export const appearance={theme:'night',locale:'en',profile:'full'};
export function sample() {
  const value=capture();
  const seed=value.projection.rows[0];
  value.projection.rows=[["codex","Codex"],["claude","Claude Code"],["cursor","Cursor"],["gemini","Gemini CLI"]].map(([id,name],index)=>{const row=structuredClone(seed);row.id=id;row.name={en:name,zh:name};if(index)row.accounts.forEach(a=>{a.subscriptionRef=null;a.accountLocator=null;});return row;});
  // All structure comes from a real Go encoding; only synthetic display labels
  // and a finite reading vary for deterministic, legible visual scenarios.
  value.projection.rows.forEach(row=>{
    row.reason.text={en:'Reading available',zh:'已有读数'};
    row.accounts.forEach(account=>{
      account.plan.name={en:'Synthetic plan',zh:'模拟方案'};
      account.observedAt='2026-10-29T12:00:00Z';
      account.windows.forEach(window=>{window.remainingPercent=75;window.label={en:'Session',zh:'会话'};});
    });
  });
  for(const group of value.subscriptions)for(const member of group.accounts)member.account.plan.name={en:'Synthetic plan',zh:'模拟方案'};
  value.projection.rowsSummary.text={en:'Your available readings',zh:'可用读数'};
  return value;
}

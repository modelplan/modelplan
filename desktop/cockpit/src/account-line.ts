// SPDX-License-Identifier: MIT
// Owner D277 (CKP-ENG-27): the engine table's account label and its quiet "updated" line. Pure, no strings: the caller
// reads the copy from the string tables (study/rocket-r1/strings/host.js).
// Reference: CodexBar (MIT) at 7447bc77: Sources/CodexBar/Menu/MenuCardView.swift (UsageMenuCardHeaderView: account,
// plan and the "Updated" subtitle) and Sources/CodexBarCore/UsageFormatter.swift ("Updated just now" / "Updated 3m ago").
import type {WireAccount} from '../generated/wire.js';

/** The subscription with its plan when the reader knows it ("Codex Pro 200"); the name alone otherwise, or when the
 * plan only repeats the name. */
export function accountLabel(name:string,account:Pick<WireAccount,'plan'>,locale:'en'|'zh-CN'):string {
 const plan=(account.plan.name?(locale==='en'?account.plan.name.en:account.plan.name.zh):'')?.trim()??'';
 return plan&&!name.toLowerCase().includes(plan.toLowerCase())?`${name} ${plan}`:name;
}
/** Which "updated" copy to show: just now under a minute, minutes under an hour, hours under two days, then days. */
export function updatedCopy(at:number,now:number):{key:'host.updatedNow'|'host.updatedMin'|'host.updatedHour'|'host.updatedDay';n:number} {
 const minutes=Math.max(0,Math.floor((now-at)/60000));
 if(minutes<1)return {key:'host.updatedNow',n:0};
 if(minutes<60)return {key:'host.updatedMin',n:minutes};
 const hours=Math.floor(minutes/60);
 return hours<48?{key:'host.updatedHour',n:hours}:{key:'host.updatedDay',n:Math.floor(hours/24)};
}

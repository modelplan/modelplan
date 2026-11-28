// SPDX-License-Identifier: MIT
// Owner D277 (CKP-ENG-27): the engine table's account label and its quiet "updated" line. Pure, no strings: the caller
// reads the copy from the string tables (study/rocket-r1/strings/host.js).
// Reference: CodexBar (MIT) at 7447bc77: Sources/CodexBar/Menu/MenuCardView.swift (UsageMenuCardHeaderView: account,
// plan and the "Updated" subtitle) and Sources/CodexBarCore/UsageFormatter.swift ("Updated just now" / "Updated 3m ago").
import type {WireAccount,WireRow} from '../generated/wire.js';

/** The subscription with its plan when the reader knows it ("Codex Pro 200"); the name alone otherwise, or when the
 * plan only repeats the name. */
export function accountLabel(name:string,account:Pick<WireAccount,'plan'>,locale:'en'|'zh-CN'):string {
 const plan=(account.plan.name?(locale==='en'?account.plan.name.en:account.plan.name.zh):'')?.trim()??'';
 return plan&&!saysWord(name,plan)?`${name} ${plan}`:name;
}
// The name already says the plan only when the plan stands in it as whole words ("Claude Max", not "MaxCompute").
// A letter or digit on either side means another word; CJK has no spaces, so there plain containment stands.
function saysWord(name:string,plan:string):boolean {
 const hay=name.toLowerCase(),needle=plan.toLowerCase(),word=/[\p{L}\p{N}]/u,cjk=/[\p{Script=Han}\p{Script=Hiragana}\p{Script=Katakana}\p{Script=Hangul}]/u;
 const open=(c:string,edge:string)=>!c||!word.test(c)||cjk.test(c)||cjk.test(edge);
 for(let i=hay.indexOf(needle);i>=0;i=hay.indexOf(needle,i+1)){
  const before=hay.slice(0,i).at(-1)??'',after=hay.slice(i+needle.length)[0]??'';
  if(open(before,needle[0]!)&&open(after,needle.at(-1)!))return true;
 }
 return false;
}
const PENDING=new Set(['ok','not_read_yet','reader_busy','estimated']);
/** CKP-ENG-50: the column state a wire account draws. A reader that failed with nothing to show is unreadable; one that
 * has not answered yet (or is busy) is still loading; a reading kept past its freshness is stale (drawn like current). */
export function accountState(account:Pick<WireAccount,'valueState'|'lastFailure'>,rowState?:WireRow['state']):'ok'|'stale'|'loading'|'error' {
 if(account.valueState==='current')return 'ok';
 if(account.valueState==='retained')return 'stale';
 if(rowState==='empty'||rowState==='failed'||rowState==='needs_action')return 'error';
 const code=account.lastFailure?.code;
 return code&&!PENDING.has(code)?'error':'loading';
}
/** CKP-ENG-55: the footer for the readings on screen: the oldest observation, and whether reads keep failing (a reading
 * kept past its freshness whose later reads failed). Only the accounts the table shows count (macrevb-1020-1). */
export function footerState(shown:readonly Pick<WireAccount,'valueState'|'observedAt'|'lastFailure'>[]):{at:number|null;failing:boolean} {
 let at:number|null=null,failing=false;
 for(const a of shown){
  const observed=a.observedAt?Date.parse(a.observedAt):NaN;if(Number.isFinite(observed))at=at===null?observed:Math.min(at,observed);
  const failed=a.lastFailure?Date.parse(a.lastFailure.at):NaN;
  if(a.valueState==='retained'&&Number.isFinite(failed)&&(!Number.isFinite(observed)||failed>observed))failing=true;
 }
 return {at,failing};
}
/** Which "updated" copy to show: just now under a minute, minutes under an hour, hours under two days, then days. */
export function updatedCopy(at:number,now:number):{key:'host.updatedNow'|'host.updatedMin'|'host.updatedHour'|'host.updatedDay';n:number} {
 const minutes=Math.max(0,Math.floor((now-at)/60000));
 if(minutes<1)return {key:'host.updatedNow',n:0};
 if(minutes<60)return {key:'host.updatedMin',n:minutes};
 const hours=Math.floor(minutes/60);
 return hours<48?{key:'host.updatedHour',n:hours}:{key:'host.updatedDay',n:Math.floor(hours/24)};
}
/** D376: the failing form of the overview's update line drops the word "updated": "12 分钟前". */
export function agoKey(key:ReturnType<typeof updatedCopy>['key']):'host.agoNow'|'host.agoMin'|'host.agoHour'|'host.agoDay' {
 return key==='host.updatedNow'?'host.agoNow':key==='host.updatedMin'?'host.agoMin':key==='host.updatedHour'?'host.agoHour':'host.agoDay';
}

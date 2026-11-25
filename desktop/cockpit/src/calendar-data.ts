// SPDX-License-Identifier: MIT
// Calendar plugin data (CKP-PLG-06/07): the object that crosses the plugin seam, its strict bounded parser, and the
// host-side shaping from what the cockpit already receives. Nothing here fetches: peaks are the publication's peak
// windows (cockpitPeaksV1, #739), announced resets are the publication's reset events, banked resets and the user's own
// 5 h / weekly resets come from the local quota readings, all inside the `display` data the native host already sends.
import type {WireCockpitData} from '../generated/wire.js';
import {cockpitMembers} from './members.js';
import {memberColours} from './session-binding.js';
import {currentWindow} from './prototype-data-adapter.js';
import {exact,record} from './schema.js';

export interface CalendarSub {readonly abbr:string;readonly colour:string;readonly name:{readonly en:string;readonly zh:string}}
/** A published peak window; `to` is null when the publication shows no end inside its horizon. */
export interface CalendarPeak {readonly sub:number;readonly from:number;readonly to:number|null;readonly tentative:boolean}
/** One of the user's own quota resets. */
export interface CalendarReset {readonly sub:number;readonly at:number;readonly kind:'5h'|'week'}
/** An all-day item: banked resets usable until `to`, a reset announced at `from` taking effect at `to` (null: no time; it
 *  then sits on the day it was published, as the website's week board does), or `credit`: a banked reset handed out,
 *  placed at `from` (its stated effect time, else its publication) with `to` set only when the source states a time. */
export interface CalendarSpan {readonly sub:number;readonly kind:'cards'|'credit'|'creditConfirmed'|'announced'|'confirmed';readonly from:number;readonly to:number|null;readonly count:number|null}
/** Whether the user has peak rules: `no` is known (the publication's feed is present and the user has no declared plan),
 *  `yes` means a declared plan exists (it may have no window in the next 24 h), `unknown` means the feed is missing. */
export type PeakRules='yes'|'no'|'unknown';
export interface CalendarData {readonly version:1;readonly peakRules:PeakRules;readonly subs:readonly CalendarSub[];readonly peaks:readonly CalendarPeak[];readonly resets:readonly CalendarReset[];readonly spans:readonly CalendarSpan[]}

export const CALENDAR_MAX_BYTES=16*1024;
export const LIMITS={subs:16,peaks:64,resets:64,spans:16} as const;
export const emptyCalendar:CalendarData=Object.freeze({version:1,peakRules:'unknown',subs:[],peaks:[],resets:[],spans:[]});
// Times are epoch milliseconds between 2000 and 2100: anything else is not a calendar time.
const MIN_T=946_684_800_000,MAX_T=4_102_444_800_000;
const time=(v:unknown):v is number=>typeof v==='number'&&Number.isSafeInteger(v)&&v>=MIN_T&&v<=MAX_T;
const text=(v:unknown,max:number):v is string=>typeof v==='string'&&v.length>0&&v.length<=max&&!/[\u0000-\u001f\u007f]/.test(v);
const index=(v:unknown,subs:number):v is number=>typeof v==='number'&&Number.isSafeInteger(v)&&v>=0&&v<subs;
const list=(v:unknown,max:number):v is unknown[]=>Array.isArray(v)&&v.length<=max;
/** Strict structural check for calendar data from the host or the shaping below: exact keys, bounded lists and
 *  strings, known kinds, in-range times and subscription indices. Returns a frozen copy, or null. */
export function parseCalendarData(v:unknown):CalendarData|null {
 // `peakRules` is optional on the wire (a host that does not say leaves it unknown).
 const rules=record(v)&&'peakRules' in v?v.peakRules:'unknown';
 if(rules!=='yes'&&rules!=='no'&&rules!=='unknown')return null;
 if(!exact(v,record(v)&&'peakRules' in v?['version','peakRules','subs','peaks','resets','spans']:['version','subs','peaks','resets','spans'])||v.version!==1||!list(v.subs,LIMITS.subs)||!list(v.peaks,LIMITS.peaks)||!list(v.resets,LIMITS.resets)||!list(v.spans,LIMITS.spans))return null;
 const subs:CalendarSub[]=[];
 for(const s of v.subs){
  if(!exact(s,['abbr','colour','name'])||typeof s.abbr!=='string'||!/^[A-Za-z0-9]{1,3}$/.test(s.abbr)||typeof s.colour!=='string'||!/^#[0-9a-f]{6}$/i.test(s.colour)||!exact(s.name,['en','zh'])||!text(s.name.en,64)||!text(s.name.zh,64))return null;
  subs.push(Object.freeze({abbr:s.abbr,colour:s.colour,name:Object.freeze({en:s.name.en,zh:s.name.zh})}));
 }
 const n=subs.length,peaks:CalendarPeak[]=[],resets:CalendarReset[]=[],spans:CalendarSpan[]=[];
 for(const p of v.peaks){
  if(!exact(p,['sub','from','to','tentative'])||!index(p.sub,n)||!time(p.from)||!(p.to===null||time(p.to)&&p.to>p.from)||typeof p.tentative!=='boolean')return null;
  peaks.push(Object.freeze({sub:p.sub,from:p.from,to:p.to,tentative:p.tentative}));
 }
 for(const r of v.resets){
  if(!exact(r,['sub','at','kind'])||!index(r.sub,n)||!time(r.at)||(r.kind!=='5h'&&r.kind!=='week'))return null;
  resets.push(Object.freeze({sub:r.sub,at:r.at,kind:r.kind}));
 }
 for(const s of v.spans){
  if(!exact(s,['sub','kind','from','to','count'])||!index(s.sub,n)||!['cards','credit','creditConfirmed','announced','confirmed'].includes(s.kind as string)||!time(s.from)||!(s.to===null||time(s.to)&&s.to>=s.from)||!(s.count===null||typeof s.count==='number'&&Number.isSafeInteger(s.count)&&s.count>=0&&s.count<=999))return null;
  spans.push(Object.freeze({sub:s.sub,kind:s.kind as CalendarSpan['kind'],from:s.from,to:s.to,count:s.count}));
 }
 return Object.freeze({version:1,peakRules:rules,subs:Object.freeze(subs),peaks:Object.freeze(peaks),resets:Object.freeze(resets),spans:Object.freeze(spans)});
}

/** D375: the calendar writes subscription names, never codes. A name over 7 characters keeps 6 and an ellipsis. */
export const shortName=(name:string)=>{const chars=[...name];return chars.length>7?chars.slice(0,6).join('')+'…':name;};
// `abbr` is a legacy field of the seam (a host may still send it): nothing draws it. By tool row, then vendor, else from the name.
const ROW_ABBR:Readonly<Record<string,string>>={claude:'CL',codex:'CX',zai:'GL',glm:'GL',cursor:'CU',copilot:'CP',gemini:'GE',grok:'GR',kimi:'KI',qwen:'QW',minimax:'MM',opencodego:'OC',opencode:'OC'};
const VENDOR_ABBR:Readonly<Record<string,string>>={claude:'CL',openai:'CX',glm:'GL',cursor:'CU',copilot:'CP',kimi:'KI',opencode:'OC'};
export function abbreviation(rowId:string,vendorKey:string|null,name:string):string {
 const own=ROW_ABBR[rowId]??(vendorKey?VENDOR_ABBR[vendorKey]:undefined);if(own)return own;
 const letters=name.replace(/[^A-Za-z0-9]/g,'').toUpperCase().slice(0,2);return letters||'XX';
}
/** The publication's peak windows (details.peaks, cockpitPeaksV1). Read structurally: the generated wire type of
 *  this branch's base predates the field, and an older engine omits it (then there are no peaks). */
const peakFeed=(data:WireCockpitData)=>Array.isArray((data.details as {peaks?:unknown}|null|undefined)?.peaks);
function wirePeaks(data:WireCockpitData):{rowId:string;startsAt:string;endsAt:string|null;status:string}[] {
 const raw=(data.details as {peaks?:unknown}|null|undefined)?.peaks;
 if(!Array.isArray(raw))return [];
 return raw.slice(0,32).flatMap(p=>record(p)&&typeof p.rowId==='string'&&typeof p.startsAt==='string'&&(p.endsAt===null||typeof p.endsAt==='string')&&typeof p.status==='string'?[{rowId:p.rowId,startsAt:p.startsAt,endsAt:p.endsAt as string|null,status:p.status}]:[]);
}
const label=(v:string,fallback:string)=>v.replace(/[\u0000-\u001f\u007f]/g,'').slice(0,64)||fallback.slice(0,64);
const ms=(v:string|null|undefined)=>{const t=v?Date.parse(v):NaN;return Number.isFinite(t)?t:null;};
/** When an announced reset takes effect: the middle of its window down to the half hour (never into the next local day), a
 *  date-only schedule at that local day's start, no schedule: unknown. */
function effectiveAt(schedule:{from:string;through:string;precision:string}|undefined):number|null {
 if(!schedule)return null;const from=ms(schedule.from),through=ms(schedule.through);if(from===null)return null;
 if(schedule.precision==='date'){const d=new Date(from);return new Date(d.getFullYear(),d.getMonth(),d.getDate()).getTime();}
 const mid=through===null?from:(from+through)/2;// Floor on the local day's own half-hour grid (a zone like Kathmandu, UTC+5:45, has no UTC-aligned half hours).
 const d=new Date(mid),day0=new Date(d.getFullYear(),d.getMonth(),d.getDate()).getTime();return day0+Math.floor((mid-day0)/1_800_000)*1_800_000;
}
/** Shape the calendar from the cockpit display data at `now`. Only the user's own subscriptions (the engine's members)
 *  appear; a peak, reset event or banked reset of a row the user does not have is left out. */
export function calendarFromCockpit(data:WireCockpitData,now:number):CalendarData {
 const members=cockpitMembers(data).slice(0,LIMITS.subs);
 const colours=memberColours(members);
 const subs:CalendarSub[]=members.map(m=>({abbr:abbreviation(m.row.id,m.row.vendorKey,m.row.name.en),colour:colours.get(m.key)??'#c6ccd4',name:{en:label(m.row.name.en,m.row.id),zh:label(m.row.name.zh,m.row.id)}}));
 const subOfRow=(rowId:string)=>{const i=members.findIndex(m=>m.row.id===rowId);return i<0?null:i;};
 const peaks:CalendarPeak[]=[];
 for(const p of wirePeaks(data)){
  const sub=subOfRow(p.rowId),from=ms(p.startsAt),to=ms(p.endsAt);
  if(sub===null||from===null||to!==null&&(to<=from||to<=now))continue;
  if(peaks.some(x=>x.sub===sub&&x.from===from))continue;
  peaks.push({sub,from,to,tentative:p.status!=='confirmed'});
 }
 // The user's own resets: the next reset of each current 5-hour (session) and weekly window.
 const resets:CalendarReset[]=[];
 members.forEach((m,sub)=>{for(const w of m.account.windows){
  if(w.role!=='session'&&w.role!=='weekly'||w.modelScope||!currentWindow(m.account,w,now))continue;
  const at=ms(w.resetsAt);if(at===null||at<=now)continue;
  const kind=w.role==='session'?'5h':'week';if(!resets.some(r=>r.sub===sub&&r.kind===kind&&r.at===at))resets.push({sub,at,kind});
 }});
 const spans:CalendarSpan[]=[];
 // Reset cards: personal facts, joined only through a verified subscription reference (as the alert list does).
 const verified=new Set(data.subscriptions.map(s=>s.subscriptionRef));
 members.forEach((m,sub)=>{
  if(m.unstable||!verified.has(m.key))return;
  const details=data.details?.subscriptions.filter(s=>s.subscriptionRef===m.key)??[],cards=details.length===1?details[0]!.resetCards:null;
  if(!cards||cards.state==='unknown')return;
  // The producer may list only part of the cards (state partial, truncated, or a count above the items): then there is no
  // exact count and no expiry beyond the one it states itself (macrevc-844-5/6, as the alert list does).
  const items=cards.items??[],partial=cards.truncated||cards.state!=='complete'||cards.count!==null&&cards.count>items.length;
  const live=items.filter(c=>{const t=ms(c.expiresAt);return t===null||t>now;});
  const expiries=live.flatMap(c=>{const t=ms(c.expiresAt);return t!==null?[t]:[];}).sort((a,b)=>a-b);
  // A stated earliest expiry that has passed is not a reason to drop the cards: any listed card still live keeps the
  // span, with no date beyond a stated future one (macrevc-844-8).
  const stated=ms(cards.earliestExpiresAt),statedFuture=stated!==null&&stated>now;
  const to=partial?(statedFuture?stated:null):(expiries[0]??(statedFuture?stated:null));
  if(!live.length&&!statedFuture&&(!partial||stated!==null||cards.count===0))return;
  spans.push({sub,kind:'cards',from:now,to,count:partial?null:live.length});
 });
 // Announced (or confirmed) public resets for the user's rows, still current.
 for(const e of data.details?.resetEvents??[]){
  const sub=subOfRow(e.rowId),published=ms(e.publishedAt),expires=ms(e.expiresAt);
  if(sub===null||published===null||expires===null||expires<=now)continue;
  const at=effectiveAt(e.schedule);
  // A banked reset (+1) is placed where the website puts it: the stated time, else the day it was published.
  if(e.kind==='reset_credit'){spans.push({sub,kind:e.status==='confirmed'?'creditConfirmed':'credit',from:at??published,to:at,count:1});continue;}
  spans.push({sub,kind:e.status==='confirmed'?'confirmed':'announced',from:Math.min(published,now),to:at!==null&&at>=Math.min(published,now)?at:null,count:null});
 }
 const clip=<T,>(xs:T[],n:number)=>xs.slice(0,n);
 const declared=members.some(m=>m.row.id.startsWith('declared:'));
 const peakRules:PeakRules=!peakFeed(data)?'unknown':declared?'yes':'no';
 return {version:1,peakRules,subs,peaks:clip(peaks.sort((a,b)=>a.from-b.from),LIMITS.peaks),resets:clip(resets.sort((a,b)=>a.at-b.at),LIMITS.resets),spans:clip(spans,LIMITS.spans)};
}

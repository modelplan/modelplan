// SPDX-License-Identifier: MIT
// Calendar plugin data (CKP-PLG-06/07): the object that crosses the plugin seam, its strict bounded parser, and the
// host-side shaping from what the cockpit already receives. Nothing here fetches: peaks are the publication's peak
// windows (cockpitPeaksV1, #739), announced resets are the publication's reset events, reset cards and the user's own
// 5 h / weekly resets come from the local quota readings, all inside the `display` data the native host already sends.
import type {WireCockpitData} from '../generated/wire.js';
import {cockpitMembers} from './members.js';
import {memberColour} from './session-binding.js';
import {currentWindow} from './prototype-data-adapter.js';
import {exact,record} from './schema.js';

export interface CalendarSub {readonly abbr:string;readonly colour:string;readonly name:{readonly en:string;readonly zh:string}}
/** A published peak window; `to` is null when the publication shows no end inside its horizon. */
export interface CalendarPeak {readonly sub:number;readonly from:number;readonly to:number|null;readonly tentative:boolean}
/** One of the user's own quota resets. */
export interface CalendarReset {readonly sub:number;readonly at:number;readonly kind:'5h'|'week'}
/** An all-day item: reset cards usable until `to`, or a reset announced at `from` taking effect at `to` (null: no time). */
export interface CalendarSpan {readonly sub:number;readonly kind:'cards'|'announced'|'confirmed';readonly from:number;readonly to:number|null;readonly count:number|null}
export interface CalendarData {readonly version:1;readonly subs:readonly CalendarSub[];readonly peaks:readonly CalendarPeak[];readonly resets:readonly CalendarReset[];readonly spans:readonly CalendarSpan[]}

export const CALENDAR_MAX_BYTES=16*1024;
export const LIMITS={subs:16,peaks:64,resets:64,spans:16} as const;
export const emptyCalendar:CalendarData=Object.freeze({version:1,subs:[],peaks:[],resets:[],spans:[]});
// Times are epoch milliseconds between 2000 and 2100: anything else is not a calendar time.
const MIN_T=946_684_800_000,MAX_T=4_102_444_800_000;
const time=(v:unknown):v is number=>typeof v==='number'&&Number.isSafeInteger(v)&&v>=MIN_T&&v<=MAX_T;
const text=(v:unknown,max:number):v is string=>typeof v==='string'&&v.length>0&&v.length<=max&&!/[\u0000-\u001f\u007f]/.test(v);
const index=(v:unknown,subs:number):v is number=>typeof v==='number'&&Number.isSafeInteger(v)&&v>=0&&v<subs;
const list=(v:unknown,max:number):v is unknown[]=>Array.isArray(v)&&v.length<=max;
/** Strict structural check for calendar data from the host or the shaping below: exact keys, bounded lists and
 *  strings, known kinds, in-range times and subscription indices. Returns a frozen copy, or null. */
export function parseCalendarData(v:unknown):CalendarData|null {
 if(!exact(v,['version','subs','peaks','resets','spans'])||v.version!==1||!list(v.subs,LIMITS.subs)||!list(v.peaks,LIMITS.peaks)||!list(v.resets,LIMITS.resets)||!list(v.spans,LIMITS.spans))return null;
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
  if(!exact(s,['sub','kind','from','to','count'])||!index(s.sub,n)||!['cards','announced','confirmed'].includes(s.kind as string)||!time(s.from)||!(s.to===null||time(s.to)&&s.to>=s.from)||!(s.count===null||typeof s.count==='number'&&Number.isSafeInteger(s.count)&&s.count>=0&&s.count<=999))return null;
  spans.push(Object.freeze({sub:s.sub,kind:s.kind as CalendarSpan['kind'],from:s.from,to:s.to,count:s.count}));
 }
 return Object.freeze({version:1,subs:Object.freeze(subs),peaks:Object.freeze(peaks),resets:Object.freeze(resets),spans:Object.freeze(spans)});
}

// Two-letter tags (mockup legend: CL/CX/GL/CU) by tool row, then by vendor, else from the name.
const ROW_ABBR:Readonly<Record<string,string>>={claude:'CL',codex:'CX',zai:'GL',glm:'GL',cursor:'CU',copilot:'CP',gemini:'GE',grok:'GR',kimi:'KI',qwen:'QW',minimax:'MM',opencodego:'OC',opencode:'OC'};
const VENDOR_ABBR:Readonly<Record<string,string>>={claude:'CL',openai:'CX',glm:'GL',cursor:'CU',copilot:'CP',kimi:'KI',opencode:'OC'};
export function abbreviation(rowId:string,vendorKey:string|null,name:string):string {
 const own=ROW_ABBR[rowId]??(vendorKey?VENDOR_ABBR[vendorKey]:undefined);if(own)return own;
 const letters=name.replace(/[^A-Za-z0-9]/g,'').toUpperCase().slice(0,2);return letters||'XX';
}
/** The publication's peak windows (details.peaks, cockpitPeaksV1). Read structurally: the generated wire type of
 *  this branch's base predates the field, and an older engine omits it (then there are no peaks). */
function wirePeaks(data:WireCockpitData):{rowId:string;startsAt:string;endsAt:string|null;status:string}[] {
 const raw=(data.details as {peaks?:unknown}|null|undefined)?.peaks;
 if(!Array.isArray(raw))return [];
 return raw.slice(0,32).flatMap(p=>record(p)&&typeof p.rowId==='string'&&typeof p.startsAt==='string'&&(p.endsAt===null||typeof p.endsAt==='string')&&typeof p.status==='string'?[{rowId:p.rowId,startsAt:p.startsAt,endsAt:p.endsAt as string|null,status:p.status}]:[]);
}
const label=(v:string,fallback:string)=>v.replace(/[\u0000-\u001f\u007f]/g,'').slice(0,64)||fallback.slice(0,64);
const ms=(v:string|null|undefined)=>{const t=v?Date.parse(v):NaN;return Number.isFinite(t)?t:null;};
/** When an announced reset takes effect: the middle of its window to the half hour (as the alert list places it), a
 *  date-only schedule at that local day's start, no schedule: unknown. */
function effectiveAt(schedule:{from:string;through:string;precision:string}|undefined):number|null {
 if(!schedule)return null;const from=ms(schedule.from),through=ms(schedule.through);if(from===null)return null;
 if(schedule.precision==='date'){const d=new Date(from);return new Date(d.getFullYear(),d.getMonth(),d.getDate()).getTime();}
 const mid=through===null?from:(from+through)/2;return Math.round(mid/1_800_000)*1_800_000;
}
/** Shape the calendar from the cockpit display data at `now`. Only the user's own subscriptions (the engine's members)
 *  appear; a peak, reset event or reset card of a row the user does not have is left out. */
export function calendarFromCockpit(data:WireCockpitData,now:number):CalendarData {
 const members=cockpitMembers(data).slice(0,LIMITS.subs);
 const subs:CalendarSub[]=members.map(m=>({abbr:abbreviation(m.row.id,m.row.vendorKey,m.row.name.en),colour:memberColour(m),name:{en:label(m.row.name.en,m.row.id),zh:label(m.row.name.zh,m.row.id)}}));
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
  const expiries=(cards.items??[]).flatMap(c=>{const t=ms(c.expiresAt);return t!==null&&t>now?[t]:[];}).sort((a,b)=>a-b);
  const to=expiries[0]??ms(cards.earliestExpiresAt);if(to===null||to<=now)return;
  spans.push({sub,kind:'cards',from:now,to,count:expiries.length||cards.count});
 });
 // Announced (or confirmed) public resets for the user's rows, still current.
 for(const e of data.details?.resetEvents??[]){
  const sub=subOfRow(e.rowId),published=ms(e.publishedAt),expires=ms(e.expiresAt);
  if(sub===null||published===null||expires===null||expires<=now)continue;
  const at=effectiveAt(e.schedule);
  spans.push({sub,kind:e.status==='confirmed'?'confirmed':'announced',from:Math.min(published,now),to:at!==null&&at>=Math.min(published,now)?at:null,count:null});
 }
 const clip=<T,>(xs:T[],n:number)=>xs.slice(0,n);
 return {version:1,subs,peaks:clip(peaks.sort((a,b)=>a.from-b.from),LIMITS.peaks),resets:clip(resets.sort((a,b)=>a.at-b.at),LIMITS.resets),spans:clip(spans,LIMITS.spans)};
}

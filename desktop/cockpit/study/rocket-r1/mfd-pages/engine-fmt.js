// SPDX-License-Identifier: MIT
// The engine-only adapter pre-escapes all display strings. Keep the original
// formatter intact for other consumers, and avoid escaping those values twice.
export {dhm,tok,when,hm,relativeMoment,approxCost} from './fmt.js';
import {hm} from './fmt.js';
export const esc=value=>String(value??'');
// D474 §2.1, one time format for the band (and the shared alert sentence, alert-sentence.js alertDuration):
// "4d14h" / "3h09" / "42m", whole minutes first so 119.7 is "2h00", never "1h60"; at least 1m. `narrow`: a countdown of
// ten days or more shows whole days, rounded ("14d23h" → "15d"), so a 91 pt cell keeps 100% beside it.
export function countdown(minutes,{narrow=false}={}){
 if(minutes==null||!Number.isFinite(minutes))return '--';
 const m=Math.max(1,Math.round(minutes));
 if(m<60)return `${m}m`;
 if(m<1440)return `${Math.floor(m/60)}h${String(m%60).padStart(2,'0')}`;
 if(narrow&&m>=14400)return `${Math.round(m/1440)}d`;
 return `${Math.floor(m/1440)}d${Math.floor(m%1440/60)}h`;
}
// How long ago: "28m前" / "1h40前" / "2d3h前" (en "28m ago").
export const ago=(minutes,lang='zh-CN')=>{const t=countdown(Math.max(1,minutes??0));return lang==='en'?`${t} ago`:`${t}前`;};
// Our estimate of a moment, rounded to the half hour, with its approximation word: "17:30 前后" / "around 17:30".
export function estimateAt(ms,{lang='zh-CN'}={}){
 if(ms==null||!Number.isFinite(ms))return '';
 const at=hm(Math.round(ms/1800e3)*1800e3);
 return lang==='en'?`around ${at}`:`${at} 前后`;
}

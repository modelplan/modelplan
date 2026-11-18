// SPDX-License-Identifier: MIT
// Page text for one locale, read from the shared string tables (study/rocket-r1/strings/host.js). It reads the
// table for the locale it is given, so it never depends on which language the last repaint selected.
import {tables} from '../study/rocket-r1/i18n.js';
import '../study/rocket-r1/strings/host.js';

export type HostLocale='en'|'zh-CN';
export function ht(locale:string,key:string,vars?:Readonly<Record<string,string|number>>):string{
 const entry=(locale==='en'?tables.en:tables['zh-CN'])[key]??tables.en[key];
 if(typeof entry!=='string')return key;
 return vars?entry.replace(/\{(\w+)\}/g,(m,n:string)=>String(vars[n]??m)):entry;
}

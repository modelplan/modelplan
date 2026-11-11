export function setLanguage(locale:'en'|'zh-CN'):void;
export function t(key:string,vars?:Record<string,unknown>):string;
export function formatCredits(value:number|null,locale:'en'|'zh-CN'):string;
export const tables:Readonly<Record<'en'|'zh-CN',Readonly<Record<string,string|Readonly<Record<string,string>>>>>>;

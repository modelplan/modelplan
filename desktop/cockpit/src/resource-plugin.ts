// SPDX-License-Identifier: MIT
// The resource plugin (owner D324, D327): CPU, memory and disk of this Mac, in the plugin framework's column and big
// screen. The page never samples. The app's ResourceSampler (desktop/native/ModelPlanResources, system calls only, no
// child processes) reads the Mac while this column runs and pushes `pluginData` readings of the shape below; the plugin
// keeps the last ten minutes in memory (never stored) and describes the cells.
//
// D327 rules drawn here: lists read CPU · 内存 · 磁盘; the plugin colour is orchid; only the numbers turn amber or red
// (CPU from 70 % / 90 %, memory by macOS memory pressure, not by percentage, disk from 90 %), bars keep the plugin ink.
// The widget ring, its readout switch and the hover card are native (ModelPlanResources ResourceReadout / ResourceCard).
//
// Interim (until the D323 custom-draw hook, modelplan#1092, is on main): the big screen is drawn as framework lines.
// The charts (memory 10-minute stacked area + pressure strip, CPU 10-second bars with a 70 % line, disk bar with a
// 90 % notch) switch to `draw(ctx)` once the hook lands.
//
// No import of plugin-registry values: the registry imports this module for builtinPlugins (type imports are erased).
import type {CockpitPlugin,PluginCell,PluginColumn,PluginContext,PluginScreen,PluginWords} from './plugin-registry.js';

export const RESOURCE_INK='#da66c2';
/** The page keeps what the host's ring buffer keeps: ten minutes. */
export const RESOURCE_WINDOW_MS=10*60*1000;
const MAX_PER_READING=120,MAX_KEPT=720,TREND_POINTS=30;
export type ResourcePressure='normal'|'warn'|'critical';
/** One host sample (ModelPlanResources ResourcePagePayload): percentages 0–100, sizes in bytes, `t` in Unix ms. */
export interface ResourceSample {
  readonly t:number;readonly cpuUser:number;readonly cpuSystem:number;readonly load:number;
  readonly memTotal:number;readonly memApp:number;readonly memWired:number;readonly memCompressed:number;readonly memCached:number;readonly memFree:number;
  readonly swapUsed:number;readonly pressure:ResourcePressure;readonly diskTotal:number;readonly diskFree:number;
}
export interface ResourceState {readonly samples:readonly ResourceSample[]}
const KEYS=['t','cpuUser','cpuSystem','load','memTotal','memApp','memWired','memCompressed','memCached','memFree','swapUsed','pressure','diskTotal','diskFree'] as const;
const BYTES=['memTotal','memApp','memWired','memCompressed','memCached','memFree','swapUsed','diskTotal','diskFree'] as const;
const PRESSURES:readonly string[]=['normal','warn','critical'];
const percent=(v:unknown)=>typeof v==='number'&&Number.isFinite(v)&&v>=0&&v<=100;
const bytes=(v:unknown)=>typeof v==='number'&&Number.isSafeInteger(v)&&v>=0;
function parseSample(raw:unknown):ResourceSample|null {
  if(raw===null||typeof raw!=='object'||Array.isArray(raw))return null;
  const o=raw as Record<string,unknown>,keys=Object.keys(o);
  if(keys.length!==KEYS.length||!KEYS.every(k=>k in o))return null;
  if(typeof o.t!=='number'||!Number.isSafeInteger(o.t)||o.t<=0)return null;
  if(!percent(o.cpuUser)||!percent(o.cpuSystem)||(o.cpuUser as number)+(o.cpuSystem as number)>100.5)return null;
  if(typeof o.load!=='number'||!Number.isFinite(o.load)||o.load<0||o.load>4096)return null;
  if(!BYTES.every(k=>bytes(o[k]))||(o.memTotal as number)<=0||(o.diskTotal as number)<=0)return null;
  const s=o as unknown as ResourceSample;
  if(s.memApp+s.memWired+s.memCompressed+s.memCached>s.memTotal*1.05||s.diskFree>s.diskTotal)return null;
  if(!PRESSURES.includes(o.pressure as string))return null;
  const copy:Record<string,unknown>={};for(const k of KEYS)copy[k]=o[k];
  return Object.freeze(copy) as unknown as ResourceSample;
}
/** Derived values of one sample. */
export interface ResourceView {readonly cpu:number;readonly memory:number;readonly memoryUsed:number;readonly cached:number;readonly disk:number;readonly pressure:ResourcePressure}
export function resourceView(s:ResourceSample):ResourceView {
  const used=s.memApp+s.memWired+s.memCompressed;
  return {cpu:Math.min(100,s.cpuUser+s.cpuSystem),memory:Math.min(100,used/s.memTotal*100),memoryUsed:used,cached:Math.min(100,s.memCached/s.memTotal*100),
    disk:(s.diskTotal-s.diskFree)/s.diskTotal*100,pressure:s.pressure};
}
export type ResourceLevel='mid'|'low'|null;
/** D327: only the numbers change colour. CPU amber ≥ 70 %, red ≥ 90 %; memory by macOS pressure; disk amber ≥ 90 %. */
export function resourceLevels(v:{readonly cpu:number;readonly pressure:ResourcePressure;readonly disk:number}):{cpu:ResourceLevel;memory:ResourceLevel;disk:ResourceLevel} {
  return {cpu:v.cpu>=90?'low':v.cpu>=70?'mid':null,memory:v.pressure==='critical'?'low':v.pressure==='warn'?'mid':null,disk:v.disk>=90?'mid':null};
}
const GB=1024**3;
/** One decimal below 100 GB, whole numbers above; a whole number drops its ".0" (32 GB, 15.1 GB). */
export function gb(value:number):string {const g=value/GB,r=g>=100?Math.round(g):Math.round(g*10)/10;return String(r);}
const pct=(v:number)=>Math.round(v);
const statesOf=(state:unknown):readonly ResourceSample[]=>state&&typeof state==='object'&&Array.isArray((state as ResourceState).samples)?(state as ResourceState).samples:[];
const latest=(state:unknown)=>{const s=statesOf(state);return s.length?s[s.length-1]:null;};
const pressureWords=(c:PluginContext,s:ResourceSample):PluginWords=>{
  const name=c.words(s.pressure==='critical'?'plugin.resourcesPressureCritical':s.pressure==='warn'?'plugin.resourcesPressureWarn':'plugin.resourcesPressureNormal');
  if(s.swapUsed<GB/10)return name;
  const swap=c.words('plugin.resourcesSwap',{gb:gb(s.swapUsed)});
  return {full:`${name.full} · ${swap.full}`,short:name.short};
};
const peak=(samples:readonly ResourceSample[])=>samples.reduce((m,s)=>Math.max(m,resourceView(s).cpu),0);
export const resourcePlugin:CockpitPlugin=Object.freeze({
  id:'resources',
  title:'plugin.resourcesTitle',
  summary:'plugin.resourcesSummary',
  // White line art in the shared 16 px frame (plugin-registry PLUGIN_ICON_FRAME): a rounded screen with a heartbeat line.
  icon:'<svg viewBox="0 0 16 16" aria-hidden="true"><rect x="1" y="1.5" width="14" height="13" rx="3" fill="none" stroke="currentColor" stroke-width="1.3"/><path d="M3.5 8.5h2l1.3-3 2 5 1.2-2h2.5" fill="none" stroke="currentColor" stroke-width="1.3" stroke-linejoin="round" stroke-linecap="round"/></svg>',
  underline:RESOURCE_INK,
  ink:RESOURCE_INK,
  defaultEnabled:true,
  hostSampled:true,
  // D324: the column samples every 2, 5 or 10 s while it is shown (the host snaps other saved values to these).
  settings:Object.freeze([Object.freeze({key:'intervalSeconds',kind:'seconds' as const,min:2,max:10,default:5})]),
  accept(data:unknown,previous:unknown){
    if(data===null||typeof data!=='object'||Array.isArray(data)||Object.keys(data).length!==1)return undefined;
    const raw=(data as {samples?:unknown}).samples;
    if(!Array.isArray(raw)||raw.length<1||raw.length>MAX_PER_READING)return undefined;
    const incoming:ResourceSample[]=[];
    for(const r of raw){const s=parseSample(r);if(!s)return undefined;incoming.push(s);}
    const byTime=new Map<number,ResourceSample>();
    for(const s of [...statesOf(previous),...incoming])byTime.set(s.t,s);
    const sorted=[...byTime.values()].sort((a,b)=>a.t-b.t),newest=sorted[sorted.length-1].t;
    const kept=sorted.filter(s=>s.t>newest-RESOURCE_WINDOW_MS).slice(-MAX_KEPT);
    return Object.freeze({samples:Object.freeze(kept)}) as ResourceState;
  },
  column(state:unknown,c:PluginContext):PluginColumn{
    const samples=statesOf(state),s=latest(state);
    const tags=[c.words('plugin.resourcesCpu'),c.words('plugin.resourcesMemory'),c.words('plugin.resourcesDisk')];
    const foot={label:c.words('plugin.resourcesPressure'),value:s?pressureWords(c,s):null};
    if(!s)return {cells:tags.map(tag=>({tag,value:null,bar:null})),foot};
    const v=resourceView(s),lv=resourceLevels(v),recent=samples.slice(-TREND_POINTS).map(resourceView);
    const cells:PluginCell[]=[
      {tag:tags[0],value:pct(v.cpu),unit:'%',side:c.words('plugin.resourcesPeak',{n:pct(peak(samples))}),bar:v.cpu/100,trend:recent.map(x=>x.cpu/100),level:lv.cpu},
      {tag:tags[1],value:pct(v.memory),unit:'%',side:c.words('plugin.resourcesGb',{used:gb(v.memoryUsed),total:gb(s.memTotal)}),bar:v.memory/100,trend:recent.map(x=>x.memory/100),level:lv.memory},
      {tag:tags[2],value:pct(v.disk),unit:'%',side:c.words('plugin.resourcesFree',{gb:gb(s.diskFree)}),bar:v.disk/100,level:lv.disk},
    ];
    return {cells,foot};
  },
  screen(state:unknown,c:PluginContext):PluginScreen{
    const s=latest(state),w=(key:string,vars?:Readonly<Record<string,string|number>>)=>c.words(key,vars).full;
    const every={label:w('plugin.resourcesSampling'),value:w('plugin.resourcesEvery',{n:c.settings.intervalSeconds})};
    if(!s)return {lines:[every]};
    const v=resourceView(s),samples=statesOf(state),unit=(text:string)=>`${text} GB`;
    return {lines:[
      {label:w('plugin.resourcesCpu'),value:`${pct(v.cpu)}%`},
      {label:w('plugin.resourcesUserSystem'),value:`${pct(s.cpuUser)}% · ${pct(s.cpuSystem)}%`},
      {label:w('plugin.resourcesLoad'),value:String(Math.round(s.load*10)/10)},
      {label:w('plugin.resourcesPeak10'),value:`${pct(peak(samples))}%`},
      {label:w('plugin.resourcesMemory'),value:`${pct(v.memory)}% · ${w('plugin.resourcesGb',{used:gb(v.memoryUsed),total:gb(s.memTotal)})}`},
      {label:w('plugin.resourcesPressure'),value:pressureWords(c,s).full},
      {label:w('plugin.resourcesKinds'),value:unit([s.memWired,s.memApp,s.memCompressed].map(gb).join(' · '))},
      {label:w('plugin.resourcesCachedFree'),value:unit([s.memCached,s.memFree].map(gb).join(' · '))},
      {label:w('plugin.resourcesDisk'),value:`${pct(v.disk)}% · ${w('plugin.resourcesFree',{gb:gb(s.diskFree)})}`},
      every,
    ]};
  },
});

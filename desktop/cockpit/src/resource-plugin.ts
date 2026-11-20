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
// The big screen paints its charts through the D323 draw hook (modelplan#1092): memory 10-minute stacked area (used /
// cached) with a pressure strip, CPU 10-second bars (user / system) with a 70 % dashed line, disk bar with a 90 % notch.
// The label/value lines stay as the fallback when a draw fails.
//
// No import of plugin-registry values: the registry imports this module for builtinPlugins (type imports are erased).
import type {CockpitPlugin,PluginCell,PluginColumn,PluginContext,PluginDrawContext,PluginScreen,PluginWords} from './plugin-registry.js';

export const RESOURCE_INK='#da66c2';
/** The page keeps what the host's ring buffer keeps: ten minutes. */
export const RESOURCE_WINDOW_MS=10*60*1000;
// MAX_PER_READING = ModelPlanResources ResourcePageFeed.maximumPerReading (ten minutes at 2 s is 300 samples).
const MAX_PER_READING=360,MAX_KEPT=720,TREND_POINTS=30;
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
/** Chart data (pure, unit-tested): memory fractions per sample, a 60-cell pressure strip and 60 CPU bars of 10 s each
 *  (oldest first, the cell/bar holding the newest sample last), the disk used percentage and the two thresholds. */
export interface ChartData {
  readonly memory:readonly {readonly t:number;readonly used:number;readonly cached:number}[];
  readonly strip:readonly ResourcePressure[];
  readonly cpu:readonly {readonly user:number;readonly system:number}[];
  readonly disk:number;readonly cpuLine:number;readonly diskNotch:number;
}
const BINS=60,BIN_MS=10_000,RANK:Record<ResourcePressure,number>={normal:0,warn:1,critical:2};
export function chartData(samples:readonly ResourceSample[]):ChartData {
  const base={cpuLine:70,diskNotch:90};
  if(!samples.length)return {memory:[],strip:[],cpu:[],disk:0,...base};
  const newest=samples[samples.length-1]!;
  const memory=samples.map(s=>({t:s.t,used:(s.memApp+s.memWired+s.memCompressed)/s.memTotal,cached:Math.min(1-(s.memApp+s.memWired+s.memCompressed)/s.memTotal,s.memCached/s.memTotal)}));
  const strip:ResourcePressure[]=Array<ResourcePressure>(BINS).fill('normal'),sums=Array.from({length:BINS},()=>({user:0,system:0,n:0}));
  for(const s of samples){
    const age=Math.floor((newest.t-s.t)/BIN_MS);if(age>=BINS)continue;const i=BINS-1-age;
    if(RANK[s.pressure]>RANK[strip[i]!])strip[i]=s.pressure;
    sums[i]!.user+=s.cpuUser;sums[i]!.system+=s.cpuSystem;sums[i]!.n++;
  }
  const cpu=sums.map(b=>b.n?{user:b.user/b.n,system:b.system/b.n}:{user:0,system:0});
  return {memory,strip,cpu,disk:(newest.diskTotal-newest.diskFree)/newest.diskTotal*100,...base};
}
const SVG='http://www.w3.org/2000/svg';
/** Paints the charts into the host's clipped area with SVG, cockpit tokens and the orchid ink. */
function drawCharts(c:PluginDrawContext,state:unknown):void {
  const samples=statesOf(state);if(!samples.length||c.width<=0||c.height<=0)return;
  const d=chartData(samples),doc=c.area.ownerDocument,W=Math.max(1,c.width),H=Math.max(1,c.height);
  const node=(tag:string,attrs:Record<string,string|number>,parent?:Element)=>{const e=doc.createElementNS(SVG,tag);for(const [k,v] of Object.entries(attrs))e.setAttribute(k,String(v));parent?.append(e);return e;};
  const svg=node('svg',{class:'pl-draw-chart',width:W,height:H,viewBox:`0 0 ${W} ${H}`,role:'img','aria-label':c.words('plugin.resourcesTitle').full});
  const T=c.tokens,pad=6,gap=8,innerW=W-2*pad,fs=Math.max(8,Math.min(11,H/16));
  const label=(text:string,x:number,y:number,anchor='start')=>{const t=node('text',{x,y,fill:T.muted,'font-size':fs,'font-family':T.lcdFont,'text-anchor':anchor},svg);t.textContent=text;};
  // Order CPU · Memory · Disk (D347, same as the column). Heights come from one budget so the three sections always fit
  // inside the area: every section is label row + body + gap, and the bodies share what is left.
  const lab=fs+3,stripH=Math.max(3,Math.min(6,H*0.04)),diskH=Math.max(5,Math.min(10,H*0.05)),fixed=pad*2+3*lab+2*gap+stripH+gap+diskH+4;
  const free=Math.max(12,H-fixed),cpuH=free*0.4,memH=free*0.6;
  let y=pad;
  // CPU: one bar per 10 s, user (ink) under system (lighter), with the 70 % dashed line.
  label(c.words('plugin.resourcesCpu').full,pad,y+fs);y+=lab;
  const cw=innerW/60,cTop=y,cBot=y+cpuH,cy=(v:number)=>cBot-Math.min(100,v)/100*(cBot-cTop);
  const cpu=node('g',{'data-chart':'cpu'},svg);
  d.cpu.forEach((b,i)=>{const g=node('g',{'data-bar':i,'data-user':b.user.toFixed(1),'data-system':b.system.toFixed(1)},cpu);
    node('rect',{x:(pad+i*cw).toFixed(2),y:cy(b.user).toFixed(2),width:Math.max(0.5,cw-0.5).toFixed(2),height:(cBot-cy(b.user)).toFixed(2),fill:RESOURCE_INK},g);
    node('rect',{x:(pad+i*cw).toFixed(2),y:cy(b.user+b.system).toFixed(2),width:Math.max(0.5,cw-0.5).toFixed(2),height:(cy(b.user)-cy(b.user+b.system)).toFixed(2),fill:RESOURCE_INK,'fill-opacity':0.45},g);});
  node('line',{'data-chart':'cpu-line',x1:pad,x2:W-pad,y1:cy(d.cpuLine),y2:cy(d.cpuLine),stroke:T.mid,'stroke-dasharray':'3 3','stroke-width':1},svg);
  y=cBot+gap;
  // Memory: stacked area (used, then cached on top) over the ten minutes, with the pressure strip under it.
  label(c.words('plugin.resourcesMemory').full,pad,y+fs);y+=lab;
  const mTop=y,mBot=y+memH,last=d.memory[d.memory.length-1]!,span=RESOURCE_WINDOW_MS,t0=last.t-span;
  const X=(t:number)=>pad+Math.max(0,t-t0)/span*innerW,Y=(f:number)=>mBot-Math.min(1,Math.max(0,f))*(mBot-mTop);
  const edge=(f:(p:ChartData['memory'][number])=>number)=>d.memory.map(p=>`${X(p.t).toFixed(1)},${Y(f(p)).toFixed(1)}`);
  const area=(top:string[],bottom:string[])=>`M${top.join('L')}L${bottom.slice().reverse().join('L')}Z`;
  const floor=d.memory.map(p=>`${X(p.t).toFixed(1)},${mBot.toFixed(1)}`),usedEdge=edge(p=>p.used),stackEdge=edge(p=>p.used+p.cached);
  node('path',{'data-chart':'memory-cached',d:area(stackEdge,usedEdge),fill:T.ink,'fill-opacity':0.18},svg);
  node('path',{'data-chart':'memory-used',d:area(usedEdge,floor),fill:RESOURCE_INK,'fill-opacity':0.85},svg);
  y=mBot+3;
  const strip=node('g',{'data-chart':'pressure'},svg);
  d.strip.forEach((p,i)=>node('rect',{x:(pad+i*cw).toFixed(2),y,width:Math.max(0.5,cw-0.5).toFixed(2),height:stripH,fill:p==='critical'?T.low:p==='warn'?T.mid:T.ghost,'data-pressure':p},strip));
  y+=stripH+gap;
  // Disk: one bar with the 90 % notch.
  label(c.words('plugin.resourcesDisk').full,pad,y+fs);y+=lab;
  node('rect',{x:pad,y,width:innerW,height:diskH,fill:T.ghost},svg);
  node('rect',{'data-chart':'disk',x:pad,y,width:(innerW*d.disk/100).toFixed(2),height:diskH,fill:RESOURCE_INK},svg);
  node('line',{'data-chart':'disk-notch',x1:pad+innerW*d.diskNotch/100,x2:pad+innerW*d.diskNotch/100,y1:y-1,y2:y+diskH+1,stroke:T.mid,'stroke-width':1.5},svg);
  c.area.replaceChildren(svg);
}
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
  settings:Object.freeze([Object.freeze({key:'intervalSeconds',kind:'seconds' as const,min:2,max:10,default:5,choices:Object.freeze([2,5,10])})]),
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
    return {draw:(ctx:PluginDrawContext)=>drawCharts(ctx,state),lines:[
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

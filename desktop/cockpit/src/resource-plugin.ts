// SPDX-License-Identifier: MIT
// The resource plugin (owner D324, D327): CPU, memory and disk of this Mac, in the plugin framework's column and big
// screen. The page never samples. The app's ResourceSampler (desktop/native/ModelPlanResources, system calls only, no
// child processes) reads the Mac while this column runs and pushes `pluginData` readings of the shape below; the plugin
// keeps the last ten minutes in memory (never stored) and describes the cells.
//
// D327 rules drawn here: lists read CPU · 内存 · 磁盘; the plugin colour is orchid (the key underline). D371 B4c: the cell
// bars and numbers take the status colour (normal / amber from 80 % / red from 90 %, 3 % hysteresis), as the quota rings.
// The widget ring, its readout switch and the hover card are native (ModelPlanResources ResourceReadout / ResourceCard).
//
// D407 (owner 11-24, option R1): the column paints the half-circle radar through the D323 draw hook (drawRadar below).
// D413 (option B): the big screen is a four-card history grid (drawGrid). The cells and the label/value lines stay as the
// fallback when a draw fails.
//
// No import of plugin-registry values needed: plugin-builtins.ts lists this plugin (type imports are erased).
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
  /** D407: network bytes per second in and out (all interfaces but loopback), always as a pair; absent when the host has
   *  no rate yet (its first read) or cannot read it. */
  readonly netIn?:number;readonly netOut?:number;
}
/** D413: one host minute (ModelPlanResources ResourceMinute): the mean and the raw peak of every reading in it. */
export interface ResourceMinute {
  readonly t:number;readonly cpu:number;readonly cpuPeak:number;readonly memory:number;readonly memoryPeak:number;readonly disk:number;readonly diskPeak:number;
  readonly netIn?:number;readonly netInPeak?:number;readonly netOut?:number;readonly netOutPeak?:number;
}
export interface ResourceState {readonly samples:readonly ResourceSample[];readonly minutes?:readonly ResourceMinute[]}
const KEYS=['t','cpuUser','cpuSystem','load','memTotal','memApp','memWired','memCompressed','memCached','memFree','swapUsed','pressure','diskTotal','diskFree'] as const;
const BYTES=['memTotal','memApp','memWired','memCompressed','memCached','memFree','swapUsed','diskTotal','diskFree'] as const;
const NET=['netIn','netOut'] as const;
const rate=(v:unknown)=>typeof v==='number'&&Number.isSafeInteger(v)&&v>=0&&v<=1e12;
const MINUTE_KEYS=['t','cpu','cpuPeak','memory','memoryPeak','disk','diskPeak'] as const,MINUTE_NET=['netIn','netInPeak','netOut','netOutPeak'] as const;
const MINUTE_MS=60_000,HOUR_MS=60*MINUTE_MS;
function parseMinute(raw:unknown):ResourceMinute|null {
  if(raw===null||typeof raw!=='object'||Array.isArray(raw))return null;
  const o=raw as Record<string,unknown>,keys=Object.keys(o),net='netIn' in o;
  if(keys.length!==MINUTE_KEYS.length+(net?MINUTE_NET.length:0)||!MINUTE_KEYS.every(k=>k in o)||net&&!MINUTE_NET.every(k=>k in o&&rate(o[k])))return null;
  if(typeof o.t!=='number'||!Number.isSafeInteger(o.t)||o.t<=0||o.t%MINUTE_MS!==0)return null;
  if(!['cpu','cpuPeak','memory','memoryPeak','disk','diskPeak'].every(k=>percent(o[k])))return null;
  const copy:Record<string,unknown>={};for(const k of net?[...MINUTE_KEYS,...MINUTE_NET]:MINUTE_KEYS)copy[k]=o[k];
  return Object.freeze(copy) as unknown as ResourceMinute;
}
const PRESSURES:readonly string[]=['normal','warn','critical'];
const percent=(v:unknown)=>typeof v==='number'&&Number.isFinite(v)&&v>=0&&v<=100;
const bytes=(v:unknown)=>typeof v==='number'&&Number.isSafeInteger(v)&&v>=0;
function parseSample(raw:unknown):ResourceSample|null {
  if(raw===null||typeof raw!=='object'||Array.isArray(raw))return null;
  const o=raw as Record<string,unknown>,keys=Object.keys(o),net='netIn' in o||'netOut' in o;
  if(keys.length!==KEYS.length+(net?NET.length:0)||!KEYS.every(k=>k in o)||net&&!NET.every(k=>k in o&&rate(o[k])))return null;
  if(typeof o.t!=='number'||!Number.isSafeInteger(o.t)||o.t<=0)return null;
  if(!percent(o.cpuUser)||!percent(o.cpuSystem)||(o.cpuUser as number)+(o.cpuSystem as number)>100.5)return null;
  if(typeof o.load!=='number'||!Number.isFinite(o.load)||o.load<0||o.load>4096)return null;
  if(!BYTES.every(k=>bytes(o[k]))||(o.memTotal as number)<=0||(o.diskTotal as number)<=0)return null;
  const s=o as unknown as ResourceSample;
  if(s.memApp+s.memWired+s.memCompressed+s.memCached>s.memTotal*1.05||s.diskFree>s.diskTotal)return null;
  if(!PRESSURES.includes(o.pressure as string))return null;
  const copy:Record<string,unknown>={};for(const k of net?[...KEYS,...NET]:KEYS)copy[k]=o[k];
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
/** D371 B4c (11-13 round-4 status colour, same family as the quota rings): one rule for CPU, memory and disk. Amber from
 *  80 %, red from 90 %; a level is left only once the value is 3 points below its threshold (no flicker at the border).
 *  Memory is also at least amber under warn pressure and red under critical pressure. */
export const LEVEL_AMBER=80,LEVEL_RED=90,LEVEL_HYSTERESIS=3;
export type ResourceLevels={cpu:ResourceLevel;memory:ResourceLevel;disk:ResourceLevel};
export function levelStep(percent:number,previous:ResourceLevel=null):ResourceLevel {
  const red=previous==='low'?LEVEL_RED-LEVEL_HYSTERESIS:LEVEL_RED,amber=previous?LEVEL_AMBER-LEVEL_HYSTERESIS:LEVEL_AMBER;
  return percent>=red?'low':percent>=amber?'mid':null;
}
const worse=(a:ResourceLevel,b:ResourceLevel):ResourceLevel=>a==='low'||b==='low'?'low':a==='mid'||b==='mid'?'mid':null;
export function resourceLevels(v:{readonly cpu:number;readonly pressure:ResourcePressure;readonly disk:number;readonly memory?:number},previous?:ResourceLevels):ResourceLevels {
  const pressure:ResourceLevel=v.pressure==='critical'?'low':v.pressure==='warn'?'mid':null;
  return {cpu:levelStep(v.cpu,previous?.cpu),memory:worse(levelStep(v.memory??0,previous?.memory),pressure),disk:levelStep(v.disk,previous?.disk)};
}
/** The levels after the newest sample, walking the kept history so the hysteresis has its memory. */
export function levelsOf(samples:readonly ResourceSample[]):ResourceLevels {
  let levels:ResourceLevels|undefined;
  for(const s of samples)levels=resourceLevels(resourceView(s),levels);
  return levels??{cpu:null,memory:null,disk:null};
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
// ---- D407 R1 (owner 11-24): the half-circle radar, in the column and on the big screen.
// Three concentric half arcs, outer to inner CPU · memory · disk (D347 order), in the status colour of their level. Each
// arc drops a leader line from its left foot to its own row below the radar: the name under the line, the number, the
// detail, and a history sparkline when there is history. The arcs are the bars, so the rows draw none. Network has no
// 100 % so it is never an arc: one text row at the bottom. Radar details (owner): faint range rings, ticks every 10 %,
// bearing spokes, an amber/red tick at 80/90 %, and a static sweep glow. D397: nothing moves at idle; the host draws
// again only on a reading, a repaint or a size change, and this code starts no frame loop or timer.
const SVG='http://www.w3.org/2000/svg';
type Arc='cpu'|'memory'|'disk';
const ARCS:readonly Arc[]=['cpu','memory','disk'];
/** Bytes per second as the radar's network row prints it: 999B, 86K, 1.2M, 2.5G. */
export function formatRate(bps:number):string {
  const one=(v:number)=>{const r=Math.round(v*10)/10;return r>=10?String(Math.round(v)):String(r);};
  return bps>=1e9?one(bps/1e9)+'G':bps>=1e6?one(bps/1e6)+'M':bps>=1e3?Math.round(bps/1e3)+'K':Math.round(bps)+'B';
}
const networkWords=(s:ResourceSample)=>s.netIn===undefined||s.netOut===undefined?null:`↓${formatRate(s.netIn)} ↑${formatRate(s.netOut)}`;
/** Geometry of the radar in a `width`×`height` area (pure, unit-tested). The rows share every pixel between the radar and
 *  the network row, so the area has no empty band below. A row is one text line with an inline sparkline; with room to
 *  spare the sparkline moves under the line (`block`), and the big screen (`detail`) adds a detail line when it fits. */
export interface RadarLayout {
  readonly cx:number;readonly cy:number;readonly scale:number;readonly r:readonly [number,number,number];readonly bw:number;
  readonly fs:number;readonly vfs:number;readonly rows:readonly number[];readonly rowH:number;readonly line:number;readonly netY:number;readonly pad:number;
  readonly detail:boolean;readonly block:boolean;
}
export function radarLayout(width:number,height:number,detail:boolean):RadarLayout {
  const W=Math.max(60,width),H=Math.max(80,height),pad=detail?8:4,fs=detail?11:10,vfs=detail?17:14,netH=fs+8,line=Math.ceil(vfs*1.4);
  const fit=(extra:number)=>Math.max(18,Math.min(W/2-pad-5,H-pad-6-4-3*(line+extra)-netH,detail?140:1e9));
  const widthCap=Math.min(W/2-pad-5,detail?140:1e9);
  // The detail line is kept only when the radar still gets most of its width-limited size with it.
  const withDetail=detail&&fit(fs+3)>=Math.min(widthCap,H*0.36);
  const scale=fit(withDetail?fs+3:0);
  const cx=W/2,cy=pad+6+scale,bw=Math.max(4,Math.min(detail?14:11,scale*0.13)),gap=Math.max(3,bw*0.6);
  const r1=scale-3-bw/2,r:[number,number,number]=[r1,r1-bw-gap,r1-2*(bw+gap)];
  const top=cy+4,netY=H-pad-1,rowH=(netY-fs-5-top)/3;
  const block=rowH-line-(withDetail?fs+3:0)>=16;
  return {cx,cy,scale,r,bw,fs,vfs,pad,rowH,line,netY,detail:withDetail,block,rows:[0,1,2].map(i=>top+i*rowH)};
}
const polar=(cx:number,cy:number,r:number,v:number)=>{const a=Math.PI-Math.min(100,Math.max(0,v))/100*Math.PI;return [cx+r*Math.cos(a),cy-r*Math.sin(a)] as const;};
const arcPath=(cx:number,cy:number,r:number,v:number)=>{const [x,y]=polar(cx,cy,r,v);return `M${(cx-r).toFixed(2)},${cy.toFixed(2)}A${r.toFixed(2)},${r.toFixed(2)} 0 0 1 ${x.toFixed(2)},${y.toFixed(2)}`;};
/** Paints the R1 radar into the host's clipped area with cockpit tokens (column and big screen). */
function drawRadar(c:PluginDrawContext,state:unknown,detail:boolean):void {
  const samples=statesOf(state),last=samples[samples.length-1];if(!last||c.width<=0||c.height<=0)return;
  const doc=c.area.ownerDocument,T=c.tokens,W=Math.max(1,c.width),H=Math.max(1,c.height),L=radarLayout(W,H,detail);
  const node=(tag:string,attrs:Record<string,string|number>,parent?:Element)=>{const e=doc.createElementNS(SVG,tag);for(const [k,v] of Object.entries(attrs))e.setAttribute(k,String(v));parent?.append(e);return e;};
  const w=(key:string,vars?:Readonly<Record<string,string|number>>)=>c.words(key,vars);
  const v=resourceView(last),lv=levelsOf(samples),value:Record<Arc,number>={cpu:v.cpu,memory:v.memory,disk:v.disk};
  const tone=(l:ResourceLevel)=>l==='low'?T.low:l==='mid'?T.mid:T.ok;
  const tags:Record<Arc,PluginWords>={cpu:w('plugin.resourcesCpu'),memory:w('plugin.resourcesMemory'),disk:w('plugin.resourcesDisk')};
  const net=networkWords(last),netName=w('plugin.resourcesNetwork').full;// the svg's label always has the full words
  const svg=node('svg',{class:'pl-draw-chart pl-radar',width:W,height:H,viewBox:`0 0 ${W} ${H}`,role:'img',
    'aria-label':[...ARCS.map(a=>`${tags[a].full} ${pct(value[a])}%`),...(net?[`${netName} ${net}`]:[])].join(' · ')});
  const {cx,cy,scale,r,bw,fs,vfs,pad}=L,f=(n:number)=>n.toFixed(2);
  // Range rings and bearing spokes inside the innermost arc, faint.
  const inner=r[2]-bw/2-2;
  for(const k of [0.36,0.7])if(inner*k>4)node('path',{'data-ring':'',d:arcPath(cx,cy,inner*k,100),fill:'none',stroke:T.muted,'stroke-opacity':0.35,'stroke-width':0.7,'stroke-dasharray':'2 3'},svg);
  for(const b of [25,50,75]){const [x0,y0]=polar(cx,cy,inner*0.2,b),[x1,y1]=polar(cx,cy,scale,b);
    node('line',{'data-bearing':b,x1:f(x0),y1:f(y0),x2:f(x1),y2:f(y1),stroke:T.muted,'stroke-opacity':0.22,'stroke-width':0.7},svg);}
  // The static sweep glow: a faint wedge trailing a faint line (never animated, D397).
  const sweep=node('g',{'data-sweep':''},svg);
  for(const [from,op] of [[46,0.03],[52,0.05],[57,0.08]] as const){const [ax,ay]=polar(cx,cy,scale,from),[bx,by]=polar(cx,cy,scale,62);
    node('path',{d:`M${f(cx)},${f(cy)}L${f(ax)},${f(ay)}A${f(scale)},${f(scale)} 0 0 1 ${f(bx)},${f(by)}Z`,fill:T.ok,'fill-opacity':op},sweep);}
  {const [x,y]=polar(cx,cy,scale,62);node('line',{x1:f(cx),y1:f(cy),x2:f(x),y2:f(y),stroke:T.ok,'stroke-opacity':0.35,'stroke-width':0.8},sweep);}
  // The arcs: a ghost track and the value in its status colour.
  ARCS.forEach((a,i)=>{
    node('path',{'data-track':a,d:arcPath(cx,cy,r[i]!,100),fill:'none',stroke:T.rule,'stroke-width':f(bw)},svg);
    node('path',{'data-arc':a,'data-value':pct(value[a]),d:arcPath(cx,cy,r[i]!,Math.max(0.5,value[a])),fill:'none',stroke:tone(lv[a]),'stroke-width':f(bw),'stroke-opacity':value[a]>0?1:0},svg);
  });
  // The scale: thin outer arc, a tick every 10 % (longer at 0 / 50 / 100), amber and red ticks at 80 and 90 %.
  node('path',{d:arcPath(cx,cy,scale,100),fill:'none',stroke:T.muted,'stroke-opacity':0.6,'stroke-width':0.7},svg);
  for(let t=0;t<=100;t+=10){const len=t%50===0?5:3,[x0,y0]=polar(cx,cy,scale,t),[x1,y1]=polar(cx,cy,scale+len,t);
    node('line',{'data-tick':t,x1:f(x0),y1:f(y0),x2:f(x1),y2:f(y1),stroke:T.muted,'stroke-opacity':0.7,'stroke-width':0.8},svg);}
  for(const [t,ink] of [[LEVEL_AMBER,T.mid],[LEVEL_RED,T.low]] as const){const [x0,y0]=polar(cx,cy,scale,t),[x1,y1]=polar(cx,cy,scale+4.5,t);
    node('line',{'data-threshold':t,x1:f(x0),y1:f(y0),x2:f(x1),y2:f(y1),stroke:ink,'stroke-width':1.4},svg);}
  node('line',{x1:pad,x2:W-pad,y1:f(cy),y2:f(cy),stroke:T.muted,'stroke-opacity':0.5,'stroke-width':0.8},svg);
  const s=Math.max(4,Math.min(9,scale*0.08));
  node('path',{d:`M${f(cx)},${f(cy-s*1.9)}L${f(cx+s)},${f(cy-1)}L${f(cx)},${f(cy-s*0.55)}L${f(cx-s)},${f(cy-1)}Z`,fill:'none',stroke:T.mid,'stroke-width':1.2,'stroke-linejoin':'round'},svg);
  // The rows: leader from each arc's left foot down to its name; number, side value, detail and sparkline.
  // Full-width (CJK) glyphs are about one em; Latin and digits in the LCD face about 0.62 em.
  const width=textWidth;
  const side:Record<Arc,PluginWords>={cpu:w('plugin.resourcesPeak',{n:pct(peak(samples))}),memory:w('plugin.resourcesGb',{used:gb(v.memoryUsed),total:gb(last.memTotal)}),disk:w('plugin.resourcesFree',{gb:gb(last.diskFree)})};
  const details:Record<Arc,string>={
    cpu:`${w('plugin.resourcesUserSystem').full} ${pct(last.cpuUser)}% · ${pct(last.cpuSystem)}% · ${w('plugin.resourcesLoad').full} ${Math.round(last.load*10)/10}`,
    memory:`${w('plugin.resourcesKinds').full} ${[last.memWired,last.memApp,last.memCompressed].map(gb).join(' · ')} · ${w('plugin.resourcesCachedFree').full} ${[last.memCached,last.memFree].map(gb).join(' · ')} GB`,
    disk:`${pct(v.disk)}% · ${gb(last.diskTotal)} GB`};
  const xv=cx-r[2]+Math.max(bw/2+6,width(tags.disk.short,fs)/2+6),right=W-pad,recent=samples.slice(-60),spacing=bw+Math.max(3,bw*0.6);
  ARCS.forEach((a,i)=>{
    const foot=cx-r[i]!,top=L.rows[i]!,base=top+(L.block?L.line-3:L.rowH/2+vfs*0.35),ink=tone(lv[a]);
    node('line',{'data-leader':a,x1:f(foot),x2:f(foot),y1:f(cy+1),y2:f(base-fs-1),stroke:ink,'stroke-width':1.4},svg);
    // The name sits centred under its leader; the short form when the long one would cross the next leader or the number.
    const row=node('g',{'data-row':a},svg),roomL=i<2?spacing-2:xv-foot-2,tag=width(tags[a].full,fs)/2<=roomL?tags[a].full:tags[a].short;
    node('text',{'data-label':'',x:f(foot),y:f(base),'text-anchor':'middle','font-size':fs,'font-family':T.silkFont,fill:T.ink},row).textContent=tag;
    const num=node('text',{'data-num':'',x:f(xv),y:f(base),'font-size':vfs,'font-family':T.lcdFont,fill:ink},row);num.textContent=String(pct(value[a]));
    node('tspan',{'font-size':f(vfs*0.6)},num).textContent='%';
    const after=xv+width(`${pct(value[a])}`,vfs)+width('%',vfs*0.6)+6,free=right-after;
    // An inline sparkline needs at least 22 px. For CPU and memory it comes first: the side value gives way to its short
    // form, then to nothing. Disk barely moves in ten minutes, so there its free space comes first and the line takes
    // what is left.
    const inline=!L.block&&recent.length>=2,need=inline?28:0,fitsW=(t:string,room:number)=>width(t,fs)<=room;
    const said=fitsW(side[a].full,free-need)?side[a].full:fitsW(side[a].short,free-need)?side[a].short:a==='disk'&&fitsW(side[a].short,free)?side[a].short:'';
    if(said)node('text',{'data-side':'',x:f(right),y:f(base),'text-anchor':'end','font-size':fs,'font-family':T.lcdFont,fill:T.muted},row).textContent=said;
    let sx=xv,sr=right,sy=base+4,sh=Math.min(60,top+L.rowH-sy-3);
    if(L.detail){const room=right-xv,t=node('text',{'data-detail':'',x:f(xv),y:f(base+fs+2),'font-size':fs-1,'font-family':T.lcdFont,fill:T.muted},row);t.textContent=details[a];
      if(width(details[a],fs-1)>room){t.setAttribute('textLength',f(room));t.setAttribute('lengthAdjust','spacingAndGlyphs');}sy=base+fs+6;sh=Math.min(60,top+L.rowH-sy-3);}
    if(!L.block){sx=after;sr=right-(said?width(said,fs)+6:0);sh=Math.min(vfs*0.8,L.rowH-6);sy=base-sh;}
    if(recent.length>=2&&sh>=4&&sr-sx>=22){
      const pts=recent.map((p,j)=>{const pv=resourceView(p)[a];return `${f(sx+j/(recent.length-1)*(sr-sx))},${f(sy+sh-Math.min(100,pv)/100*sh)}`;});
      node('line',{x1:f(sx),x2:f(sr),y1:f(sy+sh),y2:f(sy+sh),stroke:T.muted,'stroke-opacity':0.3,'stroke-width':0.6},row);
      node('path',{'data-spark':a,d:`M${pts.join('L')}`,fill:'none',stroke:ink,'stroke-opacity':0.8,'stroke-width':1,'stroke-linejoin':'round'},row);
    }
  });
  // Network: text only (no 100 %, so no arc). On the big screen (no bottom line) the pressure shares the row.
  node('line',{x1:pad,x2:W-pad,y1:f(L.netY-fs-4),y2:f(L.netY-fs-4),stroke:T.muted,'stroke-opacity':0.3,'stroke-width':0.6},svg);
  if(detail){const p=node('g',{'data-row':'pressure'},svg);node('text',{x:pad,y:f(L.netY),'font-size':fs,'font-family':T.lcdFont,fill:T.muted},p).textContent=`${w('plugin.resourcesPressure').full} `;
    node('tspan',{fill:T.ink},p.lastChild as Element).textContent=pressureWords(c,last).full;}
  // The name gives way to its short form, then the upload rate, when the row is narrow.
  const n=node('g',{'data-row':'network'},svg),netWords=w('plugin.resourcesNetwork'),left=detail?right-W/2:pad;
  const fits=(name:string,rate:string)=>width(name,fs)+6+width(rate,fs)<=right-left;
  const down=net?`↓${formatRate(last.netIn!)}`:'',pick=!net?[netWords.full,'']:fits(netWords.full,net)?[netWords.full,net]:fits(netWords.short,net)?[netWords.short,net]:[netWords.short,down];
  node('text',{x:detail?f(right-(pick[1]?width(pick[1],fs)+6:0)):pad,y:f(L.netY),'text-anchor':detail?'end':'start','font-size':fs,'font-family':T.lcdFont,fill:T.muted},n).textContent=pick[0]!;
  if(pick[1])node('text',{'data-net':'',x:f(right),y:f(L.netY),'text-anchor':'end','font-size':fs,'font-family':T.lcdFont,fill:T.ink},n).textContent=pick[1];
  c.area.replaceChildren(svg);
}
// ---- D413 (owner 11-24, option B): the big screen is a four-card grid, CPU · memory · disk · network. Each card: a status
// lamp and the name, the big current value, a 峰/均 pair, a detail line, and a white thin-line history (amber above 80 %,
// red above 90 %, a dotted average, a hollow peak dot, a bright "now" dot) in the effort page's type and grid. Radar
// details stay static (range lines, bearing dots, 80/90 ticks, a still sweep at "now"). The centre bottom key picks
// 10 min (the raw readings) or 1 h (one point a minute, its peak from the raw readings). Nothing animates (D397).
export type ResourceRange='10m'|'1h';
export type ResourceMetric='cpu'|'memory'|'disk'|'netIn'|'netOut';
export interface SeriesPoint {readonly t:number;readonly v:number;readonly peak:number}
export interface ResourceSeries {
  readonly range:ResourceRange;readonly start:number;readonly end:number;
  readonly points:Readonly<Record<ResourceMetric,readonly SeriesPoint[]>>;
  readonly peak:Readonly<Record<ResourceMetric,number|null>>;readonly avg:Readonly<Record<ResourceMetric,number|null>>;
}
const METRICS:readonly ResourceMetric[]=['cpu','memory','disk','netIn','netOut'];
const sampleValue=(s:ResourceSample,m:ResourceMetric):number|null=>{const v=resourceView(s);return m==='netIn'?s.netIn??null:m==='netOut'?s.netOut??null:v[m];};
/** The screen's series (pure, unit-tested). 10 min: every raw reading. 1 h: one point a minute: the host's folds, and
 *  for minutes the host has not folded yet (the current one, or a host that sends none) the page's own readings. */
export function resourceSeries(state:unknown,range:ResourceRange):ResourceSeries {
  const samples=statesOf(state),end=samples.length?samples[samples.length-1]!.t:0,span=range==='1h'?HOUR_MS:RESOURCE_WINDOW_MS,start=end-span;
  const points={} as Record<ResourceMetric,SeriesPoint[]>;for(const m of METRICS)points[m]=[];
  if(range==='10m'){for(const s of samples){if(s.t<=start)continue;for(const m of METRICS){const v=sampleValue(s,m);if(v!==null)points[m].push({t:s.t,v,peak:v});}}}
  else{
    const host=new Map<number,ResourceMinute>();for(const x of (state as ResourceState|undefined)?.minutes??[])if(x.t>start-MINUTE_MS)host.set(x.t,x);
    const own=new Map<number,ResourceSample[]>();for(const s of samples){const k=Math.floor(s.t/MINUTE_MS)*MINUTE_MS;if(host.has(k))continue;let l=own.get(k);if(!l){l=[];own.set(k,l);}l.push(s);}
    const keys=[...new Set([...host.keys(),...own.keys()])].sort((a,b)=>a-b);
    for(const k of keys){
      const h=host.get(k);
      if(h){const net:Record<string,[number|undefined,number|undefined]>={netIn:[h.netIn,h.netInPeak],netOut:[h.netOut,h.netOutPeak]};
        for(const m of METRICS){const [v,p]=m==='cpu'?[h.cpu,h.cpuPeak]:m==='memory'?[h.memory,h.memoryPeak]:m==='disk'?[h.disk,h.diskPeak]:net[m]!;
          if(v!==undefined&&p!==undefined)points[m].push({t:k+MINUTE_MS/2,v,peak:p});}continue;}
      const list=own.get(k)!;
      for(const m of METRICS){const vs=list.map(x=>sampleValue(x,m)).filter((x):x is number=>x!==null);if(vs.length)points[m].push({t:k+MINUTE_MS/2,v:vs.reduce((a,b)=>a+b,0)/vs.length,peak:Math.max(...vs)});}
    }
    // A minute that overlaps the window counts (its start may be before the window's): 60 closed minutes + the open one.
    for(const m of METRICS)points[m]=points[m].filter(p=>p.t+MINUTE_MS/2>start);
  }
  const peakOf={} as Record<ResourceMetric,number|null>,avgOf={} as Record<ResourceMetric,number|null>;
  for(const m of METRICS){const p=points[m];peakOf[m]=p.length?Math.max(...p.map(x=>x.peak)):null;avgOf[m]=p.length?p.reduce((a,x)=>a+x.v,0)/p.length:null;}
  return {range,start,end,points,peak:peakOf,avg:avgOf};
}
const rangeToggle=(c:PluginContext,range:ResourceRange)=>({key:'range',value:range,options:[{value:'10m',label:c.words('plugin.resourcesRange10')},{value:'1h',label:c.words('plugin.resourcesRange60')}]});
/** Bytes per second as the network card's big number: value and unit apart. */
function rateParts(bps:number):[string,string] {
  if(bps>=1e9)return [String(Math.round(bps/1e8)/10),'GB/s'];if(bps>=1e6)return [String(Math.round(bps/1e5)/10),'MB/s'];
  if(bps>=1e3)return [String(Math.round(bps/1e3)),'KB/s'];return [String(Math.round(bps)),'B/s'];
}
let gridIds=0;
/** Full-width (CJK) glyphs are about one em; Latin and digits in the LCD face about 0.62 em. */
const textWidth=(text:string,size:number)=>[...text].reduce((n,ch)=>n+(/[\u2e80-\uffef]/.test(ch)?1:0.62),0)*size;
/** Paints the D413 four-card grid into the screen's clipped area (drawn at its measured size; 362 × 213 in the app). */
function drawGrid(c:PluginDrawContext,state:unknown,range:ResourceRange):void {
  const samples=statesOf(state),last=samples[samples.length-1];if(!last||c.width<=0||c.height<=0)return;
  const doc=c.area.ownerDocument,T=c.tokens,W=Math.max(1,c.width),H=Math.max(1,c.height),f=(n:number)=>n.toFixed(1),id=`rg${++gridIds}-`;
  const node=(tag:string,attrs:Record<string,string|number>,parent?:Element)=>{const e=doc.createElementNS(SVG,tag);for(const [k,v] of Object.entries(attrs))e.setAttribute(k,String(v));parent?.append(e);return e;};
  const w=(key:string,vars?:Readonly<Record<string,string|number>>)=>c.words(key,vars).full;
  const MUTED='#87939e',DETAIL='#6f7a85',TICK='#5d6873',INK='#e9edf0',GLASS='#04070c',font=T.lcdFont;
  const series=resourceSeries(state,range),v=resourceView(last),lv=levelsOf(samples);
  const tone=(l:ResourceLevel)=>l==='low'?T.low:l==='mid'?T.mid:T.ok,figure=(l:ResourceLevel)=>l==='low'?T.low:l==='mid'?T.mid:INK;
  const rangeWord=w(range==='1h'?'plugin.resourcesLast60':'plugin.resourcesLast10');
  const svg=node('svg',{class:'pl-draw-chart pl-grid',width:W,height:H,viewBox:`0 0 ${W} ${H}`,role:'img','data-range':range,
    'aria-label':`${w('plugin.resourcesTitle')} · ${rangeWord} · ${w('plugin.resourcesCpu')} ${pct(v.cpu)}% · ${w('plugin.resourcesMemory')} ${pct(v.memory)}% · ${w('plugin.resourcesDisk')} ${pct(v.disk)}%`});
  const text=(x:number,y:number,size:number,fill:string,content:string,attrs:Record<string,string|number>={},parent:Element=svg)=>{const t=node('text',{x:f(x),y:f(y),'font-size':size,'font-family':font,fill,...attrs},parent);t.textContent=content;return t;};
  const span=(parent:Element,content:string,attrs:Record<string,string|number>)=>{node('tspan',attrs,parent).textContent=content;};
  // Top line: "资源 · 最近 10 分钟" left; memory pressure and load right (values in ink).
  const headEl=text(8,17,11,INK,w('plugin.resourcesHead',{range:rangeWord}),{'data-head':''});
  // The right side gives way before it meets the title: full words and load, then without the load, then the short
  // words, then the value alone (EN \"Mem pressure Elevated · Load 1.2\" does not fit beside \"Resources · last 10 min\" at 362 px).
  const pw=pressureWords(c,last),headRoom=W-16-textWidth(headEl.textContent??'',11)-8;
  const loadText=String(Math.round(last.load*100)/100),pLabel=c.words('plugin.resourcesPressure');
  const sides:[string,string,string][]=[[`${pLabel.full} `,pw.full,` · ${w('plugin.resourcesLoad')} ${loadText}`],[`${pLabel.full} `,pw.full,''],[`${pLabel.short} `,pw.short,''],['',pw.short,'']];
  const [sl,sv,sx]=sides.find(([a,b,x])=>textWidth(a+b+x,10)<=headRoom)??sides[sides.length-1]!;
  const right=text(W-8,17,10,MUTED,sl,{'text-anchor':'end'});
  span(right,sv,{fill:INK});if(sx){const k=sx.indexOf(loadText);span(right,sx.slice(0,k),{});span(right,loadText,{fill:INK});}
  const gap=7,cw=Math.floor((W-16-gap)/2),top=25.5,ch=Math.max(40,Math.floor((H-top-23.5-6)/2));
  const netName=w('plugin.resourcesNetwork'),netLast=last.netIn!==undefined&&last.netOut!==undefined;
  type Card={metric:ResourceMetric;name:string;lamp:string;big:[string,string];colour:string;detail:string;pv:[string,string]|null;percent:boolean};
  const pctText=(n:number|null)=>n===null?'':`${Math.round(n)}%`,rateText=(n:number|null)=>n===null?'':formatRate(n);
  const [netBig,netUnit]=netLast?rateParts(last.netIn!):['',''];
  const cards:Card[]=[
    {metric:'cpu',name:w('plugin.resourcesCpu'),lamp:tone(lv.cpu),big:[String(pct(v.cpu)),'%'],colour:figure(lv.cpu),detail:w('plugin.resourcesUserSys',{u:pct(last.cpuUser),s:pct(last.cpuSystem)}),pv:[pctText(series.peak.cpu),pctText(series.avg.cpu)],percent:true},
    {metric:'memory',name:w('plugin.resourcesMemory'),lamp:tone(lv.memory),big:[String(pct(v.memory)),'%'],colour:figure(lv.memory),detail:c.words('plugin.resourcesGb',{used:gb(v.memoryUsed),total:gb(last.memTotal)}).short,pv:[pctText(series.peak.memory),pctText(series.avg.memory)],percent:true},
    {metric:'disk',name:w('plugin.resourcesDisk'),lamp:tone(lv.disk),big:[String(pct(v.disk)),'%'],colour:figure(lv.disk),detail:c.words('plugin.resourcesFree',{gb:gb(last.diskFree)}).short,pv:[pctText(series.peak.disk),pctText(series.avg.disk)],percent:true},
    {metric:'netIn',name:`${netName} ↓`,lamp:T.ok,big:[netBig,netUnit],colour:INK,detail:netLast?`↑ ${rateParts(last.netOut!).join(' ')}`:'',pv:netLast?[rateText(series.peak.netIn),rateText(series.avg.netIn)]:null,percent:false},
  ];
  const ticks=range==='1h'?{n:12,major:6,labels:[w('plugin.resourcesAgo',{n:60}),'−30',w('plugin.resourcesNow')]}:{n:10,major:5,labels:[w('plugin.resourcesAgo',{n:10}),'−5',w('plugin.resourcesNow')]};
  cards.forEach((card,i)=>{
    const x0=8.5+(i%2)*(cw+gap),y0=top+Math.floor(i/2)*(ch+6),g=node('g',{'data-card':card.metric==='netIn'?'network':card.metric},svg);
    node('rect',{x:f(x0),y:f(y0),width:cw,height:ch,rx:3,fill:'#ffffff','fill-opacity':0.018,stroke:'#ffffff12'},g);
    node('rect',{'data-lamp':'',x:f(x0+6.5),y:f(y0+5.5),width:2,height:7,rx:0.6,fill:card.lamp},g);
    text(x0+12.5,y0+12.5,9,MUTED,card.name,{'data-name':''},g);
    if(card.detail)text(x0+cw-6.5,y0+12.5,9,DETAIL,card.detail,{'text-anchor':'end','data-detail':''},g);
    if(card.big[0]){const big=text(x0+6.5,y0+32.5,16,card.colour,card.big[0],{'font-weight':600,'data-value':''},g);span(big,card.big[1],{'font-size':9,'font-weight':400,fill:MUTED,dx:1});}
    if(card.pv){const pv=text(x0+cw-6.5,y0+31.5,10,INK,'',{'text-anchor':'end','data-pv':''},g);span(pv,`${w('plugin.resourcesPk')} `,{'font-size':9,fill:MUTED});span(pv,card.pv[0],{});span(pv,`${w('plugin.resourcesAvg')} `,{'font-size':9,fill:MUTED,dx:6});span(pv,card.pv[1],{});}
    // The chart: x by time over the range, y 0–100 % (network: 0 to the range's peak).
    const cx0=x0+6.5,cx1=x0+cw-10.5,cy0=y0+38.5,cy1=y0+ch-7.5,hgt=cy1-cy0;
    const pts=series.points[card.metric],max=card.percent?100:Math.max(1,series.peak.netIn??0,series.peak.netOut??0);
    const X=(t:number)=>cx0+Math.max(0,Math.min(1,(t-series.start)/Math.max(1,series.end-series.start)))*(cx1-cx0),Y=(val:number)=>cy1-Math.min(1,Math.max(0,val/max))*hgt;
    node('line',{x1:f(cx0),x2:f(cx1),y1:f(cy1+0.5),y2:f(cy1+0.5),stroke:INK,'stroke-opacity':0.14},g);
    for(const [k,op] of [[0.5,0.07],[1,0.045]] as const)node('line',{'data-ring':'',x1:f(cx0),x2:f(cx1),y1:f(cy1-k*hgt),y2:f(cy1-k*hgt),stroke:'#ffffff','stroke-opacity':op,'stroke-dasharray':'2 3'},g);
    for(let k=1;k<5;k++){const x=cx0+k/5*(cx1-cx0);node('line',{'data-bearing':'',x1:f(x),x2:f(x),y1:f(cy0),y2:f(cy1),stroke:'#ffffff','stroke-opacity':0.05,'stroke-dasharray':'1 3'},g);}
    const defs=node('defs',{},g),gid=id+i;
    const grad=(name:string,x2:number,y2:number,stops:[number,number][])=>{const l=node('linearGradient',{id:gid+name,x1:0,y1:0,x2,y2},defs);for(const [o,op] of stops)node('stop',{offset:o,'stop-color':INK,'stop-opacity':op},l);};
    grad('a',0,1,[[0,0.16],[1,0.015]]);grad('s',1,0,[[0,0],[1,0.07]]);
    const noNet=card.metric==='netIn'&&!netLast;
    if(!noNet)node('rect',{'data-sweep':'',x:f(cx1-22),y:f(cy0-1),width:22,height:f(hgt+1),fill:`url(#${gid}s)`},g);
    node('line',{x1:f(cx1+0.5),x2:f(cx1+0.5),y1:f(cy0-1),y2:f(cy1),stroke:INK,'stroke-opacity':0.2},g);
    if(noNet){text((cx0+cx1)/2,(cy0+cy1)/2+3,9,DETAIL,w('plugin.resourcesNoNet'),{'text-anchor':'middle','data-empty':''},g);}
    else if(pts.length){
      const line=pts.map(p=>`${f(X(p.t))},${f(Y(p.v))}`).join(' L'),area=`M${line} L${f(X(pts[pts.length-1]!.t))},${f(cy1)} L${f(X(pts[0]!.t))},${f(cy1)} Z`;
      const clip=(name:string,y:number,h:number)=>{const cp=node('clipPath',{id:gid+name},defs);node('rect',{x:f(cx0-2),y:f(y),width:f(cx1-cx0+4),height:f(Math.max(0,h))},cp);return `url(#${gid+name})`;};
      node('path',{d:area,fill:`url(#${gid}a)`},g);
      const d=`M${line}`;
      if(card.percent){
        const y80=Y(LEVEL_AMBER),y90=Y(LEVEL_RED),cw80=clip('w',y80,cy1+3-y80),ca=clip('m',y90,y80-y90),cr=clip('r',cy0-6,y90-cy0+6);
        const ga=node('g',{'clip-path':ca},g),gr=node('g',{'clip-path':cr},g);
        node('path',{d:area,fill:T.mid,'fill-opacity':0.22},ga);node('path',{d:area,fill:T.low,'fill-opacity':0.2},gr);
        node('path',{'data-line':'',d,fill:'none',stroke:INK,'stroke-opacity':0.88,'stroke-width':1.2,'stroke-linejoin':'round','clip-path':cw80},g);
        node('path',{'data-line-mid':'',d,fill:'none',stroke:T.mid,'stroke-width':1.3,'stroke-linejoin':'round','clip-path':ca},g);
        node('path',{'data-line-low':'',d,fill:'none',stroke:T.low,'stroke-width':1.3,'stroke-linejoin':'round','clip-path':cr},g);
      }else{
        node('path',{'data-line':'',d,fill:'none',stroke:INK,'stroke-opacity':0.88,'stroke-width':1.2,'stroke-linejoin':'round'},g);
        const up=series.points.netOut;if(up.length)node('path',{'data-line-up':'',d:`M${up.map(p=>`${f(X(p.t))},${f(Y(p.v))}`).join(' L')}`,fill:'none',stroke:INK,'stroke-opacity':0.6,'stroke-width':1,'stroke-dasharray':'1 2'},g);
      }
      const avg=series.avg[card.metric];if(avg!==null)node('line',{'data-avg':'',x1:f(cx0),x2:f(cx1),y1:f(Y(avg)),y2:f(Y(avg)),stroke:MUTED,'stroke-width':1,'stroke-dasharray':'.1 2.6','stroke-linecap':'round'},g);
      const hi=pts.reduce((a,p)=>p.peak>a.peak?p:a,pts[0]!);
      node('circle',{'data-peak':'',cx:f(X(hi.t)),cy:f(Y(hi.peak)),r:2,fill:GLASS,stroke:INK,'stroke-opacity':0.85,'stroke-width':1},g);
      const now=pts[pts.length-1]!,nowInk=card.percent&&now.v>=LEVEL_RED?T.low:card.percent&&now.v>=LEVEL_AMBER?T.mid:INK;
      node('circle',{cx:f(X(now.t)),cy:f(Y(now.v)),r:4.5,fill:nowInk,'fill-opacity':0.14},g);
      node('circle',{'data-now':'',cx:f(X(now.t)),cy:f(Y(now.v)),r:2.1,fill:nowInk,stroke:GLASS,'stroke-width':1},g);
    }
    // The scale at the right edge: 0 / 50 / 100, and the amber and red ticks at 80 / 90 % (percent cards only).
    for(const k of [0,0.5,1])node('line',{x1:f(cx1+1.5),x2:f(cx1+4.5),y1:f(cy1-k*hgt),y2:f(cy1-k*hgt),stroke:INK,'stroke-opacity':0.25},g);
    if(card.percent)for(const [t,ink] of [[LEVEL_AMBER,T.mid],[LEVEL_RED,T.low]] as const)node('line',{'data-threshold':t,x1:f(cx1+1.5),x2:f(cx1+4.5),y1:f(Y(t)),y2:f(Y(t)),stroke:ink,'stroke-opacity':0.7},g);
    // The time axis under the bottom row: a short tick each minute (1 h: each 5 minutes), a long one each 5 (30).
    if(i>=2){for(let k=0;k<=ticks.n;k++){const x=cx0+k/ticks.n*(cx1-cx0),major=k%ticks.major===0;node('line',{'data-tick':'',x1:f(x),x2:f(x),y1:f(cy1+1),y2:f(cy1+(major?4:2.5)),stroke:INK,'stroke-opacity':major?0.35:0.2},g);}
      const ly=y0+ch+11.5;text(cx0,ly,8,TICK,ticks.labels[0]!,{},g);text((cx0+cx1)/2,ly,8,TICK,ticks.labels[1]!,{'text-anchor':'middle'},g);text(cx1,ly,8,TICK,ticks.labels[2]!,{'text-anchor':'end'},g);}
  });
  c.area.replaceChildren(svg);
}
const peak=(samples:readonly ResourceSample[])=>samples.reduce((m,s)=>Math.max(m,resourceView(s).cpu),0);
export const resourcePlugin:CockpitPlugin=Object.freeze({
  id:'resources',
  title:'plugin.resourcesTitle',
  screenShort:'plugin.resourcesScreenShort',
  summary:'plugin.resourcesSummary',
  // D371: white line art without the small square frame: just the heartbeat line.
  icon:'<svg viewBox="0 0 16 16" aria-hidden="true"><path d="M1 8.5h3.5l1.8-5 3.2 9 1.8-4H15" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linejoin="round" stroke-linecap="round"/></svg>',
  underline:RESOURCE_INK,
  ink:RESOURCE_INK,
  defaultEnabled:true,
  hostSampled:true,
  // D324: the column samples every 2, 5 or 10 s while it is shown (the host snaps other saved values to these).
  settings:Object.freeze([Object.freeze({key:'intervalSeconds',kind:'seconds' as const,min:2,max:10,default:5,choices:Object.freeze([2,5,10])})]),
  accept(data:unknown,previous:unknown){
    // A reading is {samples} or (D413) {samples, minutes}: the host's last hour of one-minute folds, sent when it changed.
    if(data===null||typeof data!=='object'||Array.isArray(data))return undefined;
    const keys=Object.keys(data);if(!keys.includes('samples')||keys.some(k=>k!=='samples'&&k!=='minutes'))return undefined;
    const raw=(data as {samples?:unknown}).samples,rawMinutes=(data as {minutes?:unknown}).minutes;
    let minutes:readonly ResourceMinute[]|undefined=(previous as ResourceState|undefined)?.minutes;
    if(rawMinutes!==undefined){
      if(!Array.isArray(rawMinutes)||rawMinutes.length>60)return undefined;
      const parsed:ResourceMinute[]=[];for(const m of rawMinutes){const x=parseMinute(m);if(!x)return undefined;parsed.push(x);}
      minutes=Object.freeze(parsed.sort((a,b)=>a.t-b.t));
    }
    if(!Array.isArray(raw)||raw.length<1||raw.length>MAX_PER_READING)return undefined;
    const incoming:ResourceSample[]=[];
    for(const r of raw){const s=parseSample(r);if(!s)return undefined;incoming.push(s);}
    const byTime=new Map<number,ResourceSample>();
    for(const s of [...statesOf(previous),...incoming])byTime.set(s.t,s);
    const sorted=[...byTime.values()].sort((a,b)=>a.t-b.t),newest=sorted[sorted.length-1].t;
    const kept=sorted.filter(s=>s.t>newest-RESOURCE_WINDOW_MS).slice(-MAX_KEPT);
    return Object.freeze(minutes?{samples:Object.freeze(kept),minutes}:{samples:Object.freeze(kept)}) as ResourceState;
  },
  column(state:unknown,c:PluginContext):PluginColumn{
    const samples=statesOf(state),s=latest(state);
    const tags=[c.words('plugin.resourcesCpu'),c.words('plugin.resourcesMemory'),c.words('plugin.resourcesDisk')];
    const foot={label:c.words('plugin.resourcesPressure'),value:s?pressureWords(c,s):null};
    if(!s)return {cells:tags.map(tag=>({tag,value:null,bar:null})),foot};
    const v=resourceView(s),lv=levelsOf(samples),recent=samples.slice(-TREND_POINTS).map(resourceView);
    const cells:PluginCell[]=[
      {tag:tags[0],value:pct(v.cpu),unit:'%',side:c.words('plugin.resourcesPeak',{n:pct(peak(samples))}),bar:v.cpu/100,tone:true,trend:recent.map(x=>x.cpu/100),level:lv.cpu},
      {tag:tags[1],value:pct(v.memory),unit:'%',side:c.words('plugin.resourcesGb',{used:gb(v.memoryUsed),total:gb(s.memTotal)}),bar:v.memory/100,tone:true,trend:recent.map(x=>x.memory/100),level:lv.memory},
      {tag:tags[2],value:pct(v.disk),unit:'%',side:c.words('plugin.resourcesFree',{gb:gb(s.diskFree)}),bar:v.disk/100,tone:true,level:lv.disk},
    ];
    // D407: with a reading the column paints the R1 radar; the cells are its fallback (and the empty column's tags).
    return {cells,foot,draw:(ctx:PluginDrawContext)=>drawRadar(ctx,state,false)};
  },
  screen(state:unknown,c:PluginContext):PluginScreen{
    const s=latest(state),w=(key:string,vars?:Readonly<Record<string,string|number>>)=>c.words(key,vars).full;
    const every={label:w('plugin.resourcesSampling'),value:w('plugin.resourcesEvery',{n:c.settings.intervalSeconds})};
    if(!s)return {lines:[every],toggle:rangeToggle(c,c.memo?.range==='1h'?'1h':'10m')};
    const v=resourceView(s),samples=statesOf(state),unit=(text:string)=>`${text} GB`;
    const range:ResourceRange=c.memo?.range==='1h'?'1h':'10m';
    return {draw:(ctx:PluginDrawContext)=>drawGrid(ctx,state,range),toggle:rangeToggle(c,range),lines:[
      {label:w('plugin.resourcesCpu'),value:`${pct(v.cpu)}%`},
      {label:w('plugin.resourcesUserSystem'),value:`${pct(s.cpuUser)}% · ${pct(s.cpuSystem)}%`},
      {label:w('plugin.resourcesLoad'),value:String(Math.round(s.load*10)/10)},
      {label:w('plugin.resourcesPeak10'),value:`${pct(peak(samples))}%`},
      {label:w('plugin.resourcesMemory'),value:`${pct(v.memory)}% · ${w('plugin.resourcesGb',{used:gb(v.memoryUsed),total:gb(s.memTotal)})}`},
      {label:w('plugin.resourcesPressure'),value:pressureWords(c,s).full},
      {label:w('plugin.resourcesKinds'),value:unit([s.memWired,s.memApp,s.memCompressed].map(gb).join(' · '))},
      {label:w('plugin.resourcesCachedFree'),value:unit([s.memCached,s.memFree].map(gb).join(' · '))},
      {label:w('plugin.resourcesDisk'),value:`${pct(v.disk)}% · ${w('plugin.resourcesFree',{gb:gb(s.diskFree)})}`},
      {label:w('plugin.resourcesNetwork'),value:networkWords(s)??''},
      every,
    ]};
  },
});

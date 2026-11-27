// SPDX-License-Identifier: MIT
// D465 narrow-column English/Chinese labels (master spec G-g). Narrow Resources columns: en 107.6 pt (5 en band columns), zh 91 pt (English is only specified from 107.6), plus the 146 pt
// shipping width; pressure normal / warn / critical. Names come from main's strings; a name that does not fit drops to its
// short form, never an ellipsis; no text clipped or overlapping.
// (base note) D465 (owner 2026-11-27): the Resources column keeps the approved R1 radar drawing; only the sizing changes. The radius
// follows the column WIDTH (minus room for the "CPU" label) and five rows (CPU, memory, disk, network, pressure) share the
// remaining height. Nothing is cut or ellipsised; side values drop first. Checked at the column's width today (146) and
// when the calendar column is gone (198), at zoom 1 and 0.85, in both languages.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,sample,shell,excludePortholeFlicker} from '../fixture.mjs';
test.beforeEach(async({page})=>excludePortholeFlicker(page));

const GB=1024**3,T0=Date.UTC(2026,10,19,12);
const reading=(t,o={})=>{const s={t,cpuUser:30,cpuSystem:5,load:2.4,memTotal:32*GB,memApp:27*GB,memWired:3*GB,memCompressed:1.4*GB,memCached:2*GB,memFree:1*GB,swapUsed:0.8*GB,pressure:'warn',diskTotal:494*GB,diskFree:72*GB,netIn:139_000,netOut:41_000,...o};
 for(const k of Object.keys(s))if(k.startsWith('mem')||k.startsWith('disk')||k==='swapUsed')s[k]=Math.round(s[k]);return s;};
const column=page=>page.locator('.eng-cols .pl-col[data-plugin="resources"]');

/** The same shape as the clipped() helper of the other column specs: an svg text is clipped when it leaves the draw area or runs into another text. */
const clipped=page=>page.evaluate(()=>{
 const col=document.querySelector('.pl-col[data-plugin="resources"]'),area=col.querySelector('.pl-draw').getBoundingClientRect();
 const texts=[...col.querySelectorAll('.pl-radar text')].map(t=>({t:t.textContent,r:t.getBoundingClientRect(),row:t.closest('[data-row]')?.dataset.row}));
 const overlaps=[];for(let i=0;i<texts.length;i++)for(let j=i+1;j<texts.length;j++){const a=texts[i].r,b=texts[j].r;
  if(a.left<b.right-.5&&b.left<a.right-.5&&a.top<b.bottom-.5&&b.top<a.bottom-.5)overlaps.push(texts[i].t+' / '+texts[j].t);}
 return {outside:texts.filter(x=>x.r.left<area.left-.5||x.r.right>area.right+.5||x.r.top<area.top-.5||x.r.bottom>area.bottom+.5).map(x=>x.t),overlaps,
  rows:[...col.querySelectorAll('.pl-radar [data-row]')].map(r=>r.dataset.row),
  names:[...col.querySelectorAll('.pl-radar [data-label],.pl-radar [data-name]')].map(n=>n.textContent),
  pressure:col.querySelector('[data-row="pressure"]')?.textContent??''};
});
/** Width of the radar's own ink (arcs, ticks, thresholds) against the column width. */
const radarShare=page=>page.evaluate(()=>{
 const col=document.querySelector('.pl-col[data-plugin="resources"]'),c=col.getBoundingClientRect();
 const parts=[...col.querySelectorAll('.pl-radar [data-arc],.pl-radar [data-tick],.pl-radar [data-threshold]')].map(e=>e.getBoundingClientRect());
 return {share:(Math.max(...parts.map(r=>r.right))-Math.min(...parts.map(r=>r.left)))/c.width,column:c.width};
});


const NAMES={en:{full:['CPU','Memory','Disk','Network','Mem pressure'],short:['CPU','Mem','Disk','Net','Pressure']},'zh-CN':{full:['CPU','内存','磁盘','网络','内存压力'],short:['CPU','内存','磁盘','网络','压力']}};
const VALUE={en:{normal:/Normal|^$/,warn:/Elevated|High/,critical:/Critical/},'zh-CN':{normal:/正常|^$/,warn:/偏高/,critical:/严重/}};
for(const [locale,widths] of [['en',[107.6,146]],['zh-CN',[91,107.6,146]]])for(const width of widths)for(const zoom of [1,0.85])for(const pressure of ['normal','warn','critical'])
test(`D465 narrow labels at ${width} pt, zoom ${zoom}, ${locale}, pressure ${pressure}: no clipping, no ellipsis, no swapped text`,async({page})=>{
 await page.clock.setFixedTime(new Date('2026-11-19T12:00:00Z'));
 await page.addInitScript(()=>{window.__events=[];window.webkit={messageHandlers:{cockpit:{postMessage(raw){window.__events.push(JSON.parse(raw));}}}};});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance:{...appearance,locale},shell,redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('plugins',{plugins:{version:1,entries:[{id:'calendar',enabled:false,pinned:false}],settings:{}}}))).toBe(true);
 const data=sample();data.projection.rows=data.projection.rows.slice(0,2);
 expect(await receive(send('display',{data}))).toBe(true);
 await expect(column(page)).toHaveCount(1);
 await page.evaluate(([width,zoom])=>{document.documentElement.style.zoom=String(zoom);
  const col=document.querySelector('.eng-cols .pl-col[data-plugin="resources"]');
  for(const [k,v] of [['width',width+'px'],['min-width','0px'],['max-width',width+'px'],['justify-self','start']])col.style.setProperty(k,v,'important');},[width,zoom]);
 const samples=[0,1,2,3,4].map(i=>reading(T0+i*5000,{pressure,swapUsed:pressure==='normal'?0:0.8*GB,cpuUser:30+i*2}));
 expect(await receive(send('pluginData',{id:'resources',data:{samples}}))).toBe(true);
 await expect(column(page).locator('.pl-radar')).toHaveCount(1);
 await expect.poll(async()=>(await radarShare(page)).column,{message:'the column takes its width'}).toBeGreaterThan(0);
 await page.waitForTimeout(200);
 const m=await clipped(page);
 expect(m.rows).toEqual(['cpu','memory','disk','network','pressure']);
 expect(m.outside,'every text inside the column').toEqual([]);
 expect(m.overlaps,'no text runs into another').toEqual([]);
 m.names.forEach((n,i)=>expect([NAMES[locale].full[i],NAMES[locale].short[i],...(i===4?['']:[])],`name ${i}: ${n}`).toContain(n));
 expect(m.pressure,'never an ellipsis').not.toMatch(/…/);
 expect(m.pressure,'the pressure value is shown whole').toMatch(VALUE[locale][pressure]);
});

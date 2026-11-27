// SPDX-License-Identifier: MIT
// The page side of the cockpit plugin columns (D121/D124, D293): lays plugins into the engine table in the subscription
// columns' own grammar, runs the lifecycle, the plugin key (click = its big screen, right-click = Remove) and the
// empty-slot "+" menu.
//
// Lifecycle (owner D124): a plugin runs only while the cockpit is open (the page is visible and not occluded) AND its
// column is on the shown page (placed by the latest drawn table; a new table is drawn before it is attached, so
// placement, not DOM connection, is the test). Every repaint, page change, visibility change, removal or teardown
// re-checks that, so nothing samples in the background. A plugin's state (e.g. its trend history) survives repaints.
//
// The page has no timers (bundle rule). The host samples: the page reports the plugins that are running
// (`pluginsRunning`, on every change) and the host pushes readings for them (`pluginData`), which reach a plugin only
// while it runs.
//
// Custom draw (owner D323): a plugin whose column or screen carries `draw` paints inside one clipped area the host gives
// it (the column's cell rows, or the screen body under the title bar). The key, underline, pin, "+" menu, bottom line,
// title bar and lifecycle stay here. A draw that throws falls back to the plugin's cells or lines; a size change draws
// again; focus on a `data-focus` element survives every redraw.
//
// State: the host (Settings › Subscriptions › Plugins) owns the durable copy and sends it as a `plugins` message. Until
// the host has sent one, page edits stay in this page only and nothing is posted, so an older host never sees an action
// it does not know, and default-on plugins stay off (an older host's cockpit is the v1 table).
//
// Shaped data and ticks (v1.1 calendar): a running plugin with `derive` gets its reading shaped here from the display
// data the page rendered, through its own `accept`, unless the host pushes readings for it. A running plugin with
// `nextDeadline` names its next redraw; the view reports the earliest to the host, whose `tick` redraws it.
import type {WireCockpitData,WireRow} from '../generated/wire.js';
import {PLUGIN_TOKENS,PluginRegistry,screenShortText,type CockpitPlugin,type PluginCell,type PluginContext,type PluginDrawContext,type PluginLocale,type PluginWords} from './plugin-registry.js';
import {builtinPlugins} from './plugin-builtins.js';
import {pluginLayout,type LayoutPage,type PluginLayout} from './plugin-layout.js';
import {disablePlugin,emptyPluginState,enablePlugin,enabledPlugins,parsePluginState,pluginSettings,type PluginState} from './plugin-state.js';
import {ht} from './host-text.js';
import '../study/rocket-r1/strings/plugins.js';
/** Long and short forms of a `plugin.*` string-table key in one locale (`<key>Short` when it exists). */
/** D387 / D413: what the Overview | screen switch and the bottom keys show for the one open screen. */
export interface PluginScreenInfo {
  readonly id:string;
  /** The full name (tooltip and accessible name). */
  readonly name:string;
  /** The switch's short name, or null: the switch shows the icon alone. */
  readonly short:string|null;
  /** Trusted, bundled SVG markup (the plugin's own key icon). */
  readonly icon:string;
  /** The centre bottom key's two-way choice, when the screen has one. */
  readonly toggle:{readonly value:string;readonly options:readonly {readonly value:string;readonly text:string}[];pick(value:string):void}|null;
}
export function pluginWords(locale:PluginLocale,key:string,vars?:Readonly<Record<string,string|number>>):PluginWords {
  const full=ht(locale,key,vars),shortKey=key+'Short',short=ht(locale,shortKey,vars);
  return {full,short:short===shortKey?full:short};
}
const DETECTED=new Set<WireRow['state']>(['needs_action','needs_consent','needs_keychain']);
const NOT_CONNECTED=new Set<WireRow['state']>(['off']);
const MENU_ROWS=5;
/** '+' menu rows: tools the engine found but that have no connected account, detected ones first. */
export function connectableRows(data:WireCockpitData|null):{row:WireRow;detected:boolean}[] {
  const rows=(data?.projection.rows??[]).filter(row=>row.kind==='tool'&&row.accounts.length===0);
  return [...rows.filter(r=>DETECTED.has(r.state)).map(row=>({row,detected:true})),...rows.filter(r=>NOT_CONNECTED.has(r.state)).map(row=>({row,detected:false}))].slice(0,MENU_ROWS);
}
const el=<K extends keyof HTMLElementTagNameMap>(tag:K,className?:string,text?:string)=>{const e=document.createElement(tag);if(className)e.className=className;if(text!==undefined)e.textContent=text;return e;};
/** A text box that takes its short form when the long one does not fit (prototype-engine fit()). */
const fitted=(className:string,words:PluginWords)=>{const e=el('span',className+' pl-fit',words.full);e.dataset.full=words.full;e.dataset.short=words.short;return e;};
/** Menus and the big screen sit outside the engine table's fit(): the same long-then-short rule, once they are laid out. */
const fitIn=(box:HTMLElement)=>{for(const e of box.querySelectorAll<HTMLElement>('.pl-fit[data-short]')){e.textContent=e.dataset.full??'';if(e.clientWidth>0&&e.scrollWidth>e.clientWidth)e.textContent=e.dataset.short??'';if(e.classList.contains('pl-side')&&e.clientWidth>0&&e.scrollWidth>e.clientWidth)e.textContent='';}};// D371 Q5: a side value that does not fit even short is hidden
const icon=(plugin:CockpitPlugin,className:string)=>{const span=el('span',className);span.setAttribute('aria-hidden','true');span.innerHTML=plugin.icon;return span;};
const clamp01=(v:number)=>Math.max(0,Math.min(1,v));
/** The stable `data-focus` key of the focused element inside `box`, if any (D323: focus survives a redraw). */
function focusKey(box:HTMLElement):string|null {
  const active=document.activeElement,marked=active instanceof HTMLElement&&box.contains(active)?active.closest<HTMLElement>('[data-focus]'):null;
  return marked&&box.contains(marked)?marked.dataset.focus??null:null;
}
function refocus(box:HTMLElement,key:string|null) {
  if(key===null||!box.isConnected)return;
  for(const e of box.querySelectorAll<HTMLElement>('[data-focus]'))if(e.dataset.focus===key){if(document.activeElement!==e)e.focus({preventScroll:true});return;}
}
const SVG='http://www.w3.org/2000/svg';
function trendLine(points:readonly number[]):SVGSVGElement|null {
  const values=points.filter(Number.isFinite).slice(-48);if(values.length<2)return null;
  const svg=document.createElementNS(SVG,'svg');svg.setAttribute('class','pl-trend');svg.setAttribute('viewBox','0 0 100 8');svg.setAttribute('preserveAspectRatio','none');svg.setAttribute('aria-hidden','true');
  const path=document.createElementNS(SVG,'path');
  path.setAttribute('d',values.map((v,i)=>`${i?'L':'M'}${(i*100/(values.length-1)).toFixed(1)} ${(7-6*clamp01(v)).toFixed(1)}`).join(''));
  svg.append(path);return svg;
}
function drawCell(cell:PluginCell|undefined,row:number):HTMLElement {
  if(!cell){const empty=el('div','qcell none');empty.dataset.row=String(row);return empty;}
  const box=el('div','qcell pl-cell'+(cell.level?' pl-'+cell.level:''));box.dataset.row=String(row);
  const line=el('span','qline');
  if(!(typeof cell.value==='number'||typeof cell.bar==='number')){
    // The calendar's cells keep the three-row form (tag above, big value with the side value, colour mark below).
    box.classList.add('pl-cal');
    box.append(fitted('pl-tag',cell.tag));
    if(cell.big)line.append(el('b','pl-big',cell.big));
    if(cell.side){const side=fitted('qtxt',cell.side);side.dataset.small=cell.side.short;line.append(side);}
  }else{
    // D371 Q5 (owner 11-21): two layers, 31 pt in all. The number line (22 pt) reads "39% CPU": the tag follows the % inline in
    // 10 px grey and is never hidden; the side value sits at the right edge and gives way (full, short, then gone), never cut.
    const lead=el('span','pl-lead');
    if(typeof cell.value==='number'&&Number.isFinite(cell.value)){const num=el('b','qnum'),value=el('span','qvalue',String(Math.round(cell.value)));num.append(value);if(cell.unit)num.append(el('small','',cell.unit));lead.append(num);}
    lead.append(el('span','pl-tag',cell.tag.full));
    line.append(lead);
    if(cell.side){const side=fitted('qtxt pl-side',cell.side);side.dataset.small=cell.side.short;line.append(side);}
  }
  box.append(line);
  // D375: the subscription's colour mark with its name, so a colour is never alone.
  if(cell.subline&&/^#[0-9a-f]{6}$/i.test(cell.subline.colour)){
    const sub=el('span','pl-sub'),mark=el('i','pl-sw');mark.style.background=cell.subline.colour;mark.setAttribute('aria-hidden','true');
    sub.append(mark,fitted('pl-subt',cell.subline.text));box.append(sub);
  }
  if(typeof cell.bar==='number'&&Number.isFinite(cell.bar)){
    // 6 pt bar 3 pt below the number line; the trend is one 1 px line inside the bar's track.
    const meter=el('span','pl-meter'),bar=el('span','pl-bar'+(cell.tone?' pl-tone':'')),fill=el('i');fill.style.width=(clamp01(cell.bar)*100).toFixed(1)+'%';bar.append(fill);
    const trend=trendLine(cell.trend??[]);if(trend)bar.append(trend);
    meter.append(bar);box.append(meter);
  }
  const words=[cell.tag.full,typeof cell.value==='number'?String(Math.round(cell.value))+(cell.unit??''):cell.big??'',cell.side?.full??'',cell.subline?.text.full??''].filter(Boolean).join(' · ');
  box.setAttribute('aria-label',words);return box;
}
export interface MenuOptions {readonly data:WireCockpitData|null;readonly locale:PluginLocale;readonly mark:(vendorKey:string|null)=>string|null;readonly connect:()=>boolean}
export interface PluginHost {
  readonly registry:PluginRegistry;
  state():PluginState;
  layout(subscriptions:number):PluginLayout;
  /** The engine's repaint; replaced by each new engine table. */
  bindEngine(repaint:(()=>void)|null):void;
  /** Turn the first empty slots of a drawn page into this page's plugin columns, then re-check the lifecycle. */
  decorate(table:HTMLElement,page:LayoutPage,locale:PluginLocale):void;
  /** Nothing is placed (empty or cleared table). */
  clearPlacement():void;
  /** The engine is about to replace its table: remember a focused drawn control (plugin id and `data-focus` key) so the
   *  plugin's new column takes focus back once it is drawn and attached (D323 focus contract). */
  hold():void;
  setVisible(visible:boolean):void;
  setInteractive(interactive:boolean):void;
  applyHostState(raw:unknown):boolean;
  /** A host reading for a running plugin; false when the plugin is not running or refuses the data. */
  deliver(id:string,data:unknown):boolean;
  remove(id:string):boolean;
  add(id:string):boolean;
  openMenu(anchor:HTMLElement,options:MenuOptions):boolean;
  closeMenu():void;
  /** CKP-PLG-53: the plugin's big screen inside the big-screen area; null closes it. The key toggles; `keep` (a host
   *  request such as the widget card's action) leaves an already open screen open. */
  openScreen(id:string|null,keep?:boolean):boolean;
  /** D387: the deck follows the one open screen (its plugin id and shown name), or null when none is open. */
  onScreen(listener:(screen:PluginScreenInfo|null)=>void):void;
  /** Close an open plugin screen and report whether one was covering the page. */
  dismissScreen():boolean;
  /** Plugins currently running (for tests and diagnostics). */
  running():string[];
  /** The display data the page rendered, at the host's time: running plugins with `derive` get their shaped reading. */
  display(data:WireCockpitData|null,now:number):void;
  /** The host's deadline tick: running plugins are shaped and drawn again at `now`. */
  tick(now:number):void;
  /** The earliest redraw a running plugin asked for, or null. */
  nextDeadline():number|null;
  dispose():void;
}
const hosts=new WeakMap<HTMLElement,PluginHost>();
export const pluginHostOf=(root:HTMLElement)=>hosts.get(root)??null;
export interface PluginReports {
  /** The page changed the plugin choices (right-click Remove, "Add" in the + menu). */
  readonly state:(state:PluginState)=>void;
  /** The plugins now running, in user order; the host samples exactly these. */
  readonly running:(ids:string[])=>void;
  /** D376: right-click Remove asks the native host to confirm and turn the plugin off. False (no native host) = the page removes it itself. */
  readonly close?:(id:string)=>boolean;
}
export function mountPluginHost(root:HTMLElement,report:PluginReports,registry=new PluginRegistry(builtinPlugins)):PluginHost {
  let state:PluginState=emptyPluginState,negotiated=false,visible=false,interactive=false,disposed=false,locale:PluginLocale='en';
  let repaint:(()=>void)|null=null,menu:HTMLElement|null=null,menuAnchor:HTMLElement|null=null,reported:string|null=null,screen:{id:string;box:HTMLElement;list:HTMLElement;area:HTMLElement;opening:boolean}|null=null;
  const readings=new Map<string,unknown>(),columns=new Map<string,HTMLElement>(),running=new Set<string>(),placed=new Set<string>(),hostFed=new Set<string>();
  let shown:WireCockpitData|null=null,now=0;
  // D323 custom draw: per-plugin view memory, the size each area was last drawn at, and one observer that draws an area
  // again when its size changes (a column is drawn before its table is attached, so the first real size arrives here).
  const memos=new Map<string,Record<string,unknown>>(),drawnAt=new WeakMap<HTMLElement,{id:string;w:number;h:number}>();
  let drawing=false,pending:{id:string;key:string}|null=null;
  /** Stop watching the draw areas of the columns about to be dropped (a replaced table, cleared placement). */
  const forget=()=>{for(const column of columns.values())for(const area of column.querySelectorAll<HTMLElement>(':scope > .pl-draw'))watch?.unobserve(area);};
  /** Gives focus back to a held control in this plugin's new column, only when focus was dropped (not moved elsewhere). */
  function restoreHeld(column:HTMLElement,id:string) {
    if(!pending||pending.id!==id||!column.isConnected)return;
    const active=document.activeElement;if(active&&active!==document.body){pending=null;return;}
    const key=pending.key;pending=null;refocus(column,key);
  }
  const watch=typeof ResizeObserver==='undefined'?null:new ResizeObserver(entries=>{
    for(const entry of entries){
      const area=entry.target as HTMLElement,last=drawnAt.get(area);
      if(!last||!area.isConnected||area.clientWidth===last.w&&area.clientHeight===last.h)continue;
      if(area.classList.contains('pl-screen-d'))drawScreen();else redrawColumn(last.id);
    }
  });
  const memo=(id:string)=>{let m=memos.get(id);if(!m){m={};memos.set(id,m);}return m;};
  /** Draws one area; false (and the area left empty) when the plugin's draw throws. */
  function paint(area:HTMLElement,id:string,draw:(context:PluginDrawContext)=>void,opening:boolean):boolean {
    const key=focusKey(area);area.replaceChildren();
    const w=area.clientWidth,h=area.clientHeight;drawnAt.set(area,{id,w,h});watch?.observe(area);
    const was=drawing;drawing=true;
    try{draw({...context(id),area,width:w,height:h,tokens:PLUGIN_TOKENS,memo:memo(id),opening,redraw:()=>redrawPlugin(id)});}
    catch{area.replaceChildren();return false;/* The plugin's cells or lines are drawn instead. */}
    finally{drawing=was;}
    refocus(area,key);return true;
  }
  /** A plugin asked to be drawn again: its column and, when open, its screen. Ignored while a draw runs (no recursion). */
  function redrawPlugin(id:string) {if(drawing||disposed)return;redrawColumn(id);if(screen?.id===id)drawScreen();}
  const guard=<T>(fn:()=>T,fallback:T):T=>{try{return fn();}catch{return fallback;/* A plugin failure never takes the cockpit down. */}};
  const context=(id:string):PluginContext=>({locale,settings:pluginSettings(state,registry,id),now,memo:memo(id),words:(key,vars)=>pluginWords(locale,key,vars)});
  // Before the host sent its plugin state, defaults do not apply (D121 default-on needs a host that knows plugins).
  const active=()=>enabledPlugins(state,registry,negotiated);
  const enabled=(id:string)=>active().some(p=>p.id===id);
  /** A reading (host push or shaped here) through the plugin's own `accept`; redraws on success. */
  function take(plugin:CockpitPlugin,data:unknown):boolean {
    const next=guard(()=>plugin.accept(data,readings.get(plugin.id)),undefined);if(next===undefined)return false;
    readings.set(plugin.id,next);redrawColumn(plugin.id);if(screen?.id===plugin.id)drawScreen();return true;
  }
  /** Shapes a running plugin's reading from the rendered display data (unless the host feeds it). */
  function derive(id:string):boolean {
    const plugin=registry.get(id);
    if(!plugin?.derive||!shown||hostFed.has(id)||!running.has(id))return false;
    const data=shown;let raw:unknown,ok=false;guard(()=>{raw=plugin.derive!(data,now);ok=true;},undefined);
    return ok&&take(plugin,raw);
  }
  // Sample S4 (#1104 PLG-A2): an open big screen is a surface of its own. With six subscription columns an unpinned
  // plugin has no column, yet the screen the widget card opened must get readings, so it runs while its screen is open.
  const shouldRun=(id:string)=>!disposed&&visible&&(placed.has(id)||screen?.id===id)&&enabled(id);
  /** (Re)draws one plugin column's rows in place: one cell per table row, the bottom line, and the reserve row when the table has one. */
  function fill(column:HTMLElement,plugin:CockpitPlugin,rows:number,reserve:boolean) {
    const drawn=guard(()=>plugin.column(readings.get(plugin.id),context(plugin.id)),{cells:[]});
    const cells=()=>Array.from({length:rows},(_,i)=>drawCell(drawn.cells?.[i],i));
    const key=focusKey(column);
    // D323: a custom draw gets one clipped area over all the cell rows; the bottom line stays the framework's.
    // The same draw area is reused by a redraw: a fresh element would be a new observation at the depth the resize callback
    // is delivering, which the browser reports as a "ResizeObserver loop" error.
    const before=column.querySelector<HTMLElement>(':scope > .pl-draw');
    const area=typeof drawn.draw==='function'&&rows>0?(before&&before.dataset.plugin===plugin.id?before:el('div','pl-draw')):null;
    for(const old of column.querySelectorAll<HTMLElement>(':scope > .pl-draw'))if(old!==area)watch?.unobserve(old);
    if(area){area.style.gridRow=`1 / span ${rows}`;area.dataset.plugin=plugin.id;}
    const parts:HTMLElement[]=area?[area]:cells();
    const foot=el('div','qrow qrow-t pl-foot');
    if(drawn.foot){foot.setAttribute('role','group');foot.setAttribute('aria-label',[drawn.foot.label.full,drawn.foot.value?.full].filter(Boolean).join(' · '));foot.append(fitted('pl-foot-l',drawn.foot.label));if(drawn.foot.value){const v=fitted('pl-foot-v',drawn.foot.value);v.title=drawn.foot.value.full;foot.append(v);}}// D406: one line with an ellipsis (CSS); the tooltip holds the full text
    parts.push(foot);if(reserve)parts.push(el('div','qrow qrow-r'));
    column.replaceChildren(...parts);column.dataset.rows=String(rows);column.dataset.reserve=String(reserve);
    const ink=plugin.ink;if(ink)column.style.setProperty('--pl-ink',ink);else column.style.removeProperty('--pl-ink');
    if(area){const ok=paint(area,plugin.id,drawn.draw!,false);column.dataset.draw=ok?'custom':'fallback';if(!ok){watch?.unobserve(area);area.replaceWith(...cells());}}
    else delete column.dataset.draw;
    refocus(column,key);restoreHeld(column,plugin.id);
    if(column.isConnected)column.querySelectorAll<HTMLElement>('.pl-cell:not(.pl-cal)').forEach(fitIn);// a redrawn Resources cell (the calendar's cells and bottom line keep main's later fit) is measured at once (the table's own fit() only runs on a resize)
  }
  function redrawColumn(id:string) {
    const column=columns.get(id),plugin=registry.get(id);
    if(column?.isConnected&&plugin)fill(column,plugin,Number(column.dataset.rows)||0,column.dataset.reserve==='true');
  }
  function reconcile() {
    if(screen&&!enabled(screen.id)){closeScreen();return;/* closeScreen reconciles. */}
    for(const id of [...running])if(!shouldRun(id))running.delete(id);
    for(const id of [...placed,...screen?[screen.id]:[]])if(!running.has(id)&&shouldRun(id)){running.add(id);derive(id);}
    for(const [id,column] of columns)column.dataset.running=String(running.has(id));
    if(negotiated&&!disposed){const ids=active().map(p=>p.id).filter(id=>running.has(id)),key=ids.join();if(key!==reported){reported=key;report.running(ids);}}
  }
  function changed(next:PluginState|null) {
    if(!next||disposed)return false;
    state=next;if(negotiated)report.state(state);
    for(const id of [...placed])if(!enabled(id))placed.delete(id);
    for(const id of [...memos.keys()])if(!enabled(id))memos.delete(id);
    // macrevb-1096-2: a plugin turned off (Settings or Remove) keeps no readings; its next Add starts from a fresh sample.
    for(const id of [...readings.keys()])if(!enabled(id))readings.delete(id);
    reconcile();repaint?.();return true;
  }
  // ---- the big screen (CKP-PLG-53): drawn inside the big-screen well only, so faders and page keys stay uncovered.
  // Invariant (macrevb-835-1): any activation of an MFD page key closes the screen. `click` is the activation event for a
  // button whether it came from a pointer, Enter or Space, so the capture listener sees every path.
  // Invariant (macrevb-835-2): the screen's frame (icon, title, Close) is built once per opening; readings, repaints,
  // locale and settings changes update its text and lines in place, so a focused control is never replaced.
  // D387: the screen is one view of the lower panel. Any other view key (a page key, a subscription key, All) ends it.
  // D401: a subscription or All key is handled by the engine, which asks `dismissScreen` first (pressing the remembered
  // selection again brings it back instead of toggling it off); only a page key ends the screen here.
  const pageKeys=(e:Event)=>{if(screen&&(e.target as Element|null)?.closest?.('.mfd-pk .pk'))closeScreen();};
  // D401: a plugin key follows the subscription-key logic. While a screen is open only its key is lit: the lit subscription
  // (or All) key goes dark and is remembered, then lit again when the screen closes (a new table is dimmed as it is drawn).
  const dimmed=new Set<HTMLElement>();
  const dimSubs=()=>{for(const k of dimmed)if(!k.isConnected)dimmed.delete(k);for(const k of root.querySelectorAll<HTMLElement>('.eng-keys .ek:not(.pl-key),.ek[data-all]')){if(k.getAttribute('aria-pressed')==='true')dimmed.add(k);k.classList.remove('on');k.setAttribute('aria-pressed','false');}};
  const lightSubs=()=>{for(const k of dimmed)if(k.isConnected){k.classList.add('on');k.setAttribute('aria-pressed','true');}dimmed.clear();};
  // The plugin key is pressed (lit, aria-pressed) exactly while its screen is open, as a subscription key is while selected.
  const markKey=(key:HTMLElement,open:boolean)=>{key.classList.toggle('on',open);key.setAttribute('aria-expanded',String(open));key.setAttribute('aria-pressed',String(open));};
  let listener:((s:PluginScreenInfo|null)=>void)|null=null,told='';
  const tell=(s:PluginScreenInfo|null)=>{const sig=s?[s.id,s.name,s.short,s.toggle?.value,s.toggle?.options.map(o=>o.value+o.text).join()].join('\0'):'';if(sig===told)return;told=sig;listener?.(s);};
  function drawScreen() {
    if(!screen)return;const plugin=registry.get(screen.id);if(!plugin){closeScreen();return;}
    const title=pluginWords(locale,plugin.title);
    const shown=guard(()=>plugin.screen(readings.get(plugin.id),context(plugin.id)),{lines:[]});
    // D323: a custom draw paints the body under the title bar; when it throws, the lines are shown instead.
    const opening=screen.opening;screen.opening=false;
    // The area is shown before the draw so the plugin measures its real size (no second draw from the observer).
    if(typeof shown.draw==='function'){screen.area.hidden=false;screen.list.hidden=true;}
    const custom=typeof shown.draw==='function'&&paint(screen.area,plugin.id,shown.draw,opening);
    screen.area.hidden=!custom;screen.list.hidden=custom;screen.box.dataset.draw=typeof shown.draw!=='function'?'lines':custom?'custom':'fallback';
    if(!custom)screen.area.replaceChildren();
    const lines=custom?[]:(Array.isArray(shown.lines)?shown.lines:[]).slice(0,12);
    const rows=[...screen.list.children] as HTMLElement[];
    lines.forEach((line,i)=>{let row=rows[i];if(!row){row=el('div');row.append(el('dt'),el('dd'));screen!.list.append(row);}
      const [dt,dd]=[row.children[0]!,row.children[1]!];if(dt.textContent!==line.label)dt.textContent=line.label;if(dd.textContent!==line.value)dd.textContent=line.value;});
    for(const row of rows.slice(lines.length))row.remove();
    screen.box.setAttribute('aria-label',ht(locale,'plugin.screenAria',{name:title.full}));fitIn(screen.box);
    // D413: the switch's short name and icon, and the screen's bottom toggle (its pick lives in the view memory only).
    const id=screen.id,toggle=shown.toggle&&Array.isArray(shown.toggle.options)&&shown.toggle.options.length===2?shown.toggle:null;
    tell({id,name:title.full,short:plugin.screenShort?screenShortText(pluginWords(locale,plugin.screenShort).full,locale):null,icon:plugin.icon,
      toggle:toggle?{value:toggle.value,options:toggle.options.map(o=>({value:o.value,text:o.label.full})),pick:(value:string)=>{
        if(screen?.id!==id||!toggle.options.some(o=>o.value===value))return;memo(id)[toggle.key]=value;drawScreen();}}:null});
  }
  function closeScreen(restoreFocus=false) {
    if(!screen)return;const id=screen.id;watch?.unobserve(screen.area);screen.box.remove();screen=null;
    document.removeEventListener('click',pageKeys,true);
    for(const key of root.querySelectorAll<HTMLElement>('.eng-keys .pl-key'))markKey(key,false);lightSubs();tell(null);
    if(restoreFocus)root.querySelector<HTMLElement>(`.eng-keys .pl-key[data-plugin="${id}"]`)?.focus();
    reconcile();// S4: a plugin that ran only for its screen stops.
  }
  function openScreen(id:string|null,keep=false):boolean {
    if(id===null){closeScreen();return true;}
    const plugin=registry.get(id);
    // D466: a page-only plugin (the calendar) is the deck's fixed page; the deck opens it.
    if(plugin?.pageOnly){if(disposed)return false;closeScreen();root.dispatchEvent(new CustomEvent('cockpit-calendar',{detail:{scope:null}}));return true;}
    if(disposed||!enabled(id)||!plugin)return false;
    if(screen?.id===id){if(!keep)closeScreen();return true;}
    const well=root.querySelector<HTMLElement>('.dk-mfd .mfd-screen');if(!well)return false;
    closeScreen();const box=el('section','pl-screen');box.dataset.plugin=id;box.setAttribute('role','region');box.tabIndex=-1;
    // D413: no title row and no Close key; the Overview | screen switch names the screen and returns.
    const list=el('dl','pl-screen-l'),area=el('div','pl-screen-d');area.hidden=true;area.dataset.plugin=id;box.append(list,area);
    well.append(box);screen={id,box,list,area,opening:true};reconcile();drawScreen();
    document.addEventListener('click',pageKeys,true);
    const opened=root.querySelector<HTMLElement>(`.eng-keys .pl-key[data-plugin="${id}"]`);if(opened)markKey(opened,true);dimSubs();
    return true;
  }
  // ---- menus: the empty-slot "+" menu and the plugin key's right-click menu share one popup.
  function closeMenu(restoreFocus=false) {
    if(!menu)return;menu.remove();menu=null;
    document.removeEventListener('pointerdown',outside,true);
    if(menuAnchor&&!menuAnchor.classList.contains('pl-key'))menuAnchor.classList.remove('on');if(menuAnchor?.hasAttribute('data-add-subscription'))menuAnchor.setAttribute('aria-expanded','false');if(restoreFocus&&menuAnchor?.isConnected)menuAnchor.focus();menuAnchor=null;
  }
  const outside=(e:Event)=>{if(menu&&!menu.contains(e.target as Node)&&!menuAnchor?.contains(e.target as Node))closeMenu();};
  const escape=(e:KeyboardEvent)=>{
    if(e.key!=='Escape')return;
    if(menu){e.preventDefault();e.stopPropagation();closeMenu(true);}
    else if(screen){e.preventDefault();e.stopPropagation();closeScreen(true);}
  };
  document.addEventListener('keydown',escape,true);
  const moved=()=>{pending=null;};document.addEventListener('focusin',moved,true);
  function popup(anchor:HTMLElement,label:string):HTMLElement {
    const m=el('div','pl-menu');m.setAttribute('role','menu');m.setAttribute('aria-label',label);m.dataset.mat='glass';return m;
  }
  function place(m:HTMLElement,anchor:HTMLElement,at?:{x:number;y:number}) {
    root.append(m);menu=m;menuAnchor=anchor;if(!anchor.classList.contains('pl-key'))anchor.classList.add('on');
    const r=anchor.getBoundingClientRect(),x=at?.x??r.left,y=at?.y??r.bottom+6;
    m.style.left=Math.max(8,Math.min(window.innerWidth-m.offsetWidth-8,x))+'px';
    m.style.top=(y+m.offsetHeight>window.innerHeight-4?Math.max(4,(at?.y??r.top)-m.offsetHeight-6):y)+'px';
    document.addEventListener('pointerdown',outside,true);fitIn(m);
    m.querySelector<HTMLButtonElement>('.pm-i:not([disabled])')?.focus();
  }
  const item=(className:string,onPick:()=>void,disabled=false)=>{const b=el('button','pm-i'+(className?' '+className:''));b.type='button';b.setAttribute('role','menuitem');if(disabled){b.disabled=true;b.setAttribute('aria-disabled','true');}b.onclick=e=>{if(!e.isTrusted||disabled)return;closeMenu();onPick();};return b;};
  function openKeyMenu(key:HTMLElement,id:string,at?:{x:number;y:number}) {
    const plugin=registry.get(id);if(disposed||!interactive||!plugin)return false;
    closeMenu();const name=pluginWords(locale,plugin.title).full,m=popup(key,ht(locale,'plugin.menuAria',{name}));
    const remove=item('pm-remove',()=>{if(report.close?.(id)!==true)host.remove(id);});remove.dataset.pmRemove=id;remove.append(fitted('pm-n',pluginWords(locale,'plugin.remove')));m.append(remove);
    place(m,key,at);return true;
  }
  const host:PluginHost={
    registry,
    state:()=>state,
    // A host-sampled plugin is laid out only once the host has sent its plugin state (it is the one that samples).
    layout:subscriptions=>pluginLayout(subscriptions,active().filter(p=>(negotiated||!registry.get(p.id)?.hostSampled)&&!registry.get(p.id)?.pageOnly)),
    bindEngine(next){repaint=next;},
    decorate(table,page,value){
      locale=value;forget();placed.clear();columns.clear();
      if(pending&&!page.plugins.includes(pending.id))pending=null;
      const keys=[...table.querySelectorAll<HTMLElement>('.eng-keys > .ek-bay')],bays=[...table.querySelectorAll<HTMLElement>('.eng-cols > .ec-bay')];
      page.plugins.forEach((id,i)=>{
        const plugin=registry.get(id),bay=bays[i];if(!plugin||!keys[i]||!bay)return;
        const title=pluginWords(locale,plugin.title);
        // CKP-PLG-50: the subscription key's box and type, a white line-art icon in the vendor-mark box, a dashed
        // underline in the plugin's colour, no digit and no ×.
        const key=el('button','ek bd-r pl-key');key.type='button';key.dataset.plugin=id;key.dataset.mat='part';
        key.setAttribute('aria-label',ht(locale,'plugin.keyAria',{name:title.full}));markKey(key,screen?.id===id);key.title=title.full;
        const identity=el('span','ek-identity');identity.append(icon(plugin,'lamp pl-icon'),fitted('ek-name',title));
        const line=el('i','bl pl-dash');line.setAttribute('aria-hidden','true');line.style.setProperty('--v',plugin.underline);
        key.append(identity,line);
        key.onclick=e=>{if(e.isTrusted)openScreen(id);};
        key.oncontextmenu=e=>{e.preventDefault();e.stopPropagation();if(e.isTrusted)openKeyMenu(key,id,{x:e.clientX,y:e.clientY});};
        key.onkeydown=e=>{if(e.isTrusted&&(e.key==='ContextMenu'||e.key==='F10'&&e.shiftKey)){e.preventDefault();openKeyMenu(key,id);}};
        keys[i].replaceWith(key);
        // CKP-PLG-51: the subscription column itself, no inner frame; each row is one cell in the Other-cell grammar.
        const col=el('div','ec pl-col');col.dataset.plugin=id;col.setAttribute('role','group');col.setAttribute('aria-label',title.full);
        fill(col,plugin,bay.querySelectorAll('.qcell').length,bay.querySelectorAll('.qrow').length>1);
        bay.replaceWith(col);columns.set(id,col);placed.add(id);
      });
      if(screen){dimSubs();const open=root.querySelector<HTMLElement>(`.eng-keys .pl-key[data-plugin="${screen.id}"]`);if(open)markKey(open,true);}
      reconcile();if(screen)drawScreen();
    },
    // Privacy barrier (clear, new view revision, waiting/empty; macrevc-844-2, macrev2-1104-2): readings, per-plugin draw
    // memory and host takeover go with the old view, so a cleared reading never comes back and the next display is shaped
    // afresh. A running plugin is sampled again by the host.
    clearPlacement(){forget();pending=null;placed.clear();columns.clear();readings.clear();memos.clear();hostFed.clear();closeMenu();closeScreen();reconcile();},
    hold(){
      // Called again while the engine rebuilds (focus already dropped): an earlier hold stays until it is used, focus
      // moves elsewhere (focusin) or the plugin is no longer placed.
      const active=document.activeElement;if(!(active instanceof HTMLElement))return;
      for(const [id,column] of columns){
        const area=column.querySelector<HTMLElement>(':scope > .pl-draw');if(!area?.contains(active))continue;
        const key=focusKey(area);if(key!==null)pending={id,key};return;
      }
    },
    setVisible(value){visible=value;reconcile();},
    setInteractive(value){interactive=value;if(!value)closeMenu();},
    applyHostState(raw){
      const next=parsePluginState(raw);if(!next||disposed)return false;
      if(!negotiated)reported=null;negotiated=true;state=next;
      for(const id of [...placed])if(!enabled(id))placed.delete(id);
      for(const id of [...memos.keys()])if(!enabled(id))memos.delete(id);
    // macrevb-1096-2: a plugin turned off (Settings or Remove) keeps no readings; its next Add starts from a fresh sample.
    for(const id of [...readings.keys()])if(!enabled(id))readings.delete(id);
      reconcile();repaint?.();return true;
    },
    deliver(id,data){
      const plugin=registry.get(id);
      if(!plugin||!running.has(id))return false;
      if(!take(plugin,data))return false;
      hostFed.add(id);return true;
    },
    display(data,at){
      shown=data;now=at;
      for(const id of running)if(!derive(id)&&registry.get(id)?.nextDeadline){redrawColumn(id);if(screen?.id===id)drawScreen();}
    },
    tick(at){
      now=at;
      for(const id of running)if(!derive(id)&&registry.get(id)?.nextDeadline){redrawColumn(id);if(screen?.id===id)drawScreen();}
    },
    nextDeadline(){
      let next=Infinity;
      for(const id of running){
        const plugin=registry.get(id);if(!plugin?.nextDeadline)continue;
        const at=guard(()=>plugin.nextDeadline!(readings.get(id),now),null);
        if(typeof at==='number'&&Number.isSafeInteger(at)&&at>now)next=Math.min(next,at);
      }
      return Number.isFinite(next)?next:null;
    },
    remove:id=>changed(disablePlugin(state,registry,id,negotiated)),
    add:id=>changed(enablePlugin(state,registry,id,negotiated)),
    openMenu(anchor,options){
      if(disposed||!interactive)return false;
      if(menu&&menuAnchor===anchor){closeMenu();return true;}closeMenu();
      const w=(key:string)=>pluginWords(options.locale,key),m=popup(anchor,ht(options.locale,'plugin.addMenu'));
      m.append(fitted('pm-h',w('plugin.connect')));
      for(const {row,detected} of connectableRows(options.data)){
        const b=item('pm-connect',()=>{options.connect();});b.dataset.pmRow=row.id;
        const src=options.mark(row.vendorKey),mark=el('span','pm-mark');mark.setAttribute('aria-hidden','true');
        if(src){const img=el('img');img.src=src;img.alt='';mark.append(img);}
        const state=fitted('pm-st'+(detected?' pm-det':''),w(detected?'plugin.detected':'plugin.notConnected'));
        b.append(mark,el('span','pm-n',options.locale==='en'?row.name.en:row.name.zh),state,el('b','pm-go'+(detected?'':' dim'),w('plugin.connectGo').full));m.append(b);
      }
      const more=item('pm-more',()=>{options.connect();});more.dataset.pmAll='';more.append(fitted('pm-n',w('plugin.allSubscriptions')));m.append(more);
      m.append(el('div','pm-sep'),fitted('pm-h',w('plugin.addPlugin')));
      for(const plugin of registry.list().filter(p=>!p.frameworkOnly&&!p.pageOnly)){
        const added=enabled(plugin.id),b=item('pm-plugin'+(added?' on':''),()=>{host.add(plugin.id);},added);b.dataset.pmPlugin=plugin.id;
        b.append(icon(plugin,'pm-ic'),fitted('pm-n',pluginWords(options.locale,plugin.title)),added?fitted('pm-ok',w('plugin.added')):el('b','pm-go',w('plugin.addGo').full));m.append(b);
      }
      anchor.setAttribute('aria-expanded','true');place(m,anchor);
      return true;
    },
    closeMenu:()=>closeMenu(),
    openScreen,
    onScreen(next){listener=next;},
    dismissScreen(){if(!screen)return false;closeScreen();return true;},
    running:()=>[...running],
    dispose(){if(disposed)return;closeMenu();closeScreen();placed.clear();visible=false;reconcile();disposed=true;repaint=null;columns.clear();readings.clear();memos.clear();pending=null;hostFed.clear();shown=null;watch?.disconnect();document.removeEventListener('focusin',moved,true);document.removeEventListener('keydown',escape,true);hosts.delete(root);},
  };
  hosts.set(root,host);
  return host;
}

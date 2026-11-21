// SPDX-License-Identifier: MIT
// Cockpit plugin columns (owner D121/D124, D293): the registry. A plugin is a fixed, bundled module; the registry never
// loads code, markup or icons from the host or the wire. Settings and Swift mirror the ids, setting ranges and the
// one-sentence summary in ModelPlanSettings/CockpitPluginPreferences.swift (checked by tests/cockpit/unit/plugins.test.mjs).
//
// D293 (CKP-PLG-50/51): a plugin does not draw its own panel. It describes up to three cells in the Other-cell grammar of
// the subscription columns (small tag · large number · side value · continuous bar with a thin trend line below) and an
// optional bottom line; the host draws them in the table's own rows, so plugin columns look and align like subscriptions.
// D323: a plugin that cells cannot express (a day strip, a week grid) may add `draw` to its column or screen and paint
// inside the area the host gives it; everything around that area stays the framework's.
// Pure: no DOM and no string tables here (the host resolves `plugin.*` keys), so the bridge and unit tests can load it.
import type {WireCockpitData} from '../generated/wire.js';
export type PluginLocale='en'|'zh-CN';
/** One per-plugin setting. `seconds` is a whole number of seconds inside [min, max] (e.g. sampling 3–30 s, D124). */
/** `choices`, when given, are the only values a user can pick (Settings shows them as one segmented control). */
export interface PluginSettingSpec {readonly key:string;readonly kind:'seconds';readonly min:number;readonly max:number;readonly default:number;readonly choices?:readonly number[]}
/** A drawn string in its two forms (long first; the short one is used when the long one does not fit). */
export interface PluginWords {readonly full:string;readonly short:string}
export interface PluginContext {
  readonly locale:PluginLocale;readonly settings:Readonly<Record<string,number>>;
  /** The host's clock (epoch ms): the time of the latest display render or deadline tick; the page has no clock of its
   *  own. 0 until the first display data arrives. */
  readonly now:number;
  /** Long and short forms of a `plugin.*` string-table key (`<key>Short` when it exists). */
  words(key:string,vars?:Readonly<Record<string,string|number>>):PluginWords;
  /** The plugin's view memory (D328: the week view's selected day, read by the column's bottom line). */
  readonly memo?:Record<string,unknown>;
}
export interface PluginCell {
  readonly tag:PluginWords;
  /** The large number. Absent when unknown: the cell then shows its tag and side text only (no "--", rule 2). */
  readonly value?:number|null;
  /** Small unit after the number, e.g. "%". */
  readonly unit?:string;
  readonly side?:PluginWords|null;
  /** Continuous bar fill, 0–1; absent draws no bar. */
  readonly bar?:number|null;
  /** Thin trend line under the bar, oldest first, each 0–1; fewer than two points draws none. */
  readonly trend?:readonly number[]|null;
  /** Past a warning line only the number turns amber (mid) or red (low). */
  readonly level?:'mid'|'low'|null;
}
export interface PluginColumn {
  /** Up to three cells, top row first; rows without a cell stay empty. Also the fallback when `draw` fails. */
  readonly cells:readonly PluginCell[];
  /** The bottom line (the subscriptions' "today" row): a label and an optional value. */
  readonly foot?:{readonly label:PluginWords;readonly value?:PluginWords|null}|null;
  /** D323 custom draw: when present, the host gives the plugin the column's cell area (every cell row, above the bottom
   *  line) and calls this instead of drawing `cells`. If it throws, the host draws `cells` instead. */
  readonly draw?:((context:PluginDrawContext)=>void)|null;
}
export interface PluginScreen {
  /** Label/value lines; also the fallback when `draw` fails. */
  readonly lines:readonly {readonly label:string;readonly value:string}[];
  /** D323 custom draw: the big screen's body below the framework's title bar. If it throws, `lines` are shown. */
  readonly draw?:((context:PluginDrawContext)=>void)|null;
}
/** D293 colours: only these instrument inks (V1-FINAL §0 white / grey, resource silver #b9c7d6) and the D327 resource
 *  plugin's orchid #da66c2 (it replaces the silver for the resource plugin; the silver stays allowed for other plugins). */
export const PLUGIN_INKS:readonly string[]=Object.freeze(['#87939e','#e9edf0','#b9c7d6','#da66c2']);
/** D323: the cockpit tokens a custom draw paints with (CSS values; the variables are defined by the cockpit sheets). */
export const PLUGIN_TOKENS=Object.freeze({
  ink:'var(--lcd-ink)',muted:'var(--lcd-muted)',ghost:'var(--lcd-ghost)',rule:'var(--lcd-rule)',
  ok:'var(--st-ok)',mid:'var(--st-mid)',low:'var(--st-low)',
  silk:'var(--silk-hi)',lcdFont:'var(--f-lcd)',silkFont:'var(--f-silk)',
} as const);
export type PluginToken=keyof typeof PLUGIN_TOKENS;
/** D323 custom draw. The framework owns the key, its underline, pin, the "+" menu, the bottom line, the big screen's
 *  title bar and the lifecycle; a plugin with `draw` paints only inside `area`, an empty box the host clips (overflow and
 *  paint containment), using `tokens` and the plugin's declared inks. The host redraws on every reading, repaint, locale
 *  change and size change; focus on an element marked `data-focus="<stable key>"` survives a redraw. */
export interface PluginDrawContext extends PluginContext {
  /** The empty, clipped box to draw into (type only: the registry itself never touches the DOM). */
  readonly area:HTMLElement;
  /** The area's size in CSS pixels at draw time (0 before it is laid out; the host draws again once it is). */
  readonly width:number;readonly height:number;
  readonly tokens:typeof PLUGIN_TOKENS;
  /** The plugin's view memory (a selected day, a zoom): shared by its column and screen, kept across redraws, dropped
   *  when the plugin is removed. Readings belong in `accept`'s state, not here. */
  readonly memo:Record<string,unknown>;
  /** True on the first draw of a newly opened big screen (per-open view state starts over). Always false in a column. */
  readonly opening:boolean;
  /** Draw the plugin again after a click inside it changed `memo`: its column and, when open, its screen. */
  redraw():void;
}
export interface CockpitPlugin {
  readonly id:string;
  /** `plugin.*` string-table keys: the key name (with a Short form) and the one-sentence summary for Settings. */
  readonly title:string;
  readonly summary:string;
  /** Trusted, bundled SVG markup: white line art at the vendor-mark size (16 px, 1.3 px stroke, currentColor). */
  readonly icon:string;
  /** The key's dashed underline colour, declared by the plugin (one of PLUGIN_INKS). */
  readonly underline:string;
  /** Bar and trend-line colour (one of PLUGIN_INKS); the instrument white when absent. */
  readonly ink?:string;
  /** D121: plugins are default on once they ship; the framework placeholder is not. */
  readonly defaultEnabled:boolean;
  /** The host samples this plugin's readings (e.g. the resource plugin). Such a plugin is drawn only for a host that sent
   *  its plugin state, so a host that cannot sample never shows an empty column. */
  readonly hostSampled?:boolean;
  readonly settings:readonly PluginSettingSpec[];
  /** Folds a host reading (`pluginData`) into the plugin's state; `undefined` refuses it. The state survives repaints. */
  accept(data:unknown,previous:unknown):unknown;
  column(state:unknown,context:PluginContext):PluginColumn;
  /** The plugin's big screen, opened from its key inside the big-screen area (CKP-PLG-53). */
  screen(state:unknown,context:PluginContext):PluginScreen;
  /** v1.1 (calendar): shape a reading from the cockpit display data the page already has (no network, no host round
   *  trip). Called for a running plugin on each display render and deadline tick; the result goes through `accept`
   *  exactly like a host push. A host that pushes `pluginData` for this plugin takes over: shaping stops for it. */
  derive?(display:WireCockpitData,now:number):unknown;
  /** v1.1 (calendar): the next time (epoch ms) this running plugin must be drawn again (a now line, a day rollover).
   *  The page reports the earliest to the host with its own deadlines; the host's tick then redraws it. No page timers. */
  nextDeadline?(state:unknown,now:number):number|null;
}
export const PLUGIN_ID=/^[a-z][a-z0-9-]{0,31}$/;
const SETTING_KEY=/^[a-zA-Z][a-zA-Z0-9]{0,31}$/;
export class PluginRegistry {
  readonly #plugins=new Map<string,CockpitPlugin>();
  constructor(plugins:readonly CockpitPlugin[]) {
    if(plugins.length>16)throw TypeError('Too many cockpit plugins');
    for(const plugin of plugins){
      if(!PLUGIN_ID.test(plugin.id)||this.#plugins.has(plugin.id))throw TypeError('Invalid cockpit plugin id');
      if(!/^plugin\.\w+$/.test(plugin.title)||!/^plugin\.\w+$/.test(plugin.summary)||typeof plugin.column!=='function'||typeof plugin.screen!=='function'||typeof plugin.accept!=='function'||plugin.derive!==undefined&&typeof plugin.derive!=='function'||plugin.nextDeadline!==undefined&&typeof plugin.nextDeadline!=='function')throw TypeError('Invalid cockpit plugin');
      if(!PLUGIN_INKS.includes(plugin.underline)||plugin.ink!==undefined&&!PLUGIN_INKS.includes(plugin.ink))throw TypeError('Invalid cockpit plugin colour');
      const keys=new Set<string>();
      for(const s of plugin.settings){
        if(!SETTING_KEY.test(s.key)||keys.has(s.key)||!Number.isSafeInteger(s.min)||!Number.isSafeInteger(s.max)||!Number.isSafeInteger(s.default)||s.min<1||s.min>s.default||s.default>s.max||s.max>86400||s.choices!==undefined&&(!s.choices.length||!s.choices.includes(s.default)||s.choices.some(c=>!Number.isSafeInteger(c)||c<s.min||c>s.max)))throw TypeError('Invalid cockpit plugin setting');
        keys.add(s.key);
      }
      this.#plugins.set(plugin.id,plugin);
    }
  }
  get(id:string):CockpitPlugin|null {return this.#plugins.get(id)??null;}
  list():CockpitPlugin[] {return [...this.#plugins.values()];}
}
// The white line-art frame shared by plugin icons: a 16 px rounded screen at the vendor marks' stroke weight.
export const PLUGIN_ICON_FRAME='<rect x="1" y="1.5" width="14" height="13" rx="3" fill="none" stroke="currentColor" stroke-width="1.3"/>';
/** Framework placeholder until the real plugins land: shows the last value (0–100) the host pushed. */
export const placeholderPlugin:CockpitPlugin=Object.freeze({
  id:'placeholder',
  title:'plugin.placeholderTitle',
  summary:'plugin.placeholderSummary',
  icon:`<svg viewBox="0 0 16 16" aria-hidden="true">${PLUGIN_ICON_FRAME}<circle cx="8" cy="8" r="2" fill="none" stroke="currentColor" stroke-width="1.3"/></svg>`,
  underline:'#87939e',
  defaultEnabled:false,
  settings:Object.freeze([Object.freeze({key:'intervalSeconds',kind:'seconds' as const,min:3,max:30,default:10})]),
  accept(data:unknown,previous:unknown){
    const value=(data as {value?:unknown}|null)?.value;
    if(data===null||typeof data!=='object'||Object.keys(data).length!==1||typeof value!=='number'||!Number.isSafeInteger(value)||value<0||value>100)return undefined;
    const history=Array.isArray(previous)?previous as number[]:[];
    return Object.freeze([...history,value].slice(-24));
  },
  column(state:unknown,context:PluginContext):PluginColumn{
    const history=Array.isArray(state)?state as number[]:[],value=history.length?history[history.length-1]:null;
    return {cells:[{tag:context.words('plugin.placeholderTag'),value,unit:value===null?undefined:'%',side:context.words('plugin.placeholderEvery',{n:context.settings.intervalSeconds}),
      bar:value===null?null:value/100,trend:history.map(v=>v/100)}],foot:{label:context.words('plugin.placeholderFoot')}};
  },
  screen(state:unknown,context:PluginContext):PluginScreen{
    const history=Array.isArray(state)?state as number[]:[],value=history.length?history[history.length-1]:null;
    return {lines:[...(value===null?[]:[{label:context.words('plugin.placeholderScreenValue').full,value:`${value}%`}]),
      {label:context.words('plugin.placeholderScreenEvery').full,value:context.words('plugin.placeholderEvery',{n:context.settings.intervalSeconds}).full}]};
  },
});
// The bundled list (placeholder, calendar, resources) is in plugin-builtins.ts, so this module stays free of plugin drawing code.

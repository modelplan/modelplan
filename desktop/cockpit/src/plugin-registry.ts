// SPDX-License-Identifier: MIT
// v1.1 cockpit plugin columns (owner D121/D124/D126/D127): the registry. A plugin is a fixed, bundled module; the
// registry never loads code, markup or icons from the host or the wire. Settings and Swift mirror the ids, titles and
// setting ranges in ModelPlanSettings/CockpitPluginPreferences.swift (CockpitPluginCatalogue) (checked by tests/cockpit/unit/plugins.test.mjs).
import type {WireCockpitData} from '../generated/wire.js';
import {exact} from './schema.js';
export type PluginLocale='en'|'zh-CN';
export interface PluginText {readonly en:string;readonly 'zh-CN':string}
/** One per-plugin setting. `seconds` is a whole number of seconds inside [min, max] (e.g. sampling 3–30 s, D124). */
export interface PluginSettingSpec {readonly key:string;readonly kind:'seconds';readonly min:number;readonly max:number;readonly default:number;readonly label:PluginText}
export interface PluginContext {
  readonly locale:PluginLocale;readonly settings:Readonly<Record<string,number>>;
  /** The host's clock: the time of the latest display render or deadline tick (the page has no clock of its own). */
  readonly now:number;
}
/** v1.1 calendar additions: each plugin declares the shape of its data. The framework refuses anything larger than
 *  `maxBytes` (as JSON, capped at PLUGIN_DATA_MAX_BYTES) before `parse` sees it; `parse` is the plugin's strict
 *  structural check (exact keys, bounded lists) and returns the value `update` receives, or null to refuse it. */
export interface PluginDataSpec<T=unknown> {readonly maxBytes:number;parse(raw:unknown):T|null}
export const PLUGIN_DATA_MAX_BYTES=64*1024;
/** Context of an expanded view (CKP-PLG-07): a temporary overlay inside the MFD screen only. */
export interface PluginOverlayContext extends PluginContext {
  /** True on the render that opens the overlay: per-open view state (zoom, scroll) starts over. */
  readonly opening:boolean;
  /** The MFD page the overlay sits over, for its "‹ Back to <page>" key. */
  readonly returnTo:string;
  /** The overlay header's status slot (right of the title), e.g. a zoom note. */
  readonly status:HTMLElement;
  /** Close the overlay. */
  close():void;
}
export interface PluginExpand {
  readonly title:PluginText;
  /** Draws the overlay body into `body` (the framework owns the frame). Called on open and again after each update,
   *  tick or locale change while open. `panel` is the plugin's column panel, for views that act on it. */
  render(body:HTMLElement,panel:HTMLElement,context:PluginOverlayContext):void;
  /** Keys while the overlay is open (before Esc closes it); true when handled. */
  key?(event:KeyboardEvent,body:HTMLElement,panel:HTMLElement,context:PluginOverlayContext):boolean;
}
export interface CockpitPlugin {
  readonly id:string;
  readonly title:PluginText;
  /** Trusted, bundled SVG markup (16 px, currentColor); never data from the host. */
  readonly icon:string;
  /** D121: plugins are default on once they ship; the framework placeholder is not. */
  readonly defaultEnabled:boolean;
  readonly settings:readonly PluginSettingSpec[];
  /** Draws the panel. Called when the panel is created and again when the locale or a setting changes. */
  render(panel:HTMLElement,context:PluginContext):void;
  /** Called only while the cockpit is open and this plugin's column is on the shown page (D124: no background sampling). */
  start?(panel:HTMLElement,context:PluginContext):void;
  stop?(panel:HTMLElement):void;
  /** Readings pushed by the host (`pluginData`), delivered only while running. The page has no timers of its own:
   *  the host samples, at the plugin's interval, exactly the plugins the page reports as running (`pluginsRunning`).
   *  Returns false for data this plugin does not accept. */
  update?(panel:HTMLElement,data:unknown,context:PluginContext):boolean;
  /** The data shape `update` accepts. A plugin without one receives no data. */
  readonly data?:PluginDataSpec;
  /** Host-side shaping from the cockpit display data the page already has (no network, no host round trip): called
   *  for a running plugin on each display render and deadline tick, and its result goes through `data` and `update`
   *  exactly like a host push. A host that pushes `pluginData` for this plugin takes over: shaping stops for it. */
  derive?(display:WireCockpitData,now:number):unknown;
  /** Host-driven tick: the next time (epoch ms) this running plugin must repaint (a now line, a day rollover). The
   *  page reports the earliest one in `nextDeadline`; the host's `tick` then reaches `tick` here. No page timers. */
  nextDeadline?(panel:HTMLElement,now:number):number|null;
  tick?(panel:HTMLElement,context:PluginContext):void;
  /** Opt in to "expand on MFD" (CKP-PLG-07): a click on the plugin's column or key (not on its own buttons) opens
   *  this view as an overlay inside the MFD screen; the faders and MFD page keys stay usable. */
  readonly expand?:PluginExpand;
}
export const PLUGIN_ID=/^[a-z][a-z0-9-]{0,31}$/;
const SETTING_KEY=/^[a-zA-Z][a-zA-Z0-9]{0,31}$/;
export class PluginRegistry {
  readonly #plugins=new Map<string,CockpitPlugin>();
  constructor(plugins:readonly CockpitPlugin[]) {
    if(plugins.length>16)throw TypeError('Too many cockpit plugins');
    for(const plugin of plugins){
      if(!PLUGIN_ID.test(plugin.id)||this.#plugins.has(plugin.id))throw TypeError('Invalid cockpit plugin id');
      if(!plugin.title.en||!plugin.title['zh-CN']||typeof plugin.render!=='function')throw TypeError('Invalid cockpit plugin');
      if(plugin.update&&(!plugin.data||!Number.isSafeInteger(plugin.data.maxBytes)||plugin.data.maxBytes<1||plugin.data.maxBytes>PLUGIN_DATA_MAX_BYTES||typeof plugin.data.parse!=='function'))throw TypeError('Cockpit plugin data needs a bounded shape');
      if(plugin.derive&&!plugin.update)throw TypeError('Cockpit plugin derive needs update');
      if(plugin.expand&&(!plugin.expand.title.en||!plugin.expand.title['zh-CN']||typeof plugin.expand.render!=='function'))throw TypeError('Invalid cockpit plugin overlay');
      const keys=new Set<string>();
      for(const s of plugin.settings){
        if(!SETTING_KEY.test(s.key)||keys.has(s.key)||!Number.isSafeInteger(s.min)||!Number.isSafeInteger(s.max)||!Number.isSafeInteger(s.default)||s.min<1||s.min>s.default||s.default>s.max||s.max>86400)throw TypeError('Invalid cockpit plugin setting');
        keys.add(s.key);
      }
      this.#plugins.set(plugin.id,plugin);
    }
  }
  get(id:string):CockpitPlugin|null {return this.#plugins.get(id)??null;}
  list():CockpitPlugin[] {return [...this.#plugins.values()];}
}
const el=(tag:string,className:string,text?:string)=>{const e=document.createElement(tag);e.className=className;if(text!==undefined)e.textContent=text;return e;};
// The shared plugin icon frame (D124 option 2 / D127 1a): a 16 px rounded screen, 1 px outline, grey.
export const PLUGIN_ICON_FRAME='<rect x="1.5" y="2.5" width="13" height="11" rx="2.2" fill="none" stroke="currentColor" stroke-width="1"/>';
/** Framework placeholder until the resource and cost plugins land: shows the last value the host pushed. */
const values=new WeakMap<HTMLElement,number>();
const paintPlaceholder=(panel:HTMLElement,context:PluginContext)=>{
  const zh=context.locale==='zh-CN',seconds=context.settings.intervalSeconds,value=values.get(panel);
  const head=el('div','pp-h');head.append(el('span','',zh?'占位插件':'Placeholder'),el('em','',`${seconds}${zh?' 秒':' s'}`));
  panel.replaceChildren(head,el('b','pp-count',value===undefined?'--':String(value)),el('div','pp-foot',zh?'插件框架':'Plugin framework'));
  if(value===undefined)delete panel.dataset.value;else panel.dataset.value=String(value);
};
export const placeholderPlugin:CockpitPlugin=Object.freeze({
  id:'placeholder',
  title:Object.freeze({en:'Placeholder','zh-CN':'占位插件'}),
  icon:`<svg viewBox="0 0 16 16" aria-hidden="true">${PLUGIN_ICON_FRAME}<circle cx="8" cy="8" r="1.6" fill="currentColor"/></svg>`,
  defaultEnabled:false,
  settings:Object.freeze([Object.freeze({key:'intervalSeconds',kind:'seconds' as const,min:3,max:30,default:10,label:Object.freeze({en:'Update interval','zh-CN':'更新间隔'})})]),
  render:paintPlaceholder,
  data:Object.freeze({maxBytes:64,parse:(raw:unknown)=>exact(raw,['value'])&&typeof raw.value==='number'&&Number.isSafeInteger(raw.value)?raw.value:null}),
  update(panel:HTMLElement,value:unknown,context:PluginContext){
    if(typeof value!=='number')return false;
    values.set(panel,value);paintPlaceholder(panel,context);return true;
  },
});

// SPDX-License-Identifier: MIT
// Persisted plugin choices: which plugins are on, their order, which are pinned to page 1, and per-plugin settings.
// The host owns the durable copy (Settings, CockpitPluginPreferences.swift); the page applies the same rules so an
// edit made on the page (× on a key, "Add" in the + menu) and one made in Settings agree.
import {PLUGIN_ID,type PluginRegistry} from './plugin-registry.js';
import {exact,record} from './schema.js';
export const MAX_PINNED=2;
export const MAX_ENTRIES=32;
export interface PluginEntry {readonly id:string;readonly enabled:boolean;readonly pinned:boolean}
export interface PluginState {
  readonly version:1;
  /** User order. Unknown ids (a plugin from a newer build) are kept so a round trip never drops them. */
  readonly entries:readonly PluginEntry[];
  readonly settings:Readonly<Record<string,Readonly<Record<string,number>>>>;
}
export const emptyPluginState:PluginState=Object.freeze({version:1,entries:Object.freeze([]),settings:Object.freeze({})});
const SETTING_KEY=/^[a-zA-Z][a-zA-Z0-9]{0,31}$/;
/** Strict structural check for state that crosses the bridge. Ranges are applied later against the registry. */
export function parsePluginState(value:unknown):PluginState|null {
  if(!exact(value,['version','entries','settings'])||value.version!==1||!Array.isArray(value.entries)||value.entries.length>MAX_ENTRIES||!record(value.settings))return null;
  const ids=new Set<string>();let pinned=0;const entries:PluginEntry[]=[];
  for(const entry of value.entries as unknown[]){
    if(!exact(entry,['id','enabled','pinned'])||typeof entry.id!=='string'||!PLUGIN_ID.test(entry.id)||ids.has(entry.id)||typeof entry.enabled!=='boolean'||typeof entry.pinned!=='boolean')return null;
    if(entry.pinned&&(!entry.enabled||++pinned>MAX_PINNED))return null;
    ids.add(entry.id);entries.push(Object.freeze({id:entry.id,enabled:entry.enabled,pinned:entry.pinned}));
  }
  const settings:Record<string,Readonly<Record<string,number>>>={};const owners=Object.keys(value.settings);
  if(owners.length>MAX_ENTRIES)return null;
  for(const id of owners){
    const values=(value.settings as Record<string,unknown>)[id];
    if(!PLUGIN_ID.test(id)||!record(values))return null;
    const keys=Object.keys(values);if(keys.length>8)return null;
    const copy:Record<string,number>={};
    for(const key of keys){const v=values[key];if(!SETTING_KEY.test(key)||typeof v!=='number'||!Number.isSafeInteger(v)||v<0||v>86400)return null;copy[key]=v;}
    settings[id]=Object.freeze(copy);
  }
  return Object.freeze({version:1,entries:Object.freeze(entries),settings:Object.freeze(settings)});
}
/** Every registered plugin gets an entry: missing ones are appended in registry order with their default (or off,
 *  when `defaults` is false: a page whose host never sent plugin state shows no default-on plugin). */
export function materialize(state:PluginState,registry:PluginRegistry,defaults=true):PluginState {
  const known=new Set(state.entries.map(e=>e.id)),missing=registry.list().filter(p=>!known.has(p.id));
  if(!missing.length)return state;
  return {...state,entries:[...state.entries,...missing.map(p=>({id:p.id,enabled:defaults&&p.defaultEnabled,pinned:false}))]};
}
export interface ResolvedPlugin {readonly id:string;readonly pinned:boolean;readonly settings:Readonly<Record<string,number>>}
/** The enabled, registered plugins in user order, each with complete in-range settings. */
export function enabledPlugins(state:PluginState,registry:PluginRegistry,defaults=true):ResolvedPlugin[] {
  return materialize(state,registry,defaults).entries.filter(e=>e.enabled&&registry.get(e.id)).map(e=>({id:e.id,pinned:e.pinned,settings:pluginSettings(state,registry,e.id)}));
}
export function pluginSettings(state:PluginState,registry:PluginRegistry,id:string):Readonly<Record<string,number>> {
  const out:Record<string,number>={},saved=state.settings[id]??{};
  for(const spec of registry.get(id)?.settings??[]){const v=saved[spec.key];out[spec.key]=Number.isSafeInteger(v)&&v>=spec.min&&v<=spec.max?v:spec.default;}
  return Object.freeze(out);
}
const replace=(state:PluginState,registry:PluginRegistry,id:string,edit:(e:PluginEntry)=>PluginEntry,defaults=true):PluginState|null=>{
  const full=materialize(state,registry,defaults);if(!full.entries.some(e=>e.id===id))return null;
  return {...full,entries:full.entries.map(e=>e.id===id?edit(e):e)};
};
/** Add (or re-add) a plugin. Returns null for an unregistered id. */
export const enablePlugin=(state:PluginState,registry:PluginRegistry,id:string,defaults=true)=>registry.get(id)?replace(state,registry,id,e=>({...e,enabled:true}),defaults):null;
/** Remove = turn off; the entry keeps its place in the order. Removing also unpins. */
export const disablePlugin=(state:PluginState,registry:PluginRegistry,id:string,defaults=true)=>replace(state,registry,id,e=>({...e,enabled:false,pinned:false}),defaults);
/** Pin to page 1 (at most two). Returns null when the plugin is off or two others are already pinned. */
export function pinPlugin(state:PluginState,registry:PluginRegistry,id:string,pinned:boolean):PluginState|null {
  const full=materialize(state,registry),entry=full.entries.find(e=>e.id===id);
  if(!entry||pinned&&(!entry.enabled||full.entries.filter(e=>e.pinned&&e.id!==id).length>=MAX_PINNED))return null;
  return replace(full,registry,id,e=>({...e,pinned}));
}
/** Move one step earlier (-1) or later (+1) in the order. */
export function movePlugin(state:PluginState,registry:PluginRegistry,id:string,step:-1|1):PluginState|null {
  const full=materialize(state,registry),i=full.entries.findIndex(e=>e.id===id),j=i+step;
  if(i<0||j<0||j>=full.entries.length)return null;
  const entries=[...full.entries];[entries[i],entries[j]]=[entries[j],entries[i]];return {...full,entries};
}
export function setPluginSetting(state:PluginState,registry:PluginRegistry,id:string,key:string,value:number):PluginState|null {
  const spec=registry.get(id)?.settings.find(s=>s.key===key);
  if(!spec||!Number.isSafeInteger(value)||value<spec.min||value>spec.max)return null;
  return {...state,settings:{...state.settings,[id]:{...(state.settings[id]??{}),[key]:value}}};
}

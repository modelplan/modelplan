// SPDX-License-Identifier: MIT
// The page side of the v1.1 plugin columns: lays plugins into the engine table, keeps one long-lived panel per
// plugin across repaints, runs the start/stop lifecycle and the empty-slot "+" menu.
//
// Lifecycle (owner D124): a plugin runs only while the cockpit is open (the page is visible and not occluded) AND its
// column is on the shown page (placed by the latest drawn table; a new table is drawn before it is attached, so
// placement, not DOM connection, is the test). Every repaint, page change, visibility change, removal or teardown re-checks that, so
// nothing samples in the background. Panels survive repaints so a plugin keeps its own history (e.g. a 10-minute line).
//
// The page has no timers (bundle rule). The host samples: the page reports the plugins that are running
// (`pluginsRunning`, on every change) and the host pushes readings for them (`pluginData`), which reach a plugin only
// while it runs.
//
// State: the host (Settings) owns the durable copy and sends it as a `plugins` message. Until the host has sent one,
// page edits stay in this page only and nothing is posted, so an older host never sees an action it does not know.
import type {WireCockpitData,WireRow} from '../generated/wire.js';
import {PluginRegistry,builtinPlugins,type CockpitPlugin,type PluginLocale} from './plugin-registry.js';
import {pluginLayout,type LayoutPage,type PluginLayout} from './plugin-layout.js';
import {disablePlugin,emptyPluginState,enablePlugin,enabledPlugins,parsePluginState,pluginSettings,type PluginState} from './plugin-state.js';
const words={
  en:{remove:'Remove',plugin:'plugin',connect:'Connect a subscription',detected:'Detected',notConnected:'Not connected',go:'Connect',all:'All subscriptions…',add:'Add a plugin',added:'✓ Added',addGo:'Add',menu:'Add to the engine table'},
  'zh-CN':{remove:'移除',plugin:'插件',connect:'连接订阅',detected:'已检测到',notConnected:'未连接',go:'连接',all:'全部订阅…',add:'添加插件',added:'✓ 已添加',addGo:'添加',menu:'添加到引擎表'},
} as const;
const DETECTED=new Set<WireRow['state']>(['needs_action','needs_consent','needs_keychain']);
const NOT_CONNECTED=new Set<WireRow['state']>(['off']);
const MENU_ROWS=5;
/** '+' menu rows: tools the engine found but that have no connected account, detected ones first. */
export function connectableRows(data:WireCockpitData|null):{row:WireRow;detected:boolean}[] {
  const rows=(data?.projection.rows??[]).filter(row=>row.kind==='tool'&&row.accounts.length===0);
  return [...rows.filter(r=>DETECTED.has(r.state)).map(row=>({row,detected:true})),...rows.filter(r=>NOT_CONNECTED.has(r.state)).map(row=>({row,detected:false}))].slice(0,MENU_ROWS);
}
const el=<K extends keyof HTMLElementTagNameMap>(tag:K,className?:string,text?:string)=>{const e=document.createElement(tag);if(className)e.className=className;if(text!==undefined)e.textContent=text;return e;};
const icon=(plugin:CockpitPlugin,className:string)=>{const span=el('span',className);span.setAttribute('aria-hidden','true');span.innerHTML=plugin.icon;return span;};
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
  setVisible(visible:boolean):void;
  setInteractive(interactive:boolean):void;
  setLocale(locale:PluginLocale):void;
  applyHostState(raw:unknown):boolean;
  /** A host reading for a running plugin; false when the plugin is not running or refuses the data. */
  deliver(id:string,data:unknown):boolean;
  remove(id:string):boolean;
  add(id:string):boolean;
  openMenu(anchor:HTMLElement,options:MenuOptions):boolean;
  closeMenu():void;
  /** Plugins currently running (for tests and diagnostics). */
  running():string[];
  dispose():void;
}
const hosts=new WeakMap<HTMLElement,PluginHost>();
export const pluginHostOf=(root:HTMLElement)=>hosts.get(root)??null;
export interface PluginReports {
  /** The page changed the plugin choices (× on a key, "Add" in the + menu). */
  readonly state:(state:PluginState)=>void;
  /** The plugins now running, in user order; the host samples exactly these. */
  readonly running:(ids:string[])=>void;
}
export function mountPluginHost(root:HTMLElement,report:PluginReports,registry=new PluginRegistry(builtinPlugins)):PluginHost {
  let state:PluginState=emptyPluginState,negotiated=false,visible=false,interactive=false,disposed=false,locale:PluginLocale='en';
  let repaint:(()=>void)|null=null,menu:HTMLElement|null=null,menuAnchor:HTMLElement|null=null,reported:string|null=null;
  const panels=new Map<string,HTMLElement>(),drawnWith=new Map<string,string>(),running=new Set<string>(),placed=new Set<string>();
  const guard=(fn:()=>void)=>{try{fn();}catch{/* A plugin failure never takes the cockpit down. */}};
  const context=(id:string)=>({locale,settings:pluginSettings(state,registry,id)});
  const signature=(id:string)=>locale+JSON.stringify(pluginSettings(state,registry,id));
  function panelFor(plugin:CockpitPlugin):HTMLElement {
    let panel=panels.get(plugin.id);
    if(!panel){panel=el('div','pl-panel');panel.dataset.plugin=plugin.id;panels.set(plugin.id,panel);}
    if(drawnWith.get(plugin.id)!==signature(plugin.id)){
      const wasRunning=running.has(plugin.id);
      if(wasRunning){running.delete(plugin.id);guard(()=>plugin.stop?.(panel!));}
      drawnWith.set(plugin.id,signature(plugin.id));guard(()=>plugin.render(panel!,context(plugin.id)));
      if(wasRunning&&shouldRun(plugin.id)){running.add(plugin.id);guard(()=>plugin.start?.(panel!,context(plugin.id)));}
    }
    return panel;
  }
  const shouldRun=(id:string)=>!disposed&&visible&&placed.has(id)&&panels.has(id)&&enabledPlugins(state,registry).some(p=>p.id===id);
  function reconcile() {
    for(const id of [...running])if(!shouldRun(id)){running.delete(id);const p=registry.get(id),panel=panels.get(id);if(p&&panel)guard(()=>p.stop?.(panel));}
    for(const id of placed)if(!running.has(id)&&shouldRun(id)){const p=registry.get(id),panel=panels.get(id);if(p&&panel){running.add(id);guard(()=>p.start?.(panel,context(id)));}}
    for(const [id,panel] of panels)panel.dataset.running=String(running.has(id));
    if(negotiated&&!disposed){const ids=enabledPlugins(state,registry).map(p=>p.id).filter(id=>running.has(id)),key=ids.join();if(key!==reported){reported=key;report.running(ids);}}
  }
  function changed(next:PluginState|null) {
    if(!next||disposed)return false;
    state=next;if(negotiated)report.state(state);
    for(const id of [...panels.keys()])if(!enabledPlugins(state,registry).some(p=>p.id===id))placed.delete(id);
    reconcile();repaint?.();return true;
  }
  function closeMenu(restoreFocus=false) {
    if(!menu)return;menu.remove();menu=null;
    document.removeEventListener('pointerdown',outside,true);document.removeEventListener('keydown',escape,true);
    menuAnchor?.classList.remove('on');menuAnchor?.setAttribute('aria-expanded','false');if(restoreFocus&&menuAnchor?.isConnected)menuAnchor.focus();menuAnchor=null;
  }
  const outside=(e:Event)=>{if(menu&&!menu.contains(e.target as Node)&&!menuAnchor?.contains(e.target as Node))closeMenu();};
  const escape=(e:KeyboardEvent)=>{if(e.key==='Escape'&&menu){e.preventDefault();e.stopPropagation();closeMenu(true);}};
  const host:PluginHost={
    registry,
    state:()=>state,
    layout:subscriptions=>pluginLayout(subscriptions,enabledPlugins(state,registry)),
    bindEngine(next){repaint=next;},
    decorate(table,page,value){
      locale=value;placed.clear();
      const keys=[...table.querySelectorAll<HTMLElement>('.eng-keys > .ek-bay')],cols=[...table.querySelectorAll<HTMLElement>('.eng-cols > .ec-bay')];
      const w=words[locale];
      page.plugins.forEach((id,i)=>{
        const plugin=registry.get(id);if(!plugin||!keys[i]||!cols[i])return;
        const title=plugin.title[locale];
        const key=el('div','ek pl-key'+(i===0?' pl-first':''));key.dataset.plugin=id;key.dataset.mat='part';key.setAttribute('role','group');key.setAttribute('aria-label',`${title} · ${w.plugin}`);
        const identity=el('span','ek-identity');identity.append(icon(plugin,'pl-icon'),el('span','ek-name',title));
        const x=el('button','pl-x','×');x.type='button';x.dataset.pluginRemove=id;x.setAttribute('aria-label',`${w.remove} ${title}`);x.title=`${w.remove} ${title}`;
        key.append(identity,x);keys[i].replaceWith(key);
        const col=el('div','ec pl-col pl-b'+(i===0?' pl-first':''));col.dataset.plugin=id;col.setAttribute('role','group');col.setAttribute('aria-label',title);
        col.append(panelFor(plugin));cols[i].replaceWith(col);placed.add(id);
      });
      reconcile();
    },
    clearPlacement(){placed.clear();closeMenu();reconcile();},
    setVisible(value){visible=value;reconcile();},
    setInteractive(value){interactive=value;if(!value)closeMenu();},
    setLocale(value){if(locale===value)return;locale=value;for(const id of panels.keys()){const p=registry.get(id);if(p)panelFor(p);}reconcile();},
    applyHostState(raw){
      const next=parsePluginState(raw);if(!next||disposed)return false;
      if(!negotiated)reported=null;negotiated=true;state=next;
      for(const id of [...panels.keys()]){const p=registry.get(id);if(p&&drawnWith.has(id))panelFor(p);}
      reconcile();repaint?.();return true;
    },
    deliver(id,data){
      const plugin=registry.get(id),panel=panels.get(id);
      if(!plugin?.update||!panel||!running.has(id))return false;
      let accepted=false;guard(()=>{accepted=plugin.update!(panel,data,context(id));});return accepted;
    },
    remove:id=>changed(disablePlugin(state,registry,id)),
    add:id=>changed(enablePlugin(state,registry,id)),
    openMenu(anchor,options){
      if(disposed||!interactive)return false;
      if(menu&&menuAnchor===anchor){closeMenu();return true;}closeMenu();
      const w=words[options.locale],m=el('div','pl-menu');m.setAttribute('role','menu');m.setAttribute('aria-label',w.menu);m.dataset.mat='glass';
      const item=(className:string,onPick:()=>void,disabled=false)=>{const b=el('button','pm-i'+(className?' '+className:''));b.type='button';b.setAttribute('role','menuitem');if(disabled){b.disabled=true;b.setAttribute('aria-disabled','true');}b.onclick=e=>{if(!e.isTrusted||disabled)return;closeMenu();onPick();};return b;};
      m.append(el('div','pm-h',w.connect));
      for(const {row,detected} of connectableRows(options.data)){
        const b=item('pm-connect',()=>{options.connect();});b.dataset.pmRow=row.id;
        const src=options.mark(row.vendorKey),mark=el('span','pm-mark');mark.setAttribute('aria-hidden','true');
        if(src){const img=el('img');img.src=src;img.alt='';mark.append(img);}
        b.append(mark,el('span','pm-n',options.locale==='en'?row.name.en:row.name.zh),el('em',detected?'pm-det':'',detected?w.detected:w.notConnected),el('b','pm-go'+(detected?'':' dim'),w.go));m.append(b);
      }
      const more=item('pm-more',()=>{options.connect();});more.dataset.pmAll='';more.append(el('span','pm-n',w.all));m.append(more);
      m.append(el('div','pm-sep'),el('div','pm-h',w.add));
      const on=new Set(enabledPlugins(state,registry).map(p=>p.id));
      for(const plugin of registry.list()){
        const added=on.has(plugin.id),b=item('pm-plugin'+(added?' on':''),()=>{host.add(plugin.id);},added);b.dataset.pmPlugin=plugin.id;
        b.append(icon(plugin,'pm-ic'),el('span','pm-n',plugin.title[options.locale]),el('b',added?'pm-ok':'pm-go',added?w.added:w.addGo));m.append(b);
      }
      root.append(m);menu=m;menuAnchor=anchor;anchor.classList.add('on');anchor.setAttribute('aria-expanded','true');
      const r=anchor.getBoundingClientRect();
      m.style.left=Math.max(8,Math.min(window.innerWidth-m.offsetWidth-8,r.left))+'px';
      m.style.top=(r.bottom+6+m.offsetHeight>window.innerHeight-4?Math.max(4,r.top-m.offsetHeight-6):r.bottom+6)+'px';
      document.addEventListener('pointerdown',outside,true);document.addEventListener('keydown',escape,true);
      m.querySelector<HTMLButtonElement>('.pm-i:not([disabled])')?.focus();
      return true;
    },
    closeMenu:()=>closeMenu(),
    running:()=>[...running],
    dispose(){if(disposed)return;closeMenu();placed.clear();visible=false;reconcile();disposed=true;repaint=null;panels.clear();hosts.delete(root);},
  };
  hosts.set(root,host);
  return host;
}

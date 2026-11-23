// SPDX-License-Identifier: MIT
import {withinIdBound} from './caution-ack.js';
import { definitions, type WireCockpitData } from '../generated/wire.js';
import {websiteFields} from './website-link.js';
import { conforms, exact, parseMessage, record } from './schema.js';
import { cockpitMembers } from './members.js';
import {effectiveRedBelow,type RedBelow} from './threshold.js';
import {isCockpitRange,type CockpitRange} from './range.js';
import {parsePluginState,type PluginState} from './plugin-state.js';
import {PLUGIN_ID} from './plugin-registry.js';
export const MAX_MESSAGE_BYTES = 1024 * 1024;
export interface Context { readonly sessionId:string; readonly storeEpoch:string; readonly generation:string; readonly viewRevision:string }
export interface BridgeSource { readonly origin:string; readonly isMainFrame:boolean }
export interface Appearance { readonly theme:'day'|'night'; readonly locale:'en'|'zh-CN'; readonly reduceMotion:boolean; readonly reduceTransparency:boolean; readonly showProjectNames:boolean }
export type LiveAppearance = Appearance;
/** CKP-SHELL-50: `range` is the app's time range, sent with every shell (absent only from an older host: 7d). */
export interface ShellState { readonly profile:'open'|'closed'; readonly attached:boolean; readonly forcedClosed:boolean; readonly tier:'tall'|'compact'; readonly scope:string; readonly range?:CockpitRange }
export type PageAction = 'chooseSetup'|'openSettings'|'openSettingsSubscriptions'|'openHistory'|'close'|'detach'|'putBack'|'shutterToggle'|'scopeSelect'|'rangeSelect'|'openField'|'openWebsite'|'refreshMember';
export interface Header extends Context { readonly version:2; readonly pageId:string; readonly requestId:string; readonly sequence:string }
export type HostMessage = Header & (
  {readonly type:'load'; readonly appearance:Appearance; readonly shell:ShellState; readonly redBelow?:unknown; readonly showUsedPercent?:boolean; readonly showAllModels?:boolean; readonly ackedCautions?:unknown; readonly pinnedModels?:unknown; readonly memberOrder?:readonly string[]; readonly hiddenMembers?:readonly string[]} |
  ({readonly type:'appearance'; readonly redBelow?:unknown; readonly showUsedPercent?:boolean; readonly showAllModels?:boolean; readonly memberOrder?:readonly string[]; readonly hiddenMembers?:readonly string[]} & LiveAppearance) |
  ({readonly type:'shell'} & ShellState) |
  {readonly type:'ignition'; readonly on:boolean} |
  {readonly type:'select'; readonly model:string|null} |
  {readonly type:'fieldClosed'} |
  {readonly type:'display'; readonly data:WireCockpitData} |
  {readonly type:'visibility'; readonly visible:boolean; readonly occluded:boolean; readonly key:boolean} |
  {readonly type:'tick'; readonly nowUnixMs:string; readonly reason:'deadline'|'show'|'wake'|'unlock'|'clockChange'} |
  {readonly type:'clear'} | {readonly type:'unload'} |
  /** Plugin columns (D293): the host's saved plugin choices (CockpitPluginPreferences). */
  {readonly type:'plugins'; readonly plugins:PluginState} |
  /** Plugin columns: a reading the host sampled for a running plugin. */
  {readonly type:'pluginData'; readonly id:string; readonly data:unknown} |
  /** Plugin columns: open this plugin's big screen (a native action such as the widget card's "Cockpit screen ›"). */
  {readonly type:'pluginScreen'; readonly id:string});
export interface CockpitView {
  /** G3-56: caution identities the host remembered as acknowledged; sent before `configure`. */
  restoreAcked?(ids:string[]):void;
  /** D136: the favourite (pinned) model ids the host remembered; sent before `configure`. */
  restorePins?(ids:string[]):void;
  forgetAcked?():void;
  /** memberOrder (D244): the saved subscription order; absent or empty is the engine's default order. */
  configure(appearance:Appearance,redBelow:RedBelow,showUsedPercent?:boolean,showAllModels?:boolean,memberOrder?:readonly string[],hiddenMembers?:readonly string[]):void;
  updateAppearance(appearance:LiveAppearance,now:number,redBelow:RedBelow,showUsedPercent?:boolean,showAllModels?:boolean,memberOrder?:readonly string[],hiddenMembers?:readonly string[]):void;
  shell(state:ShellState):void;
  /** CKP-SHELL-33 (D178/D186): the host lights every base bell with the amber nozzle glow during a rack put-back or key detach. */
  ignite?(on:boolean):void;
  /** WP-22 (macrevb-1062-3): the enlarged field's selection, a public model id or null when it was cleared there. */
  selectModel?(id:string|null):void;
  /** Owner 11-19 (#1062): the enlarged field just closed (any close path); the porthole ignores its bounce. */
  fieldClosed?():void;
  render(data:WireCockpitData,now:number):void;
  clear():void;
  nextDeadline():number|null;
  tick(now:number):void;
  active(active:boolean,now?:number):void;
  /** Open = visible and not occluded (key or not); plugins sample only while this is true (D124). */
  visible?(visible:boolean):void;
  /** Host plugin state; false when it does not fit this page's registry rules. */
  plugins?(state:PluginState):boolean;
  pluginData?(id:string,data:unknown):boolean;
  /** Opens an enabled plugin's big screen (CKP-PLG-53); false when it is not enabled or the page cannot show it. */
  openPluginScreen?(id:string):boolean;
  dispose():void;
}
const header=['version','pageId','requestId','sequence','sessionId','storeEpoch','generation','viewRevision'];
const uuid=(v:unknown):v is string=>typeof v==='string'&&/^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$/i.test(v);
const identity=(v:unknown):v is string=>typeof v==='string'&&v.length>0&&v.length<=128&&!/[\u0000-\u001f\u007f]/.test(v);
const validAcked=(v:unknown):v is string[]=>Array.isArray(v)&&v.length<=64&&v.every(x=>typeof x==='string'&&x.length>0&&withinIdBound(x)&&!/[\u0000-\u001f\u007f]/.test(x));
const uint=(v:unknown):v is string=>typeof v==='string'&&/^(0|[1-9][0-9]{0,19})$/.test(v)&&BigInt(v)<=18446744073709551615n;
const timestamp=(v:unknown):v is string=>typeof v==='string'&&/^(0|[1-9]\d*)$/.test(v)&&v.length<=16&&BigInt(v)<=8640000000000000n;
const same=(a:Context,b:Context)=>a.sessionId===b.sessionId&&a.storeEpoch===b.storeEpoch&&a.generation===b.generation&&a.viewRevision===b.viewRevision;
let why='none';
function validData(value:unknown):value is WireCockpitData {
  const bad=(code:string):false=>{why=code;return false;};
  if(!conforms(value,{$ref:'#/$defs/CockpitData'},definitions)) return bad('data.schema');
  const data=value as WireCockpitData;
  if(data.projection.rowsVersion!==1) return bad('data.rowsVersion');
  if(new Set(data.projection.rows.map(row=>row.id)).size!==data.projection.rows.length) return bad('data.rowDuplicate');
  const ref=(v:string|null)=>v===null||/^[a-f0-9]{16}$/.test(v);
  for(const row of data.projection.rows) {
    if(!identity(row.id)) return bad('data.rowId');
    if((['denied','unset'].includes(row.consent)||row.reason.code==='cleanup_pending')&&row.accounts.length>0) return bad('data.rowAccounts');
    if(row.accounts.some(a=>!ref(a.subscriptionRef)||!ref(a.accountLocator))) return bad('data.accountRef');
  }
  if(new Set(data.subscriptions.map(s=>s.subscriptionRef)).size!==data.subscriptions.length) return bad('data.subDuplicate');
  if(!data.subscriptions.every(s=>s.accounts.every(a=>identity(a.tool)&&ref(a.account.subscriptionRef)&&ref(a.account.accountLocator)))) return bad('data.subAccount');
  return true;
}
// Code path of the last rejected host message (a fixed constant, never message content).
const no=(code:string):null=>{why=code;return null;};
/** Recovery contract: a short fingerprint of a display's data (FNV-1a over its JSON, plus length). A display the page
 *  refused (schema or render) is quarantined by it, so the identical revision sent again is refused at once instead of
 *  being validated and rendered again. Never message content in any report. */
export function dataFingerprint(data:unknown):string {
  const text=JSON.stringify(data)??'';let hash=0x811c9dc5;
  for(let i=0;i<text.length;i++){hash^=text.charCodeAt(i);hash=Math.imul(hash,0x01000193)>>>0;}
  return text.length.toString(36)+':'+hash.toString(36);
}
function message(raw:string,quarantined?:(data:unknown)=>boolean,refused?:(data:unknown)=>void):HostMessage|null {
  if(typeof raw!=='string'||raw.length>MAX_MESSAGE_BYTES||new TextEncoder().encode(raw).length>MAX_MESSAGE_BYTES) return no('msg.size');
  let m:unknown; try {m=parseMessage(raw);} catch {return no('msg.parse');}
  if(!record(m)||m.version!==2||!uuid(m.pageId)||!uuid(m.requestId)||!uint(m.sequence)||!uuid(m.sessionId)||!identity(m.storeEpoch)||['unavailable','legacy'].includes(m.storeEpoch)||!uint(m.generation)||!uint(m.viewRevision)) return no('msg.header');
  const keys=(extra:string[]=[],optional:string[]=[])=>exact(m,[...header,'type',...extra,...optional.filter(key=>Object.hasOwn(m,key))]);
  const validAppearance=(v:unknown):boolean=>exact(v,['theme','locale','reduceMotion','reduceTransparency','showProjectNames'])&&typeof v.showProjectNames==='boolean'&&['day','night'].includes(v.theme as string)&&['en','zh-CN'].includes(v.locale as string)&&typeof v.reduceMotion==='boolean'&&typeof v.reduceTransparency==='boolean';
  const validScope=(v:unknown):boolean=>{if(typeof v!=='string')return false;if(v==='all'||/^[a-f0-9]{16}$/.test(v))return true;const parts=v.split('#');let last=parts.pop()??'';if(/^\d+$/.test(last)){if(!/^[1-9]\d*$/.test(last)||Number(last)>1024)return false;last=parts.pop()??'';}return identity(parts.join('#'))&&['saved_login_api','runtime_rpc','local_log','api_key_api','local_sqlite','status_line','browser_session','manual','unknown'].includes(last);};
  // D244: the saved member order is member keys only, at most 256, no repeats.
  const validOrder=(v:unknown):boolean=>Array.isArray(v)&&v.length>0&&v.length<=256&&v.every(k=>k!=='all'&&validScope(k))&&new Set(v).size===v.length;
  const validShell=(v:unknown):boolean=>exact(v,['profile','attached','forcedClosed','tier','scope',...(record(v)&&Object.hasOwn(v,'range')?['range']:[])])&&(!record(v)||v.range===undefined||isCockpitRange(v.range))&&['open','closed'].includes(v.profile as string)&&typeof v.attached==='boolean'&&typeof v.forcedClosed==='boolean'&&['tall','compact'].includes(v.tier as string)&&validScope(v.scope);
  switch(m.type) {
    case 'load': if(!keys(['appearance','shell'],['redBelow','showUsedPercent','showAllModels','ackedCautions','pinnedModels','memberOrder','hiddenMembers'])||(m.hiddenMembers!==undefined&&!validOrder(m.hiddenMembers))||(m.memberOrder!==undefined&&!validOrder(m.memberOrder))||(m.showUsedPercent!==undefined&&typeof m.showUsedPercent!=='boolean')||(m.showAllModels!==undefined&&typeof m.showAllModels!=='boolean')||!validAppearance(m.appearance)||!validShell(m.shell)||(m.ackedCautions!==undefined&&!validAcked(m.ackedCautions))||(m.pinnedModels!==undefined&&!validAcked(m.pinnedModels))) return no('load.keys'); break;
    case 'appearance': if(!keys(['theme','locale','reduceMotion','reduceTransparency','showProjectNames'],['redBelow','showUsedPercent','showAllModels','memberOrder','hiddenMembers'])||(m.hiddenMembers!==undefined&&!validOrder(m.hiddenMembers))||(m.memberOrder!==undefined&&!validOrder(m.memberOrder))||(m.showUsedPercent!==undefined&&typeof m.showUsedPercent!=='boolean')||(m.showAllModels!==undefined&&typeof m.showAllModels!=='boolean')||typeof m.showProjectNames!=='boolean'||!['day','night'].includes(m.theme as string)||!['en','zh-CN'].includes(m.locale as string)||typeof m.reduceMotion!=='boolean'||typeof m.reduceTransparency!=='boolean') return no('appearance.fields'); break;
    case 'shell': if(!keys(['profile','attached','forcedClosed','tier','scope'],['range'])||!validShell({profile:m.profile,attached:m.attached,forcedClosed:m.forcedClosed,tier:m.tier,scope:m.scope,...(Object.hasOwn(m,'range')?{range:m.range}:{})})) return no('shell.fields'); break;
    case 'ignition': if(!keys(['on'])||typeof m.on!=='boolean') return no('ignition.fields'); break;
    case 'fieldClosed': if(!keys()) return no('fieldClosed.keys'); break;
    case 'select': if(!keys(['model'])||(m.model!==null&&!identity(m.model))) return no('select.fields'); break;
    case 'display': if(!keys(['data']))return no('display.keys');if(quarantined?.(m.data))return no('display.quarantined');if(!validData(m.data)){refused?.(m.data);return null;} break;
    case 'visibility': if(!keys(['visible','occluded','key'])||[m.visible,m.occluded,m.key].some(v=>typeof v!=='boolean')) return no('visibility.fields'); break;
    case 'tick': if(!keys(['nowUnixMs','reason'])||!timestamp(m.nowUnixMs)||!['deadline','show','wake','unlock','clockChange'].includes(m.reason as string)) return no('tick.fields'); break;
    case 'clear': case 'unload': if(!keys()) return no('clear.keys'); break;
    case 'plugins': if(!keys(['plugins'])||!parsePluginState(m.plugins)) return no('plugins.fields'); break;
    case 'pluginData': if(!keys(['id','data'])||typeof m.id!=='string'||!PLUGIN_ID.test(m.id)) return no('pluginData.fields'); break;
    case 'pluginScreen': if(!keys(['id'])||typeof m.id!=='string'||!PLUGIN_ID.test(m.id)) return no('pluginScreen.fields'); break;
    default:return no('msg.type');
  }
  return m as unknown as HostMessage;
}
function threshold(value:unknown):RedBelow {
  if(value!==10&&value!==15&&value!==20&&value!==25&&value!==30&&value!==40)console.warn('Cockpit redBelow missing or invalid; using default 25.');
  return effectiveRedBelow(value);
}
export class CockpitBridge {
  private context:Context|null=null;
  private sequence=-1n;
  private domReady=false;
  private cleared=false;
  private loadRequestId:string|null=null;
  private outputSequence=0n;
  private loaded=false;
  private ended=false;
  private visible=false;
  private occluded=true;
  private key=false;
  private hidden=true;
  private shellState:ShellState|null=null;
  private scopeMembers=new Set<string>();
  private allScopeMembers=new Set<string>();
  private hiddenMembers=new Set<string>();
  private hasDisplay=false;
  private historyTools=new Set<string>();
  private retiredSessions=new Set<string>();
  private retiredEpochs=new Set<string>();
  /** Fingerprint of the last display this page refused (schema or render); cleared by a rendered display or a barrier. */
  private quarantine:string|null=null;
  private readonly isQuarantined=(data:unknown):boolean=>this.quarantine!==null&&dataFingerprint(data)===this.quarantine;
  private readonly refuseData=(data:unknown):void=>{this.quarantine=dataFingerprint(data);};
  constructor(private readonly pageId:string,private readonly origin:string,private readonly post:(message:string)=>void,private readonly view:CockpitView,private readonly requestId:()=>string,private readonly clock:()=>number=Date.now) {
    if(!uuid(pageId)||!(origin==='modelplan-cockpit://bundle'||/^http:\/\/127\.0\.0\.1:[0-9]{1,5}$/.test(origin))) throw TypeError('Invalid cockpit configuration');
    view.clear(); view.active(false);
  }
  get disposed():boolean{return this.ended;}
  get state():'unloaded'|'loading'|'ready'|'hidden'|'cleared' {
    if(this.ended||!this.loaded) return 'unloaded';
    if(!this.domReady) return 'loading';
    if(this.cleared) return 'cleared';
    return this.isActive()?'ready':'hidden';
  }
  private isVisible():boolean {return this.loaded&&this.domReady&&!this.ended&&!this.hidden&&this.visible&&!this.occluded;}
  private isActive():boolean {return this.isVisible()&&this.key;}
  private emit(type:string,requestId:string,extra:Record<string,unknown>={}):void {
    if(this.context) this.post(JSON.stringify({version:2,pageId:this.pageId,...this.context,sequence:String(++this.outputSequence),type,requestId,...extra}));
  }
  private reportDeadline(requestId:string):void {
    if(!this.isVisible()||!this.hasDisplay||this.cleared||this.ended)return;
    const deadline=this.view.nextDeadline();
    if(deadline!==null&&(!Number.isSafeInteger(deadline)||deadline<0||deadline>8640000000000000))throw Error('Invalid deadline');
    this.emit('nextDeadline',requestId,{deadlineUnixMs:deadline===null?null:String(deadline)});
  }
  ready():void {
    if(this.ended||this.domReady) return;
    this.domReady=true;
    if(this.loaded&&this.loadRequestId) {this.emit('ready',this.loadRequestId,{appearanceVersion:2,capabilities:['appearanceUpdates','shellState','shellActions']});this.loadRequestId=null;}
    this.syncActive();
  }
  documentHidden(hidden:boolean):void {if(this.ended)return;this.hidden=hidden; this.syncActive();}
  clear(raw:string,source:BridgeSource):boolean {
    // No unvalidated convenience path: clear is the same bounded host message.
    if(this.ended)return false;
    const parsed=message(raw);
    return parsed?.type==='clear'&&this.receive(raw,source);
  }
  get lastReject():string{return why;}
  private no(code:string):false{why=code;return false;}
  receive(raw:string,source:BridgeSource):boolean {
    why='none';
    if(this.ended||!source||source.isMainFrame!==true||source.origin!==this.origin) return this.no('recv.source');
    const m=message(raw,this.isQuarantined,this.refuseData);
    if(!m) return false;
    if(m.pageId!==this.pageId) return this.no('recv.page');
    if(BigInt(m.sequence)<=this.sequence) return this.no('recv.sequence');
    if(m.type==='load') {
      if(this.loaded) return this.no('load.again');
      // First load is also an explicit privacy barrier.
      this.view.clear(); this.historyTools.clear();this.scopeMembers.clear();this.allScopeMembers.clear();this.hasDisplay=false;this.quarantine=null;
      this.context={sessionId:m.sessionId,storeEpoch:m.storeEpoch,generation:m.generation,viewRevision:m.viewRevision};
      this.sequence=BigInt(m.sequence); this.loaded=true;this.cleared=false;this.loadRequestId=m.requestId;
      this.hiddenMembers=new Set(m.hiddenMembers??[]);
      try {this.view.restoreAcked?.(validAcked(m.ackedCautions)?m.ackedCautions:[]);this.view.restorePins?.(validAcked(m.pinnedModels)?m.pinnedModels:[]);this.view.configure(m.appearance,threshold(m.redBelow),m.showUsedPercent===true,m.showAllModels===true,m.memberOrder??[],m.hiddenMembers??[]);this.view.shell(m.shell);} catch {this.unload();return this.no('load.view');}
      this.shellState=m.shell;this.syncActive();
      if(this.domReady) {this.emit('ready',m.requestId,{appearanceVersion:2,capabilities:['appearanceUpdates','shellState','shellActions']});this.loadRequestId=null;}
      return true;
    }
    if(!this.context) return this.no('recv.noContext');
    if(m.type==='clear') {
      const old=this.context;
      if(BigInt(m.viewRevision)<=BigInt(old.viewRevision)||this.retiredSessions.has(m.sessionId)||this.retiredEpochs.has(m.storeEpoch)||
        (m.storeEpoch===old.storeEpoch&&BigInt(m.generation)<BigInt(old.generation))) return this.no('clear.barrier');
      // Epochs are equality-only. Only this explicit host barrier can adopt one.
      // A generation or epoch change is the store/consent barrier: the page forgets what was acknowledged before it. A
      // session-only clear keeps it (the owner's pressed cautions must not blink again).
      if(m.storeEpoch!==old.storeEpoch||m.generation!==old.generation){this.view.forgetAcked?.();this.pendingAck=null;}
      this.view.clear(); this.historyTools.clear();this.scopeMembers.clear();this.allScopeMembers.clear();this.hasDisplay=false;this.quarantine=null;if(this.shellState)this.shellState={...this.shellState,scope:'all'};this.cleared=true;
      if(m.sessionId!==old.sessionId) this.retiredSessions.add(old.sessionId);
      if(m.storeEpoch!==old.storeEpoch) this.retiredEpochs.add(old.storeEpoch);
      this.context={sessionId:m.sessionId,storeEpoch:m.storeEpoch,generation:m.generation,viewRevision:m.viewRevision};
      this.sequence=BigInt(m.sequence);
      if(this.retiredSessions.size>128||this.retiredEpochs.size>128) {this.unload();return this.no('clear.retired');}
      this.emit('cleared',m.requestId); return true;
    }
    if(!same(m,this.context)) return this.no('recv.context');
    switch(m.type) {
      case 'appearance':
        // Recovery contract: a view exception is refused, never an unload; the page keeps what it shows.
        try {this.view.updateAppearance({theme:m.theme,locale:m.locale,reduceMotion:m.reduceMotion,reduceTransparency:m.reduceTransparency,showProjectNames:m.showProjectNames},this.clock(),threshold(m.redBelow),m.showUsedPercent===true,m.showAllModels===true,m.memberOrder??[],m.hiddenMembers??[]);} catch {return this.no('appearance.view');}
        this.hiddenMembers=new Set(m.hiddenMembers??[]);this.scopeMembers=new Set([...this.allScopeMembers].filter(id=>!this.hiddenMembers.has(id)));
        this.sequence=BigInt(m.sequence);this.reportDeadline(m.requestId);return true;
      case 'shell': {
        const shell:ShellState={profile:m.profile,attached:m.attached,forcedClosed:m.forcedClosed,tier:m.tier,scope:m.scope,...(m.range!==undefined?{range:m.range}:{})};
        try {this.view.shell(shell);} catch {return this.no('shell.view');}
        this.shellState=shell;this.sequence=BigInt(m.sequence);return true;
      }
      case 'ignition':
        try {this.view.ignite?.(m.on);} catch {this.unload();return this.no('ignition.view');}
        this.sequence=BigInt(m.sequence);return true;
      case 'fieldClosed':
        try {this.view.fieldClosed?.();} catch {return this.no('fieldClosed.view');}
        this.sequence=BigInt(m.sequence);return true;
      case 'select':
        // A selection is presentation only: a view that cannot apply it is refused, never an unload.
        try {this.view.selectModel?.(m.model);} catch {return this.no('select.view');}
        this.sequence=BigInt(m.sequence);return true;
      case 'display':
        if(!this.domReady) return this.no('display.notReady');
        // Render is synchronous and transactional (view.ts): a render that throws leaves the last rendered data on
        // screen, and the refused revision is quarantined. The page is never unloaded for it (recovery contract).
        try {this.view.render(m.data,this.clock());} catch {this.refuseData(m.data);return this.no('display.render');}
        this.quarantine=null;
        this.historyTools=new Set(m.data.projection.rows.filter(row=>row.kind==='tool').map(row=>row.id));
        this.allScopeMembers=new Set(cockpitMembers(m.data,true).map(member=>member.key));
        this.scopeMembers=new Set([...this.allScopeMembers].filter(id=>!this.hiddenMembers.has(id)));
        this.hasDisplay=true;this.cleared=false;
        this.syncActive(); this.sequence=BigInt(m.sequence); this.emit('rendered',m.requestId);this.reportDeadline(m.requestId); return true;
      case 'tick':
        if(!this.isVisible())return this.no(this.hidden?'tick.documentHidden':'tick.notVisible');
        if(!this.hasDisplay||this.cleared)return this.no('tick.noDisplay');
        try {this.view.tick(Number(m.nowUnixMs));} catch {return this.no('tick.view');}
        this.sequence=BigInt(m.sequence);this.reportDeadline(m.requestId);return true;
      case 'visibility':
        this.visible=m.visible;this.occluded=m.occluded;this.key=m.key;this.sequence=BigInt(m.sequence);
        // The host already folds window visibility, miniaturisation and occlusion into this message. A prewarmed page's
        // own visibilitychange event arrives later and can still report hidden, which made the show tick fail (G3-66).
        // A host-visible window is therefore not a hidden document; the page's real event still follows and corrects it.
        if(m.visible&&!m.occluded)this.hidden=false;
        this.syncActive();return true;
      case 'unload': this.sequence=BigInt(m.sequence);this.unload();return true;
      case 'plugins':
        // A host that sends its plugin state also accepts the page's plugin edits (pluginsEdit).
        {const before=this.pluginsNegotiated;this.pluginsNegotiated=true;
        if(!this.view.plugins?.(m.plugins)){this.pluginsNegotiated=before;return this.no('plugins.view');}}
        this.sequence=BigInt(m.sequence);return true;
      case 'pluginData':
        // Readings are only for a host that negotiated plugins and only reach a running plugin.
        if(!this.pluginsNegotiated||!this.isVisible()||!this.view.pluginData?.(m.id,m.data))return this.no('pluginData.refused');
        this.sequence=BigInt(m.sequence);return true;
      case 'pluginScreen':
        // Only for a host that negotiated plugins; presentation only, so a screen the page cannot open is refused, never an unload.
        if(!this.pluginsNegotiated||!this.view.openPluginScreen?.(m.id))return this.no('pluginScreen.refused');
        this.sequence=BigInt(m.sequence);return true;
      default:return this.no('recv.type');
    }
  }
  /** G3-56: the lamp was pressed; the host keeps the acknowledged identities across restarts. */
  private pendingAck:string[]|null=null;
  private pendingPins:string[]|null=null;
  private syncActive():void {
    this.view.active(this.isActive(),this.clock());this.view.visible?.(this.isVisible());
    if(this.pendingAck&&this.isActive()) {const ids=this.pendingAck;this.pendingAck=null;this.emit('action',this.requestId(),{action:'cautionAck',ids});}
    if(this.pendingPins&&this.isActive()) {const ids=this.pendingPins;this.pendingPins=null;this.emit('action',this.requestId(),{action:'pinnedModels',ids});}
  }
  /** D136: report the favourite model ids after every long-press; the host keeps them across restarts. */
  pinModels(ids:string[]):boolean {
    if(!validAcked(ids)) return false;
    if(!this.isActive()) {this.pendingPins=ids;return false;}
    this.pendingPins=null;this.emit('action',this.requestId(),{action:'pinnedModels',ids});return true;
  }
  acknowledgeCautions(ids:string[]):boolean {
    if(!validAcked(ids)) return false;
    // Not active (for example occluded): keep the latest report and send it when the page is next active.
    if(!this.isActive()) {this.pendingAck=ids;return false;}
    this.pendingAck=null;this.emit('action',this.requestId(),{action:'cautionAck',ids});return true;
  }
  action(action:PageAction,tool?:string):boolean {
    if(!this.isActive()||!['chooseSetup','openSettings','openSettingsSubscriptions','openHistory','close','detach','putBack','shutterToggle','scopeSelect','rangeSelect','openField','openWebsite','refreshMember'].includes(action)) return false;
    // CKP-SHELL-50: one of the three ranges, by key; the host decides and echoes it in the shell.
    if(action==='rangeSelect') {
      if(!isCockpitRange(tool))return false;
      this.emit('action',this.requestId(),{action,key:tool});return true;
    }
    if(['close','detach','putBack','shutterToggle'].includes(action)) {
      if(!this.shellState)return false;
      if(action==='detach'&&!this.shellState.attached||action==='putBack'&&this.shellState.attached||action==='shutterToggle'&&this.shellState.forcedClosed)return false;
    }
    // Owner D277 (CKP-ENG-27): read one shown subscription (or all of them) again. Native asks the engine through the
    // same per-member refresh the widget's ring uses; only a current member key or `all` crosses.
    if(action==='refreshMember') {
      if(!this.hasDisplay||!tool||(tool!=='all'&&!this.scopeMembers.has(tool)))return false;
      this.emit('action',this.requestId(),{action,key:tool});return true;
    }
    if(action==='scopeSelect') {
      if(!this.hasDisplay||!tool||(tool!=='all'&&!this.scopeMembers.has(tool)))return false;
      this.emit('action',this.requestId(),{action,key:tool});return true;
    }
    // D63: a click on a still rocket opens the field focused on it, by the published display name the still and the
    // publication share. Native resolves the name against the published models and ignores anything else.
    if(action==='openField'&&tool!==undefined) {
      if(typeof tool!=='string'||!tool.trim()||tool.length>64)return false;
      this.emit('action',this.requestId(),{action,key:tool});return true;
    }
    if(action==='openWebsite') {
      const link=tool?websiteFields(tool):null;
      if(!link)return false;
      this.emit('action',this.requestId(),{action,...link});return true;
    }
    if(action==='openHistory'?(!tool||!this.historyTools.has(tool)):tool!==undefined) return false;
    this.emit('action',this.requestId(),{action,...(tool?{tool}:{})});return true;
  }
  private pluginsNegotiated=false;
  /** Plugin columns: a plugin edit made on the page (right-click Remove or the + menu). Posted only to a host that sent its plugin state. */
  pluginsEdit(state:PluginState):boolean {
    if(!this.pluginsNegotiated||!this.isActive()||!parsePluginState(state))return false;
    this.emit('action',this.requestId(),{action:'pluginsEdit',plugins:state});return true;
  }
  /** Plugin columns: the plugins now running (open cockpit, column shown); the host samples exactly these. */
  pluginsRunning(ids:string[]):boolean {
    if(!this.pluginsNegotiated||this.ended||!this.context||ids.length>16||!ids.every(id=>PLUGIN_ID.test(id)))return false;
    this.emit('action',this.requestId(),{action:'pluginsRunning',ids});return true;
  }
  unload():void {
    if(this.ended) return;
    this.view.clear();this.historyTools.clear();this.scopeMembers.clear();this.allScopeMembers.clear();this.hasDisplay=false;this.view.active(false);this.view.dispose();
    this.pendingAck=null;this.context=null;this.shellState=null;this.loadRequestId=null;this.retiredEpochs.clear();this.retiredSessions.clear();this.ended=true;this.loaded=false;
  }
}

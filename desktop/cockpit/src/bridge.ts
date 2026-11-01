// SPDX-License-Identifier: MIT
import { definitions, type WireCockpitData } from '../generated/wire.js';
import { conforms, exact, parseMessage, record } from './schema.js';
export const MAX_MESSAGE_BYTES = 1024 * 1024;
export interface Context { readonly sessionId:string; readonly storeEpoch:string; readonly generation:string; readonly viewRevision:string }
export interface BridgeSource { readonly origin:string; readonly isMainFrame:boolean }
export interface Appearance { readonly theme:'day'|'night'; readonly locale:'en'|'zh-CN'; readonly profile:'full'|'compact' }
export interface Header extends Context { readonly version:1; readonly pageId:string; readonly requestId:string; readonly sequence:string }
export type HostMessage = Header & (
  {readonly type:'load'; readonly appearance:Appearance} |
  {readonly type:'display'; readonly data:WireCockpitData} |
  {readonly type:'visibility'; readonly visible:boolean; readonly occluded:boolean; readonly key:boolean} |
  {readonly type:'clear'} | {readonly type:'unload'});
export interface CockpitView {
  configure(appearance:Appearance):void;
  render(data:WireCockpitData):void;
  clear():void;
  active(active:boolean):void;
  dispose():void;
}
const header=['version','pageId','requestId','sequence','sessionId','storeEpoch','generation','viewRevision'];
const uuid=(v:unknown):v is string=>typeof v==='string'&&/^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$/i.test(v);
const identity=(v:unknown):v is string=>typeof v==='string'&&v.length>0&&v.length<=128&&!/[\u0000-\u001f\u007f]/.test(v);
const uint=(v:unknown):v is string=>typeof v==='string'&&/^(0|[1-9][0-9]{0,19})$/.test(v)&&BigInt(v)<=18446744073709551615n;
const same=(a:Context,b:Context)=>a.sessionId===b.sessionId&&a.storeEpoch===b.storeEpoch&&a.generation===b.generation&&a.viewRevision===b.viewRevision;
function validData(value:unknown):value is WireCockpitData {
  if(!conforms(value,{$ref:'#/$defs/CockpitData'},definitions)) return false;
  const data=value as WireCockpitData;
  if(data.projection.rowsVersion!==1||new Set(data.projection.rows.map(row=>row.id)).size!==data.projection.rows.length) return false;
  const ref=(v:string|null)=>v===null||/^[a-f0-9]{16}$/.test(v);
  for(const row of data.projection.rows) {
    if(!identity(row.id)||(['denied','unset'].includes(row.consent)||row.reason.code==='cleanup_pending')&&row.accounts.length>0) return false;
    if(row.accounts.some(a=>!ref(a.subscriptionRef)||!ref(a.accountLocator))) return false;
  }
  return new Set(data.subscriptions.map(s=>s.subscriptionRef)).size===data.subscriptions.length &&
    data.subscriptions.every(s=>s.accounts.every(a=>identity(a.tool)&&ref(a.account.subscriptionRef)&&ref(a.account.accountLocator)));
}
function message(raw:string):HostMessage|null {
  if(typeof raw!=='string'||raw.length>MAX_MESSAGE_BYTES||new TextEncoder().encode(raw).length>MAX_MESSAGE_BYTES) return null;
  let m:unknown; try {m=parseMessage(raw);} catch {return null;}
  if(!record(m)||m.version!==1||!uuid(m.pageId)||!uuid(m.requestId)||!uint(m.sequence)||!uuid(m.sessionId)||!identity(m.storeEpoch)||['unavailable','legacy'].includes(m.storeEpoch)||!uint(m.generation)||!uint(m.viewRevision)) return null;
  const keys=(extra:string[]=[])=>exact(m,[...header,'type',...extra]);
  switch(m.type) {
    case 'load': if(!keys(['appearance'])||!exact(m.appearance,['theme','locale','profile'])||!['day','night'].includes(m.appearance.theme as string)||!['en','zh-CN'].includes(m.appearance.locale as string)||!['full','compact'].includes(m.appearance.profile as string)) return null; break;
    case 'display': if(!keys(['data'])||!validData(m.data)) return null; break;
    case 'visibility': if(!keys(['visible','occluded','key'])||[m.visible,m.occluded,m.key].some(v=>typeof v!=='boolean')) return null; break;
    case 'clear': case 'unload': if(!keys()) return null; break;
    default:return null;
  }
  return m as unknown as HostMessage;
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
  private historyTools=new Set<string>();
  private retiredSessions=new Set<string>();
  private retiredEpochs=new Set<string>();
  constructor(private readonly pageId:string,private readonly origin:string,private readonly post:(message:string)=>void,private readonly view:CockpitView,private readonly requestId:()=>string) {
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
  private isActive():boolean {return this.loaded&&this.domReady&&!this.ended&&!this.hidden&&this.visible&&!this.occluded&&this.key;}
  private emit(type:string,requestId:string,extra:Record<string,unknown>={}):void {
    if(this.context) this.post(JSON.stringify({version:1,pageId:this.pageId,...this.context,sequence:String(++this.outputSequence),type,requestId,...extra}));
  }
  ready():void {
    if(this.ended||this.domReady) return;
    this.domReady=true;
    if(this.loaded&&this.loadRequestId) {this.emit('ready',this.loadRequestId);this.loadRequestId=null;}
    this.view.active(this.isActive());
  }
  documentHidden(hidden:boolean):void {if(this.ended)return;this.hidden=hidden; this.view.active(this.isActive());}
  clear(raw:string,source:BridgeSource):boolean {
    // No unvalidated convenience path: clear is the same bounded host message.
    if(this.ended)return false;
    const parsed=message(raw);
    return parsed?.type==='clear'&&this.receive(raw,source);
  }
  receive(raw:string,source:BridgeSource):boolean {
    if(this.ended||!source||source.isMainFrame!==true||source.origin!==this.origin) return false;
    const m=message(raw);
    if(!m||m.pageId!==this.pageId||BigInt(m.sequence)<=this.sequence) return false;
    if(m.type==='load') {
      if(this.loaded) return false;
      // First load is also an explicit privacy barrier.
      this.view.clear(); this.historyTools.clear();
      this.context={sessionId:m.sessionId,storeEpoch:m.storeEpoch,generation:m.generation,viewRevision:m.viewRevision};
      this.sequence=BigInt(m.sequence); this.loaded=true;this.cleared=false;this.loadRequestId=m.requestId;
      this.view.configure(m.appearance); this.view.active(this.isActive());
      if(this.domReady) {this.emit('ready',m.requestId);this.loadRequestId=null;}
      return true;
    }
    if(!this.context) return false;
    if(m.type==='clear') {
      const old=this.context;
      if(BigInt(m.viewRevision)<=BigInt(old.viewRevision)||this.retiredSessions.has(m.sessionId)||this.retiredEpochs.has(m.storeEpoch)||
        (m.storeEpoch===old.storeEpoch&&BigInt(m.generation)<BigInt(old.generation))) return false;
      // Epochs are equality-only. Only this explicit host barrier can adopt one.
      this.view.clear(); this.historyTools.clear();this.cleared=true;
      if(m.sessionId!==old.sessionId) this.retiredSessions.add(old.sessionId);
      if(m.storeEpoch!==old.storeEpoch) this.retiredEpochs.add(old.storeEpoch);
      this.context={sessionId:m.sessionId,storeEpoch:m.storeEpoch,generation:m.generation,viewRevision:m.viewRevision};
      this.sequence=BigInt(m.sequence);
      if(this.retiredSessions.size>128||this.retiredEpochs.size>128) {this.unload();return false;}
      this.emit('cleared',m.requestId); return true;
    }
    if(!same(m,this.context)) return false;
    switch(m.type) {
      case 'display':
        if(!this.domReady) return false;
        // Render is synchronous, with no queued/private snapshot cache to revive.
        try {this.view.render(m.data);} catch {this.unload();return false;}
        this.historyTools=new Set(m.data.projection.rows.filter(row=>row.kind==='tool').map(row=>row.id));this.cleared=false;
        this.view.active(this.isActive()); this.sequence=BigInt(m.sequence); this.emit('rendered',m.requestId); return true;
      case 'visibility':
        this.visible=m.visible;this.occluded=m.occluded;this.key=m.key;this.sequence=BigInt(m.sequence);
        this.view.active(this.isActive());return true;
      case 'unload': this.sequence=BigInt(m.sequence);this.unload();return true;
      default:return false;
    }
  }
  action(action:'chooseSetup'|'openSettings'|'openHistory',tool?:string):boolean {
    if(!this.isActive()||!['chooseSetup','openSettings','openHistory'].includes(action)) return false;
    if(action==='openHistory'?(!tool||!this.historyTools.has(tool)):tool!==undefined) return false;
    this.emit('action',this.requestId(),{action,...(tool?{tool}:{})});return true;
  }
  unload():void {
    if(this.ended) return;
    this.view.clear();this.historyTools.clear();this.view.active(false);this.view.dispose();
    this.context=null;this.loadRequestId=null;this.retiredEpochs.clear();this.retiredSessions.clear();this.ended=true;this.loaded=false;
  }
}

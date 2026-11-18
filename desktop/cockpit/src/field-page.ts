// SPDX-License-Identifier: MIT
// The enlarged launch field (WP-22, owner D298): a page of its own in a separate native panel, official edition only.
// The panel is one transparent rectangle (88% of the cockpit screen's visible frame) over the native dim. The reserved
// launch-field component (runtime/field-scene/launch-field.js, version 1.1.0, window mode) draws everything inside it: the
// soft-canopy window, the in-field menu, the × and site keys and the 3D field. It loads with a dynamic import when the view
// opens, and the panel destroys this page on close, which releases the WebGL context and resets a tried effort.
// Native paints the dim, so the component's own is off (dim:false). Without WebGL the window shows its own 2D field. Esc belongs to the component (clear search, leave the
// fly-in, then close); a click outside the rectangle, the 180 s idle close and losing key are native's.
// Low Power Mode (spike 11-08, D63): the page cannot read it, so native passes it in the payload and through `power`;
// it quiets the field like Reduce Motion. Increase Contrast and Reduce Motion arrive live through `options`.
// Spec: the component's INTEGRATION-SPEC 1.1.0 and the r7 FINAL SPEC (confirm 2026-11-18/03).
import {FIELD_LIMIT,provisionalIds,windowModel,type PublishedModel,type WindowModel} from './field-model.js';

interface Show {readonly language:'en'|'zh';readonly reduceMotion:boolean;readonly lowPower?:boolean;readonly contrast?:boolean;readonly models:readonly PublishedModel[];readonly mine:readonly string[];readonly focus:string|null;readonly asOf?:string|null}
interface Live {readonly contrast?:boolean;readonly reduceMotion?:boolean}
type Language='en'|'zh';
interface LaunchWindow {update(next:Record<string,unknown>):void;setOptions(next:{contrast?:'more'|'normal';reducedMotion?:boolean|null;language?:Language}):void;setSelection(id:string|null):void;dispose():void}
interface Component {createLaunchWindow(options:Record<string,unknown>):LaunchWindow}
export interface FieldState {readonly mode:'loading'|'window'|'none';readonly flat:boolean;readonly contrast:'more'|'normal';readonly reducedMotion:boolean;readonly shown:readonly string[]}
declare global {interface Window {modelPlanField?:{show(raw:string):boolean;power(lowPower:boolean):boolean;options(raw:string):boolean;state():FieldState|null;dispose():void}}}

const post=(message:Record<string,unknown>)=>(window.webkit?.messageHandlers as Record<string,{postMessage(m:string):void}>|undefined)?.field?.postMessage(JSON.stringify(message));

function mount(root:HTMLElement) {
 let view:LaunchWindow|null=null,mode:FieldState['mode']='none',flat=false,disposed=false,language:Language='en';
 let models:WindowModel[]=[],shown:string[]=[],mine:string[]=[],focus:string|null=null,provisional:string[]=[],asOf:string|null=null;
 let appReduce=false,systemReduce=false,lowPower=false,contrast=false;
 // The component's asset base: the atlases and 2D sprites under assets/art/rockets/, its default maker logos under
 // assets/brands/ (the official cockpit's vendor marks, D43).
 const assets=new URL('assets/',document.baseURI).href;
 const reducedMotion=()=>appReduce||systemReduce||lowPower;
 const live=()=>({contrast:contrast?'more' as const:'normal' as const,reducedMotion:reducedMotion()});
 for(const type of ['pointerdown','keydown','wheel'])root.addEventListener(type,()=>post({type:'activity'}),{passive:true});
 return {
  async show(value:Show) {
   language=value.language==='zh'?'zh':'en';document.documentElement.lang=language==='en'?'en':'zh-CN';
   appReduce=value.reduceMotion===true;lowPower=value.lowPower===true;contrast=value.contrast===true;
   models=value.models.flatMap(m=>{const w=windowModel(m);return w?[w]:[];});
   const known=new Set(models.map(m=>m.id));
   mine=value.mine.filter(id=>known.has(id));provisional=provisionalIds(value.models).filter(id=>known.has(id));
   asOf=typeof value.asOf==='string'&&/^\d{4}-\d{2}-\d{2}$/.test(value.asOf)?value.asOf:null;
   focus=value.focus!==null&&known.has(value.focus)?value.focus:null;
   // My models first, else the publication's order; a rocket clicked in the porthole joins (the last of a full fleet makes room).
   shown=(mine.length?mine:models.map(m=>m.id)).slice(0,FIELD_LIMIT);
   if(focus!==null&&!shown.includes(focus))shown=[...shown.slice(0,FIELD_LIMIT-1),focus];
   if(!models.length){post({type:'failed'});return;}
   mode='loading';
   const url='../runtime/field-scene/launch-field.js';
   const component=await import(url) as Component;
   if(disposed)return;
   // Without WebGL, or on a later 3D failure, the window swaps in its own 2D field (menu, keys and card kept) and then
   // reports it: onFail and onSlow are informational here, never a close.
   view=component.createLaunchWindow({container:root,language,assetBase:assets,dim:false,limit:FIELD_LIMIT,...live(),
    onClose:(reason:string)=>post({type:'close',reason}),
    onOpenSite:(target:unknown,params:unknown)=>post({type:'openSite',target,params}),
    onShownChange:(ids:string[])=>{shown=[...ids];},
    onSelect:(id:string|null)=>{focus=id;},
    onFail:()=>{flat=true;console.info('launch field: 3D unavailable, the window shows the 2D field');},
    onSlow:()=>{console.info('launch field: 3D is slow');}});
   mode='window';
   view.update({models,shown,focus,mine,provisional,language,...(asOf?{asOf}:{})});
   post({type:'ready'});
  },
  /** A Low Power Mode change: the field goes quiet like Reduce Motion, live. */
  power(next:boolean) {
   if(disposed||next===lowPower)return;lowPower=next;view?.setOptions({reducedMotion:reducedMotion()});
  },
  /** Increase Contrast and Reduce Motion from macOS, live (component setOptions). */
  options(next:Live) {
   if(disposed)return;
   if(typeof next.contrast==='boolean')contrast=next.contrast;
   if(typeof next.reduceMotion==='boolean')systemReduce=next.reduceMotion;
   view?.setOptions(live());
  },
  state():FieldState {return {mode,flat,...live(),shown:[...shown]};},
  dispose(){disposed=true;view?.dispose();view=null;mode='none';root.replaceChildren();},
 };
}
const root=document.getElementById('field');
if(root&&window.top===window){
 const page=mount(root);
 window.modelPlanField=Object.freeze({
  show(raw:string){try{void page.show(JSON.parse(raw) as Show).catch(()=>post({type:'failed'}));return true;}catch{return false;}},
  power(lowPower:boolean){if(typeof lowPower!=='boolean')return false;page.power(lowPower);return true;},
  options(raw:string){try{const value=JSON.parse(raw) as unknown;if(!value||typeof value!=='object')return false;page.options(value as Live);return true;}catch{return false;}},
  state(){return page.state();},
  dispose(){page.dispose();delete window.modelPlanField;},
 });
 post({type:'loaded'});
}

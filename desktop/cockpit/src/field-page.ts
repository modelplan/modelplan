// SPDX-License-Identifier: MIT
// The enlarged launch field: a page of its own in a separate native panel, official edition only. The reserved
// scene loads with a dynamic import when the view opens, and the panel destroys this page on close, which
// releases the WebGL context. The 180 s idle close and the outside-click close live in the native panel.
// Prototype: rocket-r1/porthole.js:152-225 (enlarge, syncField) for behaviour; the code is written here.
import {FIELD_LIMIT,fieldFleet,fieldModel,type FieldModel,type PublishedModel} from './field-model.js';

interface Show {readonly language:'en'|'zh';readonly reduceMotion:boolean;readonly models:readonly PublishedModel[];readonly mine:readonly string[];readonly focus:string|null}
interface Scene {update(models:readonly FieldModel[],focus:string|null,path?:boolean):void;renderFor?(ms:number):void;dispose():void}
declare global {interface Window {modelPlanField?:{show(raw:string):boolean;dispose():void}}}

const words={en:{close:'Close',mine:'Mine',all:'All',search:'Search models',noGl:'The 3D view needs WebGL, which is not available here.',empty:'No published models yet.'},
 zh:{close:'关闭',mine:'我的',all:'全部',search:'搜索模型',noGl:'3D 视图需要 WebGL，当前不可用。',empty:'暂无已发布模型。'}} as const;
const post=(message:Record<string,unknown>)=>(window.webkit?.messageHandlers as Record<string,{postMessage(m:string):void}>|undefined)?.field?.postMessage(JSON.stringify(message));
const el=<K extends keyof HTMLElementTagNameMap>(tag:K,className?:string,text?:string)=>{const e=document.createElement(tag);if(className)e.className=className;if(text!==undefined)e.textContent=text;return e;};
const webgl=()=>{try{return !!document.createElement('canvas').getContext('webgl2');}catch{return false;}};

function mount(root:HTMLElement) {
 let scene:Scene|null=null,models:FieldModel[]=[],chosen=new Set<string>(),mine:string[]=[],focus:string|null=null,language:'en'|'zh'='en',disposed=false;
 const bar=el('header','field-bar'),stage=el('div','ov-porthole field-stage'),list=el('div','field-list');
 const close=el('button','field-close');close.type='button';close.onclick=()=>post({type:'close'});
 const mineKey=el('button','field-preset'),allKey=el('button','field-preset'),count=el('span','field-count');mineKey.type=allKey.type='button';
 const search=el('input','field-search');search.type='search';
 bar.append(mineKey,allKey,search,count,close);root.append(bar,stage,list);
 const fleet=()=>fieldFleet(models,chosen);
 const refresh=()=>{
  const flown=fleet();if(focus===null||!flown.some(m=>m.id===focus))focus=flown[0]?.id??null;
  count.textContent=`${flown.length}/${FIELD_LIMIT}`;scene?.update(flown,focus,true);scene?.renderFor?.(700);
  const q=search.value.trim().toLowerCase();list.replaceChildren(...models.filter(m=>!q||m.name.toLowerCase().includes(q)).map(m=>{
   const label=el('label','field-row'),box=el('input');box.type='checkbox';box.checked=chosen.has(m.id);box.disabled=!box.checked&&chosen.size>=FIELD_LIMIT;
   box.onchange=()=>{if(box.checked)chosen.add(m.id);else chosen.delete(m.id);refresh();};label.append(box,el('span',undefined,m.name));return label;
  }));
 };
 const preset=(ids:readonly string[])=>{chosen=new Set(ids.slice(0,FIELD_LIMIT));refresh();};
 mineKey.onclick=()=>preset(mine.length?mine:models.map(m=>m.id));allKey.onclick=()=>preset(models.map(m=>m.id));search.oninput=refresh;
 const fallback=(text:string)=>{stage.replaceChildren(el('p','nogl',text));};
 for(const type of ['pointerdown','keydown','wheel'])root.addEventListener(type,()=>post({type:'activity'}),{passive:true});
 window.addEventListener('keydown',e=>{if(e.key==='Escape')post({type:'close'});});
 return {
  async show(value:Show) {
   language=value.language;const w=words[language];document.documentElement.lang=language==='en'?'en':'zh-CN';
   close.textContent='×';close.setAttribute('aria-label',w.close);mineKey.textContent=w.mine;allKey.textContent=w.all;search.placeholder=w.search;search.setAttribute('aria-label',w.search);
   models=value.models.flatMap(m=>{const f=fieldModel(m);return f?[f]:[];});mine=value.mine.filter(id=>models.some(m=>m.id===id));focus=value.focus;
   chosen=new Set((mine.length?mine:models.map(m=>m.id)).slice(0,FIELD_LIMIT));
   if(!models.length){fallback(w.empty);refresh();post({type:'ready'});return;}
   if(!webgl()){fallback(w.noGl);refresh();post({type:'ready'});return;}
   const host=el('div','r1-field p2-field'),canvas=el('div','wb-canvas'),plates=el('div','wb-plates'),voyage=el('div','wb-voyage');
   host.append(canvas,document.createElementNS('http://www.w3.org/2000/svg','svg'),plates,voyage);host.children[1]!.setAttribute('class','wb-leaders');stage.replaceChildren(host);
   const url='../runtime/field-scene/cockpit-scene.bundle.js';
   const {mountWorkbenchField}=await import(url) as {mountWorkbenchField(host:HTMLElement,options:Record<string,unknown>):Scene};
   if(disposed)return;
   const flown=fleet();focus=focus&&flown.some(m=>m.id===focus)?focus:flown[0]?.id??null;
   scene=mountWorkbenchField(host,{models:flown,focus,quiet:value.reduceMotion,showPath:true,language,onDemand:true,noIntro:true,
    onSelect:(id:string)=>{focus=id;refresh();},onFail:()=>{scene=null;fallback(w.noGl);}});
   scene.renderFor?.(1400);refresh();post({type:'ready'});
  },
  dispose(){disposed=true;scene?.dispose();scene=null;root.replaceChildren();},
 };
}
const root=document.getElementById('field');
if(root&&window.top===window){
 const page=mount(root);
 window.modelPlanField=Object.freeze({
  show(raw:string){try{void page.show(JSON.parse(raw) as Show).catch(()=>post({type:'failed'}));return true;}catch{return false;}},
  dispose(){page.dispose();delete window.modelPlanField;},
 });
 post({type:'loaded'});
}

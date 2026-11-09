// SPDX-License-Identifier: MIT
// The enlarged field's frosted model-picker card (item 6, task 91 round 5): presets, search, a frontier of the rockets
// on the field, one card per public model with a launch lamp, and a footer with reset and the website link. It holds
// only presentation state (query, preset, folded); the page owns which models fly and which one has the focus.
// v1 shows only the verdict this data can derive, "outclassed" (D71); the published lineup tags (strongest, best value,
// cheapest) and the site's picks are not in the app's data, so they are neither shown nor guessed.
// Prototype: clients/official-visuals/study/website-updates/fleet.js and the website's FrontierChart (geometry) for
// appearance and behaviour; the code is written here.
import {FIELD_LIMIT,type FieldModel} from './field-model.js';

export type Language='en'|'zh';
export type Preset='mine'|'all'|'custom';
export interface PickerView {
 readonly language:Language;readonly models:readonly FieldModel[];readonly chosen:ReadonlySet<string>;
 readonly preset:Preset;readonly focus:string|null;
 /** My subscriptions' models: they lead the list, which keeps its order while lamps change (no rows jump). */
 readonly mine:readonly string[];
}
export interface PickerActions {
 preset(next:'mine'|'all'):void;toggle(id:string,on:boolean):void;focus(id:string):void;website():void;folded(folded:boolean):void;
}

const words={
 en:{title:'Pick models',mine:'My subscriptions',all:'All',search:'Search',searchLabel:'Search models',reset:'Reset to My subscriptions',
  empty:'No matching models',onField:'on field',atStar:'on field · at each ★',roster:'My subscriptions first',more:'MORE PUBLIC MODELS',ability:'Ability',cost:'Cost',
  limit:'10 rocket limit · retract one to add another',local:'Field-local choice',compare:'Compare ↗',compareLabel:'Full fleet on the website',
  collapse:'Collapse model picker',focus:'Focus',launch:'Launch',retract:'Retract',presets:'Presets',picker:'Which engine · model picker',
  chartEmpty:'Select at least two models to compare.',chartLabel:'Ability and cost of each model at its effort',costAxis:'Cost → (vs cheapest, log)',abilityAxis:'↑ Ability',
  dominated:'Outclassed'},
 zh:{title:'选模型',mine:'我的订阅',all:'全部',search:'搜索模型',searchLabel:'搜索模型',reset:'重置为我的订阅',
  empty:'没有匹配的模型',onField:'台上场',atStar:'台上场 · 各自 ★ 推荐档',roster:'我的订阅优先',more:'其他公开模型',ability:'能力',cost:'成本',
  limit:'最多 10 台 · 先撤回一台再加入',local:'仅此发射场',compare:'网站对比 ↗',compareLabel:'在网站上看完整舰队',
  collapse:'收起选模型',focus:'定位',launch:'加入',retract:'撤回',presets:'快捷选择',picker:'选哪台 · 模型选择',
  chartEmpty:'选至少两个模型以对比。',chartLabel:'各模型推荐档的能力与成本',costAxis:'成本 →（相对最省，对数）',abilityAxis:'↑ 能力',
  dominated:'被比下去'},
} as const;

// Makers by the publication's developer ID (the scene maps zhipuai to zhipu): display name, mark under
// ./assets/brands/ (the build ships these, D43), and the website's engine colour for chart dots.
const makers:Readonly<Record<string,{name:string;mark?:string;colour:string}>>={
 openai:{name:'OpenAI',mark:'openai-white.svg',colour:'#6aa8ff'},anthropic:{name:'Anthropic',mark:'claude.svg',colour:'#ff9a6a'},
 zhipu:{name:'Zhipu AI',mark:'zhipu.svg',colour:'#63d69c'},zhipuai:{name:'Zhipu AI',mark:'zhipu.svg',colour:'#63d69c'},
 google:{name:'Google',mark:'gemini.svg',colour:'#ffd166'},xai:{name:'xAI',mark:'x-white.svg',colour:'#b9a7ff'},
 kimi:{name:'Moonshot AI',mark:'kimi-white.svg',colour:'#ff8fcf'},minimax:{name:'MiniMax',mark:'minimax.svg',colour:'#ff6f99'},
 alibaba:{name:'Alibaba',mark:'qwen.svg',colour:'#ffab5c'},qwen:{name:'Alibaba',mark:'qwen.svg',colour:'#ffab5c'},
 deepseek:{name:'DeepSeek',mark:'deepseek.svg',colour:'#7d93ff'},xiaomi:{name:'Xiaomi',mark:'xiaomi.svg',colour:'#ff9a4a'},
 meta:{name:'Meta',colour:'#7fd3ff'},tencent:{name:'Tencent',colour:'#6fe0d2'},
};
const maker=(m:FieldModel)=>Object.hasOwn(makers,m.dev)?makers[m.dev]!:{name:m.dev,colour:'#b8b0a8'};
const esc=(s:string)=>s.replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'})[c]!);
/** The chart's short name, as the website shows it: Claude drops its prefix, a trailing date goes. */
export const shortName=(name:string)=>name.replace(/^Claude\s/,'').replace(/ \(\d+\)$| \d{4}$/,'');
const times=(v:number)=>`×${v.toFixed(v<10?1:0)}`;
const ability=(m:FieldModel)=>m.sel[1],cost=(m:FieldModel)=>m.sel[2];

/** For each model at its ★ effort, the cheapest model that is at least as able and no dearer, and better in one. */
export function outclassedBy(models:readonly FieldModel[]):Map<string,FieldModel> {
 const out=new Map<string,FieldModel>();
 for(const m of models){
  if(!(cost(m)>0))continue;
  const by=models.filter(n=>n!==m&&cost(n)>0&&ability(n)>=ability(m)&&cost(n)<=cost(m)&&(ability(n)>ability(m)||cost(n)<cost(m)))
   .sort((a,b)=>cost(a)-cost(b)||ability(b)-ability(a))[0];
  if(by)out.set(m.id,by);
 }
 return out;
}
/** Walking up the cost axis, each new best ability: the models worth picking among `models`. */
export function frontierOf(models:readonly FieldModel[]):FieldModel[] {
 const front:FieldModel[]=[];let best=-Infinity;
 for(const m of [...models].filter(m=>cost(m)>0).sort((a,b)=>cost(a)-cost(b)||ability(b)-ability(a)))if(ability(m)>best){front.push(m);best=ability(m);}
 return front;
}

/** Ability against log cost for the rockets on the field (the website's FrontierChart geometry). */
function chart(flown:readonly FieldModel[],base:number,target:string|null,language:Language,W=400,H=180):string {
 const w=words[language],points=flown.filter(m=>cost(m)>0);
 if(points.length<2)return `<p class="field-chart-empty">${w.chartEmpty}</p>`;
 const rel=(m:FieldModel)=>cost(m)/base,beaten=outclassedBy(points),front=frontierOf(points);
 const aTop=Math.max(1,...points.map(ability)),xTop=Math.max(2,...points.map(rel));
 const L=40,R=22,T=22,B=30,lx1=Math.max(1,Math.ceil(Math.log2(xTop))),a0=Math.floor((Math.min(...points.map(ability))-4)/5)*5,a1=Math.ceil((aTop+4)/5)*5,step=a1-a0>40?10:5;
 const X=(x:number)=>L+Math.log2(Math.max(1,x))/lx1*(W-L-R),Y=(a:number)=>T+(1-(a-a0)/(a1-a0))*(H-T-B),f=(n:number)=>n.toFixed(1);
 // Two-line labels try four spots around each dot and keep the first clear of those placed before; at this width the
 // outclassed ones go unlabelled.
 const placed:{x:number;y:number;w:number}[]=[],labels=new Map<string,{x:number;y:number;anchor:'start'|'end'}>();
 for(const m of [...points].sort((p,q)=>ability(q)-ability(p))){
  if(W<500&&beaten.has(m.id))continue;
  const cx=X(rel(m)),cy=Y(ability(m)),lw=Math.max(shortName(m.name).length*6.6,70);
  const spots=[{x:cx+10,y:cy-7,anchor:'start' as const},{x:cx+10,y:cy+19,anchor:'start' as const},{x:cx-10,y:cy-7,anchor:'end' as const},{x:cx-10,y:cy+19,anchor:'end' as const}];
  const box=(p:typeof spots[number])=>({x:p.anchor==='start'?p.x:p.x-lw,y:p.y,w:lw});
  const fits=(p:typeof spots[number])=>{const b=box(p);return b.x>=0&&b.x+b.w<=W&&b.y>12&&b.y<H-B+4&&placed.every(o=>b.x+b.w<o.x||o.x+o.w<b.x||Math.abs(b.y-o.y)>27);};
  const spot=spots.find(fits)??spots.find(p=>box(p).x+lw<=W)??spots[0]!;
  placed.push(box(spot));labels.set(m.id,spot);
 }
 const parts:string[]=[];
 for(let e=0;e<=lx1;e++)parts.push(`<line x1="${f(X(2**e))}" x2="${f(X(2**e))}" y1="${T}" y2="${H-B}" stroke="rgba(255,201,138,.08)"/><text x="${f(X(2**e))}" y="${H-10}" text-anchor="middle" class="lcd-dim">×${2**e}</text>`);
 for(let a=a0;a<=a1;a+=step)parts.push(`<line x1="${L}" x2="${W-R}" y1="${f(Y(a))}" y2="${f(Y(a))}" stroke="rgba(255,201,138,.06)"/><text x="${L-6}" y="${f(Y(a)+3)}" text-anchor="end" class="lcd-dim">${a}</text>`);
 parts.push(`<text x="${W-R}" y="${H-B-6}" text-anchor="end" class="lcd-dim">${w.costAxis}</text><text x="${L}" y="${T-8}" class="lcd-dim">${w.abilityAxis}</text>`);
 if(front.length>1)parts.push(`<path class="field-front" d="${front.map((m,i)=>`${i?'L':'M'}${f(X(rel(m)))} ${f(Y(ability(m)))}`).join(' ')}" fill="none" stroke="#f6d38a" stroke-width="1.6" stroke-dasharray="5 4" opacity=".8"/>`);
 for(const m of points){const by=beaten.get(m.id);if(by)parts.push(`<line class="field-beaten" x1="${f(X(rel(m)))}" y1="${f(Y(ability(m)))}" x2="${f(X(rel(by)))}" y2="${f(Y(ability(by)))}" stroke="#bca184" stroke-opacity=".45" stroke-dasharray="2 3"/>`);}
 for(const m of points){
  const x=X(rel(m)),y=Y(ability(m)),on=target===m.id,label=labels.get(m.id);
  parts.push(`<g class="sp-which-dot" data-field-focus="${esc(m.id)}" opacity="${beaten.has(m.id)&&!on?.45:1}" tabindex="0" role="button" aria-label="${esc(m.name)}"><circle cx="${f(x)}" cy="${f(y)}" r="${on?9:7}" fill="${maker(m).colour}" stroke="#120a05" stroke-width="1.5"/>${label?`<text x="${f(label.x)}" y="${f(label.y)}" text-anchor="${label.anchor}" class="name">${esc(shortName(m.name))}</text><text x="${f(label.x)}" y="${f(label.y+14)}" text-anchor="${label.anchor}" class="lcd-val">${ability(m).toFixed(1)} · ${times(rel(m))}</text>`:''}</g>`);
 }
 return `<svg viewBox="0 0 ${W} ${H}" width="${W}" height="${H}" role="img" aria-label="${w.chartLabel}">${parts.join('')}</svg>`;
}

export interface FieldPicker {readonly card:HTMLElement;readonly tools:HTMLElement;render(view:PickerView):void;readonly folded:boolean}
export function createFieldPicker(actions:PickerActions):FieldPicker {
 const card=document.createElement('section');card.className='field-card website-fleet-picker';
 const tools=document.createElement('div');tools.className='website-fleet-tools';
 let query='',folded=false,view:PickerView|null=null,searching=false;
 const draw=()=>{
  if(!view)return;
  const v=view,w=words[v.language],flown=v.models.filter(m=>v.chosen.has(m.id)),count=flown.length,full=count>=FIELD_LIMIT;
  const priced=v.models.filter(m=>cost(m)>0),cheapest=[...priced].sort((a,b)=>cost(a)-cost(b))[0],base=cheapest?cost(cheapest):1;
  const beaten=outclassedBy(v.models),aTop=Math.max(1,...v.models.map(ability)),xTop=Math.max(2,...priced.map(m=>cost(m)/base));
  // The prototype ranks published recommendations first; the app has no such verdicts, so my subscriptions' models
  // lead, then the other public models, and the outclassed sink to the end; each group strongest first.
  const q=query.trim().toLowerCase(),mine=new Set(v.mine);
  const rank=(m:FieldModel)=>beaten.has(m.id)?2:mine.has(m.id)?0:1;
  const order=[...v.models].sort((a,b)=>rank(a)-rank(b)||ability(b)-ability(a));
  const shown=order.filter(m=>!q||`${m.name} ${maker(m).name}`.toLowerCase().includes(q));
  let more=false;
  const rows=shown.map(m=>{
   const heading=rank(m)>0&&!more&&shown.some(n=>rank(n)===0)?(more=true,`<p class="field-group-label">${w.more}</p>`):'';
   const on=v.chosen.has(m.id),mk=maker(m),rel=cost(m)/base,out=beaten.has(m.id),blocked=!on&&full;
   const tile=mk.mark?`<img src="assets/brands/${mk.mark}" alt="">`:`<b>${esc(mk.name.slice(0,1))}</b>`;
   const bars=`<span>${w.ability}</span><i class="a" style="width:${Math.max(5,ability(m)/aTop*100).toFixed(1)}%"></i><b>${ability(m).toFixed(1)}</b>`+
    (cost(m)>0?`<span>${w.cost}</span><i class="c" style="width:${Math.max(5,(Math.log2(rel)+1)/(Math.log2(xTop)+1)*100).toFixed(1)}%"></i><b>${times(rel)}</b>`:'');
   return `${heading}<article class="field-model-row${out?' dominated':''}${v.focus===m.id&&on?' on':''}" data-field-row="${esc(m.id)}" data-on="${on}">`+
    `<div class="field-row-top"><button type="button" class="field-model-focus sp-cr-name" data-field-focus="${esc(m.id)}" ${blocked?'disabled':''} aria-label="${w.focus} ${esc(m.name)}">`+
    `<span class="sp-tile">${tile}</span><span class="field-full-name"><span class="field-vendor-name">${esc(mk.name)}</span><b>${esc(m.name)}</b></span><em>★ ${esc(m.rec)}</em></button>`+
    `<button type="button" class="field-launch-lamp" data-fleet-model="${esc(m.id)}" aria-pressed="${on}" aria-label="${on?w.retract:w.launch} ${esc(m.name)}" ${blocked?'disabled':''}>${on?'✓':'+'}</button></div>`+
    `<div class="sp-cr-tags">${out?`<i class="tag-dominated">${w.dominated}</i>`:''}</div><div class="sp-cr-bars">${bars}</div></article>`;
  }).join('');
  const presets=(['mine','all'] as const).map(id=>`<button type="button" data-field-preset="${id}" aria-pressed="${v.preset===id}">${w[id]}</button>`).join('');
  card.setAttribute('aria-label',w.picker);card.hidden=folded;
  card.innerHTML=`<div class="field-picker-controls"><div class="field-presets" role="group" aria-label="${w.presets}">${presets}</div>`+
   `<label class="field-search"><span aria-hidden="true">⌕</span><input type="search" data-field-search value="${esc(query)}" placeholder="${w.search}" aria-label="${w.searchLabel}"></label></div>`+
   `<div class="field-which-title"><span>WHICH ENGINE</span><small>${count} ${w.atStar}</small><button data-fleet-done type="button" aria-label="${w.collapse}">−</button></div>`+
   `<div class="sp-which-chart field-frontier">${chart(flown,base,v.focus,v.language)}</div>`+
   `<div class="field-roster-heading"><b>${w.roster}</b><span>${count}/${FIELD_LIMIT} ${w.onField}</span></div>`+
   `<div class="field-model-list sp-which-roster">${rows||`<p class="field-empty">${w.empty}</p>`}</div>`+
   `<footer><button type="button" data-field-reset>↺ ${w.reset}</button><button type="button" class="field-website" aria-label="${w.compareLabel}" ${count?'':'disabled'}>${w.compare}</button>`+
   `<small>${full?w.limit:cheapest?`×1 = ${esc(cheapest.name)} ★ ${esc(cheapest.rec)} · ${w.local}`:w.local}</small></footer>`;
  tools.innerHTML=`<button type="button" data-fleet-picker aria-expanded="${!folded}" ${folded?'':'hidden'}>${w.title} <b>${count}/${FIELD_LIMIT}</b></button>`;
  if(searching){const input=card.querySelector<HTMLInputElement>('[data-field-search]');input?.focus();input?.setSelectionRange(input.value.length,input.value.length);}
 };
 // An IME composition is not rebuilt mid-way (the input would be replaced and the composition aborted); the list updates when it ends.
 const searchNow=(t:HTMLInputElement)=>{query=t.value;searching=true;draw();searching=false;};
 card.addEventListener('input',e=>{const t=e.target as HTMLInputElement;if(t.matches('[data-field-search]')){if((e as InputEvent).isComposing){query=t.value;return;}searchNow(t);}});
 card.addEventListener('compositionend',e=>{const t=e.target as HTMLInputElement;if(t.matches('[data-field-search]'))searchNow(t);});
 card.addEventListener('click',e=>{
  const t=(e.target as Element).closest('button,[data-field-focus]');if(!t||(t as HTMLButtonElement).disabled)return;
  const d=(t as HTMLElement).dataset;
  if(d.fieldPreset==='mine'||d.fieldPreset==='all'){query='';actions.preset(d.fieldPreset);}
  else if(d.fleetModel)actions.toggle(d.fleetModel,t.getAttribute('aria-pressed')!=='true');
  else if(d.fieldFocus)actions.focus(d.fieldFocus);
  else if(t.hasAttribute('data-fleet-done')){folded=true;draw();actions.folded(true);}
  else if(t.hasAttribute('data-field-reset')){query='';actions.preset('mine');}
  else if(t.classList.contains('field-website'))actions.website();
 });
 card.addEventListener('keydown',e=>{const t=(e.target as Element).closest('g[data-field-focus]') as SVGGElement|null;if(t&&(e.key==='Enter'||e.key===' ')){e.preventDefault();actions.focus(t.dataset.fieldFocus!);}});
 tools.addEventListener('click',e=>{if((e.target as Element).closest('[data-fleet-picker]')){folded=false;draw();actions.folded(false);}});
 return {card,tools,get folded(){return folded;},render(next){view=next;draw();}};
}

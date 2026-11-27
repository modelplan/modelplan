// SPDX-License-Identifier: MIT
// D474 §7.1: one hover card for every number and mark of the cockpit. Hover or keyboard focus on an element that carries
// `data-hc` (its title) shows the same card after 400 ms: a title (subject · which), the facts (`data-hc-facts`, one per line)
// and the basis in ink-3 (`data-hc-basis`: where it comes from, how old the reading is). Esc closes it, and the element's
// `aria-label` carries the same text (the views build both from one list, see `hcAttrs` in engine-view.js).
//
// The card lives in the cockpit, not in the target, so a refresh that redraws the cells does not close it: `refresh()` finds
// the target again by `data-hc-key` and updates the card in place (an open hover survives a refresh). It opens away from the
// mark (above, else below) and never covers the HUD. Text only; it takes no pointer events.
export const HOVER_DELAY_MS=400;
const MAX_FACTS=6;
export interface HoverCards {
 /** Redraw the open card from the (re-rendered) target with the same key; closes when that target is gone. */
 refresh():void;
 close():void;
 /** Stop listening but leave the open card for the next instance to adopt (a rebuilt table). */
 detach():void;
 /** The open card's key (tests, and the owner of the cells). */
 open():string|null;
 dispose():void;
}
export interface HoverCardOptions {
 /** Which surface owns the card ('engine', 'hud'): a rebuilt table adopts its predecessor's open card instead of leaving a second one. */
 owner:string;
 /** Where the card is placed (the cockpit root). */
 container:()=>HTMLElement;
 /** A rectangle the card must not cover (the HUD), or null. */
 avoid?:()=>DOMRect|null;
 delay?:number;
}
const targetOf=(e:EventTarget|null)=>e instanceof Element?e.closest<HTMLElement>('[data-hc]'):null;
const overlaps=(a:{left:number;top:number;right:number;bottom:number},b:DOMRect)=>a.left<b.right&&a.right>b.left&&a.top<b.bottom&&a.bottom>b.top;

// The last pointer position seen by any instance: a rebuilt table (a new instance) must know where the pointer is.
let pointer:{x:number;y:number}|null=null;

export function mountHoverCards(root:HTMLElement,options:HoverCardOptions):HoverCards {
 const delay=options.delay??HOVER_DELAY_MS;
 const mine=()=>options.container().querySelector<HTMLElement>(`:scope > .hc-card[data-hc-owner="${options.owner}"]`);
 let card:HTMLElement|null=mine(),key:string|null=card?.dataset.hcKey??null;
 const close=()=>{card?.remove();mine()?.remove();card=null;key=null;};
 const place=(target:HTMLElement)=>{
  if(!card)return;
  const host=options.container(),box=host.getBoundingClientRect(),r=target.getBoundingClientRect(),w=card.offsetWidth,h=card.offsetHeight,avoid=options.avoid?.()??null;
  const x=Math.max(4,Math.min(box.width-w-4,r.left-box.left+r.width/2-w/2));
  const above=r.top-box.top-h-4,below=r.bottom-box.top+4;
  const fits=(y:number)=>y>=4&&y+h<=box.height-4&&!(avoid&&overlaps({left:box.left+x,top:box.top+y,right:box.left+x+w,bottom:box.top+y+h},avoid));
  const y=fits(above)?above:fits(below)?below:above>=4?above:Math.max(4,Math.min(box.height-h-4,below));
  card.style.left=`${x.toFixed(1)}px`;card.style.top=`${y.toFixed(1)}px`;
 };
 const fill=(target:HTMLElement)=>{
  if(!card)return;
  const title=document.createElement('span');title.className='h';title.textContent=target.dataset.hc??'';
  const facts=(target.dataset.hcFacts??'').split('\n').filter(Boolean).slice(0,MAX_FACTS).map(line=>{const s=document.createElement('span');s.textContent=line;return s;});
  const basis=target.dataset.hcBasis?[(()=>{const s=document.createElement('span');s.className='basis';s.textContent=target.dataset.hcBasis!;return s;})()]:[];
  card.replaceChildren(title,...facts,...basis);
 };
 // The card is inserted at once but stays hidden for 400 ms: `.hc-card.on` turns visible through a transition delay (the
 // bundle runs no timers). A different mark restarts the delay; the same mark (or a refresh) keeps what is shown.
 const arm=(target:HTMLElement)=>{
  if(!target.isConnected)return;
  const next=target.dataset.hcKey??target.dataset.hc??'';
  card=card?.isConnected?card:mine();
  if(card&&key===next){fill(target);place(target);return;}
  if(!card){card=document.createElement('div');card.className='mfd-tip hc-card';card.dataset.hcOwner=options.owner;card.setAttribute('role','tooltip');options.container().append(card);}
  card.classList.remove('on');key=next;card.dataset.hcKey=next;card.style.setProperty('--hc-delay',`${delay}ms`);
  fill(target);place(target);void card.offsetWidth;card.classList.add('on');
 };
 const over=(e:Event)=>{const t=targetOf(e.target);if(t&&root.contains(t))arm(t);};
 const out=(e:Event)=>{
  const from=targetOf(e.target),to=targetOf((e as PointerEvent|FocusEvent).relatedTarget);
  if(!from)return;
  // Moving between two parts of one mark (a cell and its child) keeps the card.
  if(to&&(to.dataset.hcKey??to.dataset.hc)===(from.dataset.hcKey??from.dataset.hc))return;
  close();
 };
 // The table is rebuilt for a new delivery: a card whose table left the page retires itself at the next key.
 const esc=(e:KeyboardEvent)=>{if(!root.isConnected&&!card){dispose();return;}if(e.key==='Escape'&&card){close();e.preventDefault();e.stopImmediatePropagation();}};
 // A card also closes when the pointer moves onto anything that is not its mark (a redrawn mark never reports `pointerout`).
 const track=(e:PointerEvent)=>{pointer={x:e.clientX,y:e.clientY};if(e.type==='pointermove'&&card?.isConnected&&key!==null&&!(e.target instanceof Element&&e.target.closest<HTMLElement>('[data-hc-key]')?.dataset.hcKey===key))close();};
 document.addEventListener('pointermove',track,true);document.addEventListener('pointerdown',track,true);
 const dispose=()=>{document.removeEventListener('pointermove',track,true);document.removeEventListener('pointerdown',track,true);close();root.removeEventListener('pointerover',over);root.removeEventListener('pointerout',out);root.removeEventListener('focusin',over);root.removeEventListener('focusout',out);window.removeEventListener('keydown',esc,true);};
 root.addEventListener('pointerover',over);root.addEventListener('pointerout',out);
 root.addEventListener('focusin',over);root.addEventListener('focusout',out);
 window.addEventListener('keydown',esc,true);
 return {
  refresh(){
   card=card?.isConnected?card:mine();key=card?.dataset.hcKey??null;
   if(!card||key===null)return;
   const next=[...root.querySelectorAll<HTMLElement>('[data-hc-key]')].find(e=>e.dataset.hcKey===key)??null;
   // The card survives a redraw only while its mark is still under the pointer or holds the focus: a redrawn element never reports
   // the pointer leaving, so the last known pointer position decides (else the card would outlive the hover).
   const under=pointer!==null&&document.elementFromPoint(pointer.x,pointer.y)?.closest<HTMLElement>('[data-hc-key]')?.dataset.hcKey===key;
   const focused=next!==null&&(next===document.activeElement||next.contains(document.activeElement));
   // A table that is not in the page yet (just rebuilt) cannot be hit-tested: keep the card, the next refresh decides.
   if(!next||(root.isConnected&&!(under||focused))){close();return;}
   fill(next);place(next);
  },
  close,
  detach:()=>{document.removeEventListener('pointermove',track,true);document.removeEventListener('pointerdown',track,true);root.removeEventListener('pointerover',over);root.removeEventListener('pointerout',out);root.removeEventListener('focusin',over);root.removeEventListener('focusout',out);window.removeEventListener('keydown',esc,true);},
  open:()=>card?key:null,
  dispose,
 };
}

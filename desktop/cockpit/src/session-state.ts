// SPDX-License-Identifier: MIT
export type SessionState = 'idle'|'working'|'done'|'error';
export const SESSION_FLASH_COOLDOWN_MS = 30_000;
const states:readonly string[]=['idle','working','done','error'];
interface SessionRecord { state:SessionState; flashedAt:number|null }
export interface SessionChange { readonly state:SessionState; readonly changed:boolean; readonly flash:boolean }

/** Explicit session-state input only; never inferred from quota or request completion.
 * Rapid transitions update the latest state but share one flash. No pending flash,
 * timeout or interval fires later when a cooldown expires. Clear with private views.
 */
export class SessionStateTracker {
  private sessions=new Map<string,SessionRecord>();
  update(sessionID:string,state:SessionState,now:number,visible=true,reducedMotion=false):SessionChange {
    if(!sessionID||sessionID.length>128||!states.includes(state)||!Number.isFinite(now)||now<0)throw TypeError('Invalid session state');
    const previous=this.sessions.get(sessionID),changed=previous!==undefined&&previous.state!==state;
    if(previous&&!changed)return {state,changed:false,flash:false};
    const flash=changed&&visible&&!reducedMotion&&(previous.flashedAt===null||now-previous.flashedAt>=SESSION_FLASH_COOLDOWN_MS);
    this.sessions.set(sessionID,{state,flashedAt:flash?now:previous?.flashedAt??null});
    return {state,changed,flash};
  }
  clear():void {this.sessions.clear();}
}

/** Reusable session-area indicator. The consumer supplies accepted session states
 * and native visibility; no new host message or synthetic session feed is installed.
 */
export function mountSessionState(root:HTMLElement,tracker:SessionStateTracker,sessionID:string,initial:SessionState,clock:()=>number=()=>performance.now()) {
  let id:string|null=sessionID,visible=true;
  let permittedAnimation:Animation|null=null;
  const motion=matchMedia('(prefers-reduced-motion: reduce)'),listeners=new AbortController();
  const reduced=()=>matchMedia('(prefers-reduced-motion: reduce)').matches;
  const stop=()=>{permittedAnimation=null;root.classList.remove('is-flashing');};
  const settled=()=>{
    // CSS preference changes must not recreate a cancelled pulse on restoration.
    // Only the exact animation created by an eligible transition may run.
    if(!permittedAnimation||!root.getAnimations().includes(permittedAnimation)||['idle','finished'].includes(permittedAnimation.playState))stop();
  };
  const gate=()=>{if(!visible||document.hidden||reduced())stop();};
  const motionChanged=(event:MediaQueryListEvent)=>{if(event.matches)stop();};
  root.classList.add('session-state');root.setAttribute('role','img');
  function paint(state:SessionState):SessionChange {
    if(id===null)throw Error('Disposed session indicator');
    const result=tracker.update(id,state,clock(),visible&&!document.hidden,reduced());
    if(root.dataset.state!==state||!root.hasAttribute('aria-label')){root.dataset.state=state;root.setAttribute('aria-label','Session state: '+state);}
    if(result.flash){
      stop();void root.offsetWidth;root.classList.add('is-flashing');
      permittedAnimation=root.getAnimations()[0]??null;
      if(!permittedAnimation)stop();
    }
    return result;
  }
  paint(initial);
  root.addEventListener('animationend',settled,{signal:listeners.signal});
  root.addEventListener('animationcancel',settled,{signal:listeners.signal});
  root.addEventListener('animationstart',settled,{signal:listeners.signal});
  document.addEventListener('visibilitychange',gate,{signal:listeners.signal});
  motion.addEventListener('change',motionChanged,{signal:listeners.signal});
  return {
    update:paint,
    setVisible(value:boolean){visible=value;gate();},
    dispose(){id=null;listeners.abort();stop();root.removeAttribute('data-state');root.removeAttribute('role');root.removeAttribute('aria-label');root.classList.remove('session-state');},
  };
}

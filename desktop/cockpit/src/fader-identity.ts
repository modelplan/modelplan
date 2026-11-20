// SPDX-License-Identifier: MIT
// The deck names its faders by position ("model0", "model1", ...) in the publication adapter's order, and that order
// changes when sessions start or end (models in use lead). UI state held across a delivery (the selected model, the
// open comparison, the trial's ghost) is carried over by the published model it named, never by its old position.

/** Maps a positional fader id from the previous delivery to the same published model's id in the next one, or null when
 * that model is gone. Ids that are not positional (a published id) pass through unchanged. */
export function positionalRemap(before:readonly string[],after:readonly string[]):(id:string)=>string|null {
 return id=>{
  const match=/^model(\d+)$/.exec(id);if(!match)return id;
  const published=before[Number(match[1])];if(!published)return null;
  const at=after.indexOf(published);return at<0?null:'model'+at;
 };
}

/** The open comparison against the latest fader input: current and Fast follow the session as reported now. A trial
 * argument that only repeated the old current effort (the comparison opened from the LCD, nothing tried) follows it too,
 * so a new reading never turns into a trial of the old effort (audit F 2, CKP-FAD-22). */
export function refreshComparison<T extends {current:string|null;currentFast:boolean;trial?:string;fast?:boolean}>(compare:T,f:{current:string|null;currentFast:boolean}):T {
 const current=f.current??null,next={...compare,current,currentFast:!!f.currentFast};
 const fastChosen=compare.fast!==undefined&&compare.fast!==compare.currentFast; // a Fast-only trial is the user's own
 if(compare.current!==current&&compare.trial!==undefined&&compare.trial===compare.current&&!fastChosen)delete next.trial;
 return next;
}

type ComparedFader={id:string;sourceId:string;name:string;short:string;rec:string;e:unknown[];current:string|null;currentFast:boolean};
type OpenComparison={modelId:string;trial?:string;fast?:boolean};
/** The comparison card's model and arguments from the latest fader input: the current effort and Fast mode are the
 * session's as reported now (CKP-MFD-19: unreported stays unreported), only the trial is the user's. The model carries
 * its published id for the website link. */
export function comparisonInput(f:ComparedFader,compare:OpenComparison,pool:string|null){
 return {
  model:{id:f.id,publishedId:f.sourceId,name:f.name,short:f.short||f.name,rec:f.rec,e:f.e,pool},
  args:{modelId:f.id,current:f.current??null,...(compare.trial?{trial:compare.trial}:{}),...(compare.fast!==undefined?{fast:compare.fast}:{}),currentFast:!!f.currentFast},
 };
}

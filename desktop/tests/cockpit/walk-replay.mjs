// SPDX-License-Identifier: MIT
// Labels are presentation, not identity: calendar day labels change with the wall clock.
export function replayTargetMatches(recorded,actual){
 if(!actual||recorded.selector!==actual.selector||recorded.index!==actual.index)return false;
 if(recorded.key!==actual.key||recorded.choice!==actual.choice||recorded.option!==actual.option)return false;
 return !!recorded.key||!!recorded.choice||recorded.label===actual.label;
}

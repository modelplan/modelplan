export function timeRatio(e,base){
  if(typeof e?.time!=='number'||!Number.isFinite(e.time)||!(base?.time>0)||!e.timeBasis||!base.timeBasis)return null;
  if(!['source','cohort','boundary','referenceSeconds'].every(k=>e.timeBasis[k]===base.timeBasis[k]))return null;
  return e.time/base.time;
}

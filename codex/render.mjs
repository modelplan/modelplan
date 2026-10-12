// Text twin of clients/go/internal/render on main. No ANSI in MCP results.
import { recommendation } from "./data.mjs";
import { timeRatio } from "./ui/comparison.js";
export const words = {
  zh: { which:"选哪台",at:"各模型都在 ★推荐档",base:"成本以 %s 为 ×1",ability:"能力",cost:"成本",time:"耗时",skip:"跳过",why:"又贵又不更强",strongest:"最强",best_value:"最划算",cheapest:"最省",dominated:"不如 %s",equivalent_costlier:"≈ %s 但更贵",recommended:"推荐",estimated:"估算",vs:"相对 ★推荐",pts:"分" },
  en: { which:"Which engine",at:"every model at its ★ recommended effort",base:"cost relative to %s = ×1",ability:"ability",cost:"cost",time:"time",skip:"Skip",why:"costs more, not stronger",strongest:"strongest",best_value:"best value",cheapest:"cheapest",dominated:"not better than %s",equivalent_costlier:"≈ %s, costs more",recommended:"recommended",estimated:"estimate",vs:"vs ★",pts:"pts" },
};
export const short = name => name.replace(/^(Claude |Gemini )/, "");
export const ratio = v => typeof v !== "number" || !Number.isFinite(v) ? "—" : "×" + v.toFixed(v < 1 ? 2 : v < 10 ? 1 : 0);
export const pad = (s,n) => s + " ".repeat(Math.max(0,n-[...s].reduce((v,c)=>v+(/[\p{Script=Han}\u3000-\u303f\uff00-\uffef]/u.test(c)?2:1),0)));
function bar(frac,n) {
  const eighths=Math.round(Math.max(0,Math.min(1,frac))*n*8),rest=eighths%8;
  return pad("█".repeat(Math.floor(eighths/8))+(rest?" ▏▎▍▌▋▊▉█"[rest]:""),n);
}
export const tagText = (r,names,lang="zh") => (r.tags ?? []).map(k => (words[lang][k] ?? k).replace("%s",names[r.dominatedBy?.id]??"—")).join(" ");
export function renderLineup(data,lang="zh") {
  const t=words[lang], l=data.lineup; if (!l) return "openai: no published lineup (at least two complete comparable models required)";
  const by=Object.fromEntries(data.models.map(m=>[m.id,m])),names=Object.fromEntries(Object.entries(data.modelNames ?? Object.fromEntries(data.models.map(m=>[m.id,m.name]))).map(([id,name])=>[id,short(name)]));
  // Subset queries display the requested rows but retain the full published baseline.
  const name=id=>names[id]??id, rows=l.members.filter(r=>by[r.id]).slice().sort((a,b)=>(b.ability??0)-(a.ability??0));
  const out=[`WHICH ENGINE ${t.which} · OpenAI · ${t.at} · ${t.base.replace("%s",name(l.baseline))}`];
  for(const s of l.steps) out.push(`  ${pad(name(s.from)+" → "+name(s.to),26)}  ${t.ability} ${s.abilityDelta>=0?"+":""}${s.abilityDelta.toFixed(1)}  ${t.cost} ${ratio(s.costRatio)}`);
  const skip=l.members.filter(r=>r.dominatedBy).map(r=>name(r.id));
  if(skip.length)out.push(`  ${t.skip}${lang==="zh"?"：":": "}${skip.join(lang==="zh"?"、":", ")}${lang==="zh"?"（":" ("}${t.why}${lang==="zh"?"）":")"}`);
  out.push("");const aMax=Math.max(0,...l.members.map(r=>r.ability??0)),xMax=Math.max(1,...l.members.map(r=>r.costRelative??1));
  for(const r of rows){ const m=by[r.id],rec=recommendation(m),eff=rec?"★"+rec.label:"—";
    if(r.status==="incomplete"){out.push(`  ${pad(name(r.id),18)} ${pad(eff,8)}  —`);continue;}
    const cells=Math.max(1,Math.round((Math.log2(r.costRelative)+1)/(Math.log2(xMax)+1)*5));
    out.push(`  ${pad(name(r.id),18)} ${pad(eff,8)} ${t.ability} ${r.ability.toFixed(1).padStart(5)} ${bar(aMax?r.ability/aMax:0,12)}  ${t.cost} ${pad(ratio(r.costRelative),6)} ${"▰".repeat(cells)+"▱".repeat(5-cells)}  ${tagText(r,names,lang)}`);
  }
  return out.join("\n")+"\n";
}
export function renderEffort(m,lang="zh") {
  const t=words[lang],rec=recommendation(m),ri=m.configurations.indexOf(rec);
  const out=[`${m.name}  ${m.configurations.length} · ★ ${rec?.label??"—"} ${t.recommended} · ${t.vs}`];
  for(let i=m.configurations.length-1;i>=0;i--){const c=m.configurations[i];
    const a=c.ability===null?"—":rec?.ability==null?c.ability.toFixed(1):`${c.ability.toFixed(1)} (${c.ability-rec.ability>=0?"+":""}${(c.ability-rec.ability).toFixed(1)}${t.pts})`;
    const cost=c.cost===null||!rec?.cost?"—":ratio(c.cost/rec.cost);
    const value=timeRatio(c,rec);
    const time=value===null?"—":ratio(value)+((c.timeEstimated||rec.timeEstimated)?" "+t.estimated:"");
    out.push(`  ${i===ri?"◆":ri>=0&&i>ri?"┆":"│"} ${pad(i===ri?"★ "+c.label:c.label,8)}  ${t.ability} ${pad(a,14)}  ${t.cost} ${pad(cost,7)}  ${t.time} ${time}`);
  }
  return out.join("\n")+"\n";
}

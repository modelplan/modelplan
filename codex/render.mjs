// Text twin of clients/go/internal/render on main. No ANSI in MCP results.
import { recommendation } from "./data.mjs";
import { timeRatio } from "./ui/comparison.js";
export const words = {
  zh: { which:"选哪台",at:"各模型都在 ★推荐档",base:"成本以 %s 为 ×1",ability:"能力",cost:"成本",time:"耗时",skip:"跳过",why:"又贵又不更强",strongest:"最强",best_value:"最划算",cheapest:"最省",dominated:"不如 %s",equivalent_costlier:"≈ %s 但更贵",recommended:"推荐",estimated:"估算",vs:"相对 ★推荐",pts:"分",step:"↑ 比低一档" },
  en: { which:"Which engine",at:"every model at its ★ recommended effort",base:"cost relative to %s = ×1",ability:"ability",cost:"cost",time:"time",skip:"Skip",why:"costs more, not stronger",strongest:"strongest",best_value:"best value",cheapest:"cheapest",dominated:"not better than %s",equivalent_costlier:"≈ %s, costs more",recommended:"recommended",estimated:"estimate",vs:"vs ★",pts:"pts",step:"↑ vs one below" },
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
// Speed tiers for one model, as in `modelplan effort`: "⚡ Codex Fast  plan quota ×2.5 · credits ×2 · speed-up not stated".
const g2=v=>String(Math.round(v*100)/100);
export function renderSpeed(m,tiers=[],lang="zh") {
  const zh=lang==="zh",out=[];
  for(const t of tiers){const x=t.models.find(v=>v.modelId===m.id);if(!x)continue;
    const parts=t.billing.map(b=>b.billsTo==="plan-quota"?(zh?"套餐额度 ×":"plan quota ×")+g2(b.ratio):b.billsTo==="credits"?(zh?"积分 ×":"credits ×")+g2(b.ratio):null).filter(Boolean);
    const s=x.speed.ratio;parts.push(s==null?(zh?"提速未公布":"speed-up not stated"):(zh?`提速最多 ×${g2(s)} · 生成耗时最低 ×${g2(1/s)}`:`up to ×${g2(s)} faster · generation time ≥ ×${g2(1/s)}`));
    out.push(`  ${t.tier==="ultrafast"?"⚡⚡":"⚡"} Codex ${t.label}  ${parts.join(" · ")}`);}
  return out.length?out.join("\n")+"\n":"";
}
export function renderEffort(m,lang="zh",tiers=[]) {
  const t=words[lang],rec=recommendation(m),ri=m.configurations.indexOf(rec);
  const out=[`${m.name}  ${m.configurations.length} · ★ ${rec?.label??"—"} ${t.recommended} · ${t.vs} · ${t.step}`];
  for(let i=m.configurations.length-1;i>=0;i--){const c=m.configurations[i];
    const a=c.ability===null?"—":rec?.ability==null?c.ability.toFixed(1):`${c.ability.toFixed(1)} (${c.ability-rec.ability>=0?"+":""}${(c.ability-rec.ability).toFixed(1)}${t.pts})`;
    const cost=c.cost===null||!rec?.cost?"—":ratio(c.cost/rec.cost);
    const value=timeRatio(c,rec);
    const time=value===null?"—":ratio(value)+((c.timeEstimated||rec.timeEstimated)?" "+t.estimated:"");
    out.push(`  ${i===ri?"◆":ri>=0&&i>ri?"┆":"│"} ${pad(i===ri?"★ "+c.label:c.label,8)}  ${t.ability} ${pad(a,14)}  ${t.cost} ${pad(cost,7)}  ${t.time} ${pad(time,6)}  ${stepUp(m.configurations,i,t.pts)}`.trimEnd());
  }
  return out.join("\n")+"\n"+renderSpeed(m,tiers,lang);
}

// One effort against the next lower one, as in the CLI: "↑ +3.7分 ×1.45".
export function stepUp(es,i,pts) {
  if(i===0)return "";const lo=es[i-1],hi=es[i];
  if(![lo.ability,hi.ability,lo.cost,hi.cost].every(v=>typeof v==="number"&&Number.isFinite(v))||lo.cost<=0)return "↑ —";
  const d=hi.ability-lo.ability;return `↑ ${d>=0?"+":""}${d.toFixed(1)}${pts} ×${(hi.cost/lo.cost).toFixed(2)}`;
}

export const quotaWords = {
  zh:{title:"你的 Codex 额度（本机读取）",none:"本机没有可读的 Codex 额度",used:"已用",resets:"重置还有",kinds:{five_hour:"5小时",weekly:"每周",monthly:"每月",unknown:"窗口"},pace:{surplus:"富余",on_track:"正常",tight:"偏紧",exhausted:"用完",reset_passed:"已过重置",unknown:"—"},
    headroom:{spend:"额度富余：重置前用不完，可升档或开 Fast",normal:"额度正常：按 ★ 推荐档用",conserve:"额度偏紧：保持 ★ 或降一档",exhausted:"额度已用完：等重置或换用其他套餐",unknown:"额度未知"},stale:"读数较旧",d:"天",h:"时",m:"分",
    reader:{cli:"modelplan CLI 读取",python:"Python 回退读取",account:"Codex 账号读数"},setup:{missing:"设置：可选的 modelplan CLI 未安装，额度提醒和任务开始简报未启用；可在看板点“安装 CLI”，或运行 %c",declined:"设置：CLI 未安装（你已选择暂不安装）",outdated:"设置：modelplan CLI %v 低于 %m，简报和账号读数不可用；可在看板点“升级 CLI”",failed:"设置：modelplan CLI 运行失败（%e）",hookNever:"设置：提醒钩子尚未运行，需要在 Codex 中信任（CLI 输入 /hooks，桌面端在钩子审核里），信任后下一条消息生效",hookStale:"设置：插件更新后，新版提醒钩子还没运行过；Codex 会跳过有变化、未重新信任的钩子，请在 /hooks 或桌面端钩子审核里重新信任",ok:"设置完整：CLI %v · 钩子已运行 · 主动提醒可用"},credits:"%n 次完整重置可用%e · 需在 Codex 中自己兑换",creditsExpire:"，最早 %s 到期",thread:{"current-thread":"当前会话","recent-thread":"最近本机会话"},threadUnknown:"不一定是这次对话",defaultEffort:"默认档",observed:"%s前观测",unseen:"本机未观测到",hintsOff:"主动提醒未启用",hintReason:{cli_missing:"需要可选的 modelplan CLI 0.4+，本机未安装",cli_without_advise:"本机 modelplan CLI 不支持 advise，升级到 0.4+",advice_invalid:"CLI 返回的提醒无法解析",cli_failed:"modelplan CLI 运行失败"}},
  en:{title:"Your Codex quota (read on this machine)",none:"No Codex quota readable on this machine",used:"used",resets:"resets in",kinds:{five_hour:"5h",weekly:"week",monthly:"month",unknown:"window"},pace:{surplus:"surplus",on_track:"on track",tight:"tight",exhausted:"exhausted",reset_passed:"reset since",unknown:"—"},
    headroom:{spend:"Surplus: it resets unused, step up or use Fast",normal:"On track: use the ★ effort",conserve:"Tight: stay at ★ or step down",exhausted:"Exhausted: wait for the reset or use another plan",unknown:"Quota unknown"},stale:"old reading",d:"d",h:"h",m:"m",
    reader:{cli:"read by the modelplan CLI",python:"read by the Python fallback",account:"Codex account reading"},setup:{missing:"Setup: the optional modelplan CLI is not installed, so quota hints and the task-start brief are off; click Install CLI on the dashboard or run %c",declined:"Setup: CLI not installed (you chose not now)",outdated:"Setup: modelplan CLI %v is older than %m; the brief and the account reading are off; click Upgrade CLI on the dashboard",failed:"Setup: modelplan CLI failed (%e)",hookNever:"Setup: the hint hook has not run yet; trust it in Codex (/hooks in the CLI, hook review in the desktop app); it starts with the next message",hookStale:"Setup: since the plugin update the new hint hook has not run; Codex skips a changed hook until it is trusted again (/hooks, or the desktop hook review)",ok:"Setup complete: CLI %v · hook ran · hints on"},credits:"%n full reset credit(s) available%e · redeem them in Codex yourself",creditsExpire:", first expires %s",thread:{"current-thread":"this thread","recent-thread":"latest local thread"},threadUnknown:"may not be this conversation",defaultEffort:"default effort",observed:"seen %s ago",unseen:"not seen on this machine",hintsOff:"Proactive hints off",hintReason:{cli_missing:"they need the optional modelplan CLI 0.4+, not installed here",cli_without_advise:"the installed modelplan CLI has no advise; upgrade to 0.4+",advice_invalid:"the CLI's hints could not be parsed",cli_failed:"the modelplan CLI failed"}},
};
export function duration(min,q) {
  if(min<60)return `${min}${q.m}`;
  if(min<48*60)return min%60?`${Math.floor(min/60)}${q.h}${min%60}${q.m}`:`${min/60}${q.h}`;
  const d=Math.floor(min/1440),h=Math.floor((min%1440)/60);return h?`${d}${q.d}${h}${q.h}`:`${d}${q.d}`;
}
export function renderQuota(quota,lang="zh",advice=null,setup=null) {
  const q=quotaWords[lang],a=quota?.account,status=s=>setup?setupStatusLines(setup,q):hintStatus(advice,q);
  if(!a)return `${q.none}${quota?.reason?" ("+quota.reason+")":""}.\n`+status().map(l=>l+"\n").join("");
  const age=w=>typeof w?.ageMinutes==="number"&&w.ageMinutes>60?` · ${q.observed.replace("%s",duration(w.ageMinutes,q))}`:"";
  const head=[q.title,a.plan].filter(Boolean).join(" · ")+(a.stale?` · ${q.stale}`:"");
  const lines=[...threadLine(a.harness,q,quota.evaluatedAt),...a.windows.map(w=>{const kind=q.kinds[w.kind]??w.kind,used=typeof w.usedPercent==="number"?`${Math.round(w.usedPercent)}% ${q.used}`:"—";
    const reset=typeof w.resetsInMinutes==="number"?` · ${q.resets} ${duration(w.resetsInMinutes,q)}`:"";
    return `  ${kind}${w.limit?" "+w.limit:""} ${used}${reset} · ${q.pace[w.pace]??w.pace}${age(w)}`;}),
    ...["five_hour","weekly"].filter(k=>!a.windows.some(w=>w.kind===k&&!w.limit)).map(k=>`  ${q.kinds[k]} ${q.unseen}`)];
  const hints=(advice?.events??[]).map(e=>`  ${e.severity==="warn"?"!":"↑"} ${e.text[lang]??e.text.en}`);
  const cs=(a.cards??[]).filter(c=>c.kind==="full"&&c.count>0),first=cs.map(c=>c.expiresAt).filter(Boolean).sort()[0];
  const credits=cs.length?[`  ◆ ${q.credits.replace("%n",cs.reduce((s,c)=>s+c.count,0)).replace("%e",first?q.creditsExpire.replace("%s",first.slice(0,16).replace("T"," ")+"Z"):"")}`]:[];
  const reader=a.via==="codex-account"?q.reader.account:quota.reader?q.reader[quota.reader]:null;
  return [head,...lines,...credits,`  → ${q.headroom[a.headroom]??a.headroom}`,...hints,...status(),...(reader?[`  · ${reader}`]:[])].join("\n")+"\n";
}
// Each setup part on its own line, only what is not ready; one line when everything is.
function setupStatusLines(s,q){
  const c=s.cli??{},out=[],fill=t=>t.replace("%v",c.version??"").replace("%m",c.min??"").replace("%e",c.error??"").replace("%c",c.command??"");
  if(c.status==="missing")out.push(s.declined?q.setup.declined:fill(q.setup.missing));
  else if(c.status==="outdated")out.push(fill(q.setup.outdated));
  else if(c.status==="failed")out.push(fill(q.setup.failed));
  if(!s.hook?.lastRun)out.push(q.setup.hookNever);
  else if(s.hook.current===false)out.push(q.setup.hookStale);
  if(!out.length&&s.advice?.status==="ok")out.push(fill(q.setup.ok));
  return out.map(l=>"  · "+l);
}
// Hints are an optional add-on; say when and why they are off instead of showing nothing.
function hintStatus(advice,q){
  if(advice?.status!=="unavailable")return [];
  return [`  · ${q.hintsOff}${advice.reason?(q===quotaWords.zh?"：":": ")+(q.hintReason[advice.reason]??advice.reason):""}`];
}
// Which thread the model and effort came from. Only current-thread is this conversation.
function threadLine(h,q,evaluatedAt){
  if(!h?.model&&!h?.effort)return [];
  const ago=h.observedAt&&evaluatedAt?Math.max(0,Math.round((Date.parse(evaluatedAt)-Date.parse(h.observedAt))/60000)):null;
  const parts=[h.model,h.effort||q.defaultEffort,h.serviceTier==="fast"?"⚡ Fast":h.serviceTier||null].filter(Boolean).join(" · ");
  const note=[ago!==null?q.observed.replace("%s",duration(ago,q)):null,h.attribution==="current-thread"?null:q.threadUnknown].filter(Boolean).join(", ");
  const zh=q===quotaWords.zh;
  return [`  ${q.thread[h.attribution]??q.thread["recent-thread"]}${zh?"：":": "}${parts}${note?(zh?`（${note.replace(", ","，")}）`:` (${note})`):""}`];
}

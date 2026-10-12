// Presentation of the published entry only: never derive tags, a frontier or a baseline.
const lineupEsc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const lineupFinite=v=>typeof v==='number'&&Number.isFinite(v);
const lineupFx=v=>lineupFinite(v)?'×'+v.toFixed(v<1?2:v<10?1:0):'—';
const lineupFmt=v=>lineupFinite(v)?v.toFixed(1):'—';
export function publishedLineupView(data,{labels,language='zh',activeId=null}){
  const t=labels,l=data.lineup,by=Object.fromEntries(data.models.map(m=>[m.id,m])),nm=id=>by[id]?.name??data.modelNames?.[id]??id;
  const priority=r=>r.tags.some(t=>t==='strongest'||t==='best_value')?0:r.tags.includes('cheapest')?1:2;
  const rows=l?l.members.filter(r=>by[r.id]).slice().sort((a,b)=>priority(a)-priority(b)||(b.ability??0)-(a.ability??0)):[];
  const skip=l?.members.filter(r=>r.dominatedBy).map(r=>nm(r.id))??[];
  const verdict=l?'<div class="mp-verdict">'+l.steps.map(s=>'<span><b>'+lineupEsc(nm(s.from))+' → '+lineupEsc(nm(s.to))+'</b>'+t.a+' <em class="a">'+(s.abilityDelta>=0?'+':'')+lineupFmt(s.abilityDelta)+'</em> · '+t.c+' <em class="c">'+lineupFx(s.costRatio)+'</em></span>').join('')+(skip.length?'<span class="sk" data-skip>'+t.skip+(language==='zh'?'：':': ')+lineupEsc(skip.join(language==='zh'?'、':', '))+'</span>':'')+'</div>':'';
  const aMax=Math.max(1,...rows.map(r=>r.ability??0)),xMax=Math.max(1,...rows.map(r=>r.costRelative??1));
  const html=rows.map(r=>{const m=by[r.id],e=m.configurations.find(e=>e.effort===m.recommended),tags=r.tags.map(tag=>'<span class="mp-tag '+tag+'"'+(tag==='strongest'?' title="'+lineupEsc(language==='zh'?'推荐档对比：距最高分不超过 '+l.tie+' 分时，取费用更低的配置；不代表最高档上限。':'Recommended configurations: within '+l.tie+' point(s) of the top, prefer lower reference-task cost; not a maximum-effort ranking.')+'"':'')+'>'+lineupEsc((t[tag]??tag).replace('%s',nm(r.dominatedBy?.id)))+'</span>').join('');
    return '<button type="button" class="mp-row '+(m.id===activeId?'on':'')+'" data-model="'+lineupEsc(m.id)+'" aria-pressed="'+(m.id===activeId)+'"><i class="dot" style="background:var(--mp-openai)" aria-hidden="true"></i><span class="n">'+lineupEsc(m.name)+'<em>★ '+lineupEsc(e?.label??'—')+'</em></span><span class="mp-tags">'+tags+'</span><span class="mp-bars"><span>'+t.a+'</span><i class="a" style="width:'+Math.max(0,(r.ability??0)/aMax*100)+'%"></i><b>'+lineupFmt(r.ability)+'</b><span>'+t.c+'</span><i class="c" style="width:'+(lineupFinite(r.costRelative)?(Math.log2(r.costRelative)+1)/(Math.log2(xMax)+1)*100:0)+'%"></i><b>'+lineupFx(r.costRelative)+'</b></span></button>';
  }).join('')||'<div class="empty">'+t.no+'</div>';
  return {source:l,rows,verdict,html,base:l?t.base.replace('%s',nm(l.baseline)):t.no};
}

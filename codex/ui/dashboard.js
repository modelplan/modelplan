const $=id=>document.getElementById(id),finite=v=>typeof v==='number'&&Number.isFinite(v);
const esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const fx=v=>finite(v)?'×'+v.toFixed(v<1?2:v<10?1:0):'—',fmt=v=>finite(v)?v.toFixed(1):'—';
const W={zh:{which:'推荐档',base:'成本以 %s 为 ×1',a:'能力',c:'成本',t:'耗时',cheapest:'最省',strongest:'高能力优选',best_value:'最划算',dominated:'不如 %s',equivalent_costlier:'≈ %s 但更贵',rec:'推荐',at:'各模型都在 ★推荐档',skip:'跳过',vs:'相对 ★推荐',above:'超推荐',below:'低于推荐',estimate:'估算',no:'暂无数据',loading:'读取已核验发布…',error:'数据读取失败',retry:'重试',readonly:'只读比较',advisory:'比较设置，不切换会话',chart:'档位详情',resets:'公开重置公告',boundary:'不代表你的额度',more:'更多公告',empty:'近14天暂无已收录公告',unavailable:'公告数据暂不可用',published:'公布',scope:'范围',unknown:'未注明',confirmed:'来源确认',announced:'预告 / 待确认',effective:'生效',deadline:'预告截止',window:'预告时段',source:'原始来源',timeUnknown:'生效时间未注明',evidence:'数据与依据',full:'全部模型 ↗',current:'已核验发布',cached:'保留上一份快照',pts:'分',count:'个模型',restore:'恢复本模型推荐',release:'版本',publication:'发布',units:'口径',sourceLabel:'来源'},en:{which:'Recommended efforts',base:'cost relative to %s = ×1',a:'Ability',c:'Cost',t:'Time',cheapest:'cheapest',strongest:'high-capability pick',best_value:'best value',dominated:'not better than %s',equivalent_costlier:'≈ %s, costs more',rec:'recommended',at:'every model at its ★ recommended effort',skip:'Skip',vs:'vs ★',above:'Above rec.',below:'Below rec.',estimate:'Estimate',no:'No data',loading:'Reading verified publication…',error:'Data unavailable',retry:'Retry',readonly:'Read-only',advisory:'Comparison only; session unchanged',chart:'Effort details',resets:'Public reset notices',boundary:'Not your quota',more:'More notices',empty:'No recorded notices in the last 14 days',unavailable:'Reset data unavailable',published:'Published',scope:'Scope',unknown:'Unspecified',confirmed:'Source-confirmed',announced:'Announced / pending',effective:'Effective',deadline:'Scheduled by',window:'Announced window',source:'Original post',timeUnknown:'Effective time unspecified',evidence:'Data & basis',full:'All models ↗',current:'Verified publication',cached:'Last good snapshot',pts:'pts',count:'models',restore:'Restore model recommendation',release:'Release',publication:'Publication',units:'Units',sourceLabel:'Source'}};
let lang='zh',data=null,activeId=null,selected={},series=new Set(['ability','cost','time']),userTheme=false;
const w=()=>W[lang],rec=m=>m.configurations.find(e=>e.effort===m.recommended),model=()=>data?.models.find(m=>m.id===activeId);
let hostReady=false,hostInit=null,hostContext={},requestId=0,pending=new Map();const embedded=window.parent!==window&&!document.documentElement.hasAttribute('data-preview');
function panelButton(){const expanded=hostContext.displayMode==='fullscreen';$('expand').textContent=lang==='zh'?(expanded?'收起 ↙':'展开 ↗'):(expanded?'Return ↙':'Expand ↗');$('expand').ariaLabel=lang==='zh'?(expanded?'返回对话内看板':'展开面板'):(expanded?'Return to inline view':'Expand panel');}
function presentationNote(text){$('toast').textContent=text;$('toast').hidden=false;setTimeout(()=>{$('toast').hidden=true;},5000);}
function rpc(method,params){return new Promise((resolve,reject)=>{const id=++requestId,timer=setTimeout(()=>{pending.delete(id);reject(Error('Host bridge timeout'))},20000);pending.set(id,{resolve,reject,timer});window.parent.postMessage({jsonrpc:'2.0',id,method,params},'*')});}
function applyTheme(theme){document.documentElement.dataset.theme=theme==='light'?'light':'dark';}
window.addEventListener('message',e=>{if(e.source!==window.parent)return;const m=e.data;if(!m||m.jsonrpc!=='2.0')return;
 if(m.id!==undefined&&pending.has(m.id)){const p=pending.get(m.id);clearTimeout(p.timer);pending.delete(m.id);m.error?p.reject(Error(m.error.message)):p.resolve(m.result);return;}
 if(m.method==='ui/notifications/tool-result'&&m.params?.structuredContent)accept(m.params.structuredContent);
 if(m.method==='ui/notifications/host-context-changed'&&m.params?.theme&&!userTheme)applyTheme(m.params.theme);
 if(m.method==='ui/notifications/host-context-changed'){hostContext={...hostContext,...m.params};panelButton();}
 if(m.id!==undefined&&m.method)window.parent.postMessage({jsonrpc:'2.0',id:m.id,result:{}},'*');
});
async function initializeHost(){const r=await rpc('ui/initialize',{protocolVersion:'2026-01-26',appInfo:{name:'modelplans-dashboard',version:'0.5.0'},appCapabilities:{availableDisplayModes:['inline','fullscreen']}});hostReady=true;hostContext=r.hostContext??{};panelButton();if(r.hostContext?.theme)applyTheme(r.hostContext.theme);window.parent.postMessage({jsonrpc:'2.0',method:'ui/notifications/initialized'},'*');}
function accept(next){if(next?.schemaVersion!==1||!Array.isArray(next.models)||!next.publicationId)return showError(Error('Invalid published dashboard'));data=next;
 if(next.language)lang=next.language;
 if(next.focusModelId&&next.models.some(m=>m.id===next.focusModelId))activeId=next.focusModelId;
 if(!next.models.some(m=>m.id===activeId))activeId=next.lineup?.members.find(r=>r.tags.includes('best_value'))?.id??next.models[0]?.id;
 for(const m of next.models)if(!m.configurations.some(e=>e.effort===selected[m.id]))selected[m.id]=m.recommended??m.configurations[0]?.effort;
 render();
}
async function load(refresh=false){$('refresh').disabled=true;try{if(embedded){await hostInit;if(!hostReady)throw Error('Host bridge unavailable');const r=await rpc('tools/call',{name:'get_model_dashboard',arguments:{refresh,lang}});if(r.isError)throw Error(r.content?.[0]?.text??'Data tool failed');accept(r.structuredContent);}else{const r=await fetch('/api/dashboard'+(refresh?'?refresh=1':''));if(!r.ok)throw Error('Data API '+r.status);accept(await r.json());}}catch(e){if(data){data={...data,stale:true,error:e.message};render();}else showError(e);}finally{$('refresh').disabled=false;}}
function showError(e){$('models').innerHTML='<div class="error-state">'+w().error+'<br><small>'+esc(e.message)+'</small><br><button class="mp-chip" id="retry">'+w().retry+'</button></div>';$('retry').onclick=()=>load(true);$('statusText').textContent=w().error;$('resets').innerHTML='<li><span>'+w().unavailable+'</span></li>';}
function render(){const t=w(),l=data.lineup,by=Object.fromEntries(data.models.map(m=>[m.id,m])),nm=id=>by[id]?.name??data.modelNames?.[id]??id;
 panelButton();
 $('language').textContent=lang==='zh'?'EN':'中';document.documentElement.lang=lang==='zh'?'zh-CN':'en';$('scopeHint').textContent=t.readonly;$('advisory').textContent=t.advisory;$('chartToggle').textContent=t.chart;$('evidenceLabel').textContent=t.evidence;$('website').textContent=t.full;$('restore').ariaLabel=t.restore;
 $('lineupHeading').textContent=t.which;$('base').textContent=l?t.base.replace('%s',nm(l.baseline)):t.no;
 const view=publishedLineupView(data,{labels:t,language:lang,activeId});
 $('base').textContent=view.base;$('verdict').innerHTML=view.verdict;$('models').innerHTML=view.html;
 $('lineupNote').textContent=view.rows.length+' '+(lang==='zh'?'个已评估模型 · ↕ 列表可滚动':'evaluated models · ↕ scroll this list');$('lineupNote').title=t.at;
 const c=model();$('selectedConsole').hidden=!c;if(c)renderConsole(c);renderResets();
 $('state').classList.toggle('stale',data.stale);$('statusText').textContent=(data.stale?t.cached:t.current)+' · '+data.publicationId.slice(0,8);
 $('metadata').innerHTML=[[lang==='zh'?'摘要构建':'Digest built',dateTime(data.builtAt)],[t.publication,data.publicationId],[t.units,Object.entries(data.units).map(([k,v])=>k+': '+v).join(' · ')],[t.sourceLabel,data.source],['Timezone',Intl.DateTimeFormat().resolvedOptions().timeZone],[lang==='zh'?'核验':'Verified',dateTime(data.verifiedAt)],[lang==='zh'?'检查':'Checked',dateTime(data.checkedAt)]].map(([k,v])=>'<dt>'+esc(k)+'</dt><dd>'+esc(v)+'</dd>').join('')+(data.error?'<dt>State</dt><dd>'+esc(data.error)+'</dd>':'');
}
function renderConsole(m){const t=w(),E=m.configurations,ri=E.findIndex(e=>e.effort===m.recommended),ci=Math.max(0,E.findIndex(e=>e.effort===selected[m.id])),r=E[ri],q=E[ci],pos=i=>E.length===1?50:92-84*i/(E.length-1),lev=$('lever');
 $('selectedName').textContent=m.name;$('selectedEffort').textContent=q.label;lev.dataset.fixed=E.length===1;lev.setAttribute('aria-valuemin','0');lev.setAttribute('aria-valuemax',String(E.length-1));lev.setAttribute('aria-valuenow',String(ci));lev.setAttribute('aria-valuetext',q.label+(ci===ri?' · '+t.rec:''));lev.ariaLabel=m.name+' · '+(lang==='zh'?'档位详情':'Effort');
 const signature=JSON.stringify([m.id,m.recommended,E.map(e=>[e.effort,e.label]),lang]);
 if(lev.dataset.structure!==signature){lev.dataset.structure=signature;lev.innerHTML='<span class="slot"></span>'+(ri>=0&&ri<E.length-1?'<span class="zone" style="bottom:auto;height:calc('+pos(ri)+'% - 12px)"></span>':'')+E.map((e,i)=>'<span class="det '+(i===ri?'rc ':'')+(i===ci?'cur':'')+'" style="top:'+pos(i)+'%"><button type="button" tabindex="-1" data-detent="'+i+'" aria-label="'+esc(e.label)+'"></button><small>'+(i===ri?'★ ':'')+esc(e.label)+'</small></span>').join('')+'<span class="knob" style="top:'+pos(ci)+'%"></span>';}
 lev.querySelectorAll('.det').forEach((el,i)=>el.classList.toggle('cur',i===ci));lev.querySelector('.knob').style.top=pos(ci)+'%';
 const plot=effortCurveData(m,timeRatio),row=plot.rows[ci],estimated=finite(row.time)&&row.estimated;$('tiles').title=lang==='zh'?'相对本模型 ★'+(r?.label??'—')+'：能力为增减分数，成本／耗时为倍率。':'Relative to this model’s ★'+(r?.label??'—')+': ability in point gains; cost/time in multiples.';
 $('tiles').innerHTML='<div class="readout-head"><button class="ability-reading" data-series="ability" aria-pressed="'+series.has('ability')+'"><small>'+t.a+'</small><strong>'+fmt(q.ability)+'</strong></button><span class="gain-reading">'+curveGain(row.ability)+' '+t.pts+'</span></div><div class="ratio-readings">'+[['cost',t.c],['time',t.t]].map(([key,label])=>'<button class="metric-reading '+key+'" data-series="'+key+'" aria-pressed="'+series.has(key)+'"><span>'+label+'</span><b>'+(key==='time'&&estimated?'≈':'')+curveMultiple(row[key])+'</b></button>').join('')+'</div><div class="mini-chart" id="miniChart">'+effortCurveSvg(plot,{selected:ci,series,mini:true,language:lang})+'</div>';
 renderChart(m);
}
function choose(i){const m=model();if(!m)return;const q=m.configurations[Math.max(0,Math.min(m.configurations.length-1,i))];selected[m.id]=q.effort;renderConsole(m);}
let drag=false;
function pick(e){const m=model();if(!m||m.configurations.length===1)return;const b=$('lever').getBoundingClientRect(),f=(e.clientY-b.top)/b.height;choose(Math.round((.92-f)/.84*(m.configurations.length-1)));}
$('lever').onpointerdown=e=>{if(e.button!==0)return;e.preventDefault();$('lever').focus({preventScroll:true});drag=true;$('lever').classList.add('dragging');$('lever').setPointerCapture(e.pointerId);pick(e);};
$('lever').onpointermove=e=>{if(drag)pick(e);};
function endDrag(){drag=false;$('lever').classList.remove('dragging');}
$('lever').onpointerup=endDrag;$('lever').onpointercancel=endDrag;$('lever').onlostpointercapture=endDrag;
$('lever').onkeydown=e=>{const m=model();if(!m)return;let i=m.configurations.findIndex(c=>c.effort===selected[m.id]);if(e.key==='ArrowUp'||e.key==='ArrowRight')i++;else if(e.key==='ArrowDown'||e.key==='ArrowLeft')i--;else if(e.key==='Home')i=0;else if(e.key==='End')i=m.configurations.length-1;else return;e.preventDefault();choose(i);};
function renderChart(m){const t=w(),ci=m.configurations.findIndex(e=>e.effort===selected[m.id]);
 $('legend').innerHTML=['ability','cost','time'].map((key,i)=>'<button data-series="'+key+'" aria-pressed="'+series.has(key)+'"><i style="--series:var(--mp-'+key+')"></i>'+[t.a+' Δ'+t.pts,t.c+' ×',t.t+' ×'][i]+'</button>').join('');
 $('chart').innerHTML=effortCurveSvg(effortCurveData(m,timeRatio),{selected:ci,series,language:lang});
}
function date(v){return Number.isFinite(Date.parse(v))?new Date(v).toLocaleDateString(lang==='zh'?'zh-CN':'en',{month:'2-digit',day:'2-digit'}):'—';}
function dateTime(v){return Number.isFinite(Date.parse(v))?new Date(v).toLocaleString(lang==='zh'?'zh-CN':'en',{month:'2-digit',day:'2-digit',hour:'2-digit',minute:'2-digit',hour12:false}):'—';}
function renderResets(){
 const t=w(),f=data.resetFeed;$('resetHeading').textContent='RESETS · '+t.resets;$('resetBoundary').textContent=t.boundary;$('moreResetLabel').textContent=t.more;
 const safe=v=>{try{const u=new URL(v);return ['https:','http:'].includes(u.protocol)?u.href:null;}catch{return null;}};
 const eventHtml=e=>{
  const scope=lang==='en'?({'所有付费订阅':'All paid plans','全体用户':'All users','global':'Global'}[e.scope]??e.scope??t.unknown):(e.scope??t.unknown);
  const title=({reset_credit_issued:lang==='zh'?'重置卡发放公告':'Reset credit issued',direct_reset_announced:lang==='zh'?'额度重置预告':'Reset announced',direct_reset_reported_complete:lang==='zh'?'额度重置完成公告':'Reset reported complete'}[e.eventType]);
  const status=e.status==='upstream-confirmed'?t.confirmed:e.status==='upstream-announced'?t.announced:t.unknown;
  const timing=e.at&&e.precision==='instant'?t.effective+' '+dateTime(e.at):e.at&&e.precision==='day'?date(e.at)+' · '+(lang==='zh'?'仅日期':'Date only'):t.timeUnknown;
  const link=safe(e.url);
  return '<li data-notice="'+esc(e.id)+'"><time>'+esc(date(e.publishedAt))+'</time><span class="notice">'+esc(title??status)+'</span><details><summary>'+esc(status)+' · '+t.scope+' '+esc(scope)+'</summary><p>'+t.published+' '+esc(dateTime(e.publishedAt))+'<br>'+esc(timing)+(e.schedule?.from?'<br>'+esc((e.schedule.precision==='deadline'?t.deadline:t.window)+' '+dateTime(e.schedule.from)+(e.schedule.precision==='window'?' – '+dateTime(e.schedule.through):'')):'')+'</p>'+(link?'<a href="'+esc(link)+'" target="_blank" rel="noreferrer">'+t.source+' ↗</a>':'')+'</details></li>';
 };
 const events=f?.events??[];$('resets').innerHTML=f?.status!=='published'?'<li><span>'+t.unavailable+'</span></li>':events.length?events.slice(0,2).map(eventHtml).join(''):'<li><span>'+t.empty+'</span></li>';
 $('moreResets').hidden=events.length<=2;$('resetHistory').innerHTML=events.slice(2).map(eventHtml).join('');
}
document.addEventListener('click',e=>{const row=e.target.closest('[data-model]');if(row){activeId=row.dataset.model;document.querySelectorAll('.mp-row').forEach(b=>{b.classList.toggle('on',b.dataset.model===activeId);b.setAttribute('aria-pressed',String(b.dataset.model===activeId));});renderConsole(model());return;}const s=e.target.closest('[data-series]');if(s){series=focusCurveSeries(series,s.dataset.series);const inReadout=!!s.closest('#tiles');renderConsole(model());$(inReadout?'tiles':'legend').querySelector('[data-series="'+s.dataset.series+'"]')?.focus();return;}const c=e.target.closest('[data-chart-detent]');if(c)choose(Number(c.dataset.chartDetent));});
document.addEventListener('keydown',e=>{const c=e.target.closest('[data-chart-detent]');if(c&&['Enter',' '].includes(e.key)){e.preventDefault();choose(Number(c.dataset.chartDetent));$('chart').querySelector('[data-chart-detent="'+c.dataset.chartDetent+'"]')?.focus();}});
$('chartToggle').onclick=()=>{$('chartPanel').hidden=!$('chartPanel').hidden;$('chartToggle').setAttribute('aria-expanded',String(!$('chartPanel').hidden));};
$('restore').onclick=()=>{const m=model();if(m){selected[m.id]=m.recommended??m.configurations[0]?.effort;renderConsole(m);}};
$('language').onclick=()=>{lang=lang==='zh'?'en':'zh';if(data)render();};$('theme').onclick=()=>{userTheme=true;applyTheme(document.documentElement.dataset.theme==='light'?'dark':'light');};$('refresh').onclick=()=>load(true);
$('expand').onclick=async()=>{const button=$('expand');if(!embedded){presentationNote(lang==='zh'?'请在 Codex 中打开此看板，浏览器预览没有宿主面板。':'Open this board in Codex; browser preview has no host panel.');return;}button.disabled=true;try{await hostInit;if(!hostReady)throw Error('Host bridge unavailable');const r=await requestPanelMode(rpc,hostContext);hostContext={...hostContext,displayMode:r.mode};panelButton();if(r.status!=='changed')presentationNote(lang==='zh'?'当前客户端未提供展开模式，请继续使用对话内看板。':'This host did not expand the panel; continue in the inline view.');}catch{presentationNote(lang==='zh'?'客户端未能展开面板；看板数据与选档保留。':'The host could not expand the panel; data and comparison selection are retained.');}finally{button.disabled=false;}};
const previewTheme=document.documentElement.hasAttribute('data-preview')?new URLSearchParams(location.search).get('theme'):null;
applyTheme(['light','dark'].includes(previewTheme)?previewTheme:matchMedia('(prefers-color-scheme:light)').matches?'light':'dark');
if(embedded){hostInit=initializeHost().catch(showError);setTimeout(()=>{if(hostReady&&!data)void load();},700);}else void load();
if(embedded)new ResizeObserver(()=>{if(hostReady)window.parent.postMessage({jsonrpc:'2.0',method:'ui/notifications/size-changed',params:{height:$('shell').getBoundingClientRect().height}},'*');}).observe($('shell'));

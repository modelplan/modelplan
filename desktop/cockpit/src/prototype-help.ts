// SPDX-License-Identifier: MIT
// Cockpit annotations use the released study's captions, attached to the
// currently visible controls. They do not expose or retain reading data.
import {leaderAnchor,routeLeader} from '../study/rocket-r1/help-routing.js';
type Locale='en'|'zh-CN';
const notes:ReadonlyArray<readonly [string,string,string]>=[
 ['.ck-port','Window: click to open the 3D launch field.','悬窗：点击打开 3D 发射场。'],
 ['[data-shutter]','Window shutter: drag or press to fold or expand the Window.','悬窗开关：拖动或按一下，收起或展开。'],
 ['[data-caution]','Alert lamp: press for all alerts and to stop flashing.','注意灯：按一下查看全部提醒并停止闪烁。'],
 ['[data-settings]','Settings: adjust preferences or show hints again in its window.','设置：在独立窗口调整偏好或重新显示提示。'],
 ['[data-detach]','Detach','分离窗口'],['[data-close]','Close: end the local Try and close the Cockpit.','关闭：结束本地试档并收起驾驶舱。'],
 ['.eng-krow','Engine shortcuts: 0 = All; 1–6 = visible subscriptions.','引擎快捷键：0 = 全部；1–6 = 当前显示的订阅。'],
 ['.lb-t,.qrow-t,.qaverage','Today’s output; today’s average generation speed is summed eligible output tokens divided by summed generation seconds, not live speed; current source binding, not historical account attribution','今日输出；今日平均生成速度为可测速输出 token 总量除以生成秒数总量，不是实时速度；按当前来源关联，非历史账户归属'],
 ['.t-live','Generation speed in the last 60 seconds; at least 5 eligible samples; -- means unavailable','近 60 秒生成速度：合格请求至少 5 个样本；-- 表示不可用'],
 ['.lb-first','5h: only five-hour quota appears here; a blank means none exists.','5小时：这一行只放 5 小时额度，空白表示没有此额度。'],
 ['.lb-second','Weekly: only weekly quota appears here; a blank means none exists.','每周：这一行只放每周额度，空白表示没有此额度。'],
 ['.lb-other','Other: remaining periods and scoped quotas; +N means more.','其他：其他周期和专项额度，+N 表示还有更多。'],
 ['.dk-fad','Faders: each is a model; drag or press an effort for a local comparison that leaves the session unchanged.','推杆：每个代表一个模型，拖动或点档位作本地比较，不会改会话。'],
 ['.mfd-pk','Main screen: page keys change pages; bottom keys select or return.','公共屏：页键切页，底键选项或返回原页。'],
 ['.ck-tape','Session record: running sessions come first; press a row for details.','会话记录：运行中的在前，按一行查看详情。'],
 ['.ck-base .bz-line','Flame: this subscription is working now; it does not mean an alert.','火焰：表示这个订阅正在用，不表示额度告警。'],
];
export function mountPrototypeHelp(root:HTMLElement,getLocale:()=>Locale,isActive:()=>boolean,isAttached:()=>boolean){
 const layer=document.createElement('section');layer.id='help-map';layer.className='annot help-map';layer.hidden=true;layer.setAttribute('role','region');document.body.append(layer);
 const listeners=new AbortController();let held=false;
 const visible=(e:Element)=>{if(!e.isConnected||!e.getClientRects().length)return false;for(let p:Element|null=e;p;p=p.parentElement){const s=getComputedStyle(p);if((p as HTMLElement).hidden||s.display==='none'||s.visibility==='hidden'||s.opacity==='0')return false;}return true;};
 function render(){
  if(!held||!isActive()){layer.hidden=true;return;}
  const locale=getLocale();layer.replaceChildren();layer.hidden=false;layer.dataset.surface='cockpit';layer.setAttribute('aria-label',locale==='en'?'Cockpit help':'驾驶舱说明');
  const title=document.createElement('div');title.className='help-map-title';title.textContent=locale==='en'?'Engine = subscription · Fader = model · Flame = working now':'发动机 = 订阅 · 推杆 = 模型 · 火焰 = 正在用';
  const dismiss=document.createElement('span');dismiss.className='help-map-dismiss';dismiss.textContent=locale==='en'?'Press Esc or click to dismiss help':'按 Esc 或点一下退出说明';title.append(dismiss);layer.append(title);
  const targets=notes.flatMap(([selector,en,zh])=>{const target=[...root.querySelectorAll(selector)].find(visible);if(!target)return [];const box=target.getBoundingClientRect(),caption=document.createElement('span');caption.className='an';caption.dataset.target=selector;caption.textContent=selector==='[data-detach]'&&!isAttached()?(locale==='en'?'Put back':'放回菜单栏'):locale==='en'?en:zh;layer.append(caption);return [{target,box,caption}];}).sort((a,b)=>a.box.y-b.box.y);
  if(!targets.length){layer.hidden=true;return;}
  const viewportWidth=window.innerWidth,viewportHeight=window.innerHeight,ship=root.getBoundingClientRect();
  const shortcutTarget=root.querySelector('.eng-krow');if(shortcutTarget&&visible(shortcutTarget)){const shortcut=document.createElement('span');shortcut.className='an';shortcut.dataset.target='.eng-krow';shortcut.textContent=locale==='en'?'Engine shortcuts: 0 = All; 1–6 = visible subscriptions.':'引擎快捷键：0 = 全部；1–6 = 当前显示的订阅。';layer.append(shortcut);Object.assign(shortcut.style,{right:'12px',bottom:'12px',width:Math.min(280,viewportWidth-24)+'px'});}const available=Math.max(180,ship.x-28),width=Math.min(400,available),gap=root.dataset.layout==='890'?12:6,edge=ship.x;
  Object.assign(title.style,{left:Math.max(8,edge-width-14)+'px',top:'34px',width:width+'px'});
  for(const {caption} of targets)caption.style.width=width+'px';
  const start=34+title.offsetHeight+gap,space=viewportHeight-start-12,total=targets.reduce((n,x)=>n+x.caption.offsetHeight+gap,0),columns=total>space?2:1;
  if(columns===2)for(const {caption} of targets)caption.style.width=Math.min(width,(available-12)/2)+'px';
  const heights=Array<number>(columns).fill(start),columnWidth=targets[0].caption.offsetWidth;
  for(const [i,{caption}] of targets.entries()){const col=columns===1?0:Math.min(columns-1,Math.floor(i/Math.ceil(targets.length/columns)));Object.assign(caption.style,{left:Math.max(8,edge-14-columnWidth*(columns-col)-12*(columns-col-1))+'px',top:heights[col]+'px'});heights[col]+=caption.offsetHeight+gap;}
  const rect=(e:Element)=>{const r=e.getBoundingClientRect();return {x:r.x,y:r.y,width:r.width,height:r.height};};
  const labels=targets.map(x=>rect(x.caption)),live=[...root.querySelectorAll('.eng-cols,.fd-chs,.bank-lcd,.hud,.mfd-screen,.t-lines')].filter(visible).map(rect),titleRect=rect(title),viewport={width:viewportWidth,height:viewportHeight};
  const svg=document.createElementNS('http://www.w3.org/2000/svg','svg');svg.setAttribute('aria-hidden','true');svg.setAttribute('viewBox',`0 0 ${viewportWidth} ${viewportHeight}`);
  targets.forEach(({box,caption},i)=>{const r=labels[i],start={x:r.x+r.width+2,y:r.y+r.height/2},blocks=[...live,titleRect,...labels.filter((_,j)=>j!==i)],side=caption.dataset.target?.startsWith('[data-')||['.mfd-pk','.ck-tape'].includes(caption.dataset.target??'')?'top':caption.dataset.target==='.dk-fad'?'bottom':'left',preferred=side==='top'?{x:box.x+box.width/2,y:Math.max(28,box.y-4)}:side==='bottom'?{x:box.x+box.width/2,y:box.y+box.height+4}:{x:box.x-4,y:box.y+box.height/2};
   const end=leaderAnchor(box,preferred,blocks,viewport),points=end?routeLeader(start,end,blocks,viewport):[];if(!end||!points.length)return;
   const path=document.createElementNS(svg.namespaceURI,'path');path.setAttribute('d',points.map((p,j)=>(j?'L':'M')+p.x+' '+p.y).join(' '));svg.append(path);const circle=document.createElementNS(svg.namespaceURI,'circle');circle.setAttribute('cx',String(end.x));circle.setAttribute('cy',String(end.y));circle.setAttribute('r','2');svg.append(circle);
  });layer.prepend(svg);
 }
 const observer=new MutationObserver(()=>{if(held)render();});observer.observe(root,{childList:true,subtree:true,attributes:true,attributeFilter:['class','style','hidden','data-layout']});
 const down=(e:KeyboardEvent)=>{if(e.key==='Alt'&&isActive()){held=true;render();e.preventDefault();}else if(e.key==='Escape'&&held){held=false;render();e.preventDefault();}};
 const up=(e:KeyboardEvent)=>{if(e.key==='Alt'){held=false;render();}};
 window.addEventListener('keydown',down,{signal:listeners.signal});window.addEventListener('keyup',up,{signal:listeners.signal});window.addEventListener('blur',()=>{held=false;render();},{signal:listeners.signal});window.addEventListener('pointerdown',()=>{if(held){held=false;render();}},{signal:listeners.signal});window.addEventListener('resize',render,{signal:listeners.signal});
 return {refresh:render,hide(){held=false;render();},dispose(){listeners.abort();observer.disconnect();layer.remove();}};
}

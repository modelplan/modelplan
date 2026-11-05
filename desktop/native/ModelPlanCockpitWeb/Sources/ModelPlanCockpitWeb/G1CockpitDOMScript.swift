// SPDX-License-Identifier: MIT
#if DEBUG
  /// Pure read-only layout/style observation. It neither dispatches input nor reports protocol receipts.
  enum G1CockpitDOMScript {
    static let source = #"""
      (() => {
        let count=0;
        // Resolve modern colour syntax with WebKit itself, using an unattached scratch canvas.
        // This never inserts a node or changes the inspected document's style/state.
        const scratch=document.createElement('canvas');scratch.width=scratch.height=1;
        const paint=scratch.getContext('2d',{colorSpace:'srgb',willReadFrequently:true}),colours=new Map();
        const colour=(s,scheme)=>{
          if(!s)return null;
          let m=s.match(/^rgba?\(([^)]+)\)$/);
          if(m){const v=m[1].split(/[ ,/]+/).filter(Boolean).map(Number);if(v.length>=3&&v.every(Number.isFinite))return {r:v[0]/255,g:v[1]/255,b:v[2]/255,a:v.length>3?v[3]:1}}
          m=s.match(/^color\(srgb[ ]+([^)]*)\)$/);
          if(m){const v=m[1].split(/[ /]+/).filter(Boolean).map(Number);if(v.length>=3&&v.every(Number.isFinite))return {r:v[0],g:v[1],b:v[2],a:v.length>3?v[3]:1}}
          if(!paint||!CSS.supports('color',s))return null;
          const key=(scheme||'')+'|'+s;if(colours.has(key))return colours.get(key);
          scratch.style.colorScheme=scheme||'normal';paint.clearRect(0,0,1,1);paint.fillStyle='rgba(0,0,0,0)';paint.fillStyle=s;paint.fillRect(0,0,1,1);
          const v=paint.getImageData(0,0,1,1).data,result={r:v[0]/255,g:v[1]/255,b:v[2]/255,a:v[3]/255};colours.set(key,result);return result;
        };
        const source=s=>{try{const u=new URL(s,location.href);return u.protocol==='modelplan-cockpit:'&&u.host==='bundle'?u.pathname.replace(/^\//,''):null}catch{return null}};
        const read=(n,path,depth,opacityVisible=true)=>{
          if(++count>2048||depth>32)return null;
          const s=getComputedStyle(n),r=n.getBoundingClientRect(),p=n.parentElement?.getBoundingClientRect();
          const paintedOpacity=opacityVisible&&Number(s.opacity)>0;
          const sensitive=(n.tagName==='INPUT'||n.tagName==='TEXTAREA')&&(/password|secret|token|api.?key/i.test([n.type,n.id,n.name,n.autocomplete].join(' ')));
          let text=Array.from(n.childNodes).filter(x=>x.nodeType===Node.TEXT_NODE).map(x=>x.textContent).join('').trim();
          if(n.tagName==='INPUT'||n.tagName==='TEXTAREA')text=sensitive?null:(n.tagName==='TEXTAREA'||['text','search','email','url','tel','number','date','time'].includes(n.type)?n.value:null);
      if(n.tagName==='SELECT')text=n.selectedOptions?.[0]?.textContent?.trim()||'';
          const bg=colour(s.backgroundColor,s.colorScheme),filters=[];if(s.filter!=='none')filters.push(s.filter);
          const back=s.backdropFilter||s.webkitBackdropFilter;if(back&&back!=='none')filters.push('backdrop:'+back);
          const effects=[];if(s.boxShadow!=='none')effects.push('box-shadow:'+s.boxShadow);
          if(s.backgroundImage!=='none')effects.push(s.backgroundImage.includes('url(')?'background-image:asset-reference':'background-image:'+s.backgroundImage.slice(0,512));
          const animations=n.getAnimations().map(a=>{const t=a.effect?.getComputedTiming();return [a.playState,a.currentTime,t?.progress].join(':')});
          let asset=n.tagName==='IMG'?source(n.currentSrc||n.src):null;
          if(!asset){const match=s.backgroundImage.match(/url\(["']?([^"')]+)["']?\)/);if(match)asset=source(match[1])}
          const attrs={domOrder:path.split('/').pop(),position:s.position,isolation:s.isolation,mixBlendMode:s.mixBlendMode,classes:n.className?.baseVal??String(n.className||''),evidence:'completed-web-layout',opacity:s.opacity,transform:s.transform,zIndex:s.zIndex};
          for(const k of ['data-member','data-scope','data-role','data-choice','data-opt','aria-pressed','aria-selected','aria-expanded'])if(n.hasAttribute(k))attrs[k]=n.getAttribute(k).slice(0,160);
          const unavailable={};if(sensitive)unavailable.text='Secure control content withheld';
          if(text&&text.length>2048)attrs.textTruncated='true';
          return {identifier:n.id||n.getAttribute('data-testid')||path,role:n.getAttribute('role')||n.tagName.toLowerCase(),
            frame:[[r.x,r.y],[r.width,r.height]],
            visible:s.display!=='none'&&s.visibility!=='hidden'&&s.visibility!=='collapse'&&paintedOpacity&&r.width>0&&r.height>0&&r.right>0&&r.bottom>0&&r.left<innerWidth&&r.top<innerHeight,
            text:text===null?null:text.slice(0,2048),ink:colour(s.color,s.colorScheme),fill:bg,assetSource:asset,
            layerRoles:Array.from(n.classList||[]).slice(0,32),zOrder:s.zIndex==='auto'?null:Number(s.zIndex),
            interaction:{hover:n.matches(':hover'),press:n.matches(':active'),disabled:n.matches(':disabled')||n.getAttribute('aria-disabled')==='true'},
            filters,effects,animationPhase:animations.length?animations.join('|'):'idle',attributes:attrs,unavailable,
            children:Array.from(n.children).map((c,i)=>read(c,path+'/'+i,depth+1,paintedOpacity)).filter(Boolean)};
        };
        const root=document.querySelector('.ck')||document.body;
        const tree=root?read(root,'cockpit.dom',0):null;
        return JSON.stringify({capturedAt:performance.timeOrigin+performance.now(),devicePixelRatio,viewportWidth:innerWidth,viewportHeight:innerHeight,truncated:count>2048,tree});
      })()
      """#
  }
#endif

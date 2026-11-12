// SPDX-License-Identifier: MIT
// One maker colour table for the cockpit (D131, COL-2.1-18). The colours come from livery-table.ts, a generated copy of
// the website's shared table; nothing else in the app names a maker colour. Colour never identifies a maker alone: every
// mark that uses it keeps its logo and name.
import {MAKERS,TOOLS,type Shade} from './livery-table.js';

/** The cockpit's vendor keys (CLI rows) and the shared table's maker ids that carry their colour. */
const makerOf:Readonly<Record<string,string>>={openai:'openai',claude:'anthropic',anthropic:'anthropic',glm:'zhipuai',zhipu:'zhipuai',zhipuai:'zhipuai',kimi:'kimi',google:'google',xai:'xai',meta:'meta',deepseek:'deepseek',alibaba:'alibaba',xiaomi:'xiaomi',minimax:'minimax'};
export const NEUTRAL='#c6ccd4';
/** Two colour-only marks closer than this (CIEDE2000) are told apart by the later one's alternate shade. */
export const COLLISION_DELTA_E=15;

export function shadeOf(vendorKey:string|null|undefined):Shade|null {
 if(!vendorKey)return null;
 if(Object.hasOwn(makerOf,vendorKey))return MAKERS[makerOf[vendorKey]!]??null;
 return Object.hasOwn(TOOLS,vendorKey)?TOOLS[vendorKey]!:null;
}
/** The brand colour as is (marks that also show the logo and name). Unknown vendors stay neutral. */
export const brandColour=(vendorKey:string|null|undefined):string=>shadeOf(vendorKey)?.colour??NEUTRAL;

// CIEDE2000 on sRGB hex colours.
const lab=(hex:string):[number,number,number]=>{
 const [r,g,b]=[1,3,5].map(i=>{const c=parseInt(hex.slice(i,i+2),16)/255;return c<=0.04045?c/12.92:((c+0.055)/1.055)**2.4;}) as [number,number,number];
 const f=(t:number)=>t>216/24389?Math.cbrt(t):(24389/27*t+16)/116;
 const x=f((0.4124564*r+0.3575761*g+0.1804375*b)/0.95047),y=f(0.2126729*r+0.7151522*g+0.072175*b),z=f((0.0193339*r+0.119192*g+0.9503041*b)/1.08883);
 return [116*y-16,500*(x-y),200*(y-z)];
};
export function deltaE(a:string,b:string):number {
 const [L1,a1,b1]=lab(a),[L2,a2,b2]=lab(b),rad=Math.PI/180,deg=180/Math.PI;
 const C1=Math.hypot(a1,b1),C2=Math.hypot(a2,b2),Cm=(C1+C2)/2,G=0.5*(1-Math.sqrt(Cm**7/(Cm**7+25**7)));
 const ap1=a1*(1+G),ap2=a2*(1+G),Cp1=Math.hypot(ap1,b1),Cp2=Math.hypot(ap2,b2);
 const h=(y:number,x:number)=>x===0&&y===0?0:((Math.atan2(y,x)*deg)+360)%360,hp1=h(b1,ap1),hp2=h(b2,ap2);
 const dL=L2-L1,dC=Cp2-Cp1;let dh=0;if(Cp1*Cp2!==0){dh=hp2-hp1;if(dh>180)dh-=360;else if(dh<-180)dh+=360;}
 const dH=2*Math.sqrt(Cp1*Cp2)*Math.sin(dh*rad/2),Lm=(L1+L2)/2,Cpm=(Cp1+Cp2)/2;
 let hm=hp1+hp2;if(Cp1*Cp2===0)hm=hp1+hp2;else if(Math.abs(hp1-hp2)<=180)hm/=2;else hm=(hm+(hm<360?360:-360))/2;
 const T=1-0.17*Math.cos((hm-30)*rad)+0.24*Math.cos(2*hm*rad)+0.32*Math.cos((3*hm+6)*rad)-0.2*Math.cos((4*hm-63)*rad);
 const Sl=1+0.015*(Lm-50)**2/Math.sqrt(20+(Lm-50)**2),Sc=1+0.045*Cpm,Sh=1+0.015*Cpm*T;
 const Rt=-2*Math.sqrt(Cpm**7/(Cpm**7+25**7))*Math.sin(60*Math.exp(-(((hm-275)/25)**2))*rad);
 return Math.sqrt((dL/Sl)**2+(dC/Sc)**2+(dH/Sh)**2+Rt*(dC/Sc)*(dH/Sh));
}

/** UI white inks of the cockpit: a near-white or near-grey maker mark must not read as one of them. Coloured brands stay
 * single solid colours (state colours live on lamps and text, not on identity marks). */
export const RESERVED_UI=['#f0f2f4','#e9edf0'] as const;
export type Trim={readonly kind:'light'|'dark';readonly ink:string;readonly base:string};
const chroma=(hex:string)=>Math.hypot(lab(hex)[1],lab(hex)[2]);
const luma=(hex:string)=>lab(hex)[0];
/** The two-tone treatment of a maker mark drawn in its brand colour, the way the website's rockets draw it (shared table
 * base/ink/trim, not a different hue): near-white and near-grey makers (OpenAI "white over black", Z.ai "dark with a white
 * edge"). Coloured makers stay single-colour. */
export function trimOf(vendorKey:string|null|undefined,shown?:string):Trim|null {
 const shade=shadeOf(vendorKey);if(!shade||(shown!==undefined&&shown!==shade.colour))return null;
 if(chroma(shade.colour)>=12)return null;
 const base=shade.base??shade.colour,ink=shade.trim??shade.ink??(luma(shade.colour)>50?'#111214':'#ffffff');
 return {kind:luma(base)>50?'light':'dark',ink,base};
}

/** Colours for the makers of one view, in view order. The first of two close makers keeps its brand colour; a later one
 * that sits within COLLISION_DELTA_E of a colour already shown takes its alternate shade (or, if that collides too, the
 * candidate that is farthest from the others). Two-tone marks (trimOf) are told apart by their trim, so they only compete
 * with marks of the same tone (OpenAI with Cursor, not OpenAI with Z.ai). Two entries of the same vendor share one colour. Deterministic. */
export function resolveColours(vendorKeys:readonly (string|null|undefined)[]):string[] {
 const taken=new Map<string,string[]>(),byVendor=new Map<string,string>();
 return vendorKeys.map(key=>{
  const shade=shadeOf(key);if(!shade)return NEUTRAL;
  const id=key as string,known=byVendor.get(id);if(known)return known;
  const group=trimOf(key)?.kind??'plain',list=taken.get(group)??[];taken.set(group,list);
  const gap=(c:string)=>list.reduce((m,t)=>Math.min(m,deltaE(c,t)),Infinity);
  let pick=shade.colour;
  if(gap(pick)<COLLISION_DELTA_E)pick=gap(shade.alt)>=gap(pick)?shade.alt:pick;
  byVendor.set(id,pick);list.push(pick);return pick;
 });
}

/** The two-tone treatment for a colour as drawn on a mark (its brand colour), or null. */
export function trimForColour(colour:string):Trim|null {
 const hex=colour.toLowerCase();
 for(const table of [MAKERS,TOOLS])for(const [key,shade] of Object.entries(table))if(shade.colour===hex){const t=trimOf(key,hex);if(t)return t;}
 return null;
}

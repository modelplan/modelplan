// SPDX-License-Identifier: MIT
// The enlarged field's silhouette: the approved c01 porthole window, feathered ~10% into the desktop (CKP-PORT-11).
// It is derived at open from the already-published window-890-1x.png, so no new image is drawn or shipped: trim the
// window to its alpha bounds, stretch it to 1000x650, threshold at half alpha, then fade 65 px (10% of the short side)
// inward with a smoothstep of the distance to the outside. The same alpha drives the CSS mask, bare-desktop clicks
// and the axis-label lanes. Prototype: clients/official-visuals/study/field-picker-tags/build-feather.mjs,
// feather-shape.js (task 91 round 5); the code is written here.
/** The usable horizontal span at row `y` for a label `labelHeight` tall (the axis lanes take this shape). */
export type SafeSpan=(width:number,height:number,y:number,labelHeight:number)=>{left:number;right:number};

export const SHAPE_WIDTH=1000,SHAPE_HEIGHT=650,FEATHER=65;
export interface FieldShape {
 readonly width:number;readonly height:number;readonly alpha:Uint8Array;
 /** Opacity 0-1 at a point given as fractions of the shape's box (bilinear). */
 at(x:number,y:number):number;
 /** Whether a viewport point inside `box` lands on (nearly) bare desktop. */
 bare(box:DOMRect,clientX:number,clientY:number):boolean;
 /** The label lane at row `y` of a `width`x`height` view where the scene is fully opaque. */
 readonly span:SafeSpan;
 /** A PNG of the mask, for `mask-image`; revoke with `dispose`. */
 readonly maskUrl:string;
 dispose():void;
}

/** The feathered alpha for a source window's RGBA pixels. Pure, for tests and the page alike. */
export function featherAlpha(rgba:Uint8ClampedArray,width:number,height:number):Uint8Array {
 // Trim to the window's alpha bounds (the source has transparent margins).
 let left=width,right=-1,top=height,bottom=-1;
 for(let y=0;y<height;y++)for(let x=0;x<width;x++)if(rgba[(y*width+x)*4+3]!>10){if(x<left)left=x;if(x>right)right=x;if(y<top)top=y;if(y>bottom)bottom=y;}
 const W=SHAPE_WIDTH,H=SHAPE_HEIGHT,d=new Float32Array(W*H),big=W+H,q=Math.SQRT2;
 if(right<left)return new Uint8Array(W*H);
 const tw=right-left+1,th=bottom-top+1;
 // Stretch by bilinear sampling of the trimmed alpha, then threshold.
 const sample=(sx:number,sy:number)=>{
  const x0=Math.max(0,Math.min(tw-1,Math.floor(sx))),y0=Math.max(0,Math.min(th-1,Math.floor(sy))),x1=Math.min(tw-1,x0+1),y1=Math.min(th-1,y0+1),fx=Math.max(0,Math.min(1,sx-x0)),fy=Math.max(0,Math.min(1,sy-y0));
  const a=(x:number,y:number)=>rgba[((top+y)*width+left+x)*4+3]!;
  return (a(x0,y0)*(1-fx)+a(x1,y0)*fx)*(1-fy)+(a(x0,y1)*(1-fx)+a(x1,y1)*fx)*fy;
 };
 for(let y=0;y<H;y++)for(let x=0;x<W;x++)d[y*W+x]=sample((x+.5)*tw/W-.5,(y+.5)*th/H-.5)>=128?big:0;
 // Two-pass chamfer distance to the outside (the box edge counts as outside).
 for(let y=0;y<H;y++)for(let x=0;x<W;x++){const i=y*W+x;if(!d[i])continue;
  d[i]=Math.min(d[i]!,x?d[i-1]!+1:1,y?d[i-W]!+1:1,x&&y?d[i-W-1]!+q:q,x<W-1&&y?d[i-W+1]!+q:q);}
 for(let y=H-1;y>=0;y--)for(let x=W-1;x>=0;x--){const i=y*W+x;if(!d[i])continue;
  d[i]=Math.min(d[i]!,x<W-1?d[i+1]!+1:1,y<H-1?d[i+W]!+1:1,x<W-1&&y<H-1?d[i+W+1]!+q:q,x&&y<H-1?d[i+W-1]!+q:q);}
 const alpha=new Uint8Array(W*H);
 for(let i=0;i<d.length;i++){const t=Math.max(0,Math.min(1,d[i]!/FEATHER));alpha[i]=Math.round(255*t*t*(3-2*t));}
 return alpha;
}

export function shapeFromAlpha(alpha:Uint8Array,maskUrl='',revoke=()=>{}):FieldShape {
 const W=SHAPE_WIDTH,H=SHAPE_HEIGHT;
 const at=(x:number,y:number)=>{
  if(!(x>=0&&x<=1&&y>=0&&y<=1))return 0;
  const px=x*(W-1),py=y*(H-1),ix=Math.floor(px),iy=Math.floor(py),jx=Math.min(W-1,ix+1),jy=Math.min(H-1,iy+1),fx=px-ix,fy=py-iy,a=(x:number,y:number)=>alpha[y*W+x]!;
  return ((a(ix,iy)*(1-fx)+a(jx,iy)*fx)*(1-fy)+(a(ix,jy)*(1-fx)+a(jx,jy)*fx)*fy)/255;
 };
 // Prototype feather-shape.js: below 3.5% opacity is bare desktop; labels need 97% at their top, middle and bottom.
 const span:SafeSpan=(width,height,y,labelHeight)=>{
  const safe=(x:number)=>Math.min(...[0,labelHeight/2,labelHeight].map(dy=>at(x/width,(y+dy)/height)))>=.97;
  let left=0,right=width;while(left<width&&!safe(left))left+=2;while(right>left&&!safe(right))right-=2;
  return {left:left+4,right:right-4};
 };
 return {width:W,height:H,alpha,at,span,maskUrl,
  bare:(box,clientX,clientY)=>at((clientX-box.x)/box.width,(clientY-box.y)/box.height)<.035,
  dispose:revoke};
}

/** Loads the published window image (same origin) and derives the shape; null when it cannot be read. */
export async function featherShape(src:string):Promise<FieldShape|null> {
 try {
  const image=new Image();image.src=src;await image.decode();
  const read=document.createElement('canvas');read.width=image.naturalWidth;read.height=image.naturalHeight;
  const context=read.getContext('2d',{willReadFrequently:true});if(!context)return null;
  context.drawImage(image,0,0);
  const alpha=featherAlpha(context.getImageData(0,0,read.width,read.height).data,read.width,read.height);
  const mask=document.createElement('canvas');mask.width=SHAPE_WIDTH;mask.height=SHAPE_HEIGHT;
  const paint=mask.getContext('2d');if(!paint)return null;
  const pixels=paint.createImageData(SHAPE_WIDTH,SHAPE_HEIGHT);
  for(let i=0;i<alpha.length;i++){pixels.data[i*4]=pixels.data[i*4+1]=pixels.data[i*4+2]=255;pixels.data[i*4+3]=alpha[i]!;}
  paint.putImageData(pixels,0,0);
  const blob=await new Promise<Blob|null>(done=>mask.toBlob(done,'image/png'));if(!blob)return null;
  const url=URL.createObjectURL(blob);
  return shapeFromAlpha(alpha,url,()=>URL.revokeObjectURL(url));
 } catch {return null;}
}

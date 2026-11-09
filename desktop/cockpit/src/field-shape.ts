// SPDX-License-Identifier: MIT
// The enlarged field's silhouette: the owner-approved 91 A matte (task 91 A, feather-masks/A.png), shipped byte for byte as
// runtime/canopy-c01/field-matte-A-1000x650.png and pinned by hash in the visuals register. It is 1000x650 with a 65 px
// smooth inward alpha ramp derived from the c01 porthole alpha. The page does not derive a matte: the same file drives the
// CSS mask, bare-desktop clicks and the axis-label lanes. Prototype: clients/official-visuals/study/field-picker-tags
// (feather-shape.js); the code is written here.
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

/** Loads the approved matte (same origin, exactly 1000x650) and reads its alpha; null when it cannot be read. */
export async function featherShape(src:string):Promise<FieldShape|null> {
 try {
  const image=new Image();image.src=src;await image.decode();
  if(image.naturalWidth!==SHAPE_WIDTH||image.naturalHeight!==SHAPE_HEIGHT)return null;
  const read=document.createElement('canvas');read.width=SHAPE_WIDTH;read.height=SHAPE_HEIGHT;
  const context=read.getContext('2d',{willReadFrequently:true});if(!context)return null;
  context.drawImage(image,0,0);
  const rgba=context.getImageData(0,0,SHAPE_WIDTH,SHAPE_HEIGHT).data,alpha=new Uint8Array(SHAPE_WIDTH*SHAPE_HEIGHT);
  for(let i=0;i<alpha.length;i++)alpha[i]=rgba[i*4+3]!;
  return shapeFromAlpha(alpha,src);
 } catch {return null;}
}

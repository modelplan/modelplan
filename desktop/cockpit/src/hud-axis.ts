// SPDX-License-Identifier: MIT
/** G3-202: the HUD chart's axis path. In the tall chart the vertical axis starts 5 px below the plot's top edge, so it clears
 * the porthole's curved inner rim; the compact strip (30 px high) keeps the full height. */
export const HUD_AXIS_TOP_INSET=5,HUD_TALL_MIN_HEIGHT=60;
export function hudAxisPath(width:number,height:number,left:number,right:number,top:number,bottom:number):string {
 const start=height>=HUD_TALL_MIN_HEIGHT?top+HUD_AXIS_TOP_INSET:top;
 return `M${left} ${start}V${height-bottom}H${width-right}`;
}

// SPDX-License-Identifier: MIT
// Pointer event timestamps share a monotonic time origin. Invalid or backwards
// samples cannot turn into a long press.
export function isFaderLongPress(start:number,end:number):boolean {
 return Number.isFinite(start)&&Number.isFinite(end)&&start>=0&&end>=start&&end-start>=520;
}

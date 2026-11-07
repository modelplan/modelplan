// SPDX-License-Identifier: MIT
// The study uses an inclusive boundary; absent or invalid input uses 25.
export type RedBelow=10|15|20|25|30|40;
export function effectiveRedBelow(value:unknown):RedBelow {
 return value===10||value===15||value===20||value===25||value===30||value===40?value:25;
}

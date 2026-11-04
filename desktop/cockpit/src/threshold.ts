// SPDX-License-Identifier: MIT
// The study uses an inclusive boundary; absent or invalid input uses 25.
export type RedBelow=10|16|20|25;
export function effectiveRedBelow(value:unknown):RedBelow {
 return value===10||value===16||value===20||value===25?value:25;
}

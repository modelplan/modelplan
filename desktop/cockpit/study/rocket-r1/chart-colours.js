// SPDX-License-Identifier: MIT
// History charts use each subscription's identity colour. No private palette or scoring inputs.
export const chartPalette=accounts=>accounts.map(a=>({id:a.id,vendor:a.vendor,identity:a.colour,fill:a.colour}));

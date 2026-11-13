// SPDX-License-Identifier: MIT
// Transitional boundary until cockpitDetailsV1 and publication bindings land.
// Unknown stays null; the default contains no synthetic or inferred readings.
export interface PrototypeDetailsFixture {
 readonly liveSessions:unknown|null;
 readonly publication:unknown|null;
 readonly resetEvents:unknown|null;
 readonly history:unknown|null;
}
export function unavailablePrototypeDetailsFixture():PrototypeDetailsFixture {
 return {liveSessions:null,publication:null,resetEvents:null,history:null};
}

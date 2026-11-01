// SPDX-License-Identifier: MIT
// Transitional fixture adapter until the negotiated cockpitDetailsV1 producer
// and publication bindings are available. Null means unknown, never an empty
// observation or a synthetic production reading.
export interface PrototypeDetailsFixture {
 readonly liveSessions:null;
 readonly publication:null;
 readonly resetEvents:null;
 readonly history:null;
}
export function unavailablePrototypeDetailsFixture():PrototypeDetailsFixture {
 return {liveSessions:null,publication:null,resetEvents:null,history:null};
}

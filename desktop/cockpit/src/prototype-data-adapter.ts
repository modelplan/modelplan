// SPDX-License-Identifier: MIT
// Study-only display gaps: the current cockpit wire supplies no today-token,
// average-speed, reset-card or reserve-credit values. Never synthesize them.
import type { WireAccount } from '../generated/wire.js';
export interface PrototypeEngineSupplement {
 readonly todayTokens:null; readonly todayAverageGenerationTps:null;
 readonly resetCards:null; readonly reserveCredits:WireAccount["credits"];
}
export function prototypeEngineSupplement(account:WireAccount):PrototypeEngineSupplement {
 return {todayTokens:null,todayAverageGenerationTps:null,resetCards:null,reserveCredits:account.credits};
}

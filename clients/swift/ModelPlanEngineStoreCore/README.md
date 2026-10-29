<!-- SPDX-License-Identifier: MIT -->
# ModelPlanEngineStoreCore

Portable accepted-event storage for U6, extracted from the native EngineStore.
This interface stage depends on ModelPlanEngineClient and generated ModelPlanWire.
It adds synchronous value application and a clear effect; the native consumer
retains UI/cache fanout and acknowledges the client's delivery barrier.

Implementation and event-sequence qualification follow in this draft. Production
App wiring and native acceptance remain with U6's native owner.

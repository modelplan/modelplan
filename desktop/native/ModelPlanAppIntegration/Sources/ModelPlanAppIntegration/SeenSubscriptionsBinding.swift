// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanDock
import ModelPlanEngineStore
import ModelPlanEngineClient

/// Master spec decision 3 / C45 (D474): the seen-subscriptions memory goes with the readings. A Forget (the consent
/// generation advances) or a privacy clear / store change (the epoch changes) clears it, the same rule the cockpit
/// applies to its saved scope and acknowledged cautions. An engine stop or a lost connection keeps it.
@MainActor final class SeenSubscriptionsBinding: EngineStoreSink {
    private weak var store: EngineStore?
    private let seen: DockSeenSubscriptionsStore
    private var attachment: UUID?
    init(store: EngineStore, seen: DockSeenSubscriptionsStore) {
        self.store = store; self.seen = seen
        attachment = store.attach(self)
    }
    func stop() { if let attachment { store?.detach(attachment) }; attachment = nil }
    func clearPrivateViews(_ invalidation: EngineInvalidation) {
        guard invalidation.previous != nil,
              invalidation.reason == .generationAdvanced || invalidation.reason == .epochChanged else { return }
        seen.clear()
        if let floor = invalidation.nextFloor { seen.adopt(DockSeenScope(storeEpoch: floor.storeEpoch, generation: floor.generation)) }
    }
    /// macrev2-1289-5: every delivery names its consent scope; a scope the saved memory was not written under (a privacy
    /// clear or Forget while the app was closed) drops it before any ring or `seen` uses it.
    func apply(_ snapshot: EngineStoreSnapshot) {
        guard let floor = snapshot.delivery?.floor else { return }
        seen.adopt(DockSeenScope(storeEpoch: floor.storeEpoch, generation: floor.generation))
    }
}

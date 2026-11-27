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
    }
    func apply(_ snapshot: EngineStoreSnapshot) {}
}

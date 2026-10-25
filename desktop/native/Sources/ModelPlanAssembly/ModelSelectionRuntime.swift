// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanCore
import ModelPlanSelection
import ModelPlanInstruments

/// Read-only app binding. Every request uses current store feeds, never a retained scored join.
@MainActor public final class ModelSelectionRuntime {
    private let store: SnapshotStore
    private let now: () -> Date
    private var assembly = SelectionAssembly()
    public init(store: SnapshotStore, now: @escaping () -> Date = Date.init) {
        self.store = store; self.now = now
    }
    public func evaluate(scope: SelectionScope, selectedID: String? = nil,
                         language: InstrumentLanguage = .chinese) -> AssembledModelSelection {
        assembly.evaluate(feeds:store.modelSelectionFeeds(),scope:scope,selectedID:selectedID,
            language:language,now:now())
    }
}

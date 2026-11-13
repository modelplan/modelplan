// SPDX-License-Identifier: MIT
import AppKit
import ModelPlanCore
import ModelPlanShell
import ModelPlanAssembly

@MainActor final class CommunityRuntime {
    let store: SnapshotStore
    let modelSelection: ModelSelectionRuntime
    let lifecycle: LifecycleCoordinator
    let events: SystemEvents
    init(transport: any CLITransport) {
        store = SnapshotStore(transport: transport)
        modelSelection = ModelSelectionRuntime(store: store)
        lifecycle = LifecycleCoordinator(store: store)
        events = SystemEvents(gate: lifecycle)
    }
    /// Read the surface's current intent through the existing selector/store; no cached join.
    func selection(for consumer: any CommunityInstrumentSurface) -> AssembledModelSelection {
        switch consumer.requestedInstrumentScope {
        case .all:
            return modelSelection.evaluate(scope: .all, selectedID: consumer.selectedModelID,
                                           language: consumer.instrumentLanguage)
        case .subscription(let reference):
            return modelSelection.evaluate(scope: .subscription(reference), selectedID: consumer.selectedModelID,
                                           language: consumer.instrumentLanguage)
        }
    }
    func start() { events.start() }
    func stop() async { events.stop(); await lifecycle.stop() }
}

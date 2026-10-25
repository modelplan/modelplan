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
    func start() { events.start() }
    func stop() async { events.stop(); await lifecycle.stop() }
}

// SPDX-License-Identifier: MIT
import AppKit
import ModelPlanCore
import ModelPlanShell

@MainActor final class CommunityRuntime {
    let store: SnapshotStore
    let lifecycle: LifecycleCoordinator
    let events: SystemEvents
    init(transport: any CLITransport) {
        store = SnapshotStore(transport: transport)
        lifecycle = LifecycleCoordinator(store: store)
        events = SystemEvents(gate: lifecycle)
    }
    func start() { events.start() }
    func stop() async { events.stop(); await lifecycle.stop() }
}

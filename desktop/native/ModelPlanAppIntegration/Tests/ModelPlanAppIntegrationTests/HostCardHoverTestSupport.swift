// SPDX-License-Identifier: MIT
import XCTest
import ModelPlanDock
@testable import ModelPlanAppIntegration

@MainActor private final class SyntheticCardScheduler: DockEdgeScheduling {
    func arm(at deadline: TimeInterval, _ action: @escaping @MainActor () -> Void) {}
    func cancel() {}
}

/// Feed a synthetic hover into the real controller and host presentation callback.
/// These card-content checks do not claim real pointer/window acceptance.
@MainActor func presentSyntheticHostCard(_ host: StaticDockPreviewHost, id: String,
                                         file: StaticString = #filePath, line: UInt = #line) throws {
    let content = try XCTUnwrap(host.cardContent(for: id), file: file, line: line)
    var clock: TimeInterval = 0
    let controller = DockInteractionController(clock: { clock }, scheduler: SyntheticCardScheduler()) {
        .init(catalogue: [id], preferences: .init(), targets: [], hoveredID: id,
              insideShared: true, parentExpanded: true, active: true, contents: [id: content])
    }
    host.installInteraction(controller)
    controller.start()
    clock = DockCardInteraction.entryDwell
    controller.refresh()
    XCTAssertFalse(host.card.isHidden, "The host must present the hovered card", file: file, line: line)
}

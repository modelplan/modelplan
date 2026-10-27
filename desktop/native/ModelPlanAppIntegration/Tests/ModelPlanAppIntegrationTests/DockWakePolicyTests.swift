// SPDX-License-Identifier: MIT
import XCTest
import ModelPlanDock
import ModelPlanSettings
@testable import ModelPlanAppIntegration

@MainActor private final class DockWakeScheduler: DockEdgeScheduling {
    func arm(at deadline: TimeInterval, _ action: @escaping @MainActor () -> Void) {}
    func cancel() {}
}

@MainActor final class DockWakePolicyTests: XCTestCase {
    func testApprovedSizesAndTwentyPointWakeDriveTheHostAcrossEdges() async throws {
        XCTAssertEqual(SettingsSize.allCases.map(\.nozzleDiameter), [36,44,52])
        XCTAssertEqual(SettingsPreferences().size.nozzleDiameter, 44)
        XCTAssertEqual(DockSliverParameters.current.visibleThickness, 4)
        XCTAssertEqual(DockSliverParameters.current.visibleLength, .fullSpan)
        for size in SettingsSize.allCases { for edge in SettingsDockEdge.allCases {
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: folder) }
            let screen = DockDisplayArea(id: "synthetic", frame: CGRect(x: -800, y: -300, width: 800, height: 600),
                                        visibleFrame: CGRect(x: -800, y: -300, width: 800, height: 600))
            var elapsed: TimeInterval = 0
            var pointer = CGPoint(x: -500, y: 250)
            let factor = size.nozzleDiameter / 44
            let host = StaticDockPreviewHost(appearance: { view, rows, _ in
                try view.applyCommunity(rows)
                view.setFrameSize(edge == .bottom ? CGSize(width: 180 * factor, height: 80 * factor)
                                                  : CGSize(width: 80 * factor, height: 180 * factor))
                return .init(hoverRects: [CGRect(x: 30 * factor, y: 30 * factor, width: 10 * factor, height: 30 * factor)],
                             sliverLength: 160 * factor, sliverThickness: 4 * factor)
            }, currentDate: { Date() }, createsNativePanels: false,
            nativeEnvironment: { .init(displays: [screen], layouts: [], primaryDisplayID: screen.id, pointer: pointer) },
            elapsedClock: { elapsed }, edgeScheduling: DockWakeScheduler())
            defer { host.close() }
            let store = try SettingsStore(url: folder.appendingPathComponent("settings.json"))
            try await store.update { $0.size = size; $0.dockEdge = edge }
            let c = SettingsApplicationCoordinator(store: store) { host.apply($0) }
            await c.reload(); host.setPresentationAllowed(true)
            let placement = try XCTUnwrap(host.edgePresentation?.placement)
            XCTAssertEqual(edge == .bottom ? placement.wakeFrame.height : placement.wakeFrame.width, 20)
            switch edge {
            case .left: pointer = CGPoint(x: placement.wakeFrame.minX + 20, y: placement.wakeFrame.midY)
            case .right: pointer = CGPoint(x: placement.wakeFrame.maxX - 20, y: placement.wakeFrame.midY)
            case .bottom: pointer = CGPoint(x: placement.wakeFrame.midX, y: placement.wakeFrame.minY + 20)
            }
            XCTAssertTrue(DockEdgeGeometry.canWake(at: pointer, placement: placement, displays: [screen]))
            host.refreshPresence()
            elapsed = 0.15; host.refreshPresence()
            XCTAssertEqual(host.edgePresentation?.state, .expanded, "the outer 16–20 pt band must reveal")
            elapsed = 1; host.refreshPresence()
            XCTAssertEqual(host.edgePresentation?.state, .expanded, "the full 20 pt wake stays inside after reveal")
            pointer = CGPoint(x: -10_000, y: -10_000)
            elapsed = 2; host.refreshPresence()
            elapsed = 2.5; host.refreshPresence()
            XCTAssertEqual(host.edgePresentation?.state, .sliver)
        } }
    }
}

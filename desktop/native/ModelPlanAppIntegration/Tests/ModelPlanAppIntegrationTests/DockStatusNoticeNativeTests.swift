// SPDX-License-Identifier: MIT
#if MODELPLAN_DOCK_NATIVE_JOURNEY
import AppKit
import XCTest
import ModelPlanDock
@testable import ModelPlanAppIntegration

/// The admitted native run owns the status item and restores activation policy.
@MainActor final class DockStatusNoticeNativeTests: XCTestCase {
    func testNormalEntryNoticeAttachesAndClearsOnAcknowledgement() async throws {
        let capture = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
        let application = NSApplication.shared
        let previousPolicy = application.activationPolicy()
        application.setActivationPolicy(.accessory)
        defer { application.setActivationPolicy(previousPolicy) }
        let displayed = try await S4QuotaJourney.announcedMenuIndicator(capture: capture) { app in
            app.installStatusItem()
            defer { app.removeStatusItem() }
            app.renderMenu()
            let deadline = ContinuousClock.now + .seconds(8)
            while app.statusNoticePresentation?.isVisible != true && ContinuousClock.now < deadline {
                try await Task.sleep(for: .milliseconds(50))
            }
            let shown = try XCTUnwrap(app.statusNoticePresentation)
            XCTAssertTrue(shown.isVisible)
            XCTAssertEqual(shown.tone, .blue)
            XCTAssertEqual(shown.shape, .hollow)
            XCTAssertEqual(shown.frameInButton.maxX, shown.buttonBounds.maxX, accuracy: 0.01)
            if shown.buttonIsFlipped {
                XCTAssertEqual(shown.frameInButton.minY, shown.buttonBounds.minY, accuracy: 0.01)
            } else {
                XCTAssertEqual(shown.frameInButton.maxY, shown.buttonBounds.maxY, accuracy: 0.01)
            }

            app.composition.dock.acknowledgeDockReveal()
            let cleared = try XCTUnwrap(app.statusNoticePresentation)
            XCTAssertFalse(cleared.isVisible)
            XCTAssertNil(cleared.tone)
            app.removeStatusItem()
            XCTAssertNil(app.statusNoticePresentation)
        }
        XCTAssertTrue(displayed)
    }
}
#endif

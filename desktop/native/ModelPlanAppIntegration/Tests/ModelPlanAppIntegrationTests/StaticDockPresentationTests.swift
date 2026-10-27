// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanDock
import ModelPlanSettings
@testable import ModelPlanAppIntegration

@MainActor final class StaticDockPresentationTests: XCTestCase {
    func testViewInvalidationRebuildsOnlyLiveAllowedHost() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("dock-presentation-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        var calls = 0
        let host = StaticDockPreviewHost(appearance: { view, rows, _ in
            calls += 1
            try view.applyCommunity(rows)
            return .init(hoverRects: [view.bounds])
        }, currentDate: { Date() }, createsNativePanels: false)
        let coordinator = SettingsApplicationCoordinator(store: try SettingsStore(url: folder.appendingPathComponent("settings.json"))) { host.apply($0) }
        await coordinator.reload()
        host.setPresentationAllowed(true)
        let before = calls
        host.dockView.viewDidChangeEffectiveAppearance()
        XCTAssertEqual(calls, before + 1, "the original themed sliver must be refreshed")
        let retained = host.dockView.onNeedsFreshPresentation
        XCTAssertNotNil(retained)
        retained?() // The same event hook is used by the existing window/backing observers.
        XCTAssertEqual(calls, before + 2)
        host.setPresentationAllowed(false)
        let hidden = calls
        retained?()
        XCTAssertEqual(calls, hidden, "an invalidated hidden host must not rebuild")
        host.close()
        retained?()
        XCTAssertEqual(calls, hidden, "a retired host cannot be revived")
    }
    func testAppearanceSliverPixelsReachTheBoundedRevealSurface() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("dock-sliver-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        var bytes = [UInt8](repeating: 255, count: 8 * 44 * 4)
        for y in 0..<4 { for x in 0..<4 { for channel in 0..<4 { bytes[(y * 8 + x) * 4 + channel] = 0 } } }
        let provider = try XCTUnwrap(CGDataProvider(data: Data(bytes) as CFData))
        let image = try XCTUnwrap(CGImage(width: 8, height: 44, bitsPerComponent: 8, bitsPerPixel: 32,
            bytesPerRow: 32, space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent))
        var currentImage = image
        let host = StaticDockPreviewHost(appearance: { view, rows, _ in
            try view.applyCommunity(rows)
            return .init(hoverRects: [view.bounds], sliverLength: 20, sliverThickness: 4,
                         sliverAlongAnchor: 10, sliverImage: currentImage, sliverScale: 2)
        }, currentDate: { Date() }, createsNativePanels: false)
        let coordinator = SettingsApplicationCoordinator(store: try SettingsStore(url: folder.appendingPathComponent("settings.json"))) { host.apply($0) }
        await coordinator.reload()
        let surface = try host.prepareSliver(size: CGSize(width: 4, height: 21))
        XCTAssertEqual(surface.frame.size, CGSize(width: 4, height: 21))
        XCTAssertGreaterThan(surface.retainedBytes, 0, "the provider pixels must not be replaced by nil fallback")
        XCTAssertFalse(surface.isPainted(atLocal: CGPoint(x: 0.5, y: 0.5)), "transparent authored corner stays click-through")
        XCTAssertTrue(surface.isPainted(atLocal: CGPoint(x: 3, y: 19)))
        let opaque = try XCTUnwrap(CGDataProvider(data: Data(repeating: 255, count: 8 * 44 * 4) as CFData))
        currentImage = try XCTUnwrap(CGImage(width: 8, height: 44, bitsPerComponent: 8, bitsPerPixel: 32,
            bytesPerRow: 32, space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: opaque, decode: nil, shouldInterpolate: false, intent: .defaultIntent))
        host.render(snapshot: nil, diagnostics: .init())
        XCTAssertTrue(surface.isPainted(atLocal: CGPoint(x: 0.5, y: 0.5)), "same-frame data refresh must replace the old sliver pixels")
        XCTAssertEqual(surface.frame.size, CGSize(width: 4, height: 21), "data refresh preserves the window-rounded surface size")
        host.close()
        XCTAssertFalse(surface.isPainted(atLocal: CGPoint(x: 3, y: 19)))
    }

    func testNewDefaultsReachExistingProjectionWithTheDocumentedBoundary() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("dock-defaults-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let c = SettingsApplicationCoordinator(store: try SettingsStore(url: folder.appendingPathComponent("settings.json"))) { _ in }
        await c.reload()
        let app = try XCTUnwrap(c.latest), now = Date(timeIntervalSince1970: 1_800_000_000)
        XCTAssertFalse(app.snapshot.preferences.followActiveDisplay)
        for (remaining, expected) in [(24.0, DockQuotaStatus.critical), (25.0, .warning)] {
            var input = DockInstrumentInput(id: "fixture", name: "Synthetic only", windows: [
                .init(id: "reported", period: .fiveHour, label: "5h", remainingPercent: remaining,
                      resetsAt: now.addingTimeInterval(300), durationSeconds: 18000)])
            input.dataState = .fresh
            XCTAssertEqual(try app.dockReading(for: input, at: now).status, expected,
                           "keep the existing below-threshold comparison; do not silently make it inclusive")
        }
    }

}

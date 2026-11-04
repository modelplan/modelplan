// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanSettings
import ModelPlanDock
@testable import ModelPlanAppIntegration

/// Production entry and production Dock, with no engine child, native panel or input.
@MainActor final class G1DockPlacementJourneys: XCTestCase {
    func testG1_DOCK_3_6_01_normalEntrySliverTracksHullAndSize() async throws {
        _ = NSApplication.shared
        for (size, expectedThickness) in [(SettingsSize.small, 4.0 * 36 / 44), (.medium, 4.0), (.large, 4.0 * 52 / 44)] {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent("g1-placement-" + UUID().uuidString, isDirectory: true)
            defer { try? FileManager.default.removeItem(at: root) }
            let settings = try SettingsStore(url: root.appendingPathComponent("settings.json"))
            _ = try await settings.update { $0.showDock = true; $0.autoHide = true; $0.size = size; $0.dockEdge = .right }
            let app = EngineRowsEntry.make(configuration: .init(executableURL: root.appendingPathComponent("not-launched"), applicationVersion: "g1-synthetic", allowedEnvironment: [:], offline: true, readOnly: true), settingsStore: settings, createsNativePanels: false)
            await app.prepare(); app.allowDockPresentation()
            defer { app.composition.dock.close() }
            let dock = app.composition.dock
            XCTAssertNil(dock.nativePanel)
            XCTAssertNil(dock.lastAppearanceError)
            let placement = try XCTUnwrap(dock.edgePresentation?.placement, "the normal entry must publish a real placement")
            let thickness = placement.edge == .bottom ? placement.sliverFrame.height : placement.sliverFrame.width
            let length = placement.edge == .bottom ? placement.sliverFrame.width : placement.sliverFrame.height
            let anchor = placement.edge == .bottom ? placement.frame.minX + placement.layout.alongAnchor : placement.frame.minY + placement.layout.alongAnchor
            let sliverCentre = placement.edge == .bottom ? placement.sliverFrame.midX : placement.sliverFrame.midY
            XCTAssertEqual(Double(thickness), expectedThickness, accuracy: 0.05, "S/M/L painted thickness")
            let hull = try XCTUnwrap(dock.dockView.registeredHullBounds)
            let hullSpan = placement.edge == .bottom ? hull.width : hull.height
            XCTAssertEqual(length, hullSpan, accuracy: 0.05, "the painted sliver spans the actual registered Dock hull")
            XCTAssertEqual(sliverCentre, anchor, accuracy: 0.05, "the sliver stays registered at the Dock position")
            let sliver = try dock.prepareSliver(size: placement.sliverFrame.size)
            XCTAssertEqual(sliver.frame.size, placement.sliverFrame.size)
            let width = max(1, Int(ceil(sliver.bounds.width * 2))), height = max(1, Int(ceil(sliver.bounds.height * 2)))
            let image = try XCTUnwrap(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                bytesPerRow: 0, bitsPerPixel: 0))
            let context = try XCTUnwrap(NSGraphicsContext(bitmapImageRep: image))
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = context
            context.cgContext.scaleBy(x: 2, y: 2)
            sliver.draw(sliver.bounds)
            NSGraphicsContext.restoreGraphicsState()
            let metal = try XCTUnwrap(image.colorAt(x: width / 2, y: height / 2)?.usingColorSpace(.deviceRGB))
            XCTAssertGreaterThan(metal.alphaComponent, 0.5)
            XCTAssertLessThan(abs(metal.redComponent - metal.greenComponent), 0.08, "the body is neutral, not a quota alert")
            XCTAssertLessThan(abs(metal.greenComponent - metal.blueComponent), 0.08, "the body remains neutral metal")
        }
    }
}

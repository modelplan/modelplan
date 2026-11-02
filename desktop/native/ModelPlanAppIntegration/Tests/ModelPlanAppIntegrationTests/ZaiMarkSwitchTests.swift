// SPDX-License-Identifier: MIT
import AppKit
import Foundation
import ModelPlanSettings
@_spi(DockResourceChecks) import ModelPlanDock
import ModelPlanDockResources
import ModelPlanOfficialDock
@_spi(DockResourceChecks) @testable import ModelPlanAppIntegration
@testable import S1GalleryCore
import XCTest

@MainActor final class ZaiMarkSwitchTests: XCTestCase {
    func testProductionFactoryHonoursBetaAndDisabledSwitch() async throws {
        _ = NSApplication.shared
        let now = Date(timeIntervalSince1970: 1_792_506_300)
        let display = DockDisplayArea(id: "synthetic", frame: .init(x: 0, y: 0, width: 1470, height: 956), visibleFrame: .init(x: 0, y: 0, width: 1470, height: 930))
        let environment = DockEdgeEnvironment(displays: [display], layouts: [], primaryDisplayID: "synthetic")
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("zai-switch-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        for enabled in [false, true] {
            let host = ProductionDockFactory.community(createsNativePanels: false, nativeEnvironment: { environment }, currentDate: { now })
            defer { host.close() }
            host.dockView.zaiMarkEnabled = enabled
            host.setDockContentProvider(S1SyntheticProvider(count: 4, now: now))
            let store = try SettingsStore(url: root.appendingPathComponent(enabled ? "beta.json" : "off.json"))
            let coordinator = SettingsApplicationCoordinator(store: store) { host.apply($0) }
            await coordinator.reload()
            XCTAssertNil(host.lastAppearanceError)
            let station = try XCTUnwrap(host.dockView.presentedSkinForChecks?.stations.first { $0.subscriptionID == "zhipu" })
            XCTAssertEqual(station.glyphs["zhipu"], enabled ? "logo-zai-white" : nil)
            XCTAssertEqual(station.fallbackVendorName, true)
            XCTAssertNotNil(host.dockView.presentedImageForChecks)
        }
    }

    func testNoticePulseIsFirstAppearanceOnlyAndHonoursReduceMotion() async throws {
        _ = NSApplication.shared
        let now = Date(timeIntervalSince1970: 1_792_506_300)
        let display = DockDisplayArea(id: "synthetic", frame: .init(x: 0, y: 0, width: 1470, height: 956), visibleFrame: .init(x: 0, y: 0, width: 1470, height: 930))
        let environment = DockEdgeEnvironment(displays: [display], layouts: [], primaryDisplayID: "synthetic")
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("notice-pulse-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        for reduced in [false, true] {
            let host = ProductionDockFactory.community(createsNativePanels: false, nativeEnvironment: { environment }, currentDate: { now })
            defer { host.close() }
            host.setDockContentProvider(S1SyntheticProvider(count: 1, now: now, noticeCase: .announced))
            let coordinator = SettingsApplicationCoordinator(store: try SettingsStore(url: root.appendingPathComponent("\(reduced).json"))) { host.apply($0) }
            await coordinator.reload()
            XCTAssertNil(host.lastAppearanceError)
            host.pulseDockNoticesForChecks(reduced: reduced)
            XCTAssertEqual(host.dockView.noticePulseCountForChecks, reduced ? 0 : 1)
            host.pulseDockNoticesForChecks(reduced: false)
            XCTAssertEqual(host.dockView.noticePulseCountForChecks, reduced ? 0 : 1)
            host.refreshDockContent()
            XCTAssertEqual(host.dockView.noticePulseCountForChecks, 0)
        }
    }

    func testDisabledSwitchActuallyDrawsTextInsteadOfMark() throws {
        let now = Date(timeIntervalSince1970: 1_792_506_300)
        var input = DockInstrumentInput(id: "zhipu", name: "GLM", windows: [])
        input.vendorResourceKey = "zhipu"
        let reading = try DockInstrumentProjection.evaluate(input, now: now)
        let geometry = try T2Geometry.make(subscriptions: [.init(id: "zhipu")], input: .init(coordinates: .init(edge: .right, width: 1470, height: 956, menuBarExclusion: 26)))
        let artwork = try T2BundledArtwork.records().mapValues { DockResourceFile(path: $0.path, sha256: $0.sha256, bytes: $0.bytes) }
        let official = try DockArtworkStore(root: T2BundledArtwork.rootURL(), manifest: .init(files: artwork))
        for enabled in [false, true] {
            let manifest = try JSONDecoder().decode(DockResourceManifest.self, from: DockThirdPartyResources.manifestData(zaiMarkEnabled: enabled))
            let thirdParty = try DockArtworkStore(root: DockThirdPartyResources.rootURL(), manifest: manifest)
            let renderer = DockInstrumentRenderer(resources: official, supplementalResources: thirdParty)
            let skin = try T2DockSkin.make(geometry: geometry, rows: [reading], showsPercentages: true, zaiMarkEnabled: enabled)
            let rendered = try renderer.render(skin: skin, readings: ["zhipu": reading], scale: 2)
            XCTAssertEqual(rendered.metrics.contains { $0.text == "GLM" }, !enabled)
            XCTAssertGreaterThan(rendered.image.width, 0)
        }
    }
}

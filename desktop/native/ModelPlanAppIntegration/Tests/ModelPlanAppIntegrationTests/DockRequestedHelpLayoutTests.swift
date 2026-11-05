// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import ModelPlanInstruments
import ModelPlanEngineClient
import ModelPlanSettings
@testable import ModelPlanAppIntegration

@MainActor final class DockRequestedHelpLayoutTests: XCTestCase {
    func testHelpCatalogUsesBilingualSurfaceNamesWithoutInternalTerms() {
        let chinese = HelpMapCatalog(.chinese)
        let english = HelpMapCatalog(.english)
        let names: [(HelpMapRegion, String, String)] = [
            (.window, "悬窗", "Window"), (.alert, "注意灯", "Alert lamp"),
            (.faders, "推杆", "Faders"), (.screen, "公共屏", "Main screen"),
            (.ignition, "点火钮", "Ignition"), (.sliver, "隐藏条", "Sliver")
        ]
        for (region, zh, en) in names {
            XCTAssertTrue(chinese.sentence(region).hasPrefix(zh + "："), region.rawValue)
            XCTAssertTrue(english.sentence(region).hasPrefix(en + ":"), region.rawValue)
        }
        XCTAssertTrue(chinese.sentence(.dockMove).contains("额度挂件"))
        XCTAssertTrue(english.sentence(.dockMove).contains("Quota Widget"))
        XCTAssertTrue(chinese.sentence(.ignition).contains("驾驶舱"))
        XCTAssertTrue(english.sentence(.ignition).contains("Cockpit"))
        for surface in [HelpMapSurface.dock, .cockpit] {
            let zhEntries = chinese.entries(for: surface)
            let enEntries = english.entries(for: surface)
            XCTAssertEqual(zhEntries.map(\.region), enEntries.map(\.region))
            XCTAssertFalse(zhEntries.isEmpty)
            for (zh, en) in zip(zhEntries, enEntries) {
                XCTAssertTrue(zh.sentence.unicodeScalars.contains { (0x4E00...0x9FFF).contains($0.value) }, zh.id)
                XCTAssertFalse(en.sentence.unicodeScalars.contains { (0x4E00...0x9FFF).contains($0.value) }, en.id)
                for copy in [zh.sentence, en.sentence] {
                    for term in ["source scope", "read here", "observation", "fixture", "envelope"] {
                        XCTAssertFalse(copy.localizedCaseInsensitiveContains(term), zh.id)
                    }
                }
            }
        }
    }

    func testGripAndBackgroundShareOneRequestedMapCaption() throws {
        let grip = DockRequestedHelpAnchor(id: "dock.grip.0", region: .dockMove,
            rect: CGRect(x: 900, y: 200, width: 24, height: 40), visible: true)
        let move = DockRequestedHelpAnchor(id: "dock.move", region: .dockMove,
            rect: CGRect(x: 900, y: 500, width: 40, height: 40), visible: true)
        for language in [InstrumentLanguage.english, .chinese] {
            for anchors in [[grip, move], [move, grip]] {
                let recipe = NeutralHelpUIRecipeProvider()
                let input = try XCTUnwrap(DockRequestedHelpLayout.make(session: UUID(), viewport: CGSize(width: 1600, height: 1100),
                    language: language, anchors: anchors, blocked: [], recipe: recipe))
                let labels = recipe.presentation(for: input).mapLabels
                XCTAssertEqual(labels.count, 1, "Grip and background use the same movement explanation")
                XCTAssertEqual(labels.first?.text, HelpMapCatalog(language).sentence(.dockMove))
                XCTAssertEqual(input.map.regionAnchors[.dockMove], anchors.first?.id)
                XCTAssertTrue(input.map.supplements.isEmpty)
                XCTAssertEqual(anchors.count, 2, "Map caption grouping must not mutate the host's separate targets")
            }
        }
    }
    func testNozzleHelpOnlyPromisesRefreshWhenNegotiated() throws {
        let anchor = DockRequestedHelpAnchor(id: "nozzle", region: .nozzle,
            rect: CGRect(x: 400, y: 300, width: 40, height: 40), visible: true)
        for available in [false, true] {
            let input = try XCTUnwrap(DockRequestedHelpLayout.make(session: UUID(), viewport: CGSize(width: 1000, height: 800), language: .english, anchors: [anchor], blocked: [], recipe: NeutralHelpUIRecipeProvider(), refreshAvailable: available))
            let result = NeutralHelpUIRecipeProvider().presentation(for: input)
            let label = try XCTUnwrap(result.mapLabels.first { $0.anchorID == "nozzle" })
            XCTAssertEqual(label.text.contains("click to refresh"), available)
        }
    }

    func testLabelsEveryVisibleAnchorAndOmitsHiddenAnchors() throws {
        let recipe = NeutralHelpUIRecipeProvider()
        let anchors: [DockRequestedHelpAnchor] = [
            .init(id: "ring-a", region: .rings, rect: CGRect(x: 900, y: 200, width: 40, height: 40), visible: true),
            .init(id: "ring-b", region: .rings, rect: CGRect(x: 900, y: 400, width: 40, height: 40), visible: true),
            .init(id: "move", region: .dockMove, rect: CGRect(x: 900, y: 600, width: 40, height: 40), visible: true),
            .init(id: "menu", region: .sliver, rect: CGRect(x: 1200, y: 60, width: 30, height: 20), visible: true, caption: "Show Quota Widget from the menu."),
            .init(id: "hidden", region: .ignition, rect: CGRect(x: 900, y: 800, width: 40, height: 40), visible: false),
        ]
        let input = try XCTUnwrap(DockRequestedHelpLayout.make(session: UUID(), viewport: CGSize(width: 1600, height: 1100),
            language: .english, anchors: anchors, blocked: [], recipe: recipe))
        let result = recipe.presentation(for: input)
        XCTAssertNotNil(result.mapHeader)
        XCTAssertTrue(result.unresolvedMapIDs.isEmpty)
        XCTAssertEqual(Set(result.mapLabels.map(\.anchorID)), Set(["ring-a", "move", "menu"]))
        XCTAssertFalse(result.mapLabels.contains { $0.anchorID == "ring-b" }, "Prototype labels the first visible target per region")
        XCTAssertFalse(result.mapLabels.contains { $0.anchorID == "hidden" })
    }

    func testNormalEntryFirstRunRequestsCompleteSyntheticMapAndEscapeDismisses() async throws {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("first-run-map-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: profile) }
        let store = try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: ["en"])
        let app = EngineRowsEntry.make(configuration: .init(executableURL: URL(fileURLWithPath: "/synthetic/not-launched"),
            applicationVersion: "synthetic", allowedEnvironment: [:], offline: true, readOnly: true),
            settingsStore: store, createsNativePanels: false, activateSettings: {})
        defer { app.composition.dock.close() }
        await app.prepare()
        let recipe = NeutralHelpUIRecipeProvider()
        let anchors: [DockRequestedHelpAnchor] = [
            .init(id: "ring", region: .rings, rect: CGRect(x: 900, y: 200, width: 40, height: 40), visible: true),
            .init(id: "move", region: .dockMove, rect: CGRect(x: 900, y: 400, width: 40, height: 40), visible: true),
            .init(id: "hidden", region: .ignition, rect: CGRect(x: 900, y: 600, width: 40, height: 40), visible: false),
        ]
        let input = try XCTUnwrap(DockRequestedHelpLayout.make(session: UUID(), viewport: CGSize(width: 1600, height: 1100),
            language: .english, anchors: anchors, blocked: [], recipe: recipe))
        var modes: [HelpUIMapMode] = [], shown: HelpUIPresentation?
        let map = RequestedHelpMap(apply: { value, _, _, _ in
            modes.append(value.map.mode)
            let result = recipe.presentation(for: value)
            if value.map.mode == .latched { shown = result }
            return result
        }, isCurrent: { $0.sessionID == input.sessionID })
        app.requestHelpMap = { (try? map.presentHelpMap(input: input, content: [:], context: .init())) == true }
        let editor = app.settingsHost.application.editor
        var context = editor.context
        context.capabilities.helpMapAvailable = true; context.capabilities.helpMapUsesDock = true
        app.settingsHost.application.update(context: context)
        let snapshot = try XCTUnwrap(editor.snapshot)
        _ = try await editor.completeFirstRun(options: .init(preferences: snapshot.preferences), action: .seeWhatsHere,
            host: .popup, expectedRevision: snapshot.revision)
        XCTAssertEqual(modes, [.latched])
        XCTAssertEqual(Set(try XCTUnwrap(shown).mapLabels.map(\.anchorID)), Set(["ring", "move"]))
        XCTAssertTrue(try map.handleHelpAction(.dismissMap(reason: .escape, returnFocusID: nil)))
        XCTAssertEqual(modes, [.latched, .hidden])
        await app.composition.stop()
    }
}

// SPDX-License-Identifier: MIT
import AppKit
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
            (.ignition, "点火钮", "Ignition"), (.sliver, "细条", "Sliver")
        ]
        for (region, zh, en) in names {
            XCTAssertTrue(chinese.sentence(region).hasPrefix(zh + "："), region.rawValue)
            XCTAssertTrue(english.sentence(region).hasPrefix(en + ":"), region.rawValue)
        }
        XCTAssertTrue(chinese.sentence(.dockMove).contains("额度挂件"))
        XCTAssertTrue(english.sentence(.dockMove).contains("Quota Widget"))
        XCTAssertTrue(chinese.sentence(.ignition).contains("驾驶舱"))
        XCTAssertTrue(english.sentence(.ignition).contains("Cockpit"))
        func hasLatinLetters(_ text: String) -> Bool {
            text.unicodeScalars.contains { (65...90).contains($0.value) || (97...122).contains($0.value) }
        }
        for copy in [chinese.menuTitle, chinese.title, chinese.metaphor, chinese.dismissal] {
            XCTAssertFalse(hasLatinLetters(copy.replacingOccurrences(of: "Esc", with: "")),
                           "Chinese Help chrome must stay in one language apart from the keyboard name")
        }
        for surface in [HelpMapSurface.dock, .cockpit] {
            let zhEntries = chinese.entries(for: surface)
            let enEntries = english.entries(for: surface)
            XCTAssertEqual(zhEntries.map(\.region), enEntries.map(\.region))
            XCTAssertFalse(zhEntries.isEmpty)
            for (zh, en) in zip(zhEntries, enEntries) {
                XCTAssertTrue(zh.sentence.unicodeScalars.contains { (0x4E00...0x9FFF).contains($0.value) }, zh.id)
                XCTAssertFalse(en.sentence.unicodeScalars.contains { (0x4E00...0x9FFF).contains($0.value) }, en.id)
                XCTAssertFalse(hasLatinLetters(zh.sentence.replacingOccurrences(of: "+N", with: "")),
                               "Chinese Help copy must stay in one language: \(zh.id)")
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

    /// The packaged map showed "Number: quota left in the window selected for": the label's own
    /// text field wrapped "this nozzle." onto a second line its frame had no room for. Drawn by the
    /// real layer, every map caption and the header must fit the field that shows it.
    private func assertMapTextFits(_ input: HelpUIRenderInput, _ name: String,
                                   file: StaticString = #filePath, line: UInt = #line) throws {
        func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(descendants) }
        let layer = HelpUILayerView()
        layer.frame = CGRect(origin: .zero, size: input.viewport)
        layer.update(input)
        XCTAssertNotNil(layer.presentation?.mapHeader, name, file: file, line: line)
        let fields = descendants(layer).compactMap { $0 as? NSTextField }.filter { !$0.isHidden && !$0.stringValue.isEmpty }
        XCTAssertGreaterThan(fields.count, 2, name, file: file, line: line)
        for field in fields {
            let needed = try XCTUnwrap(field.cell, file: file, line: line)
                .cellSize(forBounds: CGRect(x: 0, y: 0, width: field.frame.width, height: 10_000)).height
            XCTAssertLessThanOrEqual(needed, field.frame.height + 0.5, "\(name): \(field.stringValue)", file: file, line: line)
        }
    }

    func testEveryDockMapCaptionFitsTheTextFieldThatDrawsIt() throws {
        for language in [InstrumentLanguage.english, .chinese] {
            let regions = HelpMapCatalog(language).entries(for: .dock).map(\.region)
            let anchors = regions.enumerated().map { index, region in
                DockRequestedHelpAnchor(id: region.rawValue, region: region,
                    rect: CGRect(x: 1860, y: 120 + CGFloat(index) * 100, width: 44, height: 44), visible: true)
            }
            let input = try XCTUnwrap(DockRequestedHelpLayout.make(session: UUID(), viewport: CGSize(width: 1920, height: 120 + CGFloat(regions.count) * 100 + 80),
                language: language, anchors: anchors, blocked: [], recipe: NeutralHelpUIRecipeProvider(), refreshAvailable: true))
            try assertMapTextFits(input, "dock \(language)")
        }
    }

    /// The cockpit's Option map, both window profiles, every caption in both languages.
    func testEveryCockpitMapCaptionFitsTheTextFieldThatDrawsIt() throws {
        for language in [InstrumentLanguage.english, .chinese] {
            for profile in [HelpUIProfile.tall890, .compact640] {
                let height: CGFloat = profile == .tall890 ? 890 : 640
                let regions = HelpMapCatalog(language).entries(for: .cockpit).map(\.region)
                var anchors = regions.enumerated().map { index, region in
                    HelpUIAnchor(id: region.rawValue, rect: CGRect(x: 640, y: 120 + CGFloat(index) * (height - 230) / 15, width: 120, height: 16))
                }
                var map = HelpUIMapInput(mode: .heldOption, surface: .cockpit,
                    regionAnchors: Dictionary(uniqueKeysWithValues: regions.map { ($0, $0.rawValue) }),
                    columns: profile == .tall890 ? [CGRect(x: 8, y: 116, width: 540, height: height - 124)]
                        : [CGRect(x: 8, y: 116, width: 260, height: height - 124), CGRect(x: 280, y: 116, width: 260, height: height - 124)],
                    header: CGRect(x: 8, y: 34, width: 540, height: 70))
                map.sentenceOverrides[.pin] = language == .chinese ? "分离窗口" : "Detach window"
                anchors += [HelpUIAnchor(id: "average", rect: CGRect(x: 640, y: height - 90, width: 120, height: 16)),
                            HelpUIAnchor(id: "live", rect: CGRect(x: 640, y: height - 60, width: 120, height: 16))]
                map.todayAverageAnchorID = "average"; map.liveSpeedAnchorID = "live"
                let input = HelpUIRenderInput(sessionID: UUID(), viewport: CGSize(width: 1280, height: height), profile: profile,
                    language: language, anchors: anchors, liveReadings: anchors.map(\.rect), map: map)
                try assertMapTextFits(input, "cockpit \(language) \(profile)")
            }
        }
    }

    /// G3-12 in a packaged run: Help from the status menu, the widget on the left edge of a 1920×1080
    /// display, the status item at the top right. These anchors and readings are that run's.
    func testStatusMenuHelpMapResolvesEveryLabel() throws {
        let recipe = NeutralHelpUIRecipeProvider()
        let anchors: [DockRequestedHelpAnchor] = [
            .init(id: "status.menu", region: .sliver, rect: CGRect(x: 1641, y: 1, width: 64, height: 22), visible: true,
                  caption: "Right-click the menu bar icon and choose Show Quota Widget."),
            .init(id: "dock.ignition", region: .ignition, rect: CGRect(x: 9.3, y: 212.9, width: 28.8, height: 28.8), visible: true),
            .init(id: "dock.rings.a", region: .rings, rect: CGRect(x: 12.7, y: 257.1, width: 42.3, height: 42.3), visible: true),
            .init(id: "dock.nozzle.a", region: .nozzle, rect: CGRect(x: 11.8, y: 256.2, width: 44, height: 44), visible: true),
            .init(id: "dock.number.a", region: .number, rect: CGRect(x: 10.2, y: 305.3, width: 47.4, height: 13.5), visible: true),
            .init(id: "dock.grip.0", region: .dockMove, rect: CGRect(x: 9, y: 527.6, width: 37.2, height: 25.4), visible: true),
        ]
        let readings = [CGRect(x: 10.2, y: 305.3, width: 47.4, height: 13.5), CGRect(x: 13, y: 374.6, width: 47.4, height: 13.5),
                        CGRect(x: 13.2, y: 444, width: 47.4, height: 13.5), CGRect(x: 10.9, y: 513.3, width: 47.4, height: 13.5)]
        let input = try XCTUnwrap(DockRequestedHelpLayout.make(session: UUID(), viewport: CGSize(width: 1920, height: 1080),
            language: .english, anchors: anchors, blocked: readings, recipe: recipe))
        let result = recipe.presentation(for: input)
        XCTAssertNotNil(result.mapHeader)
        XCTAssertEqual(result.unresolvedMapIDs, [], "header \(String(describing: result.mapHeader)) labels \(result.mapLabels.map { "\($0.id) \($0.frame) leader \($0.leader.count)" })")
        XCTAssertTrue(result.mapLabels.contains { $0.anchorID == "status.menu" })
    }

    /// QA 11-08 item 7: "Number" hid the third ring and "Quota rings" covered the second. Captions
    /// go beside the widget, as in the study, and each draws a leader to its own target.
    func testCaptionsSitBesideTheWidgetWithALeaderToEachTarget() throws {
        let recipe = NeutralHelpUIRecipeProvider()
        let widget = CGRect(x: 0, y: 145, width: 72, height: 415)
        let rings = (0..<5).map { CGRect(x: 12, y: 190 + CGFloat($0) * 70, width: 42, height: 42) }
        let anchors: [DockRequestedHelpAnchor] = [
            .init(id: "status.menu", region: .sliver, rect: CGRect(x: 1641, y: 1, width: 64, height: 22), visible: true,
                  caption: "Right-click the menu bar icon and choose Show Quota Widget."),
            .init(id: "dock.ignition", region: .ignition, rect: CGRect(x: 9, y: 146, width: 29, height: 29), visible: true),
            .init(id: "dock.nozzle.a", region: .nozzle, rect: rings[0].insetBy(dx: -1, dy: -1), visible: true),
            .init(id: "dock.rings.a", region: .rings, rect: rings[0], visible: true),
            .init(id: "dock.number.a", region: .number, rect: CGRect(x: 10, y: 236, width: 47, height: 13), visible: true),
            .init(id: "dock.grip.0", region: .dockMove, rect: CGRect(x: 9, y: 530, width: 37, height: 25), visible: true),
        ] + rings.dropFirst().enumerated().map { index, ring in
            .init(id: "dock.rings.\(index + 1)", region: .rings, rect: ring, visible: true)
        }
        let readings = rings.map { CGRect(x: 10, y: $0.maxY + 4, width: 47, height: 13) }
        for language in [InstrumentLanguage.english, .chinese] {
            let input = try XCTUnwrap(DockRequestedHelpLayout.make(session: UUID(), viewport: CGSize(width: 1920, height: 1080),
                language: language, anchors: anchors, blocked: readings, avoid: [widget], recipe: recipe, refreshAvailable: true))
            let result = recipe.presentation(for: input)
            XCTAssertEqual(result.unresolvedMapIDs, [])
            XCTAssertFalse(result.mapLabels.isEmpty)
            for label in result.mapLabels {
                for ring in rings { XCTAssertFalse(label.frame.intersects(ring), "\(label.id) covers a ring") }
                XCTAssertFalse(label.frame.intersects(widget), "\(label.id) sits on the widget")
                XCTAssertGreaterThanOrEqual(label.leader.count, 2, "\(label.id) has no leader")
            }
            XCTAssertFalse(try XCTUnwrap(result.mapHeader).intersects(widget))
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

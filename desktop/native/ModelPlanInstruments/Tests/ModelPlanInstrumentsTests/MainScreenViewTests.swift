// SPDX-License-Identifier: MIT
import AppKit
import CoreText
import XCTest
@testable import ModelPlanInstruments

private enum B13Fixture {
    static let publication = SelectionPublication(publicationID: "synthetic-p", selectionRevision: "r1")
    static func selection(_ ids: [String] = ["model", "other"], scope: InstrumentScope = .all) -> InjectedModelSelection {
        .init(publication: publication, scope: scope, orderedModelIDs: ids, selectedModelID: ids.first)
    }
    static func inputs(_ tier: InstrumentFastTier? = nil) -> [FaderChannelInput] {
        [.init(model: Fixtures.model(tier: tier)), .init(model: Fixtures.model(id: "other"))]
    }
    static func controller(_ tier: InstrumentFastTier? = nil, location: MainScreenLocation = .init(.overview),
                           pages: [MainScreenPageContent] = []) throws -> MainScreenController {
        var c = MainScreenController(location: location)
        try c.update(inputs: inputs(tier), selection: selection(), publication: publication, publicationUsable: true, pages: pages)
        return c
    }
    static var option: MainScreenFooterOption {
        .init(id: "range", choices: [.init("7", title: "7"), .init("30", title: "30"), .init("off", title: "Unavailable", enabled: false)],
              selectedValue: "7", help: HelpCatalog(.english).explanation(.option))
    }
}
final class ComparisonPresentationTests: XCTestCase {
    func testFixedRolesEqualityMatrixAndUnlitTrialNeverExposeValues() {
        for (current, trial, expected) in [
            ("high", "max", [ComparisonLight.white, .blue, .gold]),
            ("high", "high", [.white, .off, .gold]),
            ("high", "medium", [.white, .gold, .gold]),
            ("medium", "max", [.gold, .blue, .gold]),
            ("medium", "medium", [.gold, .off, .gold])
        ] {
            let p = ComparisonPresentation(model: Fixtures.model(current: .init(current)), trial: .init(trial), publicationUsable: true, language: .english)
            XCTAssertEqual(p.columns.map(\.role), [.current, .trial, .recommended])
            XCTAssertEqual(p.columns.map(\.light), expected)
            if current == trial {
                XCTAssertEqual(p.columns[1].effort, ""); XCTAssertEqual(p.columns[1].equality, "= current")
                XCTAssertTrue(p.columns[1].cells.allSatisfy { $0.text.isEmpty && $0.tableValue == nil && $0.chartRatio == nil })
                XCTAssertFalse(p.chartProfiles.contains { $0.roles.contains(.trial) })
            }
            if current == "medium" { XCTAssertEqual(p.columns[0].equality, "= ★") }
            if trial == "medium" && current != trial { XCTAssertEqual(p.columns[1].equality, "= ★") }
        }
    }
    func testTableAndChartUseExactlyTheSameCurrentRatiosIncludingFast() throws {
        let tier = InstrumentFastTier(costMultiplier: 6, speedMultiplier: 2, taskTimeUnknown: false, qualifier: "Up to the published tier")
        let p = ComparisonPresentation(model: Fixtures.model(current: .init("high", fast: true), tier: tier), trial: .init("max"),
                                       publicationUsable: true, language: .english)
        let geometry = try XCTUnwrap(p.chartGeometry(in: CGRect(x: 31, y: 12, width: 281, height: 77)))
        XCTAssertTrue(geometry.axis.ticks.contains(1))
        for column in p.columns where !column.unlit {
            let profile = try XCTUnwrap(geometry.profiles.first { $0.configuration == column.configuration })
            for (i, cell) in column.cells.enumerated() {
                if let ratio = cell.chartRatio {
                    let point = try XCTUnwrap(profile.points[i])
                    XCTAssertEqual(point.ratio, ratio)
                    XCTAssertEqual((geometry.plot.maxY - point.point.y) / geometry.plot.height * geometry.axis.maximum, ratio, accuracy: 1e-12)
                    if cell.metric != .ability { XCTAssertEqual(cell.text, ComparisonPresentation.multiple(ratio)) }
                } else { XCTAssertNil(profile.points[i]) }
            }
        }
        XCTAssertEqual(p.columns[0].cells.map(\.chartRatio), [1, 1, 1])
        XCTAssertEqual(p.columns[1].cells[1].tableValue!, 8.4 / 18, accuracy: 1e-12)
        XCTAssertTrue(p.notes.contains("Up to the published tier"))
    }
    func testUnknownCurrentAndMissingMetricsNeverBorrowRecommendation() {
        let p = ComparisonPresentation(model: Fixtures.model(current: nil), trial: .init("max"), publicationUsable: true, language: .chinese)
        XCTAssertEqual(p.columns[0].light, .dim); XCTAssertEqual(p.columns[0].cells.map(\.text), ["--", "--", "--"])
        XCTAssertEqual(p.columns[1].cells.map(\.text), ["—", "—", "—"])
        XCTAssertTrue(p.chartProfiles.isEmpty)
        let tier = InstrumentFastTier(costMultiplier: 6, speedMultiplier: 2, taskTimeUnknown: true, qualifier: "Qualified")
        let fast = ComparisonPresentation(model: Fixtures.model(tier: tier), trial: .init("max", fast: true), publicationUsable: true, language: .english)
        XCTAssertEqual(fast.columns[1].cells[2].text, "—"); XCTAssertNil(fast.chartProfiles.first { $0.roles.contains(.trial) }?.ratios[2])
        XCTAssertTrue(fast.notes.contains("Fast task time unavailable")); XCTAssertTrue(fast.notes.contains("Qualified"))
        let invalid = ComparisonPresentation(model: Fixtures.model(), trial: .init("max", fast: true), publicationUsable: true, language: .english)
        XCTAssertFalse(invalid.fastAvailable); XCTAssertNil(invalid.columns[1].configuration)
    }
    func testMissingTimeBreaksPolylineAndNeverInterpolatesThroughGap() throws {
        let efforts = [
            InstrumentEffort(key: "a", label: "A", ability: Fixtures.metric(10), cost: Fixtures.metric(nil), time: Fixtures.metric(20)),
            InstrumentEffort(key: "b", label: "B", ability: Fixtures.metric(20), cost: Fixtures.metric(nil), time: Fixtures.metric(30))
        ]
        let p = ComparisonPresentation(model: Fixtures.model(current: .init("a"), rec: "b", efforts: efforts), trial: .init("b"), publicationUsable: true, language: .english)
        let g = try XCTUnwrap(p.chartGeometry(in: CGRect(x: 0, y: 0, width: 200, height: 80)))
        for profile in g.profiles { XCTAssertEqual(profile.segments.map(\.count), [1, 1]) }
        XCTAssertEqual(ComparisonPresentation.delta(-1.234), "−1.2"); XCTAssertEqual(ComparisonPresentation.delta(0.05), "±0")
        XCTAssertEqual(ComparisonPresentation.multiple(2.8), "×2.80"); XCTAssertEqual(ComparisonPresentation.multiple(nil), "—")
        XCTAssertNil(ComparisonRatioAxis(values: [Double.greatestFiniteMagnitude]))
    }
}
final class MainScreenControllerTests: XCTestCase {
    func testSourcedPageAndReplacementReturnToOriginalLocationAndPageLamp() throws {
        let base = MainScreenLocation(.destinations, destinationsMode: .timeline, timelineRange: .days7, projectPeriod: .days30)
        var c = try B13Fixture.controller(location: base)
        c.open(.page(.init(.effort)), from: .hud)
        XCTAssertEqual(c.navigation.highlightedPage, .destinations)
        c.openComparison(modelID: "model", configuration: .init("max"), from: .comparisonRow("r1"))
        XCTAssertEqual(c.navigation.sourced?.returnTo, base); XCTAssertNil(c.navigation.highlightedPage)
        c.tryEffort("low"); XCTAssertEqual(c.navigation.sourced?.source, .comparisonRow("r1"))
        c.open(.session("s1"), from: .record("s1")); XCTAssertNil(c.trial)
        c.back(); XCTAssertEqual(c.navigation.location, base); XCTAssertNil(c.navigation.sourced)
    }
    func testPageKeysKeepUnderlyingOptionsAndDiscardTemporarySourcePatch() throws {
        var c = try B13Fixture.controller(location: .init(.destinations, destinationsMode: .timeline, timelineRange: .days7, projectPeriod: .days30))
        c.pressPageKey(.overview); c.pressPageKey(.destinations)
        XCTAssertEqual(c.navigation.location, .init(.destinations, destinationsMode: .timeline, timelineRange: .days7, projectPeriod: .days30))
        c.selectPage(.init(.destinations, destinationsMode: .projects))
        c.open(.page(.init(.destinations, destinationsMode: .timeline, timelineRange: .days7)), from: .recordOverflow)
        c.pressPageKey(.destinations)
        XCTAssertEqual(c.navigation.location.destinationsMode, .projects)
        XCTAssertNil(c.navigation.sourced)
    }
    func testAllCloseRoutesEndOneTrialAndClearSourceWithoutChangingReal() throws {
        let original = B13Fixture.inputs()[0].model.current
        let routes: [(inout MainScreenController) throws -> Void] = [
            { $0.back() }, { $0.selectPage(.init(.subscriptions)) }, { $0.selectScope(.subscription("s")) },
            { $0.selectModel("other") }, { $0.receiveFaderIntent(.closeSourcedView) }, { $0.receiveFaderIntent(.trialChanged(nil)) },
            { $0.open(.alerts, from: .alertLamp) },
            { try $0.update(inputs: B13Fixture.inputs(), selection: nil, publication: nil, publicationUsable: false) }
        ]
        for route in routes {
            var c = try B13Fixture.controller(); c.openComparison(modelID: "model", configuration: .init("max"), from: .fader("model"))
            try route(&c); XCTAssertNil(c.trial); XCTAssertNil(c.sourceModelID); XCTAssertEqual(c.inputs[0].model.current, original)
        }
    }
    func testRepeatedSourcePressReturnsWhileDragAndFastKeepItsOrigin() throws {
        let tier = InstrumentFastTier(costMultiplier: 6, speedMultiplier: 2, taskTimeUnknown: true)
        var c = try B13Fixture.controller(tier)
        c.openComparison(modelID: "model", configuration: .init("max"), from: .fast("model"))
        c.receiveFaderIntent(.selectModel("model"))
        c.receiveFaderIntent(.trialChanged(.init(modelID: "model", configuration: .init("low"))))
        XCTAssertEqual(c.navigation.sourced?.source, .fast("model"))
        c.toggleFast(); XCTAssertEqual(c.trial?.configuration, .init("low", fast: true))
        c.openComparison(modelID: "model", from: .fast("model"))
        XCTAssertNil(c.trial); XCTAssertNil(c.navigation.sourced)
        let real = c.inputs[0].model.current
        c.openComparison(modelID: "model", from: .fader("model")); c.tryEffort("max"); c.toggleFast()
        XCTAssertEqual(c.inputs[0].model.current, real)
    }
    func testFooterSlotsDirectChoiceCycleAndAuthoritativeRefresh() throws {
        let page = MainScreenPageContent(.overview, lines: ["Supplied page"], options: [B13Fixture.option, nil, nil])
        var c = try B13Fixture.controller(pages: [page])
        XCTAssertEqual(MainScreenPresentation(controller: c, language: .english, compact: false).footer.count, 3)
        XCTAssertEqual(c.chooseOption(id: "range", value: "30"), [.optionSelected(page: .overview, id: "range", value: "30")])
        try c.update(inputs: B13Fixture.inputs(), selection: B13Fixture.selection(), publication: B13Fixture.publication, publicationUsable: true, pages: [page])
        XCTAssertEqual(c.option(B13Fixture.option, page: .overview).selectedValue, "30")
        XCTAssertTrue(c.chooseOption(id: "range", value: "off").isEmpty)
        XCTAssertEqual(c.chooseOption(id: "range"), [.optionSelected(page: .overview, id: "range", value: "7")])
        c.open(.alerts, from: .alertLamp)
        XCTAssertTrue(c.chooseOption(id: "range", value: "30").isEmpty)
        c.back()
        c.selectScope(.subscription("next")); XCTAssertTrue(c.pages.isEmpty)
    }
    func testInvalidPublicationSelectionDuplicateModelsAndBadContentStayUnavailable() throws {
        var c = try B13Fixture.controller()
        let duplicate = B13Fixture.inputs() + [.init(model: Fixtures.model())]
        try c.update(inputs: duplicate, selection: B13Fixture.selection(), publication: B13Fixture.publication, publicationUsable: true)
        XCTAssertTrue(c.openComparison(modelID: "model", from: .fader("model")).isEmpty)
        try c.update(inputs: B13Fixture.inputs(), selection: B13Fixture.selection(), publication: .init(publicationID: "wrong", selectionRevision: "r1"), publicationUsable: true)
        XCTAssertTrue(c.openComparison(modelID: "model", from: .fader("model")).isEmpty)
        let before = MainScreenPresentation(controller: c, language: .english, compact: false)
        XCTAssertThrowsError(try c.update(inputs: [], selection: nil, publication: nil, publicationUsable: false,
            pages: [.init(.overview), .init(.overview)]))
        XCTAssertEqual(MainScreenPresentation(controller: c, language: .english, compact: false), before)
        var fader = FaderBankController(); fader.update(inputs: B13Fixture.inputs(), publicationUsable: true)
        XCTAssertTrue(fader.changeBank(0).contains(.closeSourcedView))
    }
}
@MainActor final class MainScreenViewTests: XCTestCase {
    private func setup(_ tier: InstrumentFastTier? = nil, pages: [MainScreenPageContent] = [], provider: (any MainScreenRecipeProvider)? = nil) throws -> MainScreenView {
        let view = MainScreenView(recipeProvider: provider); view.onHelpChange = { _, _ in }
        try view.update(inputs: B13Fixture.inputs(tier), selection: B13Fixture.selection(), publication: B13Fixture.publication, publicationUsable: true,
                        language: .english, compact: false, pages: pages)
        return view
    }
    func testFixedComparisonColumnBoundsAndActualPolylineCoordinates() async throws {
        let view = try setup(), real = view.controller.inputs[0].model.current
        var frames: [CGRect]?
        for key in ["max", "high", "medium"] {
            view.openComparison(modelID: "model", configuration: .init(key), from: .fader("model"), toggle: false)
            let r = try XCTUnwrap(view.recipe), p = try XCTUnwrap(view.presentation?.comparison)
            let boxes = r.regions.filter { $0.id.hasPrefix("compare.column.") }.map(\.rect)
            XCTAssertEqual(boxes.count, 3); XCTAssertEqual(Set(boxes.map(\.width)).count, 1)
            if let frames { XCTAssertEqual(boxes, frames) } else { frames = boxes }
            if key == "high" {
                XCTAssertFalse(r.commands.contains { if case .text(let t) = $0 { return t.id == "compare.1.effort" || t.id.hasPrefix("compare.1.metric.") }; return false })
            }
            let chart = try XCTUnwrap(r.chart)
            XCTAssertEqual(chart, p.chartGeometry(in: chart.plot))
            let drawn = r.commands.compactMap { command -> [CGPoint]? in if case .polyline(let points, _, _, _) = command { return points }; return nil }
            for profile in chart.profiles { for segment in profile.segments where segment.count>1 { XCTAssertTrue(drawn.contains(segment.map(\.point))) } }
            XCTAssertEqual(view.presentation?.footer.count, 2); XCTAssertNil(view.control(for: "screen.footer.1"))
            XCTAssertTrue(view.presentation!.pageKeys.allSatisfy { !$0.lit })
            for scale in [1,2] { XCTAssertEqual(try view.rasterImage(scale: scale).width, 600 * scale) }
        }
        XCTAssertEqual(view.controller.inputs[0].model.current, real); view.dispose()
    }
    func testUnchangedRefreshReusesBitmapAndCurrentControlsHaveSharedHelp() async throws {
        let view = try setup(); var help: HelpExplanation?; view.onHelpChange = { value, _ in help = value }
        view.openComparison(modelID: "model", configuration: .init("max"), from: .fader("model"))
        let button = try XCTUnwrap(view.control(for: "compare.effort.low")); XCTAssertTrue(button.becomeFirstResponder())
        XCTAssertEqual(button.accessibilityHelp(), help?.accessibleDescription)
        let renders = view.surfaceRenders, displays = view.displayRequests
        for _ in 0..<100 {
            try view.update(inputs: B13Fixture.inputs(), selection: B13Fixture.selection(), publication: B13Fixture.publication, publicationUsable: true, language: .english, compact: false)
        }
        XCTAssertEqual(view.surfaceRenders, renders); XCTAssertEqual(view.displayRequests, displays)
        XCTAssertTrue(button === view.control(for: "compare.effort.low"))
        view.back(); XCTAssertFalse(button.accessibilityPerformPress())
        let page = try XCTUnwrap(view.control(for: "screen.page.0")); view.dispose()
        XCTAssertFalse(page.accessibilityPerformPress())
    }
    func testFooterPointerChoosesPrintedValueAndKeyboardCyclesSameKey() async throws {
        let option = MainScreenFooterOption(id: "range", choices: [.init("7", title: "7"), .init("30", title: "30")], selectedValue: "7", help: B13Fixture.option.help)
        let view = try setup(pages: [.init(.overview, options: [option, nil, nil])])
        let window = NSWindow(contentRect: view.frame, styleMask: [], backing: .buffered, defer: false); window.contentView = view
        let control = try XCTUnwrap(view.control(for: "screen.footer.0")), frame = try XCTUnwrap(view.recipe?.regions.first { $0.id == "screen.footer.0.choice.30" }?.rect)
        func event(_ type: NSEvent.EventType) -> NSEvent { NSEvent.mouseEvent(with: type, location: view.convert(CGPoint(x: frame.midX, y: frame.midY), to: nil), modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 0)! }
        control.mouseDown(with: event(.leftMouseDown)); control.mouseUp(with: event(.leftMouseUp))
        XCTAssertEqual(control.accessibilityValue() as? String, "30")
        XCTAssertTrue(control.accessibilityPerformPress()); XCTAssertEqual(control.accessibilityValue() as? String, "7")
        XCTAssertTrue(control === view.control(for: "screen.footer.0")); view.dispose(); window.contentView = nil
    }
    func testComparisonPreparationFailureRetriesWithoutCommittingNavigation() async throws {
        let provider = RecoveringMainScreenProvider()
        let tested = try setup(provider: provider); var emitted: [MainScreenIntent] = []; tested.onIntent = { emitted.append($0) }
        provider.fail = true
        tested.openComparison(modelID: "model", configuration: .init("max"), from: .fader("model"))
        XCTAssertNotNil(tested.renderError); XCTAssertNil(tested.controller.trial); XCTAssertTrue(emitted.isEmpty)
        provider.fail = false; tested.openComparison(modelID: "model", configuration: .init("max"), from: .fader("model"))
        XCTAssertEqual(tested.controller.trial?.configuration.effort, "max"); XCTAssertNil(tested.renderError)
        tested.dispose()
    }
    func testFaderAndMainScreenEndToEndKeepRealAndSourceInSync() async throws {
        let screen = try setup(), fader = FaderBankView(); fader.onHelpChange = { _, _ in }
        try fader.update(inputs: B13Fixture.inputs(), publicationUsable: true, language: .english, compact: false, now: Fixtures.now)
        fader.onIntent = { screen.receiveFaderIntent($0) }
        screen.onIntents = { effects in
            for effect in effects {
                switch effect {
                case .trialChanged(let trial): try? fader.setTrial(trial)
                case .sourceHighlightChanged: try? fader.setSourceHighlight(screen.controller.sourceModelID)
                default: break
                }
            }
        }
        let real = fader.presentation?.channels[0]?.current, position = fader.presentation?.channels[0]?.realPosition
        XCTAssertTrue(fader.control(for: "fader.slot.0.travel")!.accessibilityPerformIncrement())
        XCTAssertEqual(screen.controller.trial?.configuration.effort, "max"); XCTAssertTrue(fader.presentation?.channels[0]?.sourceHighlighted == true)
        XCTAssertTrue(screen.control(for: "compare.effort.low")!.accessibilityPerformPress())
        XCTAssertEqual(fader.controller.trial?.configuration.effort, "low")
        XCTAssertTrue(screen.control(for: "screen.footer.0")!.accessibilityPerformPress())
        XCTAssertNil(fader.controller.trial); XCTAssertFalse(fader.presentation!.channels[0]!.sourceHighlighted)
        XCTAssertEqual(fader.presentation?.channels[0]?.current, real); XCTAssertEqual(fader.presentation?.channels[0]?.realPosition, position)
        screen.dispose(); fader.dispose()
    }
    func testActualCockpitCloseRetiresControlsAndEndsTrialWithoutRendering() async throws {
        let provider = RecoveringMainScreenProvider()
        let tested = try setup(provider: provider); var effects: [MainScreenIntent] = []
        tested.onIntents = { effects.append(contentsOf: $0) }
        tested.openComparison(modelID: "model", configuration: .init("max"), from: .fader("model"))
        let button = try XCTUnwrap(tested.control(for: "compare.effort.low")), renders = tested.surfaceRenders
        effects = []; provider.failAll = true
        tested.closeForCockpit()
        XCTAssertNil(tested.controller.trial); XCTAssertNil(tested.controller.sourceModelID)
        XCTAssertTrue(effects.contains(.trialChanged(nil))); XCTAssertTrue(effects.contains(.sourceHighlightChanged(nil)))
        XCTAssertEqual(tested.surfaceRenders, renders); XCTAssertFalse(button.accessibilityPerformPress())
        XCTAssertNil(tested.presentation); XCTAssertNil(tested.recipe)
        tested.dispose()
    }
}
@MainActor private final class RecoveringMainScreenProvider: MainScreenRecipeProvider {
    var fail = false, failAll = false
    let neutral = NeutralMainScreenRecipe()
    func minimumSize(for p: MainScreenPresentation) -> CGSize { neutral.minimumSize(for: p) }
    func font(_ r: EngineFontRequest) throws -> CTFont { try neutral.font(r) }
    func image(_ id: String) throws -> CGImage { throw EngineTableError.missingResource(id) }
    func recipe(for p: MainScreenPresentation, size: CGSize) throws -> MainScreenRecipe {
        if failAll { throw EngineTableError.invalidRecipe }
        let r = try neutral.recipe(for: p, size: size)
        if p.comparison != nil && fail {
            return .init(size: r.size, commands: r.commands + [.image(resourceID: "synthetic-missing", rect: CGRect(x: 0, y: 0, width: 1, height: 1), opacity: 1)], regions: r.regions, chart: r.chart, focusInk: r.focusInk)
        }
        return r
    }
}

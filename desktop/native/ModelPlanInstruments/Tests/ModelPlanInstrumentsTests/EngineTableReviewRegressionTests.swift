// SPDX-License-Identifier: MIT
import AppKit
import CoreText
import XCTest
@testable import ModelPlanInstruments

@MainActor final class EngineTableReviewRegressionTests: XCTestCase {
    func testCompletelyEmptyTableKeepsEveryBodyAddTargetWithoutPaintingIt() async throws {
        for language in [InstrumentLanguage.chinese, .english] {
            let view = EngineTableView(); view.onHelpChange = { _, _ in }
            try view.update(columns: [], language: language, now: Fixtures.now)
            var intents: [EngineTableIntent] = []; view.onIntent = { intents.append($0) }
            let bodies = view.recipe!.regions.filter { $0.id.hasSuffix(".body") }
            XCTAssertEqual(bodies.count, 6)
            for index in 0..<6 {
                let id = "engine.empty.\(index).body"
                guard let region = bodies.first(where: { $0.id == id }), let control = view.control(for: id) else {
                    XCTFail("Missing empty LCD body \(index)"); continue
                }
                XCTAssertEqual(region.intent, .openSubscriptionsSettings)
                XCTAssertFalse(region.tabStop); XCTAssertFalse(view.keyboardOrder.contains(id))
                XCTAssertTrue(view.hitTest(CGPoint(x: region.rect.midX, y: region.rect.midY)) === control)
                XCTAssertTrue(control.accessibilityPerformPress())
            }
            XCTAssertEqual(intents, Array(repeating: .openSubscriptionsSettings, count: 6))
            let readouts = view.recipe!.commands.compactMap { command -> String? in
                if case .text(let text) = command { return text.id }; return nil
            }
            XCTAssertEqual(Set(readouts), Set(["engine.all.text", "engine.empty.message"] + (0..<6).map { "engine.empty.\($0).key.text" }))
        }
    }

    func testLateTextFontFailureRetainsCommittedStateAndIdenticalInputRetries() async throws {
        let provider = ReviewSurfaceProvider(), view = EngineTableView(recipeProvider: provider)
        view.onHelpChange = { _, _ in }
        try view.update(columns: [Fixtures.column("a")], language: .english, now: Fixtures.now)
        let oldPresentation = view.presentation, oldRecipe = view.recipe, oldRequests = view.displayRequests
        let oldControl = try XCTUnwrap(view.control(for: "engine.subscription.a"))
        let oldImages = textImages(view); XCTAssertEqual(oldImages.count, 2)
        provider.failSecondSurfaceOnce = true
        XCTAssertThrowsError(try view.update(columns: [Fixtures.column("b")], language: .english, now: Fixtures.now))
        XCTAssertEqual(provider.secondFontReads, 2, "Failure must occur in the derived surface, after full-canvas preflight")
        XCTAssertEqual(view.presentation, oldPresentation); XCTAssertEqual(view.recipe, oldRecipe)
        XCTAssertTrue(view.control(for: "engine.subscription.a") === oldControl)
        XCTAssertNil(view.control(for: "engine.subscription.b")); XCTAssertEqual(view.displayRequests, oldRequests)
        let failedImages = textImages(view)
        XCTAssertEqual(failedImages.count, oldImages.count)
        for index in oldImages.indices where index < failedImages.count { XCTAssertTrue(oldImages[index] === failedImages[index]) }

        // The provider recovers, while the exact candidate input and recipe stay the same.
        try view.update(columns: [Fixtures.column("b")], language: .english, now: Fixtures.now)
        XCTAssertEqual(provider.recipeCalls, 3)
        XCTAssertEqual(view.presentation?.columns[0]?.id, "b")
        XCTAssertNotNil(view.control(for: "engine.subscription.b")); XCTAssertNil(view.control(for: "engine.subscription.a"))
        XCTAssertEqual(view.displayRequests, oldRequests + 1)
        let newImages = textImages(view)
        XCTAssertEqual(newImages.count, 2)
        for index in oldImages.indices where index < newImages.count { XCTAssertFalse(oldImages[index] === newImages[index]) }
    }

    func testOversizedDerivedCanvasNeverPublishesAnInitialPresentation() async throws {
        let provider = ReviewSurfaceProvider(); provider.oversized = true
        let view = EngineTableView(recipeProvider: provider); view.onHelpChange = { _, _ in }
        let candidate = EngineTablePresentation(columns: [Fixtures.column("a")], requestedPage: 0, scope: .all, language: .english, now: Fixtures.now)
        let recipe = try provider.recipe(for: candidate, size: view.bounds.size)
        XCTAssertNoThrow(try EngineRecipeDrawing.raster(recipe, provider: provider, scale: 1))
        XCTAssertThrowsError(try view.update(columns: [Fixtures.column("a")], language: .english, now: Fixtures.now))
        XCTAssertNil(view.presentation); XCTAssertNil(view.recipe); XCTAssertTrue(view.regionIDs.isEmpty)
        XCTAssertTrue(textImages(view).isEmpty); XCTAssertEqual(view.displayRequests, 0)
        provider.oversized = false
        try view.update(columns: [Fixtures.column("a")], language: .english, now: Fixtures.now)
        XCTAssertEqual(view.presentation?.columns[0]?.id, "a"); XCTAssertEqual(view.displayRequests, 1)
    }

    func testOtherOverflowHelpContainsAllFactsInPointerFocusAndAccessibilityContent() async throws {
        for language in [InstrumentLanguage.chinese, .english] {
            let view = EngineTableView(); var focused: HelpExplanation?
            view.onHelpChange = { value, _ in focused = value }
            try view.update(columns: [otherColumn()], language: language, now: Fixtures.now)
            let cell = try XCTUnwrap(view.presentation?.columns[0]?.cells[2])
            XCTAssertEqual(cell.amount, "9"); XCTAssertTrue(cell.notes[0].hasSuffix("+3"))
            let body = cell.help.body
            for text in ["Fable", "9%", "Requests", "33%", "77%", "Images", "--"] { XCTAssertTrue(body.contains(text), "Missing \(text): \(body)") }
            for period in language == .chinese ? ["周", "月", "日", "burst"] : ["wk", "mo", "day", "burst"] { XCTAssertTrue(body.contains(period)) }
            let format = InstrumentFormat(language)
            for minutes in [60.0, 120.0] { XCTAssertTrue(body.contains(format.reset(Fixtures.now.addingTimeInterval(minutes * 60), now: Fixtures.now))) }
            XCTAssertTrue(body.contains(language == .chinese ? "预告" : "announced"))
            XCTAssertTrue(body.contains(language == .chinese ? "用完" : "out ~"))
            let region = try XCTUnwrap(view.recipe?.regions.first { $0.id == "engine.acct.row.2" })
            XCTAssertEqual(region.help, cell.help) // Pointer dwell consumes this exact explanation.
            let control = try XCTUnwrap(view.control(for: region.id)); XCTAssertTrue(control.becomeFirstResponder())
            XCTAssertEqual(focused, cell.help); XCTAssertEqual(control.accessibilityHelp(), cell.help.accessibleDescription)
        }
    }

    func testOtherOverflowHelpDoesNotReviveStaleReadingsOrResets() async throws {
        for language in [InstrumentLanguage.chinese, .english] {
            let p = EngineTablePresentation(columns: [otherColumn(stale: true)], requestedPage: 0, scope: .all, language: language, now: Fixtures.now)
            let cell = try XCTUnwrap(p.columns[0]?.cells[2]); XCTAssertEqual(cell.amount, "--")
            for text in ["Fable", "Requests", "Images"] { XCTAssertTrue(cell.help.body.contains(text)) }
            for text in ["9%", "33%", "77%"] { XCTAssertFalse(cell.help.body.contains(text)) }
            XCTAssertFalse(cell.help.body.contains(language == .chinese ? "预告" : "announced"))
            XCTAssertTrue(cell.help.body.contains("--"))
        }
    }

    func testScopeKeyShortcutIsAvailableInHelpFocusAndAccessibilityWithoutDrawingIt() async throws {
        for language in [InstrumentLanguage.chinese, .english] {
            let view = EngineTableView(); var focused: HelpExplanation?
            view.onHelpChange = { value, _ in focused = value }
            let columns = (0..<13).map { Fixtures.column("s\($0)") }
            try view.update(columns: columns, language: language, now: Fixtures.now, page: 2)
            let all = try XCTUnwrap(view.recipe?.regions.first { $0.id == "engine.all" })
            let subscription = try XCTUnwrap(view.recipe?.regions.first { $0.id == "engine.subscription.s12" })
            XCTAssertTrue(all.help.body.contains(language == .chinese ? "键 0" : "key 0"))
            XCTAssertTrue(subscription.help.body.contains(language == .chinese ? "键 1" : "key 1"))
            XCTAssertTrue(all.label.contains(language == .chinese ? "键 0" : "key 0"))
            XCTAssertTrue(subscription.label.contains(language == .chinese ? "键 1" : "key 1"))
            let control = try XCTUnwrap(view.control(for: subscription.id)); XCTAssertTrue(control.becomeFirstResponder())
            XCTAssertEqual(focused, subscription.help)
            XCTAssertEqual(control.accessibilityHelp(), subscription.help.accessibleDescription)
            let keyText = view.recipe!.commands.compactMap { command -> EngineTextCommand? in
                if case .text(let text) = command, text.id == "engine.subscription.s12.text" { return text }; return nil
            }
            XCTAssertEqual(keyText.first?.variants, ["s12"])
        }
    }

    func testOtherHelpBeyondLabelBudgetStillRendersAndUpdatesWithoutLosingDetails() async throws {
        let view = EngineTableView(); var focused: HelpExplanation?
        view.onHelpChange = { value, _ in focused = value }
        try view.update(columns: [Fixtures.column("acct")], language: .english, now: Fixtures.now)
        for count in [160, 161] {
            let windows = (0..<count).map { i in
                InstrumentQuota(id: "quota-\(i)", period: .daily, scope: "Quota-\(i)", remaining: Double(i % 100),
                                resetsAt: Fixtures.now.addingTimeInterval(Double(i + 60) * 60))
            }
            let column = EngineColumn(id: "acct", quotas: .init(windows: windows, now: Fixtures.now), todayTokens: nil, todayGenerationTPS: nil)
            do { try view.update(columns: [column], language: .english, now: Fixtures.now) }
            catch { XCTFail("Valid complete help must not reject the table: \(error)"); return }
            let cell = try XCTUnwrap(view.presentation?.columns[0]?.cells[2])
            XCTAssertGreaterThan(cell.help.accessibleDescription.utf8.count, 4096)
            let region = try XCTUnwrap(view.recipe?.regions.first { $0.id == "engine.acct.row.2" })
            XCTAssertLessThanOrEqual(region.label.utf8.count, 4096)
            let control = try XCTUnwrap(view.control(for: region.id)); XCTAssertTrue(control.becomeFirstResponder())
            XCTAssertEqual(focused, cell.help); XCTAssertEqual(control.accessibilityHelp(), cell.help.accessibleDescription)
            for index in 0..<count { XCTAssertTrue(cell.help.body.contains("Quota-\(index)·")) }
            XCTAssertEqual(cell.amount, "0"); XCTAssertTrue(cell.notes[0].hasSuffix("+\(count - 1)"))
            XCTAssertNoThrow(try view.rasterImage(scale: 1))
        }
    }

    private func textImages(_ view: EngineTableView) -> [AnyObject] {
        view.layer?.sublayers?.compactMap { $0.contents.map { $0 as AnyObject } } ?? []
    }
    private func otherColumn(stale: Bool = false) -> EngineColumn {
        let now = Fixtures.now
        let windows: [InstrumentQuota] = [
            .init(id: "scoped", period: .weekly, scope: "Fable", remaining: 9, resetsAt: now.addingTimeInterval(3600)),
            .init(id: "monthly", period: .monthly, remaining: 77, resetsAt: now.addingTimeInterval(7200), runsOutAt: now.addingTimeInterval(1800)),
            .init(id: "unknown", period: .daily, scope: "Images", remaining: nil),
            .init(id: "unknown-reset", period: .other("burst"), scope: "Requests", remaining: 33, publicReset: .announced(now.addingTimeInterval(10800))),
        ]
        return .init(id: "acct", quotas: .init(windows: windows, now: now), todayTokens: nil, todayGenerationTPS: nil,
                     evidence: .init(observedAt: now.addingTimeInterval(-60), freshness: stale ? .stale : .fresh))
    }
}

@MainActor private final class ReviewSurfaceProvider: EngineTableRecipeProvider {
    var oversized = false, failSecondSurfaceOnce = false
    private(set) var recipeCalls = 0, secondFontReads = 0
    func recipe(for presentation: EngineTablePresentation, size: CGSize) throws -> EngineTableRecipe {
        recipeCalls += 1; secondFontReads = 0
        var recipe = try NeutralEngineTableRecipe().recipe(for: presentation, size: size)
        let value = presentation.columns[0]?.id ?? "none"
        for index in 0..<2 {
            recipe.commands.append(.text(.init(id: "review.\(index)", variants: [value],
                rect: CGRect(x: 10, y: 40 + index * 24, width: index == 1 && oversized ? 5000 : 80, height: 20),
                font: .init(resourceID: index == 1 ? "review.second" : "review.first", size: 12),
                ink: .init(1, 1, 1), transitionDuration: 0.08)))
        }
        return recipe
    }
    func font(_ request: EngineFontRequest) throws -> CTFont {
        if request.resourceID == "review.second" {
            secondFontReads += 1
            if failSecondSurfaceOnce && secondFontReads == 2 { failSecondSurfaceOnce = false; throw EngineTableError.missingResource("review.second") }
        }
        var system = request; system.resourceID = nil
        return try NeutralEngineTableRecipe().font(system)
    }
    func image(_ resourceID: String) throws -> CGImage { throw EngineTableError.missingResource(resourceID) }
}

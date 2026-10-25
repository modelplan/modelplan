// SPDX-License-Identifier: MIT
import AppKit
import XCTest
@testable import ModelPlanInstruments

@MainActor final class EngineTableViewTests: XCTestCase {
    func testAdaptiveTracksAndPagedLastBayPreserveIDs() async throws {
        for n in [1, 2, 4, 7, 10, 13] {
            let columns = (0..<n).map { Fixtures.column("s\($0)", caution: $0 == n - 1 ? .critical : .unknown) }
            let p = EngineTablePresentation(columns: columns, requestedPage: 99, scope: .all, language: .english, now: Fixtures.now)
            XCTAssertEqual(p.tracks, n <= 6 ? max(3, n) : 6)
            XCTAssertEqual(p.columns.compactMap { $0?.id }, Array(columns.suffix((n - 1) % 6 + 1)).map(\.id))
            XCTAssertEqual(p.pageIndicators.last?.caution, .critical)
            if n == 13 { XCTAssertEqual(p.columns.filter { $0 == nil }.count, 5) }
        }
    }

    func testMonthlyAbsenceUnknownAndZeroAreDistinctInBothLanguages() async throws {
        let now = Fixtures.now
        let windows = [Fixtures.quota("month", .monthly, 77)]
        let monthly = EngineColumn(id: "m", quotas: .init(windows: windows, now: now), todayTokens: nil, todayGenerationTPS: nil)
        let unknown = EngineColumn(id: "u", quotas: .init(windows: [Fixtures.quota("5h", .fiveHours, nil)], now: now), todayTokens: nil, todayGenerationTPS: nil)
        let zero = EngineColumn(id: "z", quotas: .init(windows: [Fixtures.quota("5h", .fiveHours, 0)], now: now), todayTokens: 0, todayGenerationTPS: 0)
        for language in [InstrumentLanguage.chinese, .english] {
            let p = EngineTablePresentation(columns: [monthly, unknown, zero], requestedPage: 0, scope: .all, language: language, now: now)
            XCTAssertNil(p.columns[0]?.cells[0]); XCTAssertNil(p.columns[0]?.cells[1])
            XCTAssertTrue(p.columns[0]!.cells[2]!.notes[0].contains(language == .chinese ? "月" : "mo"))
            XCTAssertEqual(p.columns[1]?.cells[0]?.amount, "--"); XCTAssertEqual(p.columns[1]?.cells[0]?.suffix, "")
            XCTAssertEqual(p.columns[2]?.cells[0]?.amount, "0"); XCTAssertEqual(p.columns[2]?.cells[0]?.level, .critical)
            XCTAssertEqual(p.columns[2]?.todayTokens, "0"); XCTAssertEqual(p.columns[2]?.todaySpeed, "0")
        }
    }

    func testEmptyBayHasOnlyAddTargetsAndNoDataInk() async throws {
        let view = EngineTableView()
        view.onHelpChange = { _, _ in }
        try view.update(columns: [Fixtures.column("a")], language: .english, now: Fixtures.now)
        XCTAssertTrue(view.keyboardOrder.contains("engine.empty.1.key"))
        XCTAssertFalse(view.keyboardOrder.contains("engine.empty.1.body"))
        let body = try XCTUnwrap(view.recipe?.regions.first { $0.id == "engine.empty.1.body" })
        XCTAssertEqual(body.intent, .openSubscriptionsSettings)
        let texts = view.recipe!.commands.compactMap { c -> EngineTextCommand? in if case .text(let t) = c { return t }; return nil }
        XCTAssertFalse(texts.contains { $0.id.contains("empty.1") && $0.variants != ["—"] })
        let before = try view.rasterImage(scale: 1)
        // Replace this empty slot with an actually blank populated column at the same LCD coordinates.
        try view.update(columns: [Fixtures.column("a"), Fixtures.column("blank", tokens: nil)], language: .english, now: Fixtures.now)
        let after = try view.rasterImage(scale: 1)
        let clip = CGRect(x: body.rect.minX + 8, y: body.rect.minY + 8, width: body.rect.width - 16, height: body.rect.height - 16)
        let a = try XCTUnwrap(before.cropping(to: clip)?.dataProvider?.data)
        let b = try XCTUnwrap(after.cropping(to: clip)?.dataProvider?.data)
        XCTAssertEqual(a as Data, b as Data)
    }

    func testEnterSpaceAndAccessibilityPressEmitSameAddIntent() async throws {
        let view = EngineTableView(); view.onHelpChange = { _, _ in }
        try view.update(columns: [Fixtures.column("a")], language: .chinese, now: Fixtures.now)
        var intents: [EngineTableIntent] = []; view.onIntent = { intents.append($0) }
        let control = try XCTUnwrap(view.control(for: "engine.empty.1.key"))
        control.keyDown(with: key("\r", code: 36)); control.keyDown(with: key(" ", code: 49))
        XCTAssertTrue(control.accessibilityPerformPress())
        XCTAssertEqual(intents, Array(repeating: .openSubscriptionsSettings, count: 3))
        XCTAssertTrue(control.accessibilityLabel()?.contains("添加订阅") == true)
        XCTAssertTrue(control.accessibilityHelp()?.contains("添加订阅") == true)
    }

    func testControlsAndFocusHelpRemainPersistentAcrossRefresh() async throws {
        let view = EngineTableView(); var shown: HelpExplanation?
        view.onHelpChange = { explanation, _ in shown = explanation }
        try view.update(columns: [Fixtures.column("a")], language: .english, now: Fixtures.now)
        let control = try XCTUnwrap(view.control(for: "engine.empty.1.key"))
        XCTAssertTrue(control.becomeFirstResponder())
        XCTAssertTrue(shown?.accessibleDescription.contains("Add a subscription") == true)
        try view.update(columns: [Fixtures.column("a", tokens: 100)], language: .english, now: Fixtures.now)
        XCTAssertTrue(control === view.control(for: "engine.empty.1.key"))
        XCTAssertEqual(control.accessibilityHelp(), shown?.accessibleDescription)
        view.leaveHelp(); XCTAssertNil(shown)
    }

    func testRepeatedUnchangedUpdateDoesNotRequestRepaint() async throws {
        let view = EngineTableView(); view.onHelpChange = { _, _ in }
        let columns = [Fixtures.column("a")]
        try view.update(columns: columns, language: .english, now: Fixtures.now)
        for _ in 0..<100 { try view.update(columns: columns, language: .english, now: Fixtures.now) }
        XCTAssertEqual(view.displayRequests, 1)
        XCTAssertEqual(view.drawCount, 0) // No window and no private render loop.
    }

    func testPagingKeepsScopeAndBoundaryButtonIsDisabled() async throws {
        let view = EngineTableView(); view.onHelpChange = { _, _ in }
        let columns = (0..<13).map { Fixtures.column("s\($0)") }
        try view.update(columns: columns, language: .english, now: Fixtures.now, scope: .subscription("s0"))
        XCTAssertFalse(view.control(for: "engine.page.previous")!.accessibilityPerformPress())
        view.activate(.changePage(2))
        XCTAssertEqual(view.presentation?.page, 2); XCTAssertEqual(view.presentation?.scope, .subscription("s0"))
        XCTAssertEqual(view.presentation?.columns.compactMap { $0 }.first?.id, "s12")
        XCTAssertFalse(view.control(for: "engine.page.next")!.accessibilityPerformPress())
        view.activate(.changePage(99)); XCTAssertEqual(view.presentation?.page, 2)
    }

    func testRasterDensitiesAndRecipeRejectNonfiniteSizingBeforeAllocation() async throws {
        let view = EngineTableView(); view.onHelpChange = { _, _ in }
        try view.update(columns: [Fixtures.column("a")], language: .english, now: Fixtures.now)
        for scale in [1, 2] {
            let image = try view.rasterImage(scale: scale)
            XCTAssertEqual(image.width, 640 * scale); XCTAssertEqual(image.height, 300 * scale)
        }
        XCTAssertThrowsError(try view.rasterImage(scale: Int.max))
        let invalid = EngineTableRecipe(size: CGSize(width: CGFloat.infinity, height: 300), commands: [], regions: [])
        XCTAssertThrowsError(try invalid.validate())
        let valid = EngineTableRecipe(size: CGSize(width: 640, height: 300), commands: [], regions: [])
        XCTAssertThrowsError(try EngineRecipeDrawing.raster(valid, provider: view.recipeProvider, scale: 0))
    }

    func testForecastAndPublicResetDoNotInventAccountRefill() async throws {
        let now = Fixtures.now
        let quota = InstrumentQuota(id: "q", period: .fiveHours, remaining: 0, resetsAt: now.addingTimeInterval(3600), durationMinutes: 300,
                                    runsOutAt: now.addingTimeInterval(60), publicReset: .confirmedAwaitingReading)
        let column = EngineColumn(id: "a", quotas: .init(windows: [quota], now: now), todayTokens: nil, todayGenerationTPS: nil)
        let p = EngineTablePresentation(columns: [column], requestedPage: 0, scope: .all, language: .chinese, now: now)
        XCTAssertEqual(p.columns[0]?.cells[0]?.amount, "0"); XCTAssertEqual(p.columns[0]?.cells[0]?.level, .critical)
        XCTAssertEqual(p.columns[0]?.cells[0]?.noteTone, .publicReset)
        XCTAssertTrue(p.columns[0]!.cells[0]!.notes[0].contains("等读数"))
    }

    private func key(_ text: String, code: UInt16) -> NSEvent {
        NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0,
                         context: nil, characters: text, charactersIgnoringModifiers: text, isARepeat: false, keyCode: code)!
    }
}

// SPDX-License-Identifier: MIT
import AppKit
import CoreText
import XCTest
@testable import ModelPlanInstruments

@MainActor final class RecordStripViewTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_000_000)
    private func session(_ id: String, working: Bool = true, rate: Double? = nil, rateID: String? = nil, rateAge: Double = 0) -> InstrumentSession {
        .init(id: id, subscriptionID: "account", tool: "Claude Code", model: "model", effort: "high", projectID: "project", projectName: "Private Project",
              startedAt: now.addingTimeInterval(-120), endedAt: working ? nil : now.addingTimeInterval(-360), lastAt: now,
              running: working, rate: .init(value: rate, lastAt: now.addingTimeInterval(-rateAge), samples: 5, validSession60s: true,
                configuration: .init(sessionID: rateID ?? id, modelID: "model", effort: "high", fast: false)))
    }
    private func input(_ sessions: [InstrumentSession], full: Bool = false, names: Bool = true, language: InstrumentLanguage = .english,
                       identities: [String: RecordStripIdentity] = [:], cursor: RecordStripCursor? = nil) -> RecordStripViewInput {
        .init(presentation: .init(sessions: sessions, height: full ? 890 : 640, scope: .all, showProjectNames: names, now: now, language: language),
              density: full ? .full : .compact, appearance: .init(language: language), identities: identities, cursor: cursor)
    }
    private func key(_ text: String, code: UInt16) -> NSEvent {
        NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil,
                         characters: text, charactersIgnoringModifiers: text, isARepeat: false, keyCode: code)!
    }
    func testProjectionOrderCapacityAndOverflowAreUnchanged() async throws {
        let view = RecordStripView(), sessions = (0..<7).map { session("s\($0)", working: $0 != 0) }
        for full in [false, true] {
            let value = input(sessions, full: full); try view.configure(value)
            XCTAssertEqual(view.recipe?.rows.compactMap(\.id), value.presentation.lines.map(\.id))
            XCTAssertEqual(view.recipe?.rows.count, full ? 5 : 3)
            XCTAssertEqual(view.input?.presentation.overflow, full ? 2 : 4)
            XCTAssertEqual(view.input?.presentation.runningOverflow, full ? 1 : 3)
            XCTAssertNotNil(view.moreControl)
        }
    }
    func testKnownZeroUnknownStaleAndWrongConfigurationDoNotBorrowRates() async throws {
        let value = input([session("a", rate: 0), session("b", rate: 42, rateAge: 60), session("c", rate: 90, rateID: "other")])
        let texts = value.presentation.lines.map { RecordStripRowText(line: $0, identity: nil, language: .english) }
        XCTAssertEqual(texts.map(\.speed), ["0 t/s", "-- t/s", "-- t/s"])
        let done = input([session("done", working: false, rate: 99)]).presentation.lines[0]
        XCTAssertEqual(RecordStripRowText(line: done, identity: nil, language: .english).speed, "")
        XCTAssertNotNil(done.age)
    }
    func testRowKeyboardAndAXNavigationUseCanonicalReturnSource() async throws {
        let view = RecordStripView(); try view.configure(input([session("a")]))
        var nav = MainScreenNavigation(location: .init(.effort)), calls = 0
        view.onNavigate = { content, source in
            XCTAssertEqual(content, .session("a")); XCTAssertEqual(source, .record("a")); calls += 1
            nav.activate(content, from: source)
        }
        let control = try XCTUnwrap(view.control(for: "a"))
        control.keyDown(with: key("\r", code: 36)); XCTAssertEqual(nav.sourced?.returnTo.page, .effort)
        control.keyDown(with: key(" ", code: 49)); XCTAssertNil(nav.sourced)
        XCTAssertTrue(control.accessibilityPerformPress()); XCTAssertEqual(calls, 3)
        var returned = 0; view.onReturn = { returned += 1 }; control.keyDown(with: key("", code: 53)); XCTAssertEqual(returned, 1)
    }
    func testOverflowNavigatesToTimelineAndPreservesReturn() async throws {
        let view = RecordStripView(); try view.configure(input((0..<5).map { session("s\($0)") }))
        var nav = MainScreenNavigation(location: .init(.subscriptions))
        view.onNavigate = { content, source in nav.activate(content, from: source) }
        XCTAssertTrue(try XCTUnwrap(view.moreControl).accessibilityPerformPress())
        XCTAssertEqual(nav.location, .init(.destinations, destinationsMode: .timeline))
        XCTAssertEqual(nav.sourced?.source, .recordOverflow); nav.back(); XCTAssertEqual(nav.location.page, .subscriptions)
    }
    func testRefreshKeepsTargetsAndRemovesStaleActions() async throws {
        let view = RecordStripView(); try view.configure(input([session("a"), session("b")]))
        let a = try XCTUnwrap(view.control(for: "a")), b = try XCTUnwrap(view.control(for: "b"))
        try view.configure(input([session("a", rate: 29)])); XCTAssertTrue(view.control(for: "a") === a)
        XCTAssertNil(view.control(for: "b")); XCTAssertFalse(b.accessibilityPerformPress())
        try view.configure(input([])); XCTAssertNil(view.control(for: "a")); XCTAssertFalse(a.accessibilityPerformPress())
        try view.configure(input([session("a")])); XCTAssertTrue(try XCTUnwrap(view.control(for: "a")).accessibilityPerformPress())
    }
    func testRemovedTargetsStayRetiredAfterSameRowsAndOverflowReturn() async throws {
        try assertRetiredTargetsStayInert(stopAndResume:false)
    }
    func testStoppedTargetsStayRetiredAfterExplicitResume() async throws {
        try assertRetiredTargetsStayInert(stopAndResume:true)
    }
    func testReplacedNameAreasStayInertWhileTheirRowControlPersists() async throws {
        let view = RecordStripView();try view.configure(input([session("a")]))
        let row = try XCTUnwrap(view.control(for:"a")),oldNames = row.subviews
        var calls = 0;view.onNavigate = { _,_ in calls += 1 }
        try view.configure(input([session("a",rate:58)]));XCTAssertTrue(view.control(for:"a") === row)
        for name in oldNames { name.mouseDown(with:key("",code:0)) }
        XCTAssertEqual(calls,0)
        XCTAssertTrue(oldNames.allSatisfy{$0.toolTip==nil && $0.superview==nil})
        for name in row.subviews { name.mouseDown(with:key("",code:0)) }
        XCTAssertEqual(calls,2)
    }
    private func assertRetiredTargetsStayInert(stopAndResume:Bool) throws {
        let view = RecordStripView(),value = input((0..<4).map{session("s\($0)")})
        try view.configure(value)
        let oldRow = try XCTUnwrap(view.control(for:"s0")),oldMore = try XCTUnwrap(view.moreControl),oldNames = oldRow.subviews
        XCTAssertEqual(oldNames.count,2)
        var calls:[MainScreenSource] = [],returns = 0
        view.onNavigate = { _,source in calls.append(source) };view.onReturn = { returns += 1 }
        if stopAndResume { view.stop() } else { try view.configure(input([])) }
        try view.configure(value)
        if stopAndResume { view.setPresentationAllowed(true) }
        let recipe = view.recipe?.drawing
        for stale in [oldRow,oldMore] {
            XCTAssertFalse(stale.accessibilityPerformPress())
            stale.keyDown(with:key("\r",code:36));stale.keyDown(with:key(" ",code:49));stale.keyDown(with:key("",code:53))
            stale.mouseEntered(with:key("",code:0));stale.mouseExited(with:key("",code:0))
            XCTAssertFalse(stale.isEnabled);XCTAssertNil(stale.target);XCTAssertNil(stale.action)
        }
        for name in oldNames { name.mouseDown(with:key("",code:0)) }
        XCTAssertTrue(calls.isEmpty);XCTAssertEqual(returns,0);XCTAssertEqual(view.recipe?.drawing,recipe)
        XCTAssertTrue(oldNames.allSatisfy{$0.toolTip==nil && $0.superview==nil})
        let row = try XCTUnwrap(view.control(for:"s0")),more = try XCTUnwrap(view.moreControl)
        XCTAssertFalse(row === oldRow);XCTAssertFalse(more === oldMore)
        XCTAssertTrue(row.accessibilityPerformPress());row.keyDown(with:key("\r",code:36));row.keyDown(with:key(" ",code:49))
        for name in row.subviews { name.mouseDown(with:key("",code:0)) }
        XCTAssertEqual(calls,Array(repeating:.record("s0"),count:5))
        XCTAssertTrue(more.accessibilityPerformPress());more.keyDown(with:key("\r",code:36));more.keyDown(with:key(" ",code:49))
        XCTAssertEqual(Array(calls.suffix(3)),Array(repeating:.recordOverflow,count:3))
        row.keyDown(with:key("",code:53));XCTAssertEqual(returns,1)
    }
    func testExplicitPauseSurvivesEmptyRefreshAndHideDoesNotChangeCallerPermission() async throws {
        let view = RecordStripView(); try view.configure(input([session("a")]))
        view.setPresentationAllowed(false); try view.configure(input([])); try view.configure(input([session("a")]))
        let control = try XCTUnwrap(view.control(for: "a")); XCTAssertFalse(control.accessibilityPerformPress())
        view.setPresentationAllowed(true); view.isHidden = true; XCTAssertFalse(control.accessibilityPerformPress())
        view.isHidden = false; XCTAssertTrue(control.accessibilityPerformPress())
        view.stop(); XCTAssertFalse(control.accessibilityPerformPress()); try view.configure(input([session("a")]))
        XCTAssertFalse(try XCTUnwrap(view.control(for: "a")).accessibilityPerformPress())
    }
    func testPrivacyAndOnlyPermittedNameTooltips() async throws {
        let view = RecordStripView(), identity = RecordStripIdentity(fullToolName: "Claude Code", shortModelName: "M", fullModelName: "Long Model Name")
        try view.configure(input([session("a", rate: 58)], names: false, identities: ["a": identity, "hidden": identity]))
        let control = try XCTUnwrap(view.control(for: "a"))
        XCTAssertNil(control.toolTip); XCTAssertEqual(control.subviews.compactMap(\.toolTip), ["Claude Code"])
        XCTAssertFalse(control.accessibilityLabel()?.contains("Private Project") == true)
        XCTAssertTrue(control.accessibilityLabel()?.contains("Long Model Name") == true)
        XCTAssertEqual(Set(view.input!.identities.keys), ["a"])
        XCTAssertEqual(view.helpTargets().map(\.text), [InstrumentHelpDefinitions.liveSpeed(.english)])
        try view.configure(input([session("a")], identities: ["a": identity]))
        XCTAssertEqual(Set(control.subviews.compactMap(\.toolTip)), ["Claude Code", "Private Project"])
    }
    func testInvalidRecipeAndDensityFailAtomically() async throws {
        let provider = BreakingRecipe(), view = RecordStripView(provider: provider)
        try view.configure(input([session("a")])); let old = try XCTUnwrap(view.control(for: "a"))
        provider.broken = true
        XCTAssertThrowsError(try view.configure(input([session("b")]))); XCTAssertTrue(view.control(for: "a") === old)
        XCTAssertTrue(old.accessibilityPerformPress()); XCTAssertNil(view.control(for: "b"))
        let full = input((0..<5).map { session("s\($0)") }, full: true)
        XCTAssertThrowsError(try view.configure(.init(presentation: full.presentation, density: .compact, appearance: .init())))
    }
    func testStaticCursorHasNoAnimationAndPausesWithPresentation() async throws {
        let view = RecordStripView(); try view.configure(input([session("a")]))
        let box = try XCTUnwrap(view.recipe?.rows.first?.fields[.tool])
        try view.configure(input([session("a")], cursor: .init(recordID: "a", rect: CGRect(x: box.minX, y: box.minY + 2, width: 3, height: 10), visible: true)))
        let cursor = try XCTUnwrap(view.layer?.sublayers?.first)
        XCTAssertFalse(cursor.isHidden); XCTAssertTrue(cursor.animationKeys()?.isEmpty ?? true)
        view.setPresentationAllowed(false); XCTAssertTrue(cursor.isHidden)
        view.setPresentationAllowed(true); XCTAssertFalse(cursor.isHidden)
        view.stop(); XCTAssertTrue(cursor.isHidden)
    }
    func testOverflowHoverIsDistinctFromRecordIDAndClearsOnPause() async throws {
        let view = RecordStripView();try view.configure(input([session("more"),session("z1"),session("z2"),session("z3")]))
        func pixels() throws -> Data { try XCTUnwrap(try view.rasterImage(scale:1).dataProvider?.data) as Data }
        let before = try pixels(), more = try XCTUnwrap(view.moreControl)
        more.mouseEntered(with:key("",code:0));XCTAssertNotEqual(try pixels(),before)
        view.setPresentationAllowed(false);XCTAssertEqual(try pixels(),before)
        view.setPresentationAllowed(true);let row = try XCTUnwrap(view.control(for:"more"))
        row.mouseEntered(with:key("",code:0));XCTAssertNotEqual(try pixels(),before)
        row.mouseExited(with:key("",code:0));XCTAssertEqual(try pixels(),before)
    }
    func testHoverProviderCannotMoveNavigationTargetsOrPublishMissingResources() async throws {
        let provider = BreakingRecipe(),view = RecordStripView(provider:provider);try view.configure(input([session("a")]))
        let old = try XCTUnwrap(view.recipe),control = try XCTUnwrap(view.control(for:"a"));var failures = 0
        view.onRenderingFailure = { _ in failures += 1 }
        provider.moveOnHover = true;control.mouseEntered(with:key("",code:0))
        XCTAssertEqual(view.recipe?.rows,old.rows);XCTAssertEqual(failures,1)
        provider.moveOnHover = false;provider.missingOnHover = true;control.mouseEntered(with:key("",code:0))
        XCTAssertEqual(view.recipe?.drawing,old.drawing);XCTAssertEqual(failures,2)
        XCTAssertTrue(control.accessibilityPerformPress())
    }
    func testNeutralRasterIsCompleteInBothLanguagesThemesScalesAndDensities() async throws {
        let view = RecordStripView()
        for full in [false, true] { for dark in [false, true] { for language in [InstrumentLanguage.english, .chinese] {
            let value = input([session("a", rate: 58), session("b", working: false)], full: full, language: language)
            try view.configure(.init(presentation: value.presentation, density: value.density, appearance: .init(dark: dark, language: language)))
            for scale in [1, 2] {
                let image = try view.rasterImage(scale: scale)
                XCTAssertEqual(image.width, Int(view.bounds.width) * scale); XCTAssertEqual(image.height, Int(view.bounds.height) * scale)
                XCTAssertTrue(view.glyphMetrics.contains { $0.id == "record.a.speed" && $0.text == "58 t/s" })
            }
        } } }
    }
}
@MainActor private final class BreakingRecipe: RecordStripRecipeProvider {
    var broken = false,moveOnHover = false,missingOnHover = false
    private let neutral = NeutralRecordStripRecipe()
    func preferredSize(for density: RecordStripDensity) -> CGSize { neutral.preferredSize(for: density) }
    func font(_ request: EngineFontRequest) throws -> CTFont { try neutral.font(request) }
    func image(_ resourceID: String) throws -> CGImage { try neutral.image(resourceID) }
    func recipe(for input: RecordStripViewInput, size: CGSize, hover: RecordStripHover?) throws -> RecordStripRecipe {
        if broken { throw EngineTableError.invalidRecipe }
        let next = try neutral.recipe(for: input, size: size, hover: hover)
        if hover != nil && moveOnHover {
            let rows = next.rows.map { RecordStripRowLayout(id:$0.id,frame:$0.frame.offsetBy(dx:1,dy:0),fields:$0.fields.mapValues{$0.offsetBy(dx:1,dy:0)}) }
            return .init(drawing:next.drawing,rows:rows,more:next.more)
        }
        if hover != nil && missingOnHover {
            var drawing = next.drawing;drawing.commands.append(.image(resourceID:"missing",rect:CGRect(x:0,y:0,width:1,height:1),opacity:1))
            return .init(drawing:drawing,rows:next.rows,more:next.more)
        }
        return next
    }
}

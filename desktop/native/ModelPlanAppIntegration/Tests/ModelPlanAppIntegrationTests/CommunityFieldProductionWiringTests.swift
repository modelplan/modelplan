// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanCore
import ModelPlanField
import ModelPlanAssembly
import ModelPlanCockpitShell
@testable import ModelPlanAppIntegration

@MainActor private final class RecordingFieldWindow: CommunityFieldWindow {
    var shown = 0, hidden = 0
    func show(content: NSView, onClose: @escaping () -> Void) { shown += 1 }
    func hide() { hidden += 1 }
}
@MainActor final class CommunityFieldProductionWiringTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)
    private func publication(_ active: String = "a", revision: String = "r1") throws -> PublicPublication {
        let models: [[String: Any]] = ["a", "b"].map { id in
            ["id": id, "name": id, "developerId": "example", "lineageId": id, "lineageStatus": "current",
             "defaultSelected": id == active, "recommended": "high",
             "efforts": [["effort": "high", "label": "High", "available": false, "ability": 10, "cost": 2, "time": 3]]]
        }
        return try FeedDecoder.publication(JSONSerialization.data(withJSONObject: ["schemaVersion": 1,
            "publicationId": revision, "selectionRevision": revision,
            "units": ["ability": "websiteAbility", "cost": "usdPerReferenceTask", "time": "taskTimeCrossModel"],
            "models": models, "lineups": []]))
    }
    private func render(_ surface: CommunityInstrumentView, publication: PublicPublication?) {
        var assembly = SelectionAssembly()
        surface.render(publication: publication)
        surface.render(selection: assembly.evaluate(feeds: .init(publication: publication, personal: nil, personalUsable: false),
            scope: .all, now: now), publishedAt: now, now: now)
    }
    func testNormalEntryMountsCockpitAndPickerRatherThanLeavingOptInNil() async throws {
        let provider = CommunityApplicationFactory.makeSurfaces()
        let surface = try XCTUnwrap(provider.makeOverview() as? CommunityInstrumentView)
        defer { surface.dispose() }
        XCTAssertNotNil(surface.cockpitComposition, "Normal entry must mount the cockpit, not only the old MainScreen")
        let field = try XCTUnwrap(surface.cockpitComposition?.field, "Removing the actual factory field mount must fail")
        XCTAssertFalse(field.picker.isPresented)
        XCTAssertThrowsError(try field.open(), "A hidden or unfed factory must not open")
    }
    func testSameFactoryForwardsPublicFocusPersistsAndRestoresLatestScope() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let preferences = PreferenceFile(url: directory.appendingPathComponent("ui.json"))
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data(#"{"schemaVersion":1,"favouriteModelIDs":["a"]}"#.utf8).write(to: preferences.url)
        let window = RecordingFieldWindow()
        var scopes: [[String]] = []
        let neutral = CommunityCockpitSupply.neutral()
        let supply = CommunityCockpitSupply(skin: neutral.skin, frames: neutral.frames, still: { scope in
            scopes.append(scope.admittedPublicIDs); return nil
        })
        let provider = CommunityApplicationFactory.makeSurfaces(supply: supply, preferences: preferences, makeFieldWindow: { window })
        let surface = try XCTUnwrap(provider.makeOverview() as? CommunityInstrumentView)
        defer { surface.dispose() }
        render(surface, publication: try publication()); surface.resumePresentation()
        XCTAssertFalse(surface.renderFailure)
        let field = try XCTUnwrap(surface.cockpitComposition?.field)
        XCTAssertEqual(field.currentScope?.admittedPublicIDs, ["a"])
        XCTAssertEqual(field.currentScope?.projection.models.first?.efforts.first?.available, false, "Preserve the published nullable availability tuple without defaulting true")
        // Synthetic native lifecycle delivery: no App/Window/input is launched in this check.
        field.setPresented(true)
        try field.open(); XCTAssertEqual(window.shown, 1)
        field.picker.focus("b")
        XCTAssertEqual(field.focusedPublicID, "b", "The mounted production comparison must receive focus")
        XCTAssertEqual(field.enlargedProjection?.models.map(\.id), ["a", "b"])
        XCTAssertEqual(try preferences.load().favouriteModelIDs, ["a"], "The same existing preferences preserve other UI values")
        let saved = try XCTUnwrap(preferences.load().fieldPickerValue)
        XCTAssertEqual((try JSONSerialization.jsonObject(with: saved) as? [String: Any])?["ids"] as? [String], ["a", "b"])
        render(surface, publication: try publication("b", revision: "r2"))
        try field.close()
        XCTAssertEqual(scopes.last, ["b"], "Close uses current scope, never extra field models or an old capture")
        XCTAssertNil(field.enlargedProjection); XCTAssertNil(field.focusedPublicID)
        XCTAssertFalse(field.picker.isPresented)
        XCTAssertEqual(surface.requestedInstrumentScope, .all)
    }
    func testPersistenceFailureClosesTheActualProductionFieldAndRetryWorks() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let blocker = directory.appendingPathComponent("blocker")
        try Data().write(to: blocker)
        let window = RecordingFieldWindow()
        let preferences = PreferenceFile(url: blocker.appendingPathComponent("ui.json"))
        let provider = CommunityApplicationFactory.makeSurfaces(preferences: preferences, makeFieldWindow: { window })
        let surface = try XCTUnwrap(provider.makeOverview() as? CommunityInstrumentView)
        defer { surface.dispose() }
        render(surface, publication: try publication()); surface.resumePresentation()
        let field = try XCTUnwrap(surface.cockpitComposition?.field)
        field.setPresented(true); try field.open(); field.picker.focus("b")
        XCTAssertNotNil(field.binding.lastError)
        XCTAssertNil(field.enlargedProjection); XCTAssertFalse(field.picker.isPresented)
        XCTAssertGreaterThan(window.hidden, 0)
        try FileManager.default.removeItem(at: blocker)
        field.setPresented(true); try field.open(); field.picker.focus("b")
        XCTAssertNil(field.binding.lastError); XCTAssertEqual(field.focusedPublicID, "b")
        surface.suspendPresentation()
        XCTAssertNil(field.enlargedProjection); XCTAssertFalse(field.picker.isPresented)
        XCTAssertThrowsError(try field.open())
    }
    func testRealCockpitInputUsesVerifiedQuotaAndKeepsMonthlyOutOfUpperRows() async throws {
        let date = ISO8601DateFormatter()
        let raw: [String: Any] = ["schemaVersion": 1, "kind": "modelplan.personal-snapshot", "generatedAt": date.string(from: now),
            "validUntil": date.string(from: now.addingTimeInterval(600)), "accounts": [
                ["source": "cursor", "plan": "Cursor", "observedAt": date.string(from: now),
                 "subscription": ["subscriptionRef": "verified", "status": "verified"],
                 "windows": [["kind": "monthly", "windowMinutes": 43200, "remainingPercent": 60]]],
                ["source": "unknown", "windows": [["kind": "5h", "windowMinutes": 300, "remainingPercent": 90]]]
            ]]
        let personal = try FeedDecoder.personal(JSONSerialization.data(withJSONObject: raw))
        var ledger = ExpiryLedger()
        let projection = PersonalProjection.evaluate(personal, now: now, ledger: &ledger)
        let provider = CommunityApplicationFactory.makeSurfaces()
        let surface = try XCTUnwrap(provider.makeOverview() as? CommunityInstrumentView)
        defer { surface.dispose() }
        surface.render(snapshot: .make(personal: personal, presentation: projection, publication: nil), diagnostics: .init())
        render(surface, publication: try publication()); surface.resumePresentation()
        let input = try XCTUnwrap(surface.cockpitComposition?.surface.input)
        XCTAssertEqual(input.columns.map(\.id), ["verified"])
        let column = try XCTUnwrap(input.columns.first)
        XCTAssertNil(column.quotas.fiveHours); XCTAssertNil(column.quotas.weekly)
        XCTAssertEqual(column.quotas.other.first?.remaining, 60)
        XCTAssertNil(column.todayTokens, "Do not copy source-wide usage into a subscription")
    }
    func testSuspensionHidesOwnedPanelEvenWhenScopeSupplierFails() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let neutral = CommunityCockpitSupply.neutral(), window = RecordingFieldWindow()
        var failStill = false
        let supply = CommunityCockpitSupply(skin: neutral.skin, frames: neutral.frames, still: { _ in
            if failStill { throw FieldPickerConnectionError.disconnected }; return nil
        })
        let provider = CommunityApplicationFactory.makeSurfaces(supply: supply,
            preferences: PreferenceFile(url: directory.appendingPathComponent("ui.json")), makeFieldWindow: { window })
        let surface = try XCTUnwrap(provider.makeOverview() as? CommunityInstrumentView)
        defer { surface.dispose() }
        render(surface, publication: try publication()); surface.resumePresentation()
        let field = try XCTUnwrap(surface.cockpitComposition?.field)
        field.setPresented(true); try field.open()
        let hides = window.hidden; failStill = true
        field.setPresented(false)
        XCTAssertGreaterThan(window.hidden, hides, "Suspension must hide the actual owned panel despite recovery failure")
        XCTAssertNotNil(field.binding.recoveryError)
        XCTAssertThrowsError(try field.open(), "Hidden retry controls cannot reopen the field")
        failStill = false; field.setPresented(true); try field.open()
        XCTAssertNil(field.binding.lastError)
    }
    func testMissingSupplierPortFailsActualFactoryAndCannotClaimConnected() async throws {
        let neutral = CommunityCockpitSupply.neutral()
        let supply = CommunityCockpitSupply(skin: neutral.skin, frames: { _ in throw FieldPickerConnectionError.disconnected }, still: neutral.still)
        let provider = CommunityApplicationFactory.makeSurfaces(supply: supply, makeFieldWindow: { RecordingFieldWindow() })
        let surface = try XCTUnwrap(provider.makeOverview() as? CommunityInstrumentView)
        defer { surface.dispose() }
        render(surface, publication: try publication()); surface.resumePresentation()
        XCTAssertTrue(surface.renderFailure, "Disconnected real factory ports must fail, not silently fall back")
    }
}

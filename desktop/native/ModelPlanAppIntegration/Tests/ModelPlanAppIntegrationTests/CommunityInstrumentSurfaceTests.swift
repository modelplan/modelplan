// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanAssembly
import ModelPlanCore
import ModelPlanInstruments
import ModelPlanCommunityHost
import ModelPlanSettings
@testable import ModelPlanAppIntegration

@MainActor final class CommunityInstrumentSurfaceTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)
    private func selection(_ ids: [String] = ["first", "second"], language: InstrumentLanguage = .chinese,
                           revision: String? = "r") throws -> AssembledModelSelection {
        var object: [String: Any] = ["schemaVersion": 1, "publicationId": "p",
            "units": ["ability": "websiteAbility", "cost": "usdPerReferenceTask", "time": "taskTimeCrossModel"],
            "models": ids.map { ["id": $0, "name": $0, "developerId": "dev", "lineageId": "line-" + $0,
                                 "lineageStatus": "current", "defaultSelected": true] as [String: Any] }, "lineups": []]
        if let revision { object["selectionRevision"] = revision }
        let publication = try FeedDecoder.publication(JSONSerialization.data(withJSONObject: object))
        var assembly = SelectionAssembly()
        return assembly.evaluate(feeds: .init(publication: publication, personal: nil, personalUsable: false),
                                 scope: .all, language: language, now: now)
    }
    private func application(_ apply: @escaping (SettingsApplication) -> Void) throws -> SettingsApplicationCoordinator {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("community-instruments-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return SettingsApplicationCoordinator(store: try SettingsStore(url: directory.appendingPathComponent("prefs.json")), apply: apply)
    }
    func testActualProviderUsesExistingNativeViewAndPausesRasterWhileHidden() throws {
        let provider = CommunityInstrumentSurfaceProvider()
        let surface = try XCTUnwrap(provider.makeOverview() as? CommunityInstrumentView)
        XCTAssertTrue(provider.makeOverview() === surface)
        surface.render(selection: try selection(), publishedAt: now.addingTimeInterval(-120), now: now)
        XCTAssertEqual(surface.mainScreen.surfaceRenders, 0)
        surface.resumePresentation()
        XCTAssertEqual(surface.orderedModelIDs, ["first", "second"])
        XCTAssertNotNil(surface.mainScreen.recipe); XCTAssertFalse(surface.renderFailure)
        XCTAssertGreaterThan(surface.preferredContentSize.width, 440); XCTAssertGreaterThan(surface.preferredContentSize.height, 210)
        let count = surface.mainScreen.surfaceRenders
        surface.suspendPresentation(); surface.render(selection: try selection(["replacement"]), publishedAt: nil, now: now)
        XCTAssertEqual(surface.mainScreen.surfaceRenders, count)
        surface.resumePresentation(); XCTAssertEqual(surface.orderedModelIDs, ["replacement"])
        surface.dispose()
    }
    func testSettingsApplicationReevaluatesCurrentFeedAndRejectsOldRevision() async throws {
        let provider = CommunityInstrumentSurfaceProvider(), surface = try XCTUnwrap(provider.makeOverview() as? CommunityInstrumentView)
        var packets: [SettingsApplication] = [], requests = 0
        let app = try application { packets.append($0); provider.apply($0) }; await app.reload()
        surface.requestFreshSelection = { requests += 1; surface.render(selection: try! self.selection(language: surface.instrumentLanguage), publishedAt: nil, now: self.now) }
        surface.resumePresentation()
        _ = try await app.commit(.theme(.night)); let old = try XCTUnwrap(packets.last)
        _ = try await app.commit(.theme(.day)); provider.apply(old)
        XCTAssertEqual(surface.mainScreen.appearance?.name, .aqua); XCTAssertGreaterThan(requests, 1)
        _ = try await app.commit(.theme(.system)); XCTAssertNil(surface.mainScreen.appearance)
        _ = try await app.editor.commit(SettingsB21Edit.language(.english))
        XCTAssertEqual(surface.instrumentLanguage, .english); XCTAssertEqual(surface.mainScreen.presentation?.language, .english)
        XCTAssertNil(surface.mainScreen.window); surface.dispose()
    }
    func testMissingExactRevisionDoesNotErasePublicCatalogue() throws {
        let surface = CommunityInstrumentView(), packet = try selection(revision: nil)
        surface.render(selection: packet, publishedAt: nil, now: now); surface.resumePresentation()
        XCTAssertEqual(surface.orderedModelIDs, packet.shared.orderedIDs)
        XCTAssertFalse(surface.orderedModelIDs.isEmpty)
        surface.selectModel("first")
        XCTAssertEqual(surface.selectedModelID, "first")
        XCTAssertNotNil(surface.mainScreen.presentation); XCTAssertFalse(surface.renderFailure)
        XCTAssertEqual(surface.mainScreen.presentation?.displayedPage, .effort)
        surface.dispose()
    }
    func testNoPublicationReplacesOldCatalogueWithExplicitUnavailableFacts() throws {
        let surface = CommunityInstrumentView()
        surface.render(selection: try selection(), publishedAt: now, now: now); surface.resumePresentation()
        var assembly = SelectionAssembly()
        let empty = assembly.evaluate(feeds: .init(publication: nil, personal: nil, personalUsable: false), scope: .all, now: now)
        surface.render(selection: empty, publishedAt: nil, now: now)
        XCTAssertTrue(surface.orderedModelIDs.isEmpty); XCTAssertFalse(surface.modelPicker.isEnabled)
        XCTAssertTrue(surface.mainScreen.controller.pages.flatMap(\.lines).contains(empty.emptyStateMessage))
        XCTAssertNil(surface.mainScreen.controller.trial); surface.dispose()
    }
    func testSelectionRefreshCannotActivateModelRemovedByCurrentFeeds() throws {
        let surface = CommunityInstrumentView()
        surface.render(selection: try selection(), publishedAt: nil, now: now); surface.resumePresentation()
        surface.requestFreshSelection = { surface.render(selection: try! self.selection(["second"]), publishedAt: nil, now: self.now) }
        surface.selectModel("first")
        XCTAssertNil(surface.selectedModelID); XCTAssertEqual(surface.orderedModelIDs, ["second"])
        surface.dispose()
    }
    func testUnrenderableInputHidesOldBitmapAndControlsInsteadOfLeavingStaleComparison() throws {
        let surface = CommunityInstrumentView()
        surface.render(selection: try selection(), publishedAt: nil, now: now); surface.resumePresentation()
        let huge = String(repeating: "wide", count: 1000)
        surface.render(selection: try selection([huge]), publishedAt: nil, now: now)
        surface.selectModel(huge)
        XCTAssertTrue(surface.renderFailure); XCTAssertTrue(surface.mainScreen.isHidden)
        XCTAssertNil(surface.mainScreen.recipe); XCTAssertFalse(surface.modelPicker.isEnabled)
        surface.dispose()
    }
    func testReentrantSizingCallbackCoalescesTheNewLanguageRatherThanLosingIt() async throws {
        let provider = CommunityInstrumentSurfaceProvider(), surface = try XCTUnwrap(provider.makeOverview() as? CommunityInstrumentView)
        var english: SettingsApplication?
        let source = try application { if $0.effective.language == .english { english = $0 } }
        await source.reload(); _ = try await source.editor.commit(SettingsB21Edit.language(.english))
        let long = String(repeating: "model", count: 20)
        var resized = false
        surface.requestFreshSelection = { surface.render(selection: try! self.selection([long], language: surface.instrumentLanguage), publishedAt: nil, now: self.now) }
        surface.contentSizeChanged = {
            resized = true; surface.contentSizeChanged = nil
            provider.apply(english!)
        }
        surface.resumePresentation()
        surface.selectModel(long)
        XCTAssertTrue(resized)
        XCTAssertEqual(surface.instrumentLanguage, .english)
        XCTAssertEqual(surface.mainScreen.presentation?.language, .english)
        XCTAssertFalse(surface.renderFailure)
        surface.dispose()
    }
    func testPublicationAgeUsesOnlyActualPublishedInstantAndRejectsFutureStamp() {
        XCTAssertNil(PublicationSourceStamp(publishedAt: nil, observedAt: now).age)
        XCTAssertNil(PublicationSourceStamp(publishedAt: now.addingTimeInterval(1), observedAt: now).age)
        XCTAssertEqual(PublicationSourceStamp(publishedAt: now.addingTimeInterval(-120), observedAt: now).age, 120)
    }
    func testDockSizeDoesNotChangeTheIndependentMainScreenProfile() async throws {
        let provider = CommunityInstrumentSurfaceProvider(), surface = try XCTUnwrap(provider.makeOverview() as? CommunityInstrumentView)
        let app = try application { provider.apply($0) }; await app.reload()
        surface.requestFreshSelection = { surface.render(selection: try! self.selection(language: surface.instrumentLanguage), publishedAt: nil, now: self.now) }
        surface.resumePresentation(); let original = surface.preferredContentSize
        _ = try await app.commit(.size(.small)); XCTAssertEqual(surface.preferredContentSize, original)
        _ = try await app.commit(.size(.large)); XCTAssertEqual(surface.preferredContentSize, original)
        XCTAssertFalse(surface.mainScreen.presentation?.compact ?? true)
        surface.dispose()
    }
}

// SPDX-License-Identifier: MIT
import XCTest
import ModelPlanCore
import ModelPlanDock
import ModelPlanSettings
import ModelPlanCommunityHost
@testable import ModelPlanAppIntegration

@MainActor final class SubscriptionCatalogueOwnershipTests: XCTestCase {
    private final class DockCatalogue: CommunityDockSettingsRouting {
        var onPlacementObserved: ((DockEdgePlacement?, Bool) -> Void)?
        var commitDisplayPlacement: ((String, SettingsDockEdge, Double) -> Void)?
        var displayChoicesChanged: (([SettingsDisplayChoice]) -> Void)?
        var catalogueChanged: (([SettingsSubscription]) -> Void)?
        func publish(_ rows: [SettingsSubscription]) { catalogueChanged?(rows) }
    }
    private final class Consent: CommunityConsentCommandPort {
        var object = try! GeneratedAppCLIFixtures.object("consented-consent.json")
        var availability: SettingsConnectionAvailability { .init(canInspect: true, canGrant: true, canForget: true) }
        var reads = 0
        func readCanonicalConsent() async throws -> ConsentPreview {
            reads += 1
            return try FeedDecoder.consentPreview(JSONSerialization.data(withJSONObject: object))
        }
        func applyConsentJSON(_ payload: Data) async throws { XCTFail("No mutation in catalogue checks") }
        func advance() { object["generation"] = (object["generation"] as? UInt64 ?? 1) + 1 }
    }
    private actor NoReader: CLITransport {
        func execute(_ command: CLICommand) async throws -> CommandResult { XCTFail("No helper/reader in catalogue checks"); throw TransportError.launchFailed }
    }
    private func composition() throws -> (SettingsApplicationCoordinator, CommunityConnectionIntegration, DockCatalogue, Consent) {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("subscription-catalogue-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        let app = SettingsApplicationCoordinator(store: try SettingsStore(url: folder.appendingPathComponent("settings.json")), apply: { _ in })
        let consent = Consent(), transport = NoReader(), dock = DockCatalogue()
        let backend = CommunityConnectionBackend(port: consent, desktop: .init(readOnly: transport, normal: transport))
        let base = CommunitySettingsSession(application: app, canPresent: { false }, environment: { .init() }, activate: { XCTFail("No activation") })
        let entry = try CommunityApplicationFactory.connectSettings(base: base, application: app, backend: backend, placementSource: dock, canPresent: { false })
        try CommunityConnectionWiring.requireInstalled(entry, application: app, backend: backend)
        return (app, entry, dock, consent)
    }
    private var inventory: [SettingsSubscription] { [.init(id: "sub-a", name: .init("Synthetic plan", "合成方案"), source: .fresh)] }
    private func values(_ app: SettingsApplicationCoordinator, _ key: SettingKey) throws -> [SubscriptionRowValue] {
        let preferences = try XCTUnwrap(app.editor.snapshot?.preferences)
        let row = try XCTUnwrap(try SettingsCatalogue.rows(preferences: preferences, context: app.editor.context, paneID: "subscriptions").first { $0.key == key })
        guard case .subscriptions(let rows) = row.value else { XCTFail("Expected actual subscription controls"); return [] }
        return rows
    }
    func testDockInventoryArrivingBeforeCanonicalRestoreSurvivesInActualSettingsRows() async throws {
        let (app, entry, dock, consent) = try composition(); defer { entry.flow.dispose() }
        dock.publish(inventory)
        await entry.restorePreferences()
        XCTAssertEqual(consent.reads, 1)
        XCTAssertEqual(app.editor.context.subscriptions.map(\.id), ["sub-a"])
        XCTAssertEqual(try values(app, .visible).map(\.id), ["sub-a"])
        XCTAssertTrue(app.editor.connections.snapshot?.subscriptions.isEmpty == true, "Consent does not invent membership")
    }
    func testNewConsentGenerationCannotEraseCatalogueOrItsSavedChoices() async throws {
        let (app, entry, dock, consent) = try composition(); defer { entry.flow.dispose() }
        await entry.restorePreferences(); dock.publish(inventory)
        try await app.editor.commit(.visible("sub-a", false))
        var alias = AliasDraft(subscriptionID: "sub-a", committed: "")
        alias.input("Work", composing: false); try await app.editor.commit(.alias(alias))
        consent.advance(); await app.editor.connections.refresh()
        XCTAssertEqual(consent.reads, 2)
        XCTAssertEqual(app.editor.context.subscriptions.map(\.id), ["sub-a"])
        XCTAssertEqual(try values(app, .visible).first?.value, "false")
        XCTAssertEqual(try values(app, .alias).first?.value, "Work")
        XCTAssertEqual(app.editor.context.subscriptions.first?.source, .fresh)
    }
    func testAuthoritativeDockEmptyCatalogueStillRemovesRows() async throws {
        let (app, entry, dock, _) = try composition(); defer { entry.flow.dispose() }
        await entry.restorePreferences(); dock.publish(inventory)
        XCTAssertEqual(try values(app, .visible).count, 1)
        dock.publish([])
        XCTAssertTrue(app.editor.context.subscriptions.isEmpty)
        XCTAssertTrue(try values(app, .visible).isEmpty)
    }
}

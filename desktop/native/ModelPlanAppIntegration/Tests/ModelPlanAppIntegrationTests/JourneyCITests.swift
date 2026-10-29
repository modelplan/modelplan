// SPDX-License-Identifier: MIT
#if DEBUG && MODELPLAN_E2E_JOURNEY
import AppKit
import Darwin
import XCTest
import ModelPlanCore
import ModelPlanSettings
@testable import ModelPlanCommunityHost
@testable import ModelPlanAppIntegration

@MainActor final class JourneyCITests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private actor Desktop: CLITransport, ConsentJSONTransport {
        func execute(_ command: CLICommand) async throws -> CommandResult { throw TransportError.launchFailed }
        func readConsentJSON() async throws -> CommandResult { throw TransportError.launchFailed }
        func grantConsentJSON(_ payload: Data) async throws -> CommandResult { throw TransportError.launchFailed }
    }
    private final class Port: CommunityConsentCommandPort {
        func readCanonicalConsent() async throws -> ConsentPreview { throw SettingsConnectionFailure.unavailable }
        func applyConsentJSON(_ payload: Data) async throws { XCTFail("No consent mutation in observation tests") }
    }
    private final class Surface: SettingsWindowSurface {
        var presentations = 0
        func prepare() async {}
        func show(paneID: String?) { presentations += 1 }
        func hide() {}
    }
    private actor CanonicalTransport: ConsentJSONTransport {
        let data: Data
        init(_ data: Data) { self.data = data }
        func readConsentJSON() async throws -> CommandResult { .init(exitCode: 0, stdout: data) }
        func grantConsentJSON(_ payload: Data) async throws -> CommandResult { throw TransportError.launchFailed }
    }
    private actor RefreshTransport: CLITransport {
        private var count = 0
        func execute(_ command: CLICommand) async throws -> CommandResult {
            count += 1
            return .init(exitCode: count == 1 ? 1 : 0, stdout: Data())
        }
    }
    private func flags() -> () -> Void {
        let keys = ["MODELPLAN_APP_SMOKE", "MODELPLAN_E2E_JOURNEY", "MODELPLAN_E2E_NATIVE_PANELS"]
        let old = keys.map { ProcessInfo.processInfo.environment[$0] }
        keys.forEach { setenv($0, "1", 1) }
        setenv("MODELPLAN_E2E_NATIVE_PANELS", "0", 1)
        return { for (key, value) in zip(keys, old) {
            if let value { setenv(key, value, 1) } else { unsetenv(key) }
        } }
    }
    private func store() throws -> SettingsStore {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("journey-observation-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return try SettingsStore(url: root.appendingPathComponent("settings.json"))
    }
    private func snapshot(source: String = "codex", remaining: Double? = 37, extras: [String: Any] = [:]) throws -> JoinedSnapshot {
        let iso = ISO8601DateFormatter()
        var account: [String: Any] = ["source": source, "observedAt": iso.string(from: now.addingTimeInterval(-5))]
        if let remaining {
            account["windows"] = [["kind": "five_hour", "remainingPercent": remaining,
                "observedAt": iso.string(from: now.addingTimeInterval(-5)),
                "resetsAt": iso.string(from: now.addingTimeInterval(900)), "windowMinutes": 300]]
        } else { account["windows"] = []; account["stale"] = true }
        var sourceStatus: [String: Any] = ["source": "native:codex", "status": remaining == nil ? "unavailable" : "ok"]
        if remaining == nil { sourceStatus["reason"] = "parse_error" }
        var object: [String: Any] = ["schemaVersion": 1, "kind": "modelplan.personal-snapshot",
            "generatedAt": iso.string(from: now.addingTimeInterval(-10)),
            "validUntil": iso.string(from: now.addingTimeInterval(300)), "accounts": [account],
            "sources": [sourceStatus]]
        for (key, value) in extras { object[key] = value }
        let personal = try FeedDecoder.personal(JSONSerialization.data(withJSONObject: object))
        var ledger = ExpiryLedger()
        return .make(personal: personal, presentation: PersonalProjection.evaluate(personal, now: now, ledger: &ledger), publication: nil)
    }
    private func render(_ host: StaticDockPreviewHost, _ value: JoinedSnapshot) {
        var diagnostics = StoreDiagnostics(); diagnostics.personal = nil
        host.render(snapshot: value, diagnostics: diagnostics)
    }
    func testBothRuntimeFlagsGateEveryObservationAndCardDriver() async throws {
        _ = NSApplication.shared
        let restore = flags(); defer { restore() }
        let host = StaticDockPreviewHost(currentDate: { self.now }, createsNativePanels: false)
        defer { host.close() }
        let app = SettingsApplicationCoordinator(store: try store()) { host.apply($0) }
        await app.reload(); render(host, try snapshot()); host.setPresentationAllowed(true)
        XCTAssertNotNil(host.journeySnapshot); XCTAssertNotNil(host.journeyFeedGeneratedAt)
        XCTAssertEqual(host.journeyRows.count, 1); XCTAssertFalse(host.journeyReasonRows.isEmpty)
        let canonical = try JSONSerialization.data(withJSONObject: GeneratedAppCLIFixtures.object("consented-consent.json"))
        let port = CommunityCLIConsentPort(transport: CanonicalTransport(canonical), apiAvailable: true)
        _ = try await port.readCanonicalConsent()
        XCTAssertNotNil(port.journeyReadStatus)
        XCTAssertNotNil(port.journeyAllowedTools)
        XCTAssertTrue(host.journeyOpenCard(at: 0)); XCTAssertNotNil(host.journeyCardAge)
        XCTAssertNotNil(host.journeyCardGuidance)
        setenv("MODELPLAN_E2E_NATIVE_PANELS", "1", 1)
        XCTAssertTrue(CommunityJourneyCI.nativePanels)
        for missing in ["MODELPLAN_APP_SMOKE", "MODELPLAN_E2E_JOURNEY"] {
            unsetenv(missing)
            XCTAssertFalse(CommunityJourneyCI.enabled)
            XCTAssertFalse(CommunityJourneyCI.nativePanels)
            XCTAssertNil(host.journeySnapshot); XCTAssertNil(host.journeyFeedGeneratedAt)
            XCTAssertTrue(host.journeyRows.isEmpty); XCTAssertTrue(host.journeyReasonRows.isEmpty)
            XCTAssertTrue(host.journeyGrokFirstFailure.isEmpty); XCTAssertNil(host.journeyCardAge)
            XCTAssertNil(host.journeyNativePanelsEnabled); XCTAssertNil(host.journeyCardGuidance)
            XCTAssertTrue(host.journeyToolState("claude").isEmpty)
            XCTAssertNil(port.journeyReadStatus); XCTAssertNil(port.journeyAllowedTools)
            XCTAssertFalse(host.journeyOpenCard(at: 0)); XCTAssertFalse(host.journeyPressCardEnter())
            host.journeyDismissCard()
            setenv(missing, "1", 1)
            XCTAssertNotNil(host.journeyCardAge, "A disabled driver must not dismiss the retained card")
        }
        XCTAssertEqual(host.journeyRows.count, 1, "Flags gate observations without changing the retained model")
    }
    func testNativeFactoryAndRefreshObservationRequireRealRuntimeFlags() async throws {
        let restore = flags(); defer { restore() }
        XCTAssertFalse(CommunityJourneyCI.nativePanels)
        setenv("MODELPLAN_E2E_NATIVE_PANELS", "1", 1)
        XCTAssertTrue(CommunityJourneyCI.nativePanels)
        let host = ProductionDockFactory.community()
        defer { host.close() }
        XCTAssertEqual(host.journeyNativePanelsEnabled, true)
        XCTAssertNil(host.nativePanel, "Construction alone does not order a native panel")
        let fake = RefreshTransport(), gate = ConsentGatedDesktopTransport(readOnly: fake, normal: fake)
        _ = try await gate.execute(.refreshAccount)
        _ = try await gate.execute(.refreshAccount)
        let observation = await gate.journeyAccountRefresh
        XCTAssertEqual(observation?.attempts, 2); XCTAssertEqual(observation?.successes, 1)
        XCTAssertNotNil(observation?.lastSuccessAt)
        for missing in ["MODELPLAN_APP_SMOKE", "MODELPLAN_E2E_JOURNEY"] {
            unsetenv(missing)
            let disabled = await gate.journeyAccountRefresh
            XCTAssertNil(disabled); XCTAssertFalse(CommunityJourneyCI.nativePanels)
            setenv(missing, "1", 1)
        }
    }
    func testH38ObserversKeepActualPendingKeychainAndMissingKeyShapes() async throws {
        _ = NSApplication.shared
        let restore = flags(); defer { restore() }
        let host = StaticDockPreviewHost(currentDate: { self.now }, createsNativePanels: false)
        defer { host.close() }
        let app = SettingsApplicationCoordinator(store: try store()) { host.apply($0) }
        await app.reload()
        render(host, try snapshot(extras: ["accounts": [], "sources": [],
            "connections": [["id": "codex", "quota": ["status": "no", "reason": "no-reading"]]]]))
        XCTAssertEqual(host.journeyToolState("codex")["connectionNoReading"] as? Bool, true)
        render(host, try snapshot(extras: ["accounts": [],
            "sources": [["source": "native:claude", "status": "consent_required"]],
            "connections": [["id": "claude-code", "quota": ["status": "no", "reason": "keychain_choice_needed"]]]]))
        XCTAssertEqual(host.journeyToolState("claude")["nativeConsentRequired"] as? Bool, true)
        XCTAssertEqual(host.journeyToolState("claude")["keychainChoiceNeeded"] as? Bool, true)
        let reason = "Z_AI_API_KEY is not set where modelplan runs"
        render(host, try snapshot(extras: ["accounts": [], "connections": [],
            "sources": [["source": "native:zai", "status": "missing", "reason": reason]]]))
        XCTAssertEqual(host.journeyToolState("zai")["cliReason"] as? String, reason)
        render(host, try snapshot(extras: ["sources": [["source": "native:zai", "status": "missing", "reason": "unexported-fixture-text"]]]))
        XCTAssertEqual(host.journeyToolState("zai")["cliReason"] as? String, "")
        XCTAssertTrue(host.journeyToolState("unknown").isEmpty)
    }
    func testRenderedValueKeepsActualAccountAssociationWithoutInventingMembership() async throws {
        _ = NSApplication.shared
        let restore = flags(); defer { restore() }
        let host = StaticDockPreviewHost(currentDate: { self.now }, createsNativePanels: false)
        defer { host.close() }
        let app = SettingsApplicationCoordinator(store: try store()) { host.apply($0) }
        await app.reload(); render(host, try snapshot())
        let row = try XCTUnwrap(host.journeyRows.first)
        XCTAssertEqual(row["provider"] as? String, "codex")
        XCTAssertEqual(row["accountAssociated"] as? Bool, true)
        XCTAssertEqual(row["readout"] as? String, "37%")
        XCTAssertEqual(row["hasSubscription"] as? Bool, false)
        XCTAssertTrue(host.journeySnapshot?.subscriptions.isEmpty == true)
        render(host, try snapshot(source: "other"))
        XCTAssertFalse(host.journeyRows.contains { $0["accountAssociated"] as? Bool == true })
        render(host, try snapshot(source: "native:grok"))
        XCTAssertEqual(host.journeyRows.first?["providers"] as? [String], ["grok"])
    }
    func testNativeOnlyFirstFailureObservationDoesNotInventAccountOrConnection() async throws {
        _ = NSApplication.shared
        let restore = flags(); defer { restore() }
        let host = StaticDockPreviewHost(currentDate: { self.now }, createsNativePanels: false)
        defer { host.close() }
        let app = SettingsApplicationCoordinator(store: try store()) { host.apply($0) }
        await app.reload()
        let iso = ISO8601DateFormatter()
        let object: [String: Any] = ["schemaVersion": 1, "kind": "modelplan.personal-snapshot",
            "generatedAt": iso.string(from: now), "validUntil": iso.string(from: now.addingTimeInterval(300)),
            "accounts": [], "connections": [], "sources": [["source": "native:grok", "status": "unavailable", "reason": "parse_error"]]]
        let personal = try FeedDecoder.personal(JSONSerialization.data(withJSONObject: object))
        var ledger = ExpiryLedger()
        render(host, .make(personal: personal, presentation: PersonalProjection.evaluate(personal, now: now, ledger: &ledger), publication: nil))
        XCTAssertEqual(host.journeyGrokFirstFailure["nativeErrorObserved"] as? Bool, true)
        XCTAssertEqual(host.journeyGrokFirstFailure["accountCount"] as? Int, 0)
        XCTAssertEqual(host.journeyGrokFirstFailure["connectionCount"] as? Int, 0)
        render(host, try snapshot())
        XCTAssertEqual(host.journeyGrokFirstFailure["nativeErrorObserved"] as? Bool, false)
    }
    func testUnreadableCardMustReachRetainedSettingsAndBrokenRoutesCannotQualify() async throws {
        _ = NSApplication.shared
        let restore = flags(); defer { restore() }
        for failure in ["none", "onEnter", "disabledSettings"] {
            let host = StaticDockPreviewHost(currentDate: { self.now }, createsNativePanels: false)
            let app = SettingsApplicationCoordinator(store: try store()) { host.apply($0) }
            let desktop = Desktop(), firstRun = Surface()
            let lifecycle = LifecycleCoordinator(store: SnapshotStore(transport: desktop))
            lifecycle.start()
            let backend = CommunityConnectionBackend(port: Port(), desktop: .init(readOnly: desktop, normal: desktop))
            let base = CommunitySettingsSession(application: app, canPresent: { lifecycle.canPresent }, activate: {})
            let entry = try CommunityApplicationFactory.connectSettings(base: base, application: app, backend: backend,
                canPresent: { lifecycle.canPresent }, makeFirstRun: { editor in
                    XCTAssertTrue(editor === app.editor); return firstRun
                })
            let delegate = CommunityApplicationFactory.makeDelegate(surfaces: CommunityInstrumentSurfaceProvider(), companion: host,
                consentBackend: backend) { _ in entry }
            _ = delegate.configureSettings(lifecycle)
            delegate.configureCompanion(lifecycle)
            await entry.restorePreferences()
            render(host, try snapshot(remaining: nil))
            let row = try XCTUnwrap(host.journeyRows.first)
            XCTAssertFalse((row["reason"] as? String ?? "").isEmpty)
            XCTAssertTrue(host.journeyOpenCard(at: try XCTUnwrap(row["rowIndex"] as? Int)))
            let before = firstRun.presentations
            if failure == "onEnter" { host.card.onEnter = nil }
            if failure == "disabledSettings" { entry.settingsMenuItem.isEnabled = false }
            XCTAssertTrue(host.journeyPressCardEnter())
            for _ in 0..<100 where firstRun.presentations == before { try await Task.sleep(nanoseconds: 5_000_000) }
            XCTAssertEqual(firstRun.presentations > before, failure == "none", failure)
            XCTAssertTrue((delegate.settingsIntegration as? CommunityConnectionIntegration)?.flow.application === app)
            await lifecycle.stop(); entry.flow.dispose(); host.close()
            withExtendedLifetime(delegate) {}
        }
    }
}
#endif

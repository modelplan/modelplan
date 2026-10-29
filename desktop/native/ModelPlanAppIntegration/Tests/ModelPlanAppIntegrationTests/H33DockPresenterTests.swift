// SPDX-License-Identifier: MIT
import Foundation
import AppKit
import XCTest
import ModelPlanCore
import ModelPlanSettings
@testable import ModelPlanAppIntegration

@MainActor final class H33DockPresenterTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private func snapshot(accounts: [[String: Any]] = [], connections: [[String: Any]] = [], sources: [[String: Any]] = []) throws -> JoinedSnapshot {
        let iso = ISO8601DateFormatter()
        let object: [String: Any] = ["schemaVersion": 1, "kind": "modelplan.personal-snapshot",
            "generatedAt": iso.string(from: now.addingTimeInterval(-10)), "validUntil": iso.string(from: now.addingTimeInterval(300)),
            "accounts": accounts, "connections": connections, "sources": sources]
        let personal = try FeedDecoder.personal(JSONSerialization.data(withJSONObject: object))
        var ledger = ExpiryLedger()
        return .make(personal: personal, presentation: PersonalProjection.evaluate(personal, now: now, ledger: &ledger), publication: nil)
    }
    private func consent(_ ids: [String], mode: String = "automatic") throws -> ConsentPreview {
        let tools = ids.map { ["id": $0, "displayName": $0, "backend": "native", "readerId": "native:" + $0,
            "accessClass": "standard", "detected": true, "allowed": true, "keychain": "unset", "hosts": []] as [String: Any] }
        var capture = try GeneratedAppCLIFixtures.object("consented-consent.json")
        capture["mode"] = mode; capture["tools"] = tools // Explicit presenter-scope mutations of the generated capture.
        return try FeedDecoder.consentPreview(JSONSerialization.data(withJSONObject: capture))
    }
    private func model(_ snapshot: JoinedSnapshot, consent: ConsentPreview? = nil) -> CommunityDockSnapshot {
        var diagnostics = StoreDiagnostics(); diagnostics.personal = nil
        return .init(snapshot: snapshot, diagnostics: diagnostics, now: now, canonicalConsent: consent)
    }
    func testAlwaysYesCodexConnectionRequiresCanonicalConsentAndWaitsForFirstRead() throws {
        let value = try snapshot(connections: [["id": "codex", "authorization": ["status": "yes"], "quota": ["status": "no", "reason": "missing"]]])
        XCTAssertTrue(model(value).inputs.isEmpty)
        XCTAssertTrue(model(value, consent: try consent(["codex"], mode: "off")).inputs.isEmpty)
        let admitted = model(value, consent: try consent(["codex"]))
        let row = try XCTUnwrap(admitted.presentationRows.values.first)
        XCTAssertTrue(row.reason.contains("Waiting for first reading"))
        XCTAssertTrue(row.input.alias?.contains("Codex") == true)
        XCTAssertFalse(row.reason.contains("not detected"))
        XCTAssertTrue(admitted.subscriptions.isEmpty)
    }
    func test545ClaudeStatusLineConnectionStillShowsNativeKeychainGuidance() throws {
        let value = try snapshot(connections: [["id": "claude-code", "authorization": ["status": "not-applicable", "via": "status-line"]]],
            sources: [["source": "native:claude", "status": "consent_required"]])
        let row = try XCTUnwrap(model(value).presentationRows.values.first)
        XCTAssertTrue(row.nextStep.contains("Allow Keychain"))
        XCTAssertTrue(row.input.alias?.contains("Claude Code") == true)
        XCTAssertTrue(row.input.alias?.contains("Keychain") == true)
        XCTAssertTrue(row.input.windows.isEmpty)
    }
    func testAnyAccountSuppressesDuplicateButRetainsNativeSourceReasonAndMembership() throws {
        for bound in [false, true] {
            var account: [String: Any] = ["source": "claude-code", "stale": true, "windows": []]
            if bound { account["subscription"] = ["subscriptionRef": "actual-ref", "status": "verified"] }
            let value = try snapshot(accounts: [account], connections: [["id": "native:claude", "authorization": ["status": "yes"]]],
                sources: [["source": "native:claude", "status": "consent_required"]])
            let result = model(value, consent: try consent(["claude"]))
            XCTAssertEqual(result.inputs.count, 1)
            XCTAssertEqual(result.subscriptions.count, bound ? 1 : 0)
            XCTAssertTrue(result.inputs[0].alias?.contains("Claude Code") == true)
            let row = try XCTUnwrap(result.presentationRows[result.inputs[0].id])
            XCTAssertTrue(row.nextStep.contains("Keychain"))
        }
    }
    func testEveryEmptyReasonHasSettingsNextStep() throws {
        XCTAssertTrue(model(try snapshot()).emptyDiagnostic != nil)
        let text = CommunityReaderStatusPresentation.emptyText(model(try snapshot()), english: true)
        XCTAssertTrue(text.contains("Settings"))
    }
    func testActualHostWithdrawsPhantomConnectionWhenCanonicalConsentInvalidates() async throws {
        _ = NSApplication.shared
        let host = StaticDockPreviewHost(currentDate: { self.now }, createsNativePanels: false)
        defer { host.close() }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("h33-host-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let app = SettingsApplicationCoordinator(store: try SettingsStore(url: root.appendingPathComponent("settings.json"))) { host.apply($0) }
        await app.reload()
        var diagnostics = StoreDiagnostics(); diagnostics.personal = nil
        let value = try snapshot(connections: [["id": "codex", "authorization": ["status": "yes"], "quota": ["status": "no", "reason": "missing"]]])
        host.render(snapshot: value, diagnostics: diagnostics)
        host.updateDockConsent(try consent(["codex"]))
        XCTAssertTrue(host.menu().items.contains { $0.title.contains("Waiting for first reading") })
        func rowCount() -> Int {
            (host.dockView.accessibilityChildren() ?? []).compactMap { $0 as? NSAccessibilityElement }
                .filter { $0.accessibilityIdentifier()?.hasPrefix("dock.subscription.") == true }.count
        }
        XCTAssertEqual(rowCount(), 1)
        host.updateDockConsent(nil)
        XCTAssertEqual(rowCount(), 0, "reader diagnostic menu copy is not a quota/presentation row")
        XCTAssertNil(host.nativePanel)
    }
    func testRealFactoryRoutesCanonicalReadbackAndInvalidationToSameDock() async throws {
        final class Port: CommunityConsentCommandPort {
            let value: ConsentPreview
            var fail = false
            init(_ value: ConsentPreview) { self.value = value }
            var availability: SettingsConnectionAvailability { .init(canInspect: true, canGrant: true, canForget: false) }
            func readCanonicalConsent() async throws -> ConsentPreview { if fail { throw SettingsConnectionFailure.requestFailed }; return value }
            func applyConsentJSON(_ payload: Data) async throws { XCTFail("No grant in readback test") }
        }
        actor Desktop: CLITransport {
            func execute(_ command: CLICommand) async throws -> CommandResult { XCTFail("No helper in factory test"); throw TransportError.launchFailed }
        }
        _ = NSApplication.shared
        let host = StaticDockPreviewHost(currentDate: { self.now }, createsNativePanels: false)
        defer { host.close() }
        let port = Port(try consent(["codex"])), desktop = Desktop()
        let backend = CommunityConnectionBackend(port: port, desktop: .init(readOnly: desktop, normal: desktop))
        let delegate = CommunityApplicationFactory.makeDelegate(surfaces: CommunityInstrumentSurfaceProvider(), companion: host,
            consentBackend: backend) { _ in throw SettingsConnectionFailure.unavailable }
        defer { withExtendedLifetime(delegate) {} }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("h33-factory-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let app = SettingsApplicationCoordinator(store: try SettingsStore(url: root.appendingPathComponent("settings.json"))) { host.apply($0) }
        await app.reload()
        var diagnostics = StoreDiagnostics(); diagnostics.personal = nil
        host.render(snapshot: try snapshot(connections: [["id": "codex", "authorization": ["status": "yes"], "quota": ["status": "no", "reason": "missing"]]]), diagnostics: diagnostics)
        _ = try await backend.detect()
        XCTAssertTrue(host.menu().items.contains { $0.title.contains("Waiting for first reading") })
        port.fail = true
        do { _ = try await backend.detect(); XCTFail("Expected readback failure") } catch {}
        XCTAssertFalse(host.menu().items.contains { $0.title.contains("Waiting for first reading") })
        XCTAssertNil(host.nativePanel)
    }
    func testNativeFailurePrecedesLegacyMissingOnActualHost() async throws {
        _ = NSApplication.shared
        for failure in ["parse_error", "timeout"] {
            for connectionID in ["claude-code", "native:claude"] {
                let value = try snapshot(connections: [["id": connectionID, "authorization": ["status": "yes"],
                    "quota": ["status": "no", "reason": "missing"]]], sources: [["source": "native:claude", "status": "unavailable", "reason": failure]])
                let result = model(value, consent: try consent(["claude"]))
                let row = try XCTUnwrap(result.presentationRows.values.first)
                XCTAssertFalse(row.reason.contains("Waiting"), "native failure must beat the legacy missing state")
                XCTAssertTrue(row.reason.contains("unavailable"))
                let host = StaticDockPreviewHost(currentDate: { self.now }, createsNativePanels: false)
                defer { host.close() }
                let root = FileManager.default.temporaryDirectory.appendingPathComponent("native-failure-host-" + UUID().uuidString)
                defer { try? FileManager.default.removeItem(at: root) }
                let app = SettingsApplicationCoordinator(store: try SettingsStore(url: root.appendingPathComponent("settings.json"))) { host.apply($0) }
                await app.reload()
                var diagnostics = StoreDiagnostics(); diagnostics.personal = nil
                host.updateDockConsent(try consent(["claude"]))
                host.render(snapshot: value, diagnostics: diagnostics); host.setPresentationAllowed(true)
                let menu = host.menu().items.map(\.title).joined(separator: " ")
                XCTAssertTrue(menu.contains("Reading unavailable")); XCTAssertFalse(menu.contains("Waiting"))
                XCTAssertFalse(menu.contains(failure))
                host.dockView.onAction?(.subscription(row.input.id))
                func labels(_ view: NSView) -> [NSTextField] { (view as? NSTextField).map { [$0] } ?? view.subviews.flatMap(labels) }
                XCTAssertTrue(labels(host.card).contains { $0.stringValue.contains("Reading unavailable") })
                XCTAssertFalse(labels(host.card).contains { $0.stringValue.contains(failure) })
                XCTAssertNil(host.nativePanel)
            }
        }
    }
    func testSupersededDetectAndMutationCannotWithdrawNewCanonicalPresentation() async throws {
        final class Port: CommunityConsentCommandPort {
            let value: ConsentPreview
            init(_ value: ConsentPreview) { self.value = value }
            var availability: SettingsConnectionAvailability { .init(canInspect: true, canGrant: true, canForget: false) }
            func readCanonicalConsent() async throws -> ConsentPreview { value }
            func applyConsentJSON(_ payload: Data) async throws { XCTFail("Old mutation must not dispatch") }
        }
        actor Desktop: CLITransport { func execute(_ command: CLICommand) async throws -> CommandResult { throw TransportError.launchFailed } }
        final class Delay {
            var pending: CheckedContinuation<UInt64, Never>?
            var value: UInt64 = 0
            var entered = false
            func holdFirst(_ token: UInt64) async -> UInt64 {
                if entered { return token }
                entered = true; value = token
                return await withCheckedContinuation { pending = $0 }
            }
            func release() { pending?.resume(returning: value); pending = nil }
        }
        for mutation in [false, true] {
            let desktop = Desktop(), delay = Delay()
            let gate = ConsentGatedDesktopTransport(readOnly: desktop, normal: desktop)
            let backend = CommunityConnectionBackend(port: Port(try consent(["codex"])), desktop: gate,
                invalidateConsent: { await delay.holdFirst(await gate.invalidateConsent()) })
            var presented = false
            backend.onCanonicalInvalidated = { presented = false }
            backend.onCanonicalReadback = { _ in presented = true }
            let old = Task {
                if mutation { return try await backend.applyStandardConsent(allow: [.codex], deny: [], request: .init(id: UUID(), expectedConsentGeneration: 1, consentTextVersion: 2)) }
                return try await backend.detect()
            }
            for _ in 0..<100 where !delay.entered { await Task.yield() }
            XCTAssertTrue(delay.entered)
            _ = try await backend.detect()
            XCTAssertTrue(presented)
            delay.release()
            do { _ = try await old.value; XCTFail("Old token must fail") } catch {}
            XCTAssertTrue(presented, "delayed stale detect/mutation must not publish invalidation")
        }
    }


}

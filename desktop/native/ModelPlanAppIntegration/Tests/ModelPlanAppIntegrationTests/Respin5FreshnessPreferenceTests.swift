// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanCore
import ModelPlanDock
import ModelPlanSettings
import ModelPlanShell
@testable import ModelPlanCommunityHost
@testable import ModelPlanAppIntegration

@MainActor final class Respin5FreshnessPreferenceTests: XCTestCase {
    private final class Scheduler: DockEdgeScheduling {
        func arm(at deadline: TimeInterval, _ action: @escaping @MainActor () -> Void) {}
        func cancel() {}
    }
    private actor NoEffects: CLITransport, ConsentJSONTransport {
        func execute(_ command: CLICommand) async throws -> CommandResult { XCTFail("No helper"); throw TransportError.launchFailed }
        func readConsentJSON() async throws -> CommandResult { XCTFail("No consent read"); throw TransportError.launchFailed }
        func grantConsentJSON(_ data: Data) async throws -> CommandResult { XCTFail("No grant"); throw TransportError.launchFailed }
    }
    private func dock() -> StaticDockPreviewHost {
        ProductionDockFactory.community(createsNativePanels: false, nativeEnvironment: {
            .init(displays: [.init(id: "synthetic", frame: .init(x: 0,y: 0,width: 1600,height: 1000), visibleFrame: .init(x: 0,y: 0,width: 1600,height: 960))], layouts: [], primaryDisplayID: "synthetic", pointer: .init(x: 800,y: 500))
        }, elapsedClock: { 0 }, edgeScheduling: Scheduler())
    }
    private func account(_ source: String, ref: String?, remaining: Double, observed: Date?, now: Date) -> [String: Any] {
        let format = ISO8601DateFormatter()
        var value: [String: Any] = ["source": source, "via": "native", "windows": [["kind":"weekly", "remainingPercent":remaining,
            "observedAt":format.string(from:now.addingTimeInterval(-15)), "resetsAt":format.string(from:now.addingTimeInterval(3600)), "windowMinutes":10080]]]
        if let ref { value["subscription"] = ["subscriptionRef":ref,"status":"verified"] }
        if let observed { value["observedAt"] = format.string(from: observed) }
        return value
    }
    private func wire(_ accounts: [[String: Any]], now: Date) throws -> Data {
        let format = ISO8601DateFormatter()
        var raw = try GeneratedAppCLIFixtures.object("fresh-desktop.json")
        raw["generatedAt"] = format.string(from:now.addingTimeInterval(-1)); raw["validUntil"] = format.string(from:now.addingTimeInterval(600))
        raw["accounts"] = accounts; raw["sources"] = []
        return try JSONSerialization.data(withJSONObject: raw)
    }
    private func joined(_ accounts: [[String: Any]], now: Date) throws -> JoinedSnapshot {
        let personal = try FeedDecoder.personal(wire(accounts, now: now))
        var ledger = ExpiryLedger()
        return .make(personal:personal,presentation:.evaluate(personal,now:now,ledger:&ledger),publication:nil)
    }
    private var ready: StoreDiagnostics { var value = StoreDiagnostics(); value.personal = nil; return value }
    private func app(_ dock: StaticDockPreviewHost) throws -> SettingsApplicationCoordinator {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("respin5-settings-"+UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at:folder) }
        let value = SettingsApplicationCoordinator(store:try SettingsStore(url:folder.appendingPathComponent("settings.json")),apply:{dock.apply($0)})
        CommunityPlacementBinding.install(on:dock,application:value)
        return value
    }
    private func descendants(_ root: NSView) -> [NSView] { [root]+root.subviews.flatMap(descendants) }
    func testActualProductionCardsShowOriginalBoundAndUnboundAccountAgeInHours() async throws {
        for source in ["codex","claude-code"] { for bound in [true,false] {
            let now = Date(), host = dock(); defer { host.close() }
            let application = try app(host); await application.reload()
            let snapshot = try joined([account(source,ref:bound ? "sub-a":nil,remaining:75,observed:now.addingTimeInterval(-7200),now:now)],now:now)
            host.render(snapshot:snapshot,diagnostics:ready); host.setPresentationAllowed(true)
            let id = try XCTUnwrap(CommunityDockSnapshot(snapshot:snapshot,diagnostics:ready,now:now).inputs.first?.id)
            host.dockView.onAction?(.subscription(id))
            let field = try XCTUnwrap(descendants(host.card).compactMap{$0 as? NSTextField}.first{$0.accessibilityIdentifier()=="dock.card.text.source"})
            XCTAssertFalse(field.isHidden); XCTAssertTrue(field.stringValue.contains("2h"),field.stringValue)
            XCTAssertFalse(field.stringValue.contains("7200s")); XCTAssertEqual(field.accessibilityLabel(),field.stringValue)
            XCTAssertNil(host.nativePanel); XCTAssertNil(host.dockView.window)
        }}
    }
    func testBoundCardDoesNotInventAgeFromWindowOrRenderTimeWhenAccountTimeIsMissing() async throws {
        let now = Date(), host = dock(); defer {host.close()}
        let application = try app(host); await application.reload()
        let snapshot = try joined([account("codex",ref:"sub-a",remaining:75,observed:nil,now:now)],now:now)
        host.render(snapshot:snapshot,diagnostics:ready);host.setPresentationAllowed(true);host.dockView.onAction?(.subscription("sub-a"))
        let field = try XCTUnwrap(descendants(host.card).compactMap{$0 as? NSTextField}.first{$0.accessibilityIdentifier()=="dock.card.text.source"})
        XCTAssertFalse(field.isHidden);XCTAssertTrue(field.stringValue.contains("unknown"),field.stringValue)
    }
    func testActualFactoryMenuUsesSameHiddenAndUsedPreferencesAsDock() async throws {
        let now = Date(), host = dock();defer{host.close()}
        let application = try app(host);await application.reload()
        let fake = NoEffects(), port = CommunityCLIConsentPort(transport:fake,apiAvailable:false)
        let backend = CommunityConnectionBackend(port:port,desktop:.init(readOnly:fake,normal:fake))
        let delegate = CommunityApplicationFactory.makeDelegate(surfaces:NeutralSurfaceProvider(),companion:host,consentBackend:backend,transport:fake){_ in throw SettingsConnectionFailure.unavailable}
        let snapshot = try joined([account("codex",ref:"tight",remaining:10,observed:now,now:now),account("native:gemini",ref:"wide",remaining:60,observed:now,now:now)],now:now)
        host.render(snapshot:snapshot,diagnostics:ready)
        let button = NSButton();delegate.updateMenuBar(snapshot:snapshot,diagnostics:ready,now:now,button:button)
        XCTAssertEqual(button.title,"10%")
        try await application.editor.commit(.visible("tight",false))
        delegate.updateMenuBar(snapshot:snapshot,diagnostics:ready,now:now,button:button)
        XCTAssertEqual(button.title,"60%")
        try await application.editor.commit(.percentageMode(.used))
        delegate.updateMenuBar(snapshot:snapshot,diagnostics:ready,now:now,button:button)
        XCTAssertEqual(button.title,"40%")
        try await application.editor.commit(.visible("tight",true))
        delegate.updateMenuBar(snapshot:snapshot,diagnostics:ready,now:now,button:button)
        XCTAssertEqual(button.title,"90%", "Choose the tightest remaining row before formatting used percent")
        XCTAssertNil(button.contentTintColor);XCTAssertTrue(try XCTUnwrap(button.image).isTemplate)
        XCTAssertNil(delegate.status);XCTAssertNil(button.window)
    }
    func testMenuKeepsIconOnlyUntilRealSettingsPreferencesExist() throws {
        let now = Date(), host = dock();defer{host.close()}
        let fake = NoEffects(),port = CommunityCLIConsentPort(transport:fake,apiAvailable:false)
        let backend = CommunityConnectionBackend(port:port,desktop:.init(readOnly:fake,normal:fake))
        let delegate = CommunityApplicationFactory.makeDelegate(surfaces:NeutralSurfaceProvider(),companion:host,consentBackend:backend,transport:fake){_ in throw SettingsConnectionFailure.unavailable}
        let snapshot = try joined([account("codex",ref:"tight",remaining:10,observed:now,now:now)],now:now)
        let button = NSButton();delegate.updateMenuBar(snapshot:snapshot,diagnostics:ready,now:now,button:button)
        XCTAssertEqual(button.title,"")
    }
    func testAgeFormattingUsesMinutesHoursAndRejectsUnknownOrFutureTimes() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        for (seconds, expected) in [(15.0,"<1m"),(60,"1m"),(3599,"59m"),(3600,"1h"),(7200,"2h")] {
            XCTAssertTrue(CommunityObservationAge.text(observedAt:now.addingTimeInterval(-seconds),now:now).contains(expected))
        }
        for observed in [nil, now.addingTimeInterval(1), Date(timeIntervalSince1970: .infinity)] {
            XCTAssertEqual(CommunityObservationAge.text(observedAt:observed,now:now),CommunityObservationAge.unknown)
        }
    }
    func testBoundAgeFollowsTheSelectedAccountWithoutUsingReportTime() throws {
        let now = Date()
        var first = account("codex",ref:"shared",remaining:75,observed:now.addingTimeInterval(-120),now:now)
        var windows = try XCTUnwrap(first["windows"] as? [[String:Any]])
        windows[0]["kind"] = "five_hour"; first["windows"] = windows
        let snapshot = try joined([first,account("native:claude",ref:"shared",remaining:10,observed:now.addingTimeInterval(-7200),now:now)],now:now)
        let model = CommunityDockSnapshot(snapshot:snapshot,diagnostics:ready,now:now)
        let input = try XCTUnwrap(model.inputs.first)
        XCTAssertTrue(CommunityDockObservation.text(input:input,snapshot:snapshot,model:model,now:now).contains("2h"))
        XCTAssertTrue(CommunityDockObservation.text(input:input,snapshot:snapshot,model:model,now:now.addingTimeInterval(60)).contains("2h"))
        var preferences = SettingsPreferences()
        preferences.subscriptionSettings["shared"] = .init(percentagePin:.fiveHour)
        XCTAssertTrue(CommunityDockObservation.text(input:preferences.applying(to:input),snapshot:snapshot,model:model,now:now).contains("2m"))
    }
    private actor Feed: CLITransport {
        let data: Data
        var desktops = 0
        init(_ data: Data) {self.data=data}
        func execute(_ command: CLICommand) async throws -> CommandResult {
            if command == .desktop { desktops += 1; return .init(exitCode:0,stdout:data) }
            return .init(exitCode:1,stdout:Data())
        }
        func count() -> Int { desktops }
    }
    func testActualRetainedRuntimeReprojectsPreferencesImmediatelyWithoutAnotherCLIRead() async throws {
        let now = Date(), host = dock();defer{host.close()}
        let application = try app(host)
        let noEffects = NoEffects(), port = CommunityCLIConsentPort(transport:noEffects,apiAvailable:false)
        let backend = CommunityConnectionBackend(port:port,desktop:.init(readOnly:noEffects,normal:noEffects))
        let base = CommunitySettingsSession(application:application,canPresent:{false},environment:{.init()},activate:{XCTFail("No activation")})
        let entry = try CommunityApplicationFactory.connectSettings(base:base,application:application,backend:backend,placementSource:host,canPresent:{false})
        defer{entry.flow.dispose()}
        let feed = Feed(try wire([account("codex",ref:"tight",remaining:10,observed:now,now:now),account("native:gemini",ref:"wide",remaining:60,observed:now,now:now)],now:now))
        let delegate = CommunityApplicationFactory.makeDelegate(surfaces:NeutralSurfaceProvider(),companion:host,consentBackend:backend,transport:feed){_ in entry}
        let runtime = delegate.configureRuntime()
        addTeardownBlock { await runtime.store.stopAndWait() }
        XCTAssertTrue(delegate.configureRuntime() === runtime, "The actual delegate retains one store/runtime")
        _ = delegate.configureSettings(runtime.lifecycle); await entry.restorePreferences()
        runtime.store.start()
        for _ in 0..<500 where !runtime.store.idle {try await Task.sleep(nanoseconds:1_000_000)}
        XCTAssertTrue(runtime.store.idle)
        XCTAssertEqual(delegate.menuBarPresentation.title,"10%")
        let before = await feed.count()
        try await application.editor.commit(.visible("tight",false))
        XCTAssertEqual(delegate.menuBarPresentation.title,"60%", "Same apply receipt must update the menu without waiting60s")
        try await application.editor.commit(.percentageMode(.used))
        XCTAssertEqual(delegate.menuBarPresentation.title,"40%")
        let after = await feed.count();XCTAssertEqual(after,before)
        XCTAssertNil(delegate.status);XCTAssertNil(host.nativePanel)
        await runtime.store.stopAndWait()
    }

}

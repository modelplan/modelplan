// SPDX-License-Identifier: MIT
import Foundation
import OSLog
import ModelPlanEngineStore
import ModelPlanEngineClient
import ModelPlanWire
import ModelPlanCommunityHost
import ModelPlanSettings
import ModelPlanDock

@MainActor private final class EngineDockClock {
    var now: @MainActor () -> Date = { Date() }
}

/// Normal-entry composition. Construction creates no engine child or native panel when requested.
public struct EngineMenuRefreshResult {
    public let engineRequestID:WireRequestID
    public let scheduled:[WireRefreshScheduled]
}
@MainActor public final class EngineDockMenuComposition {
    public let store: EngineStore
    public let client: any EngineClient
    public let provider: EngineDockMenuProvider
    public let dock: StaticDockPreviewHost
    private let adapter: EngineDockContentProvider
    private var activityExpiryTask: Task<Void, Never>?
    private var activityPresentationPaused = false
    private let clock: EngineDockClock
    // Internal injection seam: the production entry retains the system clock.
    var currentDate: @MainActor () -> Date {
        get { clock.now }
        set { clock.now = newValue }
    }
    private var resetNotifier:EngineResetNotifier?
    private var resetScratch:URL?
    public var menuDidChange: (() -> Void)?
    public private(set) var latestSettings: SettingsApplication?
    public var settingsDidChange: ((SettingsApplication) -> Void)?
    public func applySettings(_ value: SettingsApplication) {
        latestSettings = value
        setLanguage(value.snapshot.preferences.language.rawValue)
        dock.apply(value)
        settingsDidChange?(value)
    }
    public init(configuration: EngineClientConfiguration, createsNativePanels: Bool = true,
                makeClient: (@MainActor (EngineClientConfiguration, EngineStore) -> any EngineClient)? = nil) {
        let clock = EngineDockClock()
        self.clock = clock
        let store: EngineStore
        if let makeClient {
            store = EngineStore(); client = makeClient(configuration, store)
        } else {
            let connection = EngineStoreConnection(configuration: configuration)
            store = connection.store; client = connection.client
        }
        self.store = store
        let provider = EngineDockMenuProvider(store: store)
        self.provider = provider
        adapter = EngineDockContentProvider(source: provider)
        adapter.resetEventState = { [weak store] in EngineRowsEventDecoder.decode(store?.snapshot.rows) }
        dock = ProductionDockFactory.community(createsNativePanels: createsNativePanels, currentDate: { clock.now() })
        adapter.bindDockMenuTracking(dock)
        dock.setDockContentProvider(adapter)
        provider.dockContentDidChange = { [weak self] in
            self?.adapter.scrubInvalidatedMenus()
            self?.refreshActivityPresentation()
        }
    }
    deinit { activityExpiryTask?.cancel() }
    private func refreshActivityPresentation() {
        activityExpiryTask?.cancel(); activityExpiryTask=nil
        dock.refreshDockContent(); menuDidChange?()
        guard !activityPresentationPaused else { return }
        let now=currentDate()
        guard let expiry=presentedContent.snapshot.inputs.compactMap({$0.working?.expiresAt}).filter({$0>now}).min() else { return }
        let delay=expiry.timeIntervalSince(now)
        activityExpiryTask=Task { @MainActor [weak self] in
            do { try await Task.sleep(for:.seconds(delay)); try Task.checkCancellation() }
            catch { return }
            self?.refreshActivityPresentation()
        }
    }
    func setActivityPresentationPaused(_ paused:Bool) {
        activityPresentationPaused=paused
        if paused { activityExpiryTask?.cancel(); activityExpiryTask=nil }
        else { refreshActivityPresentation() }
    }
    public var presentedContent: DockContent { adapter.makeContent(.init(snapshot: nil, diagnostics: .init(), now: currentDate())) }
    func setLanguage(_ language:String) { adapter.language=language }
    var language:String { adapter.language }
    /// Same admitted membership for M2's placement/Settings writer; cleared with the Store.
    public var accountMembers:EngineAccountMemberCatalogue {
        .init(rows:store.snapshot.rows?.projection.rows ?? [])
    }
    public var rowEvents:EngineRowsEventState { EngineRowsEventDecoder.decode(store.snapshot.rows) }
    public var resetSignals:[DockSubscriptionSignal] { _ = presentedContent; return adapter.signals }
    public var memberInstability:[String:Bool] { _ = presentedContent; return adapter.memberInstability }
    func installResetEvents(settings:SettingsStore,live:Bool) {
        let base:URL
        if live {
            guard let appSupport=FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask).first else { return }
            base=appSupport.appendingPathComponent("ModelPlan",isDirectory:true)
        } else { base=FileManager.default.temporaryDirectory.appendingPathComponent("modelplan-s4-"+UUID().uuidString,isDirectory:true);resetScratch=base }
        do {
            let notifier=try EngineResetNotifier.recovering(composition:self,settings:settings,cacheURL:base.appendingPathComponent("reset-notifications.json"),deliverToSystem:live)
            resetNotifier=notifier;notifier.start()
        } catch {
            Logger(subsystem:"ai.modelplan.notifications",category:"reset-ledger").error("Reset notification service could not be started.")
        }
    }
    /// A synthetic delivery adapter can be supplied by a non-windowed host.
    public func setResetNotificationDelivery(_ delivery:@escaping @MainActor (String) async throws -> Void) {
        resetNotifier?.deliveryOverride=delivery
        resetNotifier?.apply(store.snapshot)
    }
    public var menuPresentation: CommunityMenuBarPresentation {
        let content = presentedContent
        return .init(title: "", detail: (content.menuStatusLines ?? []).joined(separator: " · "))
    }
    public func start() async {
        do { _ = try await client.start(); _ = try await client.subscribeRows(timeout: nil) }
        catch { /* Accepted client events own errors and current data, never the Task completion. */ }
        do { _ = try await client.consent(timeout: nil) }
        catch { /* The accepted event stream owns consent state and failures. */ }
    }
    public func refresh(prepared: (@MainActor @Sendable (WireRequestID) -> Void)? = nil,
                        onResult: (@MainActor (Result<EngineMenuRefreshResult, Error>) -> Void)? = nil) async {
        var replies:[(WireRequestID,[WireRefreshScheduled])]=[]
        let token=onResult == nil ? nil : store.observeRefreshReplies { replies.append(($0,$1)) }
        defer { if let token { store.removeRefreshReplyObserver(token) } }
        do {
            let completion: EngineRequestCompletion
            if let prepared {
                completion = try await client.refresh(try .init(), timeout:nil, prepared: { id in await prepared(id) })
            } else { completion = try await client.refresh(try .init(), timeout:nil) }
            if let onResult {
                let own=replies.filter { $0.0==completion.requestID }
                guard own.count==1 else { throw EngineClientError.protocolViolation }
                onResult(.success(.init(engineRequestID:completion.requestID,scheduled:own[0].1)))
            }
        }
        catch { onResult?(.failure(error)) /* No automatic retry or optimistic value. */ }
    }
    public func stop() async { setActivityPresentationPaused(true); dock.close(); await client.stop(); if let resetScratch { try? FileManager.default.removeItem(at:resetScratch) } }
}

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
    private let admittedCache = HostPairedContentCache()
    private var deadlineLifecycleSuspended = false
    private var pendingProjectionReplacement = false
    private lazy var pairedProjection = HostPairedProjection(store: store, source: provider, provider: adapter, client: client)
    private let deadlineWall: @MainActor () -> Date
    private let deadlineElapsed: () -> TimeInterval
    private let deadlineScheduler: any DockEdgeScheduling
    private lazy var deadlineDriver: HostDeadlineDriver<DockContent> = {
        HostDeadlineDriver(wallNow: deadlineWall, elapsed: deadlineElapsed, scheduler: deadlineScheduler,
            clear: { [weak self] in
                guard let self else { return }
                self.admittedCache.clear()
                self.dock.withdrawAdmittedContent(privacy: self.provider.dockContent.status == .cleared)
                // Rebuild from the empty, localized cache after scrubbing so the
                // Dock menu has a next step even if no new projection is admitted.
                self.dock.refreshDockContent()
                self.menuDidChange?()
            }, recompute: { [weak self] now in
                guard let self else { return nil }
                defer {
                    if self.pendingProjectionReplacement && !self.deadlineLifecycleSuspended {
                        self.pendingProjectionReplacement = false
                        self.deadlineDriver.replace()
                    }
                }
                return try? self.pairedProjection.make(.init(snapshot: nil, diagnostics: .init(), now: now))
            }, install: { [weak self] content in
                guard let self else { return }
                guard let evaluatedAt = self.pairedProjection.evaluatedAt else { return }
                self.admittedCache.install(content, evaluatedAt: evaluatedAt)
                self.dock.refreshDockContent(); self.menuDidChange?()
            }, sourceIsCurrent: { [weak self] token in self?.pairedProjection.isCurrent(token) == true },
            installValidatedUnknown: true)
    }()
    private let clock: EngineDockClock
    // Internal injection seam: the production entry retains the system clock.
    var currentDate: @MainActor () -> Date {
        get { clock.now }
        set { clock.now = newValue }
    }
    private var resetNotifier:EngineResetNotifier?
    private var forecastNotifier:EngineForecastNotifier?
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
                dockEnvironment: (@MainActor () -> DockEdgeEnvironment)? = nil,
                deadlineNow: @escaping @MainActor () -> Date = { Date() },
                deadlineElapsed: (() -> TimeInterval)? = nil, deadlineScheduling: (any DockEdgeScheduling)? = nil,
                makeClient: (@MainActor (EngineClientConfiguration, EngineStore) -> any EngineClient)? = nil) {
        let clock = EngineDockClock()
        clock.now = deadlineNow
        self.clock = clock
        self.deadlineWall = { clock.now() }
        let elapsed = deadlineElapsed ?? { ProcessInfo.processInfo.systemUptime }
        self.deadlineElapsed = elapsed
        self.deadlineScheduler = deadlineScheduling ?? DockCommonModeScheduler(clock: elapsed)
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
        dock = ProductionDockFactory.community(createsNativePanels: createsNativePanels, nativeEnvironment: dockEnvironment, currentDate: { clock.now() })
        adapter.bindDockMenuTracking(dock)
        _ = pairedProjection
        dock.onWillRetire = { [weak self] in
            guard let self else { return }
            self.pairedProjection.invalidate()
            self.deadlineDriver.close()
        }
        admittedCache.fallbackText = { [weak self] in self?.fallbackStatusText }
        admittedCache.isCurrent = { [weak self] in
            guard let self else { return false }
            return self.pairedProjection.isCurrent(self.pairedProjection.generation)
        }
        admittedCache.onStale = { [weak self] in
            guard let self else { return }
            self.pairedProjection.invalidate()
            if self.pairedProjection.isProjecting { self.pendingProjectionReplacement = true; return }
            if !self.deadlineLifecycleSuspended { self.deadlineDriver.replace() }
        }
        dock.setDockContentProvider(admittedCache)
        provider.dockContentDidChange = { [weak self] in
            guard let self else { return }
            self.adapter.scrubInvalidatedMenus()
            self.pairedProjection.invalidate()
            if self.pairedProjection.isProjecting { self.pendingProjectionReplacement = true; return }
            if !self.deadlineLifecycleSuspended { self.deadlineDriver.replace() }
        }
    }
    public var presentedContent: DockContent { admittedCache.makeContent(.init(snapshot: nil, diagnostics: .init(), now: deadlineWall())) }
    func setLanguage(_ language: String) {
        guard adapter.language != language else { return }
        adapter.language = language
        // A locale change does not replace the accepted delivery. Reproject
        // atomically only if the existing cache and source are still current,
        // preserving an open card without retaining stale source data.
        if !deadlineLifecycleSuspended, !pairedProjection.isProjecting {
            let now = deadlineWall(), token = pairedProjection.generation
            if admittedCache.isAdmissible(at: now),
               let candidate = try? pairedProjection.make(.init(snapshot: nil, diagnostics: .init(), now: now)),
               candidate.sourceToken == token, pairedProjection.isCurrent(token) {
                admittedCache.install(candidate.value, evaluatedAt: now)
                dock.refreshDockContent(); menuDidChange?()
                return
            }
        }
        pairedProjection.invalidate()
        if pairedProjection.isProjecting { pendingProjectionReplacement = true; return }
        if !deadlineLifecycleSuspended { deadlineDriver.replace() }
    }
    var language:String { adapter.language }
    /// Same admitted membership for M2's placement/Settings writer; cleared with the Store.
    public var accountMembers:EngineAccountMemberCatalogue {
        .init(rows:store.snapshot.rows?.projection.rows ?? [])
    }
    public var rowEvents:EngineRowsEventState { EngineRowsEventDecoder.decode(store.snapshot.rows) }
    public var resetSignals:[DockSubscriptionSignal] { presentedContent.signals }
    public var memberInstability:[String:Bool] {
        Dictionary(uniqueKeysWithValues: presentedContent.snapshot.subscriptions.map { ($0.id, $0.isUnstable) })
    }
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
        let forecasts=EngineForecastNotifier(settings:settings,cacheURL:base.appendingPathComponent("forecast-notifications.json"),deliverToSystem:live,now:{ [weak self] in self?.currentDate() ?? Date() })
        forecastNotifier=forecasts;_=store.attach(forecasts)
    }
    /// The same seam for forecast notices.
    public func setForecastNotificationDelivery(_ delivery:@escaping @MainActor (String) async throws -> Void) {
        forecastNotifier?.deliveryOverride=delivery
        forecastNotifier?.apply(store.snapshot)
    }
    /// A synthetic delivery adapter can be supplied by a non-windowed host.
    public func setResetNotificationDelivery(_ delivery:@escaping @MainActor (String) async throws -> Void) {
        resetNotifier?.deliveryOverride=delivery
        resetNotifier?.apply(store.snapshot)
    }
    private var fallbackStatusText: String {
        let english = adapter.language == "en"
        let fallback: String
        switch provider.dockContent.status {
        case .loading:
            fallback = english ? "Loading readings. If this persists, check Settings." : "正在读取；若持续无响应，请检查设置。"
        case .empty:
            fallback = english ? "No readings are available. Check Settings." : "暂无读数，请检查设置。"
        case .failed:
            fallback = english ? "Readings unavailable. Check the engine connection in Settings." : "读数不可用，请在设置中检查引擎连接。"
        case .cleared:
            fallback = english ? "Readings cleared. Check Settings to reconnect." : "读数已清除，请在设置中重新连接。"
        case .ready:
            fallback = english ? "Readings unavailable. Check Settings." : "读数不可用，请检查设置。"
        }
        return fallback
    }
    public var menuPresentation: CommunityMenuBarPresentation {
        let detail = (presentedContent.menuStatusLines ?? []).joined(separator: " · ")
        return .init(title: "", detail: detail.isEmpty ? fallbackStatusText : detail)
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
    func suspendDeadlines() { deadlineLifecycleSuspended = true; pairedProjection.invalidate(); deadlineDriver.suspend() }
    func resumeDeadlines() { deadlineLifecycleSuspended = false; pairedProjection.invalidate(); deadlineDriver.replace() }
    public func stop() async { deadlineDriver.close(); dock.close(); await client.stop(); if let resetScratch { try? FileManager.default.removeItem(at:resetScratch) } }
}

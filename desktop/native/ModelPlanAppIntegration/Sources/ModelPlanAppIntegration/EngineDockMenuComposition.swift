// SPDX-License-Identifier: MIT
import Foundation
import OSLog
import ModelPlanEngineStore
import ModelPlanEngineClient
import ModelPlanWire
import ModelPlanCommunityHost
import ModelPlanSettings
import ModelPlanDock

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
    private let deadlineWall: @MainActor () -> Date = { Date() }
    private let deadlineElapsed: () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
    private lazy var deadlineScheduler: any DockEdgeScheduling = DockCommonModeScheduler(clock: deadlineElapsed)
    private lazy var deadlineDriver: HostDeadlineDriver<DockContent> = {
        HostDeadlineDriver(wallNow: deadlineWall, elapsed: deadlineElapsed, scheduler: deadlineScheduler,
            clear: { [weak self] in
                guard let self else { return }
                self.admittedCache.clear()
                self.dock.withdrawAdmittedContent(privacy: self.provider.dockContent.status == .cleared)
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
                self.admittedCache.install(content); self.dock.refreshDockContent(); self.menuDidChange?()
            }, sourceIsCurrent: { [weak self] token in self?.pairedProjection.isCurrent(token) == true },
            installValidatedUnknown: true)
    }()
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
                dockEnvironment: (@MainActor () -> DockEdgeEnvironment)? = nil,
                makeClient: (@MainActor (EngineClientConfiguration, EngineStore) -> any EngineClient)? = nil) {
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
        dock = ProductionDockFactory.community(createsNativePanels: createsNativePanels, nativeEnvironment: dockEnvironment)
        adapter.bindDockMenuTracking(dock)
        _ = pairedProjection
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
    func setLanguage(_ language:String) { adapter.language=language }
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
    func suspendDeadlines() { deadlineLifecycleSuspended = true; pairedProjection.invalidate(); deadlineDriver.suspend() }
    func resumeDeadlines() { deadlineLifecycleSuspended = false; pairedProjection.invalidate(); deadlineDriver.replace() }
    public func stop() async { deadlineDriver.close(); dock.close(); await client.stop(); if let resetScratch { try? FileManager.default.removeItem(at:resetScratch) } }
}

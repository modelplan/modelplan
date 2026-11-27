// SPDX-License-Identifier: MIT
import Foundation
import OSLog
import CoreGraphics
import ModelPlanEngineStore
import ModelPlanEngineClient
import ModelPlanWire
import ModelPlanCommunityHost
import ModelPlanSettings
import ModelPlanDock
import ModelPlanResources

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
    /// D466: the content provider that owns the shared news clock (the cockpit's news bridge asks it).
    var contentProvider: EngineDockContentProvider { adapter }
    private let admittedCache = HostPairedContentCache()
    private var deadlineLifecycleSuspended = false
    private var pendingProjectionReplacement = false
    private var cardReplacementMembers: Set<String> = []
    /// WP-17: what the Dock projection reads from one accepted delivery. Every store event (health, a consent or
    /// cockpit reply, a context) used to clear and redraw the Dock, four official-face passes, on the main actor while
    /// the engine client's ordered delivery waited: about 0.6 s per event on a hosted Mac, before the cockpit saw its
    /// reply. An event that leaves these unchanged changes no Dock pixel, so it only refreshes the menu.
    struct DockInputs: Equatable {
        let status: DockContentStatus
        let connection: EngineConnectionState
        let delivery: EngineDeliveryContext?
        let current: Bool
        let rowsSequence: UInt64?
        let invalidRowCount: Int
        let language: String
    }
    /// The inputs of the last completed replacement; nil after a clear, so the next delivery always redraws.
    private var replacedInputs: DockInputs?
    /// The inputs of the last full withdrawal with no admitted content since; a second clear of the same empty state
    /// (the fence withdraws again when a recompute finds no admitted rows) only drops the cache.
    private var emptyClearInputs: DockInputs?
    /// G3-161: an in-place replacement kept the painted face; the driver step's install releases it, `settled` retires it.
    private var faceAwaitingReinstall = false
    func dockInputs() -> DockInputs {
        let snapshot = store.snapshot
        return DockInputs(status: provider.dockContent.status, connection: snapshot.connection, delivery: snapshot.delivery,
                          current: snapshot.delivery.map { client.isCurrent($0) } ?? false, rowsSequence: snapshot.rows?.sequence,
                          invalidRowCount: snapshot.invalidRowCount, language: adapter.language)
    }
    private lazy var pairedProjection = HostPairedProjection(store: store, source: provider, provider: adapter, client: client)
    private let deadlineWall: @MainActor () -> Date
    private let deadlineElapsed: () -> TimeInterval
    private let deadlineScheduler: any DockEdgeScheduling
    private lazy var deadlineDriver: HostDeadlineDriver<DockContent> = {
        HostDeadlineDriver(wallNow: deadlineWall, elapsed: deadlineElapsed, scheduler: deadlineScheduler,
            clear: { [weak self] in
                guard let self else { return }
                self.admittedCache.clear()
                // WP-17: the same empty state was withdrawn already and nothing was installed since; withdrawing and
                // redrawing it again changes nothing (a kept card is never skipped: its replacement decides it).
                let inputs = self.dockInputs()
                if self.cardReplacementMembers.isEmpty, self.emptyClearInputs == inputs { return }
                let privacy = self.provider.dockContent.status == .cleared
                // G3-161: a replacement (clear, then recompute and install in the same driver step) with no card open
                // keeps the painted face; the reinstall repaints only changed readings, and `settled` retires the face
                // if nothing was reinstalled. Withdrawals, pauses, privacy and open cards retire it here as before.
                let inPlace = !privacy && self.deadlineDriver.clearReinstalls && self.dock.canReplaceInPlace
                let keepCard = self.dock.withdrawAdmittedContent(privacy: privacy, keepingCardFor: self.cardReplacementMembers,
                                                                 retainingFace: inPlace)
                self.faceAwaitingReinstall = inPlace
                // No intermediate empty face: the install (or `settled`) refreshes the Dock and menu once.
                if inPlace { self.emptyClearInputs = nil; return }
                // On withdrawal or a failed replacement the empty cache still
                // supplies the localized menu next step.
                if !keepCard {
                    self.dock.refreshDockContent()
                    self.menuDidChange?()
                }
                self.emptyClearInputs = keepCard ? nil : inputs
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
                self.emptyClearInputs = nil
                self.faceAwaitingReinstall = false
                self.admittedCache.install(content, evaluatedAt: evaluatedAt)
                self.dock.refreshDockContent(); self.menuDidChange?()
                self.armActivityExpiry()
            }, sourceIsCurrent: { [weak self] token in self?.pairedProjection.isCurrent(token) == true },
            installValidatedUnknown: true, presentationInterval: 60, settled: { [weak self] in
                guard let self, self.faceAwaitingReinstall else { return }
                // The replacement installed nothing: finish the withdrawal it deferred.
                self.faceAwaitingReinstall = false
                self.dock.completeDeferredWithdrawal()
                self.dock.refreshDockContent()
                self.menuDidChange?()
                self.emptyClearInputs = self.dockInputs()
            }, refreshPresentation: { [weak self] now in
                guard let self else { return }
                if !self.refreshCurrentPresentation(at:now) {
                    self.pairedProjection.invalidate()
                    if !self.deadlineLifecycleSuspended { self.deadlineDriver.replace() }
                }
            })
    }()
    private var activityExpiryTask: Task<Void, Never>?
    private let clock: EngineDockClock
    // Internal injection seam: the production entry retains the system clock.
    var currentDate: @MainActor () -> Date {
        get { clock.now }
        set { clock.now = newValue }
    }
    private var resetNotifier:EngineResetNotifier?
    private var forecastNotifier:EngineForecastNotifier?
    private var resetScratch:URL?
    private var newsPresence: NewsPresenceMonitor?
    private var seenBinding: SeenSubscriptionsBinding?
    /// Decision 3 (D474): the seen-subscriptions memory, for the cockpit's `seen` message. Nil unless the live app installed it.
    public private(set) var seenSubscriptions: DockSeenSubscriptionsStore?
    public var menuDidChange: (() -> Void)?
    public private(set) var latestSettings: SettingsApplication?
    public var settingsDidChange: ((SettingsApplication) -> Void)?
    public func applySettings(_ value: SettingsApplication) {
        latestSettings = value
        setLanguage(value.snapshot.preferences.language.rawValue)
        dock.apply(value)
        settingsDidChange?(value)
        menuDidChange?()
    }
    public init(configuration: EngineClientConfiguration, createsNativePanels: Bool = true,
                dockEnvironment: (@MainActor () -> DockEdgeEnvironment)? = nil, edition: ProductionEdition = .current,
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
        dock = ProductionDockFactory.community(createsNativePanels: createsNativePanels, nativeEnvironment: dockEnvironment, currentDate: { clock.now() }, edition: edition)
        adapter.bindDockMenuTracking(dock)
        dock.newsClock = adapter.newsClock
        _ = pairedProjection
        // G3-136: the empty ring's one line comes from the same admitted rows as the menu.
        dock.emptyStationReason = { [weak self] in
            guard let self else { return nil }
            let value = self.provider.dockContent
            return WidgetEmptyReason.text(status: value.status, rows: value.settingsRows.isEmpty ? value.dockRows : value.settingsRows,
                                          language: self.adapter.language == "en" ? .english : .chinese)
        }
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
            let inputs = self.dockInputs()
            if inputs.status == .cleared { self.replacedInputs = nil; self.emptyClearInputs = nil }
            // WP-17: nothing the Dock projects changed (a health, consent or cockpit reply). The admitted content
            // stays exactly as valid as it was; only the menu, which also shows those replies, is refreshed.
            else if inputs == self.replacedInputs, !self.pairedProjection.isProjecting, !self.deadlineLifecycleSuspended,
                    inputs.rowsSequence == nil || self.pairedProjection.isCurrent(self.pairedProjection.generation) {
                self.menuDidChange?()
                return
            }
            self.replacedInputs = nil
            self.adapter.scrubInvalidatedMenus()
            let previous = self.pairedProjection.acceptedDelivery
            self.pairedProjection.invalidate()
            if self.pairedProjection.isProjecting { self.pendingProjectionReplacement = true; return }
            guard !self.deadlineLifecycleSuspended else { return }

            let content = self.provider.dockContent
            self.cardReplacementMembers = []
            if let previous, self.store.snapshot.delivery == previous, content.status == .ready {
                let catalogue = EngineAccountMemberCatalogue(rows: content.dockRows)
                self.cardReplacementMembers = Set(catalogue.members.compactMap { member in
                    guard member.subscriptionRef == member.id, member.isStable,
                          member.row.state == .fresh || member.row.state == .stale,
                          member.row.consent == .allowed || member.row.consent == .implicit || member.row.consent == .notRequired,
                          member.account.valueState == .retained || member.account.valueState == .current else { return nil }
                    return member.id
                })
            }
            defer {
                self.cardReplacementMembers = []
                if self.dock.finishCardReplacement() {
                    self.dock.refreshDockContent()
                    self.menuDidChange?()
                }
            }
            self.deadlineDriver.replace()
            if !self.pendingProjectionReplacement { self.replacedInputs = inputs }
        }
    }
    /// D324/D327: puts the resource ring after the admitted subscription rings (B4, the cockpit's order) and keeps it current from the
    /// one ResourceSampler. The caller reports visibility (plugin on, cockpit column, widget shown) on the binding.
    public func installResourceWidget(sampler: ResourceSampler, language: @escaping () -> ResourceLanguage) -> ResourceWidgetBinding {
        let provider = ResourceDockContentProvider(base: admittedCache)
        // B9: the ring is added only to admitted content, never to the empty gap of a replacement.
        provider.baseAdmitted = { [weak cache = admittedCache] in cache?.hasAdmittedContent == true }
        dock.setDockContentProvider(provider)
        let binding = ResourceWidgetBinding(sampler: sampler, provider: provider, language: language,
                                            refreshCard: { [weak self] in self?.dock.refreshPluginCard() },
                                            refreshRing: { [weak self] input in
                                                guard let self, self.admittedCache.isAdmissible(at: self.deadlineWall()) else { return false }
                                                return self.dock.refreshPluginRing(input)
                                            }) { [weak self] in self?.dock.refreshDockContent() }
        // macrevb-1096-4: the hover card reads the latest sample, not the rows captured at the last ring redraw.
        dock.livePluginCard = { [weak binding] id in id == ResourceDockBridge.subscriptionID ? binding?.liveCard() : nil }
        return binding
    }
    #if DEBUG
    func installDockVisibilityTimingForChecks(clock: @escaping () -> TimeInterval, scheduler: any DockEdgeScheduling) {
        dock.installVisibilityTimingForChecks(clock: clock, scheduler: scheduler)
    }
    #endif

    public var presentedContent: DockContent { presentedContent(at: deadlineWall()) }

    private func presentedContent(at now: Date) -> DockContent {
        admittedCache.makeContent(.init(snapshot: nil, diagnostics: .init(), now: now))
    }
    func setLanguage(_ language: String) {
        guard adapter.language != language else { return }
        adapter.language = language
        if refreshCurrentPresentation(at:deadlineWall()) { return }
        pairedProjection.invalidate()
        if pairedProjection.isProjecting { pendingProjectionReplacement = true; return }
        if !deadlineLifecycleSuspended { deadlineDriver.replace() }
    }
    /// Re-evaluate only the current admitted source inside its original validity interval.
    /// Countdown/age ticks and locale changes use the same atomic path; neither renews source freshness.
    private func refreshCurrentPresentation(at now:Date) -> Bool {
        guard !deadlineLifecycleSuspended, !pairedProjection.isProjecting else { return false }
        let token=pairedProjection.generation
        guard admittedCache.isAdmissible(at:now),
              let candidate=try? pairedProjection.make(.init(snapshot:nil,diagnostics:.init(),now:now)),
              candidate.sourceToken == token, pairedProjection.isCurrent(token) else { return false }
        admittedCache.install(candidate.value,evaluatedAt:now)
        dock.refreshDockContent();menuDidChange?()
        armActivityExpiry()
        return true
    }
    /// Flames must stop when their evidence expires, even if no further engine message arrives.
    private func armActivityExpiry() {
        activityExpiryTask?.cancel(); activityExpiryTask=nil
        guard !deadlineLifecycleSuspended else { return }
        let now=deadlineWall()
        guard let expiry=presentedContent(at:now).snapshot.inputs.compactMap({$0.working?.expiresAt}).filter({$0>now}).min() else { return }
        activityExpiryTask=Task { @MainActor [weak self] in
            do { try await Task.sleep(for:.seconds(expiry.timeIntervalSince(now))); try Task.checkCancellation() }
            catch { return }
            guard let self else { return }
            self.activityExpiryTask=nil
            if !self.refreshCurrentPresentation(at:self.deadlineWall()) {
                self.pairedProjection.invalidate()
                if !self.deadlineLifecycleSuspended { self.deadlineDriver.replace() }
            }
        }
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
    func installResetEvents(settings: SettingsStore, live: Bool, isolatedLedger: URL? = nil) {
        let base: URL
        if let isolatedLedger {
            base = isolatedLedger.deletingLastPathComponent()
        } else if live {
            base=ProfileRoot.current.modelPlanSupport
        } else { base=FileManager.default.temporaryDirectory.appendingPathComponent("modelplan-s4-"+UUID().uuidString,isDirectory:true);resetScratch=base }
        // D466: the news clock survives a restart (one small JSON beside the notification ledger); the content provider
        // ticks it and the Dock host records looks on the same instance.
        if live, isolatedLedger == nil {
            let clock = DockNewsClockStore(url: base.appendingPathComponent("news-clock.json"))
            adapter.newsClock = clock; dock.newsClock = clock
            // Master spec §5.3: present = awake, unlocked, in the console session and not idle (read at the refresh
            // tick); sleep, screen sleep and lock close the span through their notifications.
            adapter.isPresent = { NewsPresenceMonitor.isPresentNow() }
            newsPresence?.stop(); newsPresence = NewsPresenceMonitor(clock: clock)
            // Decision 3 / C45 (D474): rings and cockpit columns only after a first good reading on this Mac. Member
            // keys only, 0600, cleared with Forget and a privacy clear.
            let seen = DockSeenSubscriptionsStore(url: base.appendingPathComponent("seen-subscriptions.json"))
            adapter.seenSubscriptions = seen; seenSubscriptions = seen
            seenBinding?.stop(); seenBinding = SeenSubscriptionsBinding(store: store, seen: seen)
        }
        do {
            let notifier=try EngineResetNotifier.recovering(composition:self,settings:settings,cacheURL:isolatedLedger ?? base.appendingPathComponent("reset-notifications.json"),deliverToSystem:live && isolatedLedger == nil)
            resetNotifier=notifier;notifier.start()
        } catch {
            Logger(subsystem:"ai.modelplan.notifications",category:"reset-ledger").error("Reset notification service could not be started.")
        }
        // ALR-52 (WP-11): v1 sends only reset and official-extra-reset notifications. A forecast is shown on the ALERT
        // lamp and in its list, never as a system notification, so no forecast notifier is attached.
        if NotificationKind.delivered.contains(.forecast) {
            let forecasts=EngineForecastNotifier(settings:settings,cacheURL:base.appendingPathComponent("forecast-notifications.json"),deliverToSystem:live,now:{ [weak self] in self?.currentDate() ?? Date() })
            forecastNotifier=forecasts;_=store.attach(forecasts)
        }
    }
    /// The same seam for forecast notices (unused while ALR-52 sends no forecast notifications).
    public func setForecastNotificationDelivery(_ delivery:@escaping @MainActor (String) async throws -> Void) {
        forecastNotifier?.deliveryOverride=delivery
        forecastNotifier?.apply(store.snapshot)
    }
    /// A synthetic delivery adapter can be supplied by a non-windowed host.
    public func setResetNotificationDelivery(_ delivery:@escaping @MainActor (String) async throws -> Void) {
        setResetNotificationDelivery { id, _ in try await delivery(id) }
    }

    func setResetNotificationDelivery(_ delivery: @escaping @MainActor (String, String) async throws -> Void) {
        resetNotifier?.deliveryOverride = delivery
        resetNotifier?.apply(store.snapshot)
    }
    /// The same seam with the Settings notification kind (`.reset` quota resets, `.official`
    /// public reset events).
    public func setNotificationDelivery(_ delivery:@escaping @MainActor (NotificationKind,String) async throws -> Void) {
        resetNotifier?.kindDeliveryOverride=delivery
        resetNotifier?.apply(store.snapshot)
    }
    /// True only when reset notifications can actually be delivered (system or host adapter).
    public var notificationDeliveryAvailable:Bool { resetNotifier?.delivers ?? false }
    private var fallbackStatusText: String {
        let english = adapter.language == "en"
        let fallback: String
        switch provider.dockContent.status {
        case .loading:
            fallback = english ? "Loading readings. If this persists, check Settings." : "正在读取；若持续无响应，请检查设置。"
        case .empty:
            fallback = english ? "No readings are available. Check Settings." : "暂无读数，请检查设置。"
        case .failed:
            fallback = EngineRowsText.readingServiceUnavailable.value(english ? .english : .chinese)
        case .cleared:
            fallback = english ? "Readings cleared. Check Settings to reconnect." : "读数已清除，请在设置中重新连接。"
        case .ready:
            fallback = english ? "Readings unavailable. Check Settings." : "读数不可用，请检查设置。"
        }
        return fallback
    }
    /// G3-122: the menu-bar title as a reading, so the status item can keep its number across a projection gap.
    /// Definitive (`.none` or a value): icon mode, a privacy clear, no rows, and whatever an admitted content says.
    /// A gap (`.unavailable`): no Settings yet, or no admitted content (between the clear and the install of an
    /// engine delivery, a withdrawn or suspended projection).
    var menuTitleReading: StatusTitleReading {
        guard let settings = latestSettings else { return .unavailable }
        guard settings.snapshot.preferences.menuDisplay != .icon, settings.snapshot.preferences.menuDisplay != .automatic else { return .none }
        if provider.dockContent.status == .cleared || provider.dockContent.status == .empty { return .none }
        let now = deadlineWall()
        guard let content = admittedCache.admittedContent(.init(snapshot: nil, diagnostics: .init(), now: now)) else { return .unavailable }
        return EngineMenuBarTitle.reading(inputs: content.snapshot.inputs, preferences: settings.snapshot.preferences, now: now)
    }
    /// D377: the tracked quota for the automatic display, with the same gap rules as `menuTitleReading`.
    var menuAutoInput: StatusAutoInput {
        guard let settings = latestSettings else { return .unavailable }
        if provider.dockContent.status == .cleared || provider.dockContent.status == .empty { return .none }
        let now = deadlineWall()
        guard let content = admittedCache.admittedContent(.init(snapshot: nil, diagnostics: .init(), now: now)) else { return .unavailable }
        return EngineMenuBarTitle.autoInput(inputs: content.snapshot.inputs, preferences: settings.snapshot.preferences, now: now)
    }
    public var menuPresentation: CommunityMenuBarPresentation {
        let now = deadlineWall()
        let content = presentedContent(at: now)
        let detail = (content.menuStatusLines ?? []).joined(separator: " · ")
        let title = latestSettings.map {
            EngineMenuBarTitle.make(inputs: content.snapshot.inputs, preferences: $0.snapshot.preferences, now: now)
        } ?? ""
        return .init(title: title, detail: detail.isEmpty ? fallbackStatusText : detail)
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
    func suspendDeadlines() { deadlineLifecycleSuspended = true; activityExpiryTask?.cancel(); activityExpiryTask = nil; pairedProjection.invalidate(); deadlineDriver.suspend() }
    func resumeDeadlines() { deadlineLifecycleSuspended = false; pairedProjection.invalidate(); deadlineDriver.replace() }
    public func stop() async { activityExpiryTask?.cancel(); activityExpiryTask = nil; resetNotifier?.stop(); newsPresence?.stop(); newsPresence = nil; seenBinding?.stop(); seenBinding = nil; deadlineDriver.close(); dock.close(); await client.stop(); if let resetScratch { try? FileManager.default.removeItem(at:resetScratch) } }
}

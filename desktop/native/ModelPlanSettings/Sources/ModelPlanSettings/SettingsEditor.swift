// SPDX-License-Identifier: MIT
import Foundation

/// The edits released for this Settings increment. Other catalogue rows remain unavailable for editing.
public enum SettingsB20Edit: Equatable, Sendable {
    case theme(SettingsTheme), size(SettingsSize), motion(AccessibilityPreference), transparency(AccessibilityPreference)
    case percentageMode(PercentageMode), showPercentages(Bool), percentagePin(String, PercentagePin)
    case redBelow(Int), sliverAlert(Bool), showAllModels(Bool)

    public static let keys: Set<SettingKey> = [
        .theme, .size, .motion, .transparency, .percentageMode, .showPercentages, .percentagePin, .redBelow, .sliverAlert, .showAllModels,
    ]

    public init(key: SettingKey, value: String, subscriptionID: String? = nil) throws {
        switch key {
        case .theme: if let v = SettingsTheme(rawValue: value) { self = .theme(v); return }
        case .size: if let v = SettingsSize(rawValue: value) { self = .size(v); return }
        case .motion: if let v = AccessibilityPreference(rawValue: value) { self = .motion(v); return }
        case .transparency: if let v = AccessibilityPreference(rawValue: value) { self = .transparency(v); return }
        case .percentageMode: if let v = PercentageMode(rawValue: value) { self = .percentageMode(v); return }
        case .showPercentages: if let v = Bool(value) { self = .showPercentages(v); return }
        case .percentagePin:
            if let id = subscriptionID, !id.isEmpty, let v = PercentagePin(rawValue: value) {
                self = .percentagePin(id, v); return
            }
        case .redBelow: if let v = Int(value), SettingsPreferences.redBelowChoices.contains(v) { self = .redBelow(v); return }
        case .sliverAlert: if let v = Bool(value) { self = .sliverAlert(v); return }
        case .showAllModels: if let v = Bool(value) { self = .showAllModels(v); return }
        default: break
        }
        throw SettingsError.invalidPreference
    }

    func apply(to p: inout SettingsPreferences) throws {
        switch self {
        case .theme(let v): p.theme = v
        case .size(let v): p.size = v
        case .motion(let v): p.motion = v
        case .transparency(let v): p.transparency = v
        case .percentageMode(let v): p.percentageMode = v
        case .showPercentages(let v): p.showPercentages = v
        case .redBelow(let v): p.redBelow = v
        case .sliverAlert(let v): p.sliverAlert = v
        case .showAllModels(let v): p.showAllModels = v
        case .percentagePin(let id, let v):
            var setting = p.subscriptionSettings[id] ?? .init()
            setting.percentagePin = v
            p.subscriptionSettings[id] = setting
        }
        try p.validate()
    }
}

/// A successful edit from this editor, with its exact CAS input and committed output.
/// A reset is explicit even when the persisted ledger was already empty.
public struct SettingsCommittedEdit: Sendable {
    public enum Kind: Equatable, Sendable { case preferences, resetHelpHints }
    public let before: SettingsSnapshot, after: SettingsSnapshot
    public let kind: Kind
    let origin: SettingsStore
    public func belongs(to store: SettingsStore) -> Bool { origin === store }
    public var resetRequest: SettingsHostRequest? {
        if case .resetHelpHints = kind { return .init(revision: after.revision, intent: .action(.resetHelpHints)) }
        return nil
    }
}

public enum SettingsEditorError: Error, Equatable { case notLoaded, editInProgress, subscriptionUnavailable, staleContext, actionUnavailable }

/// One presenter over the app's existing store. No service calls or second preference file.
@MainActor public final class SettingsEditor {
    public let store: SettingsStore
    public let connections: SettingsConnectionController
    private var committedSnapshot: SettingsSnapshot?
    private static let unavailableZCodeID = "zai#unknown"
    // This association belongs to this app session. The anonymous row and the
    // saved settings never need a copy of the account reference.
    private var lastZCodeMemberID: String?
    /// Saved next to the anonymous station's hide only when no ZCode account was known when it was hidden.
    /// The first sole account to arrive takes the hide over and the marker is removed in that same transaction.
    /// A hide made while an account is known never writes it, so it never transfers to a different account.
    public static let anonymousZCodeHideMarker = "zai#unknown#first-account"
    /// The account taking over a marked anonymous hide. Until the takeover is saved, every presented snapshot
    /// already shows that account hidden, so no publication (Dock, menu, Settings) shows it in between.
    private var anonymousCarryID: String?
    static let anonymousCarryAttempts = 200
    public var snapshot: SettingsSnapshot? {
        guard let committedSnapshot else { return nil }
        var preferences = committedSnapshot.preferences
        if preferences.subscriptions.hiddenIDs.remove(Self.anonymousZCodeHideMarker) != nil, let anonymousCarryID {
            preferences.subscriptions.hiddenIDs.insert(anonymousCarryID)
        }
        if let lastZCodeMemberID {
            if preferences.subscriptions.hiddenIDs.contains(lastZCodeMemberID) {
                preferences.subscriptions.hiddenIDs.insert(Self.unavailableZCodeID)
            } else {
                preferences.subscriptions.hiddenIDs.remove(Self.unavailableZCodeID)
            }
        }
        return .init(revision: committedSnapshot.revision, preferences: preferences)
    }
    public private(set) var environment: SettingsEnvironment
    public private(set) var context: SettingsPageContext
    public private(set) var isSaving = false
    public private(set) var lastChangedSubscriptionID: String?
    /// Presentation changes include loading/saving and environment changes; they are not commit receipts.
    public var onChange: (() -> Void)?
    /// Called only after persistence succeeds. Assembly must forward this snapshot to actual consumers.
    public var onCommit: ((SettingsSnapshot, EffectiveSettings) -> Void)?
    /// System accessibility/appearance changes never write preferences.
    public var onEnvironmentChange: ((SettingsSnapshot, EffectiveSettings) -> Void)?
    /// Emitted only after a successful explicit edit. The host must check revision and its own authorization.
    public var onHostRequest: ((SettingsHostRequest) -> Void)?
    private var changeObservers: [UUID: () -> Void] = [:]
    private var firstRunPresentation: (id: UUID, action: () -> Void, about: (() -> Void)?)?
    public var canPresentFirstRun: Bool { firstRunPresentation != nil || onHostRequest != nil }
    /// A local navigation seam, separate from the app's one system-effect receiver.
    public func bindFirstRunPresentation(_ action: @escaping () -> Void, about: (() -> Void)? = nil) -> UUID? {
        guard firstRunPresentation == nil else { return nil }
        let id = UUID(); firstRunPresentation = (id, action, about); notifyChange(); return id
    }
    public var canPresentConnectionHelp: Bool { firstRunPresentation?.about != nil }
    public func requestConnectionHelp() throws {
        guard !isSaving, let about = firstRunPresentation?.about else { throw SettingsEditorError.actionUnavailable }
        about()
    }
    public func unbindFirstRunPresentation(_ id: UUID) {
        if firstRunPresentation?.id == id { firstRunPresentation = nil; notifyChange() }
    }
    public private(set) var lastCommitDeliveryFailure: SettingsCommitDeliveryFailure?
    private let commitObserverLimit: Duration
    private lazy var commitObservers = SettingsCommitObservers(limit: commitObserverLimit) { [weak self] failure in
        self?.lastCommitDeliveryFailure = failure
        self?.notifyChange()
    }

    /// A save waits at most two seconds for all app observers together. A shorter bound can be
    /// injected for tests/hosts; this does not change hint display/dwell timing or persisted policy.
    public init(store: SettingsStore, context: SettingsPageContext = .init(), environment: SettingsEnvironment = .init(),
                commitObserverLimit: Duration = .seconds(2), connectionService: SettingsConnectionService? = nil) {
        precondition(commitObserverLimit > .zero && commitObserverLimit <= .seconds(2))
        self.commitObserverLimit = commitObserverLimit
        self.store = store; self.context = context; self.environment = environment
        self.connections = SettingsConnectionController(service: connectionService)
        rememberZCodeMember(in: context)
    }
    public var effective: EffectiveSettings? { snapshot.map { EffectiveSettings($0.preferences, environment: environment) } }
    private func accept(_ candidate: SettingsSnapshot) {
        // A suspended reload must not replace a newer commit/reload that resumed first.
        if candidate.revision >= (committedSnapshot?.revision ?? 0) { committedSnapshot = candidate }
        // Every newly accepted document (launch restore, reload, any commit or a rejected one's re-read) decides the
        // takeover again: a removed marker ends it, a marker that landed after the account arrived starts it.
        if committedSnapshot?.preferences.subscriptions.hiddenIDs.contains(Self.anonymousZCodeHideMarker) != true {
            anonymousCarryID = nil
        } else {
            carryAnonymousHideIfNeeded()
        }
    }
    public func observeChanges(_ observer: @escaping () -> Void) -> UUID {
        let id = UUID(); changeObservers[id] = observer; return id
    }
    public func removeChangeObserver(_ id: UUID) { changeObservers.removeValue(forKey: id) }
    /// Additive app consumers never replace the window's onChange or the coordinator's onCommit.
    public func observeCommittedEdits(onFailure: @escaping (SettingsCommitDeliveryFailure) -> Void = { _ in },
                                      _ observer: @escaping @MainActor (SettingsCommittedEdit) async -> Void) -> UUID {
        commitObservers.observe(onFailure: onFailure, observer)
    }
    public func removeCommitObserver(_ id: UUID) { commitObservers.remove(id) }
    private func notifyChange() {
        onChange?()
        for observer in Array(changeObservers.values) { observer() }
    }
    public func reload() async { accept(await store.snapshot()); notifyChange() }
    /// G3-71: the hidden-icon notice was dismissed; it stays dismissed until the notice clears (situation changes).
    public private(set) var statusItemNoticeDismissed = false
    public func dismissStatusItemNotice() { statusItemNoticeDismissed = true; notifyChange() }
    /// True only while `update(context:)` tells the observers (an engine delivery, not a user edit). A hidden Settings
    /// window may hold such a refresh until it is shown (G3-161).
    public private(set) var isDeliveringContextUpdate = false
    public func update(context: SettingsPageContext) {
        self.context = context
        rememberZCodeMember(in: context)
        if context.statusItemNotice == nil { statusItemNoticeDismissed = false }
        isDeliveringContextUpdate = true
        defer { isDeliveringContextUpdate = false }
        notifyChange()
    }
    private func rememberZCodeMember(in context: SettingsPageContext) {
        let members = context.subscriptions.filter {
            $0.tool == "zai" && !$0.isUnstable && $0.id != Self.unavailableZCodeID
        }
        // Empty or unavailable deliveries cannot replace the last known membership.
        guard !members.isEmpty else { return }
        lastZCodeMemberID = members.count == 1 ? members.first?.id : nil
        carryAnonymousHideIfNeeded()
    }
    /// Invariant: a hide made on the anonymous station while no account was known applies to the first known
    /// account before that account's first publication, and a concurrent save never drops it. The presented
    /// snapshot takes it over synchronously (callers forward that snapshot in the same main-actor turn); the
    /// durable takeover is queued and retried behind any save in flight.
    private func carryAnonymousHideIfNeeded() {
        guard anonymousCarryID == nil, let member = lastZCodeMemberID,
              committedSnapshot?.preferences.subscriptions.hiddenIDs.contains(Self.anonymousZCodeHideMarker) == true else { return }
        anonymousCarryID = member
        Task { [weak self] in await self?.persistAnonymousCarry(to: member) }
    }
    /// Whether a shown takeover of the anonymous hide is not saved yet.
    public var hasUnsavedAnonymousHideTakeover: Bool {
        anonymousCarryID != nil && committedSnapshot?.preferences.subscriptions.hiddenIDs.contains(Self.anonymousZCodeHideMarker) == true
    }
    /// Quit waits here so the hide stays bound to the account it was already shown on: an unsaved takeover
    /// would leave the marker unbound and let a different first account claim it on the next launch.
    /// Bounded: a save in flight releases within its own two-second observer limit.
    public func finishAnonymousHideTakeover(timeout: Duration = .seconds(4)) async {
        let deadline = ContinuousClock.now + timeout
        while hasUnsavedAnonymousHideTakeover, ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(20))
        }
    }
    private func persistAnonymousCarry(to member: String) async {
        let marker = Self.anonymousZCodeHideMarker, fallbackID = Self.unavailableZCodeID
        for _ in 0..<Self.anonymousCarryAttempts {
            guard anonymousCarryID == member,
                  committedSnapshot?.preferences.subscriptions.hiddenIDs.contains(marker) == true else { break }
            if !isSaving {
                // Decided against the stored document: an unhide or a known-account choice that removed the
                // marker first wins, and this write then changes nothing.
                if (try? await transact(subscriptionID: nil, edit: { preferences in
                    guard preferences.subscriptions.hiddenIDs.remove(marker) != nil else { return }
                    preferences.subscriptions.hiddenIDs.formUnion([member, fallbackID])
                })) != nil { break }
            }
            try? await Task.sleep(for: .milliseconds(50))
        }
    }
    /// The host's live read of the macOS login item. An explicit login choice is decided against it,
    /// not against the observation cached when the app started; nil keeps that cached observation.
    public var observeLogin: (@MainActor () -> LoginServiceState)?
    private func currentLogin() -> LoginServiceState {
        guard let observeLogin else { return context.capabilities.login }
        let observed = observeLogin()
        if observed != context.capabilities.login { context.capabilities.login = observed; notifyChange() }
        return observed
    }
    public func update(environment: SettingsEnvironment) {
        self.environment = environment; notifyChange()
        if let snapshot, let effective { onEnvironmentChange?(snapshot, effective) }
    }
    @discardableResult public func commit(_ edit: SettingsB20Edit) async throws -> SettingsSnapshot {
        let id: String? = { if case .percentagePin(let id, _) = edit { return id }; return nil }()
        return try await transact(subscriptionID: id, quotaPreviewID: id) { try edit.apply(to: &$0) }
    }
    @discardableResult public func commit(_ edit: SettingsB21Edit) async throws -> SettingsSnapshot {
        // An unstable member has no durable order; a stable member may still
        // move among the other stable members without saving temporary keys.
        let ids: [String]
        if case .moveSubscription = edit { ids = context.subscriptions.filter { !$0.isUnstable }.map(\.id) }
        else { ids = context.subscriptions.map(\.id) }
        let kind: SettingsCommittedEdit.Kind
        if case .resetHints = edit { kind = .resetHelpHints } else { kind = .preferences }
        // The unavailable station is an anonymous presentation fallback for the sole
        // ZCode member. Save its display choice with the normal toggle, in the same
        // local preferences transaction, without attaching an account to that station.
        let fallbackVisibility: Bool?
        let editsUnavailableZCode = edit.subscriptionID == Self.unavailableZCodeID
        if case .visible(let id, let visible) = edit,
           context.subscriptions.filter({ $0.tool == "zai" }).map(\.id) == [id] {
            fallbackVisibility = visible
        } else {
            fallbackVisibility = nil
        }
        let fallbackID = Self.unavailableZCodeID
        // Invariant: a hide choice persists across the station's availability changes. When the account is
        // known, a station edit is saved on both keys in one transaction and the association is kept.
        let carriedID: String? = (editsUnavailableZCode && fallbackVisibility != nil) ? lastZCodeMemberID : nil
        // Only a hide made with no account known may later pass to an account (the first one). Any other
        // visibility choice for the ZCode station or its sole account clears that pending takeover.
        let marksAnonymousHide = editsUnavailableZCode && fallbackVisibility == false && carriedID == nil
        let marker = Self.anonymousZCodeHideMarker
        let committed = try await transact(subscriptionID: edit.subscriptionID, kind: kind,
                                           editsUnavailableZCodeVisibility: editsUnavailableZCode && fallbackVisibility != nil && carriedID == nil) { preferences in
            try edit.apply(to: &preferences, catalogue: ids)
            if let fallbackVisibility {
                try SettingsB21Edit.visible(fallbackID, fallbackVisibility).apply(to: &preferences, catalogue: ids)
                if let carriedID {
                    if fallbackVisibility { preferences.subscriptions.hiddenIDs.remove(carriedID) }
                    else { preferences.subscriptions.hiddenIDs.insert(carriedID) }
                }
                if marksAnonymousHide { preferences.subscriptions.hiddenIDs.insert(marker) }
                else { preferences.subscriptions.hiddenIDs.remove(marker) }
            }
        }
        let intent: SettingsHostIntent?
        switch edit {
        case .login(let enabled):
            intent = LoginServicePolicy.request(choice: enabled, observed: currentLogin(), reason: .explicitUserChoice).map(SettingsHostIntent.action)
        case .resetHints: intent = .action(.resetHelpHints)
        case .shortcut:
            intent = .shortcutPreferencesChanged(openCockpit: committed.preferences.openShortcut, toggleDock: committed.preferences.dockShortcut)
        default: intent = nil
        }
        if let intent { onHostRequest?(.init(revision: committed.revision, intent: intent)) }
        return committed
    }
    @discardableResult public func commit(_ edit: SettingsB22Edit) async throws -> SettingsSnapshot {
        let previous = snapshot?.preferences.notifications.optedIn ?? false
        let saved = try await transact(subscriptionID: nil) { try edit.apply(to: &$0) }
        if case .notificationConsent(let enabled) = edit {
            onHostRequest?(.init(revision: saved.revision, intent: .notificationConsentChanged(previous: previous, enabled: enabled)))
        }
        return saved
    }
    /// User actions without a preferences mutation. Host requests are never commit receipts.
    public func request(_ action: SettingsB22Action) throws {
        guard !isSaving else { throw SettingsEditorError.editInProgress }
        guard let snapshot else { throw SettingsEditorError.notLoaded }
        if case .previewFirstRun = action, context.capabilities.firstRunPreviewAvailable, let presentation = firstRunPresentation {
            presentation.action(); return
        }
        guard let onHostRequest else { throw SettingsEditorError.actionUnavailable }
        let intent: SettingsHostIntent
        switch action {
        case .clearAppCache:
            guard context.capabilities.appCacheClearAvailable else { throw SettingsEditorError.actionUnavailable }
            intent = .action(.clearAppCache)
        case .openLink(let link): intent = .openPublicLink(link)
        case .openSystemSettings(let pane): intent = .openSystemSettings(pane)
        case .checkForUpdates:
            guard context.capabilities.updateServiceAvailable else { throw SettingsEditorError.actionUnavailable }
            intent = .checkForUpdates
        case .previewFirstRun:
            guard context.capabilities.firstRunPreviewAvailable else { throw SettingsEditorError.actionUnavailable }
            intent = .previewFirstRun
        case .exportDiagnostics:
            guard context.capabilities.diagnosticsExportAvailable else { throw SettingsEditorError.actionUnavailable }
            intent = .exportDiagnostics
        }
        onHostRequest(.init(revision: snapshot.revision, intent: intent))
    }
    @discardableResult public func completeFirstRun(options: OnboardingOptions, action: FirstRunAction,
        host: FirstRunHost, expectedRevision: UInt64) async throws -> FirstRunCommit {
        if action == .seeWhatsHere, !context.capabilities.helpMapAvailable { throw SettingsEditorError.actionUnavailable }
        var capabilities = context.capabilities
        capabilities.login = currentLogin()
        let result = try await persist(expectedRevision: expectedRevision, operation: { [store] revision in
            try await store.completeFirstRun(options: options, action: action, host: host,
                                             capabilities: capabilities, expectedRevision: revision)
        }, snapshot: { $0.snapshot })
        onHostRequest?(.init(revision: result.snapshot.revision,
            intent: .firstRunCompleted(effects: result.effects, loginRequest: result.login.request)))
        return result
    }
    private func transact(subscriptionID: String?, quotaPreviewID: String? = nil, kind: SettingsCommittedEdit.Kind = .preferences,
                          editsUnavailableZCodeVisibility: Bool = false,
                          edit: @escaping @Sendable (inout SettingsPreferences) throws -> Void) async throws -> SettingsSnapshot {
        if let id = subscriptionID {
            guard let member = context.subscriptions.first(where: { $0.id == id }), !member.isUnstable else {
                throw SettingsEditorError.subscriptionUnavailable
            }
        }
        let unstable = Set(context.subscriptions.filter(\.isUnstable).map(\.id))
        return try await persist(quotaPreviewID: quotaPreviewID, kind: kind,
                                 editsUnavailableZCodeVisibility: editsUnavailableZCodeVisibility, operation: { [store] revision in
            try await store.update(expectedRevision: revision) { preferences in
                preferences.subscriptionSettings = preferences.subscriptionSettings.filter { !unstable.contains($0.key) }
                preferences.subscriptions = .init(order: preferences.subscriptions.order.filter { !unstable.contains($0) },
                                                   hiddenIDs: preferences.subscriptions.hiddenIDs.subtracting(unstable))
                try edit(&preferences)
            }
        }, snapshot: { $0 })
    }
    private func persist<Value: Sendable>(expectedRevision: UInt64? = nil, quotaPreviewID: String? = nil,
        kind: SettingsCommittedEdit.Kind = .preferences,
        editsUnavailableZCodeVisibility: Bool = false,
        operation: @escaping @Sendable (UInt64) async throws -> Value,
        snapshot receipt: @escaping @Sendable (Value) -> SettingsSnapshot) async throws -> Value {
        guard !isSaving else { throw SettingsEditorError.editInProgress }
        guard let before = snapshot else { throw SettingsEditorError.notLoaded }
        if let expectedRevision, expectedRevision != before.revision {
            throw SettingsError.staleRevision
        }
        isSaving = true; notifyChange()
        defer { isSaving = false; notifyChange() }
        do {
            let result = try await operation(expectedRevision ?? before.revision)
            let committed = receipt(result)
            if editsUnavailableZCodeVisibility && context.subscriptions.contains(where: { $0.id == Self.unavailableZCodeID }) {
                lastZCodeMemberID = nil
            }
            accept(committed)
            if let quotaPreviewID { lastChangedSubscriptionID = quotaPreviewID }
            onCommit?(committed, EffectiveSettings(committed.preferences, environment: environment))
            let transaction = SettingsCommittedEdit(before: before, after: committed, kind: kind, origin: store)
            // Keep the reset boundary until acknowledgment or terminal delivery failure. A deadline
            // never turns this already-successful store commit into a fake save failure/retry.
            await commitObservers.deliver(transaction)
            return result
        } catch {
            // An external writer on this same actor may have advanced. Show its current truth, never retry over it.
            accept(await store.snapshot())
            throw error
        }
    }
}

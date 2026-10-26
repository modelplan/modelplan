// SPDX-License-Identifier: MIT
import Foundation

/// The edits released for this Settings increment. Other catalogue rows remain unavailable for editing.
public enum SettingsB20Edit: Equatable, Sendable {
    case theme(SettingsTheme), size(SettingsSize), motion(AccessibilityPreference), transparency(AccessibilityPreference)
    case percentageMode(PercentageMode), showPercentages(Bool), percentagePin(String, PercentagePin)
    case redBelow(Int), sliverAlert(Bool)

    public static let keys: Set<SettingKey> = [
        .theme, .size, .motion, .transparency, .percentageMode, .showPercentages, .percentagePin, .redBelow, .sliverAlert,
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
        case .redBelow: if let v = Int(value), [10, 16, 20, 25].contains(v) { self = .redBelow(v); return }
        case .sliverAlert: if let v = Bool(value) { self = .sliverAlert(v); return }
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
        case .percentagePin(let id, let v):
            var setting = p.subscriptionSettings[id] ?? .init()
            setting.percentagePin = v
            p.subscriptionSettings[id] = setting
        }
        try p.validate()
    }
}

public enum SettingsEditorError: Error, Equatable { case notLoaded, editInProgress, subscriptionUnavailable }

/// One presenter over the app's existing store. No service calls or second preference file.
@MainActor public final class SettingsEditor {
    public let store: SettingsStore
    public private(set) var snapshot: SettingsSnapshot?
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

    public init(store: SettingsStore, context: SettingsPageContext = .init(), environment: SettingsEnvironment = .init()) {
        self.store = store; self.context = context; self.environment = environment
    }
    public var effective: EffectiveSettings? { snapshot.map { EffectiveSettings($0.preferences, environment: environment) } }
    private func accept(_ candidate: SettingsSnapshot) {
        // A suspended reload must not replace a newer commit/reload that resumed first.
        if candidate.revision >= (snapshot?.revision ?? 0) { snapshot = candidate }
    }
    public func reload() async { accept(await store.snapshot()); onChange?() }
    public func update(context: SettingsPageContext) { self.context = context; onChange?() }
    public func update(environment: SettingsEnvironment) {
        self.environment = environment; onChange?()
        if let snapshot, let effective { onEnvironmentChange?(snapshot, effective) }
    }
    @discardableResult public func commit(_ edit: SettingsB20Edit) async throws -> SettingsSnapshot {
        guard !isSaving else { throw SettingsEditorError.editInProgress }
        guard let before = snapshot else { throw SettingsEditorError.notLoaded }
        if case .percentagePin(let id, _) = edit, !context.subscriptions.contains(where: { $0.id == id }) {
            throw SettingsEditorError.subscriptionUnavailable
        }
        isSaving = true; onChange?()
        defer { isSaving = false; onChange?() }
        do {
            let committed = try await store.update(expectedRevision: before.revision) { try edit.apply(to: &$0) }
            accept(committed)
            if case .percentagePin(let id, _) = edit { lastChangedSubscriptionID = id }
            onCommit?(committed, EffectiveSettings(committed.preferences, environment: environment))
            return committed
        } catch {
            // An external writer on this same actor may have advanced. Show its current truth, never retry over it.
            accept(await store.snapshot())
            throw error
        }
    }
}

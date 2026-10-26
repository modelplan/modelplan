// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanDock
import ModelPlanSettings

/// Why committed truth is being forwarded. Restore/environment/context are not user-service intents.
public enum SettingsApplicationReason: Equatable, Sendable {
    case restore, commit, environment, context
}

/// One immutable transaction for app-owned consumers, including their current subscription context.
public struct SettingsApplication: Sendable {
    public let snapshot: SettingsSnapshot
    public let effective: EffectiveSettings
    public let context: SettingsPageContext
    public let reason: SettingsApplicationReason

    /// Reuse the existing quota projection; used-percent display never changes remaining-based status.
    public func dockReading(for input: DockInstrumentInput, at now: Date) throws -> DockInstrumentReading {
        try DockInstrumentProjection.evaluate(snapshot.preferences.applying(to: input), now: now,
                                             redBelow: Double(effective.redBelow))
    }
}

/// App-scoped adapter over the existing store/editor, not a second preferences owner or file.
/// The host owns these editor receipt callbacks; its native window may independently own onChange.
@MainActor public final class SettingsApplicationCoordinator {
    public let editor: SettingsEditor
    public private(set) var latest: SettingsApplication?
    private let apply: (SettingsApplication) -> Void
    private var pending: (snapshot: SettingsSnapshot, reason: SettingsApplicationReason, contextChanged: Bool)?
    private var isApplying = false

    public init(store: SettingsStore, context: SettingsPageContext = .init(),
                environment: SettingsEnvironment = .init(), apply: @escaping (SettingsApplication) -> Void) {
        editor = SettingsEditor(store: store, context: context, environment: environment)
        self.apply = apply
        editor.onCommit = { [weak self] snapshot, _ in self?.forward(snapshot, reason: .commit) }
        editor.onEnvironmentChange = { [weak self] snapshot, _ in self?.forward(snapshot, reason: .environment) }
    }

    /// Also call after another app-owned writer commits to this same store. No service action is requested.
    public func reload() async {
        await editor.reload()
        if let snapshot = editor.snapshot { forward(snapshot, reason: .restore) }
    }

    @discardableResult public func commit(_ edit: SettingsB20Edit) async throws -> SettingsSnapshot {
        try await editor.commit(edit)
    }

    public func update(environment: SettingsEnvironment) { editor.update(environment: environment) }

    public func update(context: SettingsPageContext) {
        editor.update(context: context)
        if let snapshot = editor.snapshot { forward(snapshot, reason: .context) }
    }

    private func forward(_ snapshot: SettingsSnapshot, reason: SettingsApplicationReason) {
        // A completed save may resume after a newer reload. The successful receipt remains real,
        // but it must not roll consumers back below either known committed revision.
        let floor = max(editor.snapshot?.revision ?? 0, latest?.snapshot.revision ?? 0)
        guard snapshot.revision >= floor else { return }
        pending = (snapshot, reason, reason == .context || pending?.contextChanged == true)
        // Reentrant observations replace pending data, but never erase a context change.
        // Resolve the environment at delivery so a B→A revert cannot leave B queued.
        guard !isApplying else { return }
        isApplying = true
        defer { isApplying = false }
        while let next = pending {
            pending = nil
            guard next.snapshot.revision >= max(editor.snapshot?.revision ?? 0, latest?.snapshot.revision ?? 0) else { continue }
            let effective = EffectiveSettings(next.snapshot.preferences, environment: editor.environment)
            if !next.contextChanged, let latest, latest.snapshot.revision == next.snapshot.revision,
               latest.effective == effective { continue }
            let reason: SettingsApplicationReason = next.contextChanged && next.reason != .commit ? .context : next.reason
            let application = SettingsApplication(snapshot: next.snapshot, effective: effective,
                                                  context: editor.context, reason: reason)
            latest = application
            apply(application)
        }
    }
}

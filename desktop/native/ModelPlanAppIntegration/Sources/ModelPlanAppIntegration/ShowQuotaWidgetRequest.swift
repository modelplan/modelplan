// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanSettings

/// Value-only admission; failures never imply a widget was presented.
enum ShowQuotaWidgetAvailability: Equatable { case ready, paused, loading, saving }
enum ShowQuotaWidgetOutcome: Equatable { case ready, unavailable, changed, failed }

@MainActor enum ShowQuotaWidgetRequest {
    /// Bounded retries for writes that only moved the shared revision (hint ledger,
    /// placement or another Settings edit finishing). Never an unbounded loop.
    static let attemptLimit = 4
    static func availability(paused: Bool, loaded: Bool, saving: Bool) -> ShowQuotaWidgetAvailability {
        if paused { return .paused }
        if !loaded { return .loading }
        if saving { return .saving }
        return .ready
    }
    /// Show Quota Widget is the user's latest explicit choice when it is selected.
    static func perform(editor: SettingsEditor,
                        commit: (@MainActor (SettingsEditor) async throws -> SettingsSnapshot)? = nil) async -> ShowQuotaWidgetOutcome {
        await setVisible(true, editor: editor, commit: commit)
    }
    /// Shared by Show and the widget's own Hide. Other writers share the one store outside
    /// the editor (the Help host saves its hint ledger while the widget is concealed), so a
    /// revision that moved before or during the request is re-read and the switch is saved on
    /// top of it instead of being dropped as stale. Only an opposite choice saved after this
    /// request wins over it.
    static func setVisible(_ visible: Bool, editor: SettingsEditor,
                           commit: (@MainActor (SettingsEditor) async throws -> SettingsSnapshot)? = nil) async -> ShowQuotaWidgetOutcome {
        guard editor.snapshot != nil else { return .unavailable }
        for attempt in 0..<attemptLimit {
            if attempt > 0 || editor.isSaving { await settle(editor) }
            if editor.isSaving { continue }
            let current = await editor.store.snapshot()
            if editor.snapshot?.revision != current.revision { await editor.reload() }
            guard !editor.isSaving, let loaded = editor.snapshot, loaded.revision == current.revision else { continue }
            if loaded.preferences.showDock == visible { return .ready }
            do {
                let saved: SettingsSnapshot
                if let commit { saved = try await commit(editor) }
                else { saved = try await editor.commit(SettingsB21Edit.showDock(visible)) }
                let latest = await editor.store.snapshot()
                if latest.revision != saved.revision || editor.snapshot?.revision != latest.revision { await editor.reload() }
                // An opposite choice saved after this request is not overwritten.
                return latest.preferences.showDock == visible ? .ready : .changed
            } catch SettingsError.staleRevision {
                await editor.reload()
            } catch SettingsEditorError.editInProgress {
                continue
            } catch FoundationPreferenceError.busy {
                continue
            } catch {
                await editor.reload(); return .failed
            }
        }
        await editor.reload()
        return .changed
    }
    /// Lets an in-flight editor save finish before the next bounded attempt.
    private static func settle(_ editor: SettingsEditor) async {
        for _ in 0..<50 where editor.isSaving { try? await Task.sleep(for: .milliseconds(10)) }
    }
}

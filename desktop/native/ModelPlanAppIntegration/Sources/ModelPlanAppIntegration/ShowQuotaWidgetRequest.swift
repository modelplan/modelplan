// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanSettings

/// Value-only admission; failures never imply a widget was presented.
enum ShowQuotaWidgetAvailability: Equatable { case ready, paused, loading, saving }
enum ShowQuotaWidgetOutcome: Equatable { case ready, unavailable, changed, failed }

@MainActor enum ShowQuotaWidgetRequest {
    static func availability(paused: Bool, loaded: Bool, saving: Bool) -> ShowQuotaWidgetAvailability {
        if paused { return .paused }
        if !loaded { return .loading }
        if saving { return .saving }
        return .ready
    }
    static func perform(editor: SettingsEditor, expectedRevision: UInt64,
                        commit: (@MainActor (SettingsEditor) async throws -> SettingsSnapshot)? = nil) async -> ShowQuotaWidgetOutcome {
        guard !editor.isSaving, let snapshot = editor.snapshot else { return .unavailable }
        guard snapshot.revision == expectedRevision else { return .changed }
        let current = await editor.store.snapshot()
        guard !editor.isSaving, editor.snapshot?.revision == expectedRevision,
              current.revision == expectedRevision else { await editor.reload(); return .changed }
        if current.preferences.showDock { return .ready }
        do {
            let saved: SettingsSnapshot
            if let commit { saved = try await commit(editor) }
            else { saved = try await editor.commit(SettingsB21Edit.showDock(true)) }
            let latest = await editor.store.snapshot()
            guard latest.revision == saved.revision, latest.preferences.showDock else {
                await editor.reload(); return .changed
            }
            return .ready
        } catch SettingsError.staleRevision {
            await editor.reload(); return .changed
        } catch SettingsEditorError.editInProgress {
            await editor.reload(); return .unavailable
        } catch {
            await editor.reload(); return .failed
        }
    }
}

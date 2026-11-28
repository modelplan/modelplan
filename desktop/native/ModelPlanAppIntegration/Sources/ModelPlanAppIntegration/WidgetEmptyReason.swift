// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanEngineStore
import ModelPlanSettings
import ModelPlanWire

/// G3-136 (owner 11-18, WP-15): the one line that says why the widget is an empty ring: still reading, a tool that is
/// not allowed to be read (the shared cause table's sentence), or no subscriptions yet. Never a "?".
enum WidgetEmptyReason {
    static func text(status: DockContentStatus, rows: [RowsRow], language: SettingsLanguage) -> String {
        let english = language == .english
        if status == .loading || rows.contains(where: { $0.state == .pending }) { return WidgetCardText.stillReading.value(language) }
        if let row = rows.first(where: { $0.consent != .allowed && $0.consent != .implicit && $0.consent != .notRequired }) {
            let name = english ? row.name.en : row.name.zh
            if let entry = ReaderCauseTable.entry(code: "consent_required", tool: row.id, toolName: name) {
                return name + " · " + entry.reason.value(language)
            }
        }
        // Master spec §3.4: subscriptions are there, but none has given a good reading yet.
        if !rows.isEmpty { return WidgetCardText.noReadingYet.value(language) }
        return WidgetCardText.noSubscriptions.value(language)
    }
}

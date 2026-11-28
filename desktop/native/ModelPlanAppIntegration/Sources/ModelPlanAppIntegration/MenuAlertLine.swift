// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanDock
import ModelPlanSettings

/// Master spec S2 / §3.2 / C30 (D474, ALR-50): the menu's one alert line is the worst quota alert in the SHORT form
/// ("Codex 每周 53% · 预估2d16h · 4d14h后重置"; used up "Codex 5小时 已用完 · 3h18 后重置"). It keeps the reset time.
/// Quota only: a reserve item expiring soon never raises it (§4.1 reserve-line scope). The same alert rule as the widget
/// card footer (`DockCardAlertRule`: red at or under the red line or used up; amber only for a run-out before the reset).
enum MenuAlertLine {
    static func text(_ content: DockContent, redBelow: Double, now: Date, language: SettingsLanguage) -> String? {
        var worst: (alert: DockCardAlert, name: String)?
        for input in content.snapshot.inputs {
            let runOuts = content.snapshot.presentationRows[input.id]?.runOutTimes ?? [:]
            guard let alert = DockCardAlertRule.alert(input: input, runOutTimes: runOuts, redBelow: redBelow, now: now) else { continue }
            if let current = worst?.alert,
               current.severity != alert.severity ? current.severity > alert.severity : current.remaining <= alert.remaining { continue }
            worst = (alert, input.duplicateDisplayName)
        }
        guard let worst else { return nil }
        func minutes(_ date: Date?) -> Double? {
            guard let date else { return nil }
            let seconds = date.timeIntervalSince(now)
            return seconds.isFinite && seconds > 0 ? ceil(seconds / 60) : nil
        }
        return AlertSentence.quota(subscription: SettingsText(worst.name, worst.name),
                                   window: SettingsText(worst.alert.label, worst.alert.label),
                                   remaining: worst.alert.remaining, runOutMinutes: minutes(worst.alert.runOutAt),
                                   resetMinutes: minutes(worst.alert.resetsAt)).short.value(language)
    }
}

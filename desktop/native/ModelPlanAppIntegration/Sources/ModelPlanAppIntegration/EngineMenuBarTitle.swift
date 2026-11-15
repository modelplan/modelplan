// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanDock
import ModelPlanSettings

/// MENU-03 / MENU-04: the text beside the menu-bar icon. It reads the tightest visible
/// subscription through the same evaluator as the Dock, and is empty without a reading.
enum EngineMenuBarTitle {
    static func make(inputs: [DockInstrumentInput], preferences: SettingsPreferences, now: Date) -> String {
        if case .value(let title) = reading(inputs: inputs, preferences: preferences, now: now) { return title }
        return ""
    }
    /// G3-122: the title of one admitted content as a reading. No number here is definitive (`.none`): icon mode, no
    /// shown subscription, or an expired/unknown value (MENU_BAR.md: an expired value leaves no number). Only the
    /// composition's projection gap is `.unavailable`.
    static func reading(inputs: [DockInstrumentInput], preferences: SettingsPreferences, now: Date) -> StatusTitleReading {
        guard preferences.menuDisplay != .icon else { return .none }
        let ids = inputs.map(\.id)
        guard Set(ids).count == ids.count, let order = try? preferences.presentedSubscriptionIDs(ids) else { return .none }
        let byID = Dictionary(uniqueKeysWithValues: inputs.map { ($0.id, $0) })
        var tightest: (input: DockInstrumentInput, remaining: Double)?
        for id in order {
            guard let raw = byID[id] else { continue }
            let input = preferences.applying(to: raw)
            guard let remaining = (try? DockInstrumentProjection.evaluate(input, now: now))?.remainingPercent else { continue }
            if tightest.map({ remaining < $0.remaining }) ?? true { tightest = (input, remaining) }
        }
        guard let tightest else { return .none }
        func shown(_ remaining: Double) -> String {
            "\(Int((tightest.input.showUsedPercent ? 100 - remaining : remaining).rounded()))%"
        }
        if preferences.menuDisplay == .twoWindows {
            func window(_ period: DockQuotaPeriod) -> Double? {
                tightest.input.windows.first { $0.isGeneral && $0.period == period }
                    .flatMap { DockInstrumentProjection.admittedRemaining($0, in: tightest.input, now: now) }
            }
            let week = preferences.language == .english ? "wk" : "周"
            let parts = [window(.fiveHour).map { "5h " + shown($0) }, window(.week).map { week + " " + shown($0) }].compactMap { $0 }
            if !parts.isEmpty { return .value(parts.joined(separator: " ")) }
        }
        return .value(shown(tightest.remaining))
    }
}

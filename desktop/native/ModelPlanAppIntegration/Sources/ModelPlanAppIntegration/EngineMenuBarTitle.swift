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
        guard preferences.menuDisplay != .icon, preferences.menuDisplay != .automatic else { return .none }
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

    /// D377: the tracked quota of the automatic display, the same tightest subscription the other displays read.
    /// `.none` without a shown subscription or an admitted value.
    static func autoInput(inputs: [DockInstrumentInput], preferences: SettingsPreferences, now: Date) -> StatusAutoInput {
        let ids = inputs.map(\.id)
        guard Set(ids).count == ids.count, let order = try? preferences.presentedSubscriptionIDs(ids) else { return .none }
        let byID = Dictionary(uniqueKeysWithValues: inputs.map { ($0.id, $0) })
        // D476: the tracked quota is the most urgent one: red before amber before normal, then the least remaining. Amber
        // is the ring's own rule (an estimate that runs out before the reset).
        func rank(_ status: DockQuotaStatus) -> Int { status == .critical ? 2 : status == .warning ? 1 : 0 }
        let line = Double(preferences.effectiveRedBelow)
        // macrev2-1289-9: in automatic window selection every general window of every account is ranked on its own (the
        // ring's single-window rule picks the lowest number, which can hide an amber window). A window the user pinned
        // (Settings › percentage pin) is the only one that account offers.
        var tightest: (input: DockInstrumentInput, remaining: Double, status: DockQuotaStatus)?
        for id in order {
            guard let raw = byID[id] else { continue }
            let input = preferences.applying(to: raw)
            let candidates = input.selectedWindowID.map { pin in input.windows.filter { $0.id == pin } } ?? input.windows.filter(\.isGeneral)
            for window in candidates {
                var scoped = input; scoped.windows = [window]; scoped.selectedWindowID = window.id
                guard let reading = try? DockInstrumentProjection.evaluate(scoped, now: now, redBelow: line),
                      let remaining = reading.remainingPercent else { continue }
                let status = reading.status
                if let current = tightest {
                    if rank(status) < rank(current.status) { continue }
                    if rank(status) == rank(current.status), remaining >= current.remaining { continue }
                }
                tightest = (input, remaining, status)
            }
        }
        guard let tightest else { return .none }
        let shown = "\(Int((tightest.input.showUsedPercent ? 100 - tightest.remaining : tightest.remaining).rounded()))%"
        return .reading(.init(name: tightest.input.duplicateDisplayName, remaining: tightest.remaining, shown: shown,
                              alertLine: line, amber: tightest.status == .warning))
    }
}

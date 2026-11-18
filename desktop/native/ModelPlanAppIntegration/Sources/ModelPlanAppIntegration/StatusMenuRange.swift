// SPDX-License-Identifier: MIT
import AppKit
import ModelPlanCockpitWeb
import ModelPlanSettings

/// MENU-50 / MENU-52 (WP-09): the status menu's top rows. The selector shows and requests the app's one range
/// (`CockpitRangeState`), the same state as the cockpit's title bar and big-screen keys; the grey line under it is
/// that range's total across every subscription. Strings live in `EngineRowsText`. Reference: CodexBar
/// `StatusItemController` (a custom-view row at the top of the status menu), Stats (a segmented period control).
enum MenuRangeSummary {
    /// V1-FINAL §0 tokens: k / M / B, "33.9M", "212M". Never truncated.
    static func tokens(_ value: Int64) -> String {
        let units: [(Double, String)] = [(1_000_000_000, "B"), (1_000_000, "M"), (1000, "k")]
        let n = Double(value)
        for (scale, unit) in units where n >= scale {
            let v = n / scale
            return String(format: v < 100 ? "%.1f" : "%.0f", locale: Locale(identifier: "en_US_POSIX"), v) + unit
        }
        return String(value)
    }
    /// "全部订阅 ≈$383 · 788M". The ≈cost segment comes with WP-06 (`cost` is its already formatted "≈$383"); a missing
    /// figure is left out, and with neither figure there is no line at all.
    static func line(tokens: Int64?, cost: String?, language: SettingsLanguage) -> String? {
        guard tokens != nil || cost != nil else { return nil }
        var head = EngineRowsText.allSubscriptions.value(language)
        if let cost { head += " " + cost }
        guard let tokens else { return head }
        return head + " · " + Self.tokens(tokens)
    }
}

/// The selector row: three equal segments, the app's range selected. Choosing one asks the app; the menu stays open.
@MainActor final class StatusMenuRangeSelector: NSObject {
    let view: NSView
    let control: NSSegmentedControl
    private let onSelect: (CockpitRange) -> Void
    init(range: CockpitRange, language: SettingsLanguage, enabled: Bool, onSelect: @escaping (CockpitRange) -> Void) {
        self.onSelect = onSelect
        control = NSSegmentedControl(labels: CockpitRange.allCases.map { EngineRowsText.range($0).value(language) },
                                     trackingMode: .selectOne, target: nil, action: nil)
        view = NSView(frame: NSRect(x: 0, y: 0, width: 240, height: 30))
        super.init()
        control.target = self
        control.action = #selector(changed(_:))
        control.segmentDistribution = .fillEqually
        control.controlSize = .small
        control.frame = NSRect(x: 14, y: 4, width: 212, height: 22)
        control.autoresizingMask = [.width]
        control.selectedSegment = CockpitRange.allCases.firstIndex(of: range) ?? 0
        control.isEnabled = enabled
        control.setAccessibilityIdentifier("status.range")
        control.setAccessibilityLabel(EngineRowsText.rangeSelector.value(language))
        view.autoresizingMask = [.width]
        view.addSubview(control)
    }
    /// The range the control shows.
    var shown: CockpitRange { CockpitRange.allCases.indices.contains(control.selectedSegment) ? CockpitRange.allCases[control.selectedSegment] : .today }
    @objc private func changed(_ sender: NSSegmentedControl) {
        guard CockpitRange.allCases.indices.contains(sender.selectedSegment) else { return }
        onSelect(CockpitRange.allCases[sender.selectedSegment])
    }
}

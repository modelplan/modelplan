// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanResources
import ModelPlanSettings

/// The app's side of the resource plugin (D324): it owns the one ResourceSampler's visibility and feeds the cockpit page.
/// Cadence: cockpit column on the shown page = the column setting (2 / 5 / 10 s), widget shown = 10 s, neither = 60 s,
/// plugin off = no sampling. Every admitted sample goes to the page while the column runs (the whole ten-minute window
/// when it starts, then only newer samples).
@MainActor public final class ResourcePluginHost {
    public static let pluginID = "resources"
    public let sampler: ResourceSampler
    private let widget: ResourceWidgetBinding?
    private var feed = ResourcePageFeed()
    private var enabled = false, setting = 5, running: [String] = [], widgetShown = false
    /// Sends one `pluginData` reading to the cockpit page (EngineCockpitCoordinator.sendPluginData).
    public var sendData: ((String, [String: Any]) -> Void)?

    public init(sampler: ResourceSampler, widget: ResourceWidgetBinding? = nil) {
        self.sampler = sampler; self.widget = widget
        sampler.onSample = { [weak self] _ in self?.pushFeed() }
    }

    public var visibility: ResourceVisibility {
        ResourceVisibility(pluginEnabled: enabled, columnShown: enabled && running.contains(Self.pluginID),
                           widgetShown: enabled && widgetShown, columnSetting: setting)
    }

    /// The saved plugin choices (Settings or a page edit): on/off and the column interval.
    public func apply(_ preferences: CockpitPluginPreferences) {
        enabled = preferences.enabledIDs().contains(Self.pluginID)
        setting = preferences.value(Self.pluginID, "intervalSeconds") ?? 5
        update()
    }
    /// The page's `pluginsRunning` ids ([] when no page is shown).
    public func pageRunning(_ ids: [String]) {
        running = ids
        update()
        pushFeed()
    }
    /// Whether the widget (and with it the resource ring) is on screen.
    public func setWidgetShown(_ shown: Bool) {
        widgetShown = shown
        update()
    }

    private func update() {
        let v = visibility
        if let widget { widget.setVisibility(v) } else { sampler.setVisibility(v) }
    }
    private func pushFeed() {
        let running = visibility.columnShown
        guard let samples = feed.next(sampler.history, running: running) else { return }
        // D413: the hour of one-minute folds goes with a reading when it changed (on start, then once a minute).
        let minutes = feed.minutes(sampler.history, running: running) ?? []
        sendData?(Self.pluginID, ResourcePagePayload.data(samples, minutes: minutes))
    }
}

// SPDX-License-Identifier: MIT
import AppKit

/// D376: the words of "Turn Off <plugin>…" and its confirmation, the same on the widget ring, its hover card and the
/// cockpit plugin key.
public struct CockpitPluginClosePrompt: Equatable, Sendable {
    /// The menu item: "关闭资源占用…" / "Turn Off Resources…".
    public let menuTitle: String
    public let messageText: String
    public let informativeText: String
    public let cancelTitle: String
    public let closeTitle: String
    public init(plugin: SettingsText, language: SettingsLanguage) {
        let name = plugin.value(language)
        menuTitle = SettingsWords.text("Turn Off \(name)…", "关闭\(name)…", language)
        messageText = SettingsWords.text("Turn off \(name)?", "关闭\(name)？", language)
        informativeText = SettingsWords.text("You can turn it back on in Settings › Plugins.", "可以在 设置 › 插件 里重新打开。", language)
        cancelTitle = SettingsWords.text("Cancel", "取消", language)
        closeTitle = SettingsWords.text("Turn Off", "关闭", language)
    }
}

/// D376: the confirmation alert. App-modal (there is no document window for a sheet). macOS convention for a
/// destructive action (coordinator correction to the spec): Cancel is added first, so it is the default button
/// (Return); Turn Off is added second and marked destructive.
@MainActor public enum CockpitPluginCloseAlert {
    public static func make(_ prompt: CockpitPluginClosePrompt) -> NSAlert {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = prompt.messageText
        alert.informativeText = prompt.informativeText
        let cancel = alert.addButton(withTitle: prompt.cancelTitle)
        cancel.setAccessibilityIdentifier("plugin.close.cancel")
        let close = alert.addButton(withTitle: prompt.closeTitle)
        close.hasDestructiveAction = true
        close.setAccessibilityIdentifier("plugin.close.confirm")
        return alert
    }
    /// Runs the alert; true when the user chose Turn Off.
    public static func run(_ prompt: CockpitPluginClosePrompt) -> Bool {
        NSApp.activate()
        return make(prompt).runModal() == .alertSecondButtonReturn
    }
}

/// D376: "Turn Off <plugin>…" from the widget ring, its card or the cockpit key. It asks first; on Turn Off it applies
/// `CockpitPluginEdit.setEnabled(id, false)` through the model the Settings switch edits, so the ring, the cockpit
/// column and the sampling all stop. Cancel changes nothing. The presenter is injectable so tests run without UI.
@MainActor public final class CockpitPluginCloser {
    public let model: CockpitPluginSettingsModel
    public var language: () -> SettingsLanguage
    /// Shows the confirmation; true = Turn Off. Defaults to the app-modal alert.
    public var presenter: (CockpitPluginClosePrompt) -> Bool = { CockpitPluginCloseAlert.run($0) }
    public init(model: CockpitPluginSettingsModel, language: @escaping () -> SettingsLanguage) {
        self.model = model; self.language = language
    }
    /// The words for a listed plugin that is on now; nil for anything else (no menu item).
    public func prompt(_ pluginID: String) -> CockpitPluginClosePrompt? {
        guard let plugin = CockpitPluginCatalogue.listed(model.catalogue).first(where: { $0.id == pluginID }),
              model.preferences.enabledIDs(model.catalogue).contains(pluginID) else { return nil }
        return CockpitPluginClosePrompt(plugin: plugin.title, language: language())
    }
    /// Asks, then turns the plugin off. Returns whether it was turned off.
    @discardableResult public func requestClose(_ pluginID: String) async -> Bool {
        guard let prompt = prompt(pluginID), presenter(prompt) else { return false }
        return await model.perform(.setEnabled(pluginID, false))
    }
}

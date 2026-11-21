// SPDX-License-Identifier: MIT
import AppKit
import ModelPlanSettings

/// The cockpit's own right-click menu (the web view shows no WebKit menu). Items run host callbacks only;
/// nothing here reads or writes data. Titles follow the app language.
@MainActor final class CockpitContextMenu: NSObject {
    struct Actions {
        var settings: () -> Void, resetPosition: () -> Void, help: () -> Void
        var setSize: (SettingsSize) -> Void
    }
    let menu = NSMenu()
    private let actions: Actions
    init(language: SettingsLanguage, size: SettingsSize?, actions: Actions) {
        self.actions = actions
        super.init()
        menu.autoenablesItems = false
        func add(_ title: SettingsText, _ selector: Selector, to target: NSMenu) -> NSMenuItem {
            let item = NSMenuItem(title: title.value(language), action: selector, keyEquivalent: "")
            item.target = self; target.addItem(item); return item
        }
        _ = add(EngineRowsText.settings, #selector(openSettings), to: menu)
        _ = add(EngineRowsText.resetPosition, #selector(resetPosition), to: menu)
        let sizeItem = NSMenuItem(title: EngineRowsText.widgetSize.value(language), action: nil, keyEquivalent: "")
        let sizes = NSMenu(); sizes.autoenablesItems = false
        let choices: [(SettingsSize, SettingsText)] = [(.small, EngineRowsText.sizeSmall), (.medium, EngineRowsText.sizeMedium), (.large, EngineRowsText.sizeLarge)]
        for (value, text) in choices {
            let item = add(text, #selector(chooseSize(_:)), to: sizes)
            item.representedObject = value.rawValue; item.state = value == size ? .on : .off
        }
        sizeItem.submenu = sizes; menu.addItem(sizeItem)
        menu.addItem(.separator())
        _ = add(EngineRowsText.help, #selector(showHelp), to: menu)
    }
    @objc private func openSettings() { actions.settings() }
    @objc private func resetPosition() { actions.resetPosition() }
    @objc private func showHelp() { actions.help() }
    @objc private func chooseSize(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let value = SettingsSize(rawValue: raw) else { return }
        actions.setSize(value)
    }
}

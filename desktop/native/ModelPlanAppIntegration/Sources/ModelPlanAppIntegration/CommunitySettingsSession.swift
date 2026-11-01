// SPDX-License-Identifier: MIT
import AppKit
import ModelPlanSettings
import ModelPlanCommunityHost

/// Concrete retained integration passed to the Community host. No second editor/store, service or reader.
@MainActor public final class CommunitySettingsSession: CommunitySettingsIntegration {
    public let windowHost: SettingsWindowHost
    public let settingsMenuItem: NSMenuItem
    public private(set) var helpComposition: InstrumentHelpComposition?
    private let makeHelp: (@MainActor (SettingsApplicationCoordinator) async -> InstrumentHelpComposition)?
    private var helpTask: Task<InstrumentHelpComposition, Never>?
    private var suspended = false
    private var menuLanguageObserver: UUID?
    public init(application: SettingsApplicationCoordinator,
                canPresent: @escaping @MainActor () -> Bool,
                environment: (@MainActor () -> SettingsEnvironment)? = nil,
                activate: @escaping @MainActor () -> Void = { NSApplication.shared.activate() },
                makeSurface: (@MainActor (SettingsEditor) -> any SettingsWindowSurface)? = nil,
                makeHelp: (@MainActor (SettingsApplicationCoordinator) async -> InstrumentHelpComposition)? = nil) {
        self.makeHelp = makeHelp
        windowHost = SettingsWindowHost(application: application, canPresent: canPresent,
            environment: environment, activate: activate, makeSurface: makeSurface)
        settingsMenuItem = windowHost.menuItem(title: SettingsText("Settings…", "设置…").value(application.editor.snapshot?.preferences.language ?? .english))
        menuLanguageObserver = application.editor.observeChanges { [weak self] in self?.refreshMenuLanguage() }
    }
    deinit {
        let editor = windowHost.application.editor, observer = menuLanguageObserver
        Task { @MainActor in if let observer { editor.removeChangeObserver(observer) } }
    }
    private func refreshMenuLanguage() {
        guard let language = windowHost.application.editor.snapshot?.preferences.language else { return }
        settingsMenuItem.title = SettingsText("Settings…", "设置…").value(language)
    }
    public func restorePreferences() async {
        await windowHost.application.reload()
        guard helpComposition == nil, let makeHelp else { return }
        if helpTask == nil { helpTask = Task { await makeHelp(windowHost.application) } }
        if let task = helpTask {
            let help = await task.value
            helpComposition = help; helpTask = nil
            if suspended { help.suspend() }
        }
    }
    public func suspend() { suspended = true; windowHost.suspend(); helpComposition?.suspend() }
}

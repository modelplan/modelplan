// SPDX-License-Identifier: MIT
import Foundation

/// Provisional identifiers retained for callers of the original eight-page draft.
/// The injected structure, not this enum or its declaration order, determines navigation/grouping.
public enum SettingsPane: String, CaseIterable, Sendable {
    case appearance, rings, position, general, notifications, subscriptions, privacy, about
    public var title: SettingsText {
        SettingsStructure.provisional.panes.first { $0.id == rawValue }?.title ?? .init(rawValue, rawValue)
    }
}
public struct SettingsGroupDefinition: Equatable, Sendable {
    public let id: String
    public let title: SettingsText?
    public let keys: [SettingKey]
    public init(id: String, title: SettingsText? = nil, keys: [SettingKey]) {
        self.id = id; self.title = title; self.keys = keys
    }
}
public struct SettingsPaneDefinition: Equatable, Sendable {
    public let id: String
    public let title: SettingsText
    public let groups: [SettingsGroupDefinition]
    public init(id: String, title: SettingsText, groups: [SettingsGroupDefinition]) {
        self.id = id; self.title = title; self.groups = groups
    }
}
func validSettingsIdentifier(_ value: String) -> Bool {
    !value.isEmpty && value.utf8.count <= 64 && !value.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains)
}
public struct SettingsStructure: Equatable, Sendable {
    public let panes: [SettingsPaneDefinition]
    public init(panes: [SettingsPaneDefinition]) throws {
        let keys = panes.flatMap { $0.groups.flatMap(\.keys) }
        guard !panes.isEmpty, panes.count <= 32, Set(panes.map(\.id)).count == panes.count,
              panes.allSatisfy({ pane in
                  validSettingsIdentifier(pane.id) && !pane.title.english.isEmpty && !pane.title.chinese.isEmpty &&
                  !pane.groups.isEmpty && Set(pane.groups.map(\.id)).count == pane.groups.count &&
                  pane.groups.allSatisfy { validSettingsIdentifier($0.id) && !$0.keys.isEmpty }
              }), keys.count == Set(keys).count, Set(keys) == Set(SettingKey.allCases) else { throw SettingsError.invalidCatalogue }
        self.panes = panes
    }
    private init(provisional panes: [SettingsPaneDefinition]) { self.panes = panes }
    /// Current content only, not a final page/visual freeze. Regrouping changes this input table alone.
    public static let provisional = SettingsStructure(provisional: [
        .init(id: "appearance", title: .init("Appearance", "外观"), groups: [.init(id: "main", keys: [.theme,.size,.motion,.transparency])]),
        .init(id: "rings", title: .init("Rings and numbers", "圈和数字"), groups: [.init(id: "main", keys: [.percentageMode,.showPercentages,.percentagePin,.redBelow,.sliverAlert])]),
        .init(id: "position", title: .init("Position and behavior", "位置和行为"), groups: [.init(id: "main", keys: [.showDock,.autoHide,.reveal,.magnification,.fullscreen,.captureHiding,.activeDisplay,.order])]),
        .init(id: "general", title: .init("General", "通用"), groups: [.init(id: "main", keys: [.login,.menuDisplay,.openShortcut,.dockShortcut,.language,.opening,.countdown,.resetHints])]),
        .init(id: "notifications", title: .init("Notifications", "通知"), groups: [.init(id: "main", keys: [.notificationConsent,.forecast,.reset,.official,.expiring,.stale])]),
        .init(id: "subscriptions", title: .init("Subscriptions", "每个订阅"), groups: [.init(id: "main", keys: [.visible,.alias,.source])]),
        .init(id: "privacy", title: .init("Data and privacy", "数据与隐私"), groups: [.init(id: "main", keys: [.projectNames,.retention,.clearCLI,.clearAppCache,.privacyStatement])]),
        .init(id: "about", title: .init("About", "关于"), groups: [.init(id: "main", keys: [.appVersion,.cliStatus,.architecture,.diagnostics,.feedback,.licenses])]),
    ])
}

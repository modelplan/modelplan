// SPDX-License-Identifier: MIT
import AppKit
import ModelPlanSettings

/// D57: the app is now one product named ModelPlan with its own bundle identifier. An app from before the
/// rename keeps running beside it (two menu-bar items, a stale login item), so on launch we ask the person
/// to quit and delete it. No migration: settings live in Application Support and are shared already.
@MainActor public enum LegacyAppNotice {
    /// The identifier the app used before the D57 rename.
    public static let legacyBundleIdentifier = "org.modelplan.community.swift.scaffold"

    public struct Message: Equatable, Sendable {
        public let title: String, body: String
    }

    /// The running app's own name comes from the system, so this build carries no old product name.
    public static func message(legacyName: String?, language: SettingsLanguage) -> Message {
        let name = legacyName.flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
        switch language {
        case .chinese:
            let old = name.map { "旧版应用“\($0)”" } ?? "旧版 ModelPlan 应用"
            return .init(title: "请退出并删除旧版应用",
                         body: "\(old)仍在运行。ModelPlan 现在是一个应用，设置和记录已保留。请退出旧版、把它移到废纸篓，"
                             + "并在“系统设置 › 通用 › 登录项”里删掉它的条目。")
        case .english:
            let old = name.map { "The older app “\($0)”" } ?? "An older ModelPlan app"
            return .init(title: "Quit and delete the older app",
                         body: "\(old) is still running. ModelPlan is now one app, and your settings and history are kept. "
                             + "Quit the older app, move it to the Trash and remove its entry in System Settings › General › Login Items.")
        }
    }

    /// Names of running pre-rename apps; injectable so the decision is testable without the window server.
    public static func runningLegacyNames(lookup: (String) -> [String?] = { identifier in
        NSRunningApplication.runningApplications(withBundleIdentifier: identifier).map(\.localizedName)
    }) -> [String?] {
        lookup(legacyBundleIdentifier)
    }

    /// Shows the notice once per launch when an old app is running. Never blocks launch on failure.
    public static func presentIfNeeded(language: SettingsLanguage? = nil, running: [String?]? = nil) {
        guard let first = (running ?? runningLegacyNames()).first else { return }
        let language = language ?? SettingsLanguage.resolve(preferredLanguages: Locale.preferredLanguages)
        let text = message(legacyName: first, language: language)
        let alert = NSAlert()
        alert.messageText = text.title
        alert.informativeText = text.body
        alert.alertStyle = .informational
        alert.addButton(withTitle: language == .chinese ? "好" : "OK")
        NSApplication.shared.activate()
        alert.runModal()
    }
}

// SPDX-License-Identifier: MIT
import AppKit
import ModelPlanCore

/// Presentation-only seam. Scheduling, CLI commands, window policy and event routing stay with the app.
@MainActor public protocol NativeSurfaceProvider {
    func makeOverview() -> any NativeOverviewSurface
}
@MainActor public protocol NativeOverviewSurface: AnyObject {
    var view: NSView { get }
    func render(snapshot: JoinedSnapshot?, diagnostics: StoreDiagnostics)
}

/// Root-layer language rule for text shown before a Settings choice is known (the neutral surface and the host):
/// the first zh* or en* entry of the macOS preferred-language list wins, English when neither appears.
/// Mirrors `SettingsLanguage.resolve` in the separate Settings package.
public enum NativeSurfaceLanguage {
    public static func prefersChinese(preferredLanguages: [String] = Locale.preferredLanguages) -> Bool {
        for raw in preferredLanguages {
            let tag = raw.lowercased().replacingOccurrences(of: "_", with: "-")
            if tag == "zh" || tag.hasPrefix("zh-") { return true }
            if tag == "en" || tag.hasPrefix("en-") { return false }
        }
        return false
    }
    public static func text(_ english: String, _ chinese: String, chinese isChinese: Bool) -> String { isChinese ? chinese : english }
}

/// Complete neutral default; no official art, private checkout, WebKit or RealityKit dependency.
@MainActor public struct NeutralSurfaceProvider: NativeSurfaceProvider {
    private let preferredLanguages: [String]
    public init(preferredLanguages: [String] = Locale.preferredLanguages) { self.preferredLanguages = preferredLanguages }
    public func makeOverview() -> any NativeOverviewSurface { NeutralOverview(chinese: NativeSurfaceLanguage.prefersChinese(preferredLanguages: preferredLanguages)) }
}
@MainActor private final class NeutralOverview: NativeOverviewSurface {
    let view = NSView()
    private let chinese: Bool
    private let status: NSTextField
    private let detail = NSTextField(wrappingLabelWithString: "")
    private func t(_ en: String, _ zh: String) -> String { NativeSurfaceLanguage.text(en, zh, chinese: chinese) }
    init(chinese: Bool) {
        self.chinese = chinese
        status = NSTextField(labelWithString: NativeSurfaceLanguage.text("Not connected", "未连接", chinese: chinese))
        let title = NSTextField(labelWithString: NativeSurfaceLanguage.text("ModelPlan Community", "ModelPlan 社区版", chinese: chinese))
        title.font = .systemFont(ofSize:18, weight:.semibold)
        let intel = NSTextField(wrappingLabelWithString:NativeSurfaceLanguage.text("Intel untested; 3D may stutter", "Intel 未测试，3D 效果可能卡顿", chinese: chinese))
        intel.font = .systemFont(ofSize:11); intel.textColor = .secondaryLabelColor
        let stack = NSStackView(views:[title,status,detail,intel])
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo:view.leadingAnchor,constant:20),
            stack.trailingAnchor.constraint(equalTo:view.trailingAnchor,constant:-20),
            stack.topAnchor.constraint(equalTo:view.topAnchor,constant:20),
            stack.bottomAnchor.constraint(lessThanOrEqualTo:view.bottomAnchor,constant:-20)])
    }
    func render(snapshot: JoinedSnapshot?, diagnostics: StoreDiagnostics) {
        guard let snapshot else {
            status.stringValue = diagnostics.personal == "not-loaded" ? t("Reading local snapshot…", "正在读取本地快照…") : t("Local data unavailable", "本地数据不可用")
            detail.stringValue = t("Read-only access only. No tool reading or permission is enabled here.", "仅只读访问。此处未启用任何读取器或权限。")
            return
        }
        status.stringValue = snapshot.presentation.actionable ? t("Read-only snapshot", "只读快照") : t("Unavailable or stale", "不可用或已过期")
        let quotas = snapshot.presentation.quotas.count, working = snapshot.presentation.live.filter(\.working).count
        detail.stringValue = t("\(quotas) quota windows · \(working) recently working sessions", "\(quotas) 个额度窗口 · \(working) 个近期工作会话")
        if snapshot.publication == nil { detail.stringValue += "\n" + t("Published recommendations unavailable", "已发布的推荐不可用") }
        if diagnostics.publicationWarning { detail.stringValue += "\n" + t("Using dated, last-good public data", "正在使用带日期的上次良好公开数据") }
    }
}

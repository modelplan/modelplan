// SPDX-License-Identifier: MIT
import Foundation

public enum SettingsConnectionPresentation {
    public static func presence(_ value: SettingsToolPresence) -> SettingsText {
        switch value {
        case .detected: return .init("Detected", "已检测到")
        case .notDetected: return .init("Not detected", "未检测到")
        case .unknown: return .init("Presence unknown", "是否存在未知")
        case .unsupported: return .init("Presence check unsupported", "不支持检测")
        }
    }
    public static func summary(_ value: SettingsConnectionToolState) -> SettingsText {
        let presence = self.presence(value.presence)
        let authorization: SettingsText
        switch value.authorization {
        case .allowed: authorization = .init("Shared consent allowed", "共享授权已允许")
        case .noConsent: authorization = .init("No shared consent", "尚无共享授权")
        case .denied: authorization = .init("Shared consent denied", "共享授权已拒绝")
        case .unknown: authorization = .init("Authorization unknown", "授权状态未知")
        case .notApplicable: authorization = .init("Authorization not applicable", "授权不适用")
        }
        let connection: SettingsText
        switch value.connection {
        case .connected: connection = .init("Connected", "已连接")
        case .notConnectedYet: connection = .init("Not connected yet", "尚未连接")
        case .off: connection = .init("Reader off", "读取器已关闭")
        case .unknown: connection = .init("Connection unknown", "连接状态未知")
        }
        let quota: SettingsText
        switch value.quota {
        case .available: quota = .init("Quota available", "额度可用")
        case .stale: quota = .init("Quota stale", "额度已过期")
        case .unavailable: quota = .init("Quota unavailable", "额度不可用")
        case .unknown: quota = .init("Quota unknown", "额度未知")
        case .notApplicable: quota = .init("Quota not applicable", "额度不适用")
        }
        let binding: SettingsText
        switch value.binding {
        case .unknown: binding = .init("Subscription unverified", "订阅未验证")
        case .verified: binding = .init("Subscription verified", "订阅已验证")
        }
        let parts = [presence, authorization, connection, quota, binding]
        return .init(parts.map(\.english).joined(separator: " · "), parts.map(\.chinese).joined(separator: " · "))
    }
    public static func confirmation(_ action: SettingsConnectionAction) -> SettingsText {
        switch action {
        case .allowStandardTools(let tools):
            let names = tools.map(\.title).joined(separator: ", ")
            return .init("Allow shared usage reading for \(names)? Checked tools are your choices, not permission already granted. Browser sessions are excluded.",
                         "允许共享读取 \(names) 的用量？勾选仅代表你的选择，不代表已授权；不包括浏览器会话。")
        case .connect(let tool, .browserSession):
            return .init("Enable advanced browser-session reading for \(tool.title)? This is a separate consent request. Detection is not permission. The runtime must explain and authorize any credential access before execution.",
                         "允许 \(tool.title) 的高级浏览器会话读取？这是单独的授权请求，检测结果不代表许可。运行时必须在执行前解释并取得任何凭据访问授权。")
        case .connect(let tool, .standard):
            return .init("Request shared reader consent for \(tool.title)? This changes CLI-owned consent. Detection and local Settings choices do not grant access.",
                         "请求 \(tool.title) 的共享读取授权？此操作会更改 CLI 管理的授权，检测结果和本地设置选择不授予访问权。")
        case .disconnect(let tool):
            return .init("Turn off shared reading for \(tool.title)? Existing subscription ownership evidence is retained.",
                         "关闭 \(tool.title) 的共享读取？已有的订阅归属证据会保留。")
        case .installPlugin(let tool):
            return .init("Request ModelPlan plugin installation for \(tool.title)? The runtime may change host configuration and use the network. Confirming here is a request, not proof of installation.",
                         "请求为 \(tool.title) 安装 ModelPlan 插件？运行时可能更改宿主配置并使用网络。此处确认仅表示请求，不证明安装完成。")
        }
    }
    public static func status(_ phase: SettingsConnectionPhase) -> SettingsText {
        switch phase {
        case .unavailable: return .init("Connection service unavailable", "连接服务不可用")
        case .idle: return .init("Detection, authorization, quota and subscription ownership are separate facts.", "检测、授权、额度与订阅归属是独立事实。")
        case .loading: return .init("Checking tools…", "正在检查工具…")
        case .awaitingConfirmation(let confirmation): return self.confirmation(confirmation.action)
        case .running: return .init("Request in progress…", "请求处理中…")
        case .cancelled: return .init("Request cancelled. An already accepted external action may still complete.", "请求已取消；已被外部接受的操作仍可能完成。")
        case .failed(let code): return .init("Request unavailable: " + code.rawValue, "请求不可用：" + code.rawValue)
        case .pluginResult(let result):
            switch result.status {
            case .installed: return .init("Plugin installed (reported by runtime)", "运行时报告插件已安装")
            case .planned: return .init("Installation planned; not installed", "已规划安装；尚未安装")
            case .instructions: return .init("Installation instructions available; not installed", "可提供安装说明；尚未安装")
            case .failed: return .init("Plugin installation failed", "插件安装失败")
            }
        }
    }
}

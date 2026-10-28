// SPDX-License-Identifier: MIT
import Foundation

public enum SettingsConnectionPresentation {
    public static func availability(_ value: SettingsConnectionAvailability) -> SettingsText? {
        switch value.reason {
        case .none: return nil
        case .componentMissing: return .init("The bundled usage component is missing. Check component status in About.", "随包用量组件缺失，请在关于中检查组件状态。")
        case .componentUpdating: return .init("The bundled usage component is updating. Check component status in About.", "随包用量组件正在更新，请在关于中检查组件状态。")
        case .componentUnverified: return .init("This build's consent component has not been verified. Check CLI support in About.", "此构建的授权组件尚未核验，请在关于中检查 CLI 支持。")
        case .unavailable: return .init("Usage consent is unavailable in this build. Check component status in About.", "此构建暂不能请求用量授权，请在关于中检查组件状态。")
        }
    }
    public static func readingMode(_ value: SettingsReadingMode) -> SettingsText {
        switch value {
        case .automatic: return .init("Automatic reading", "自动读取")
        case .passive: return .init("Passive reading", "被动读取")
        case .off: return .init("Reading disabled", "已停用读取")
        case .unknown: return .init("Not verified", "尚未核验")
        }
    }
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
        case .applyStandardConsent(let tools, let denied, let keychain):
            if !denied.isEmpty {
                let names = denied.map(\.title).joined(separator: ", ")
                return .init("Revoke access and Forget cached readings for \(names)? This deletes supported scoped readings; browser-cookie cleanup may remain pending and require separate manual approval.",
                             "撤销 \(names) 的权限并忘记缓存读数？这会删除可支持的范围内读数；浏览器缓存清理可能待完成，并需要单独手动批准。")
            }
            let names = tools.map(\.title).joined(separator: ", ")
            if !keychain.isEmpty {
                return .init("Allow shared usage reading for \(names), including Claude Code Keychain access? macOS may ask for approval. Omitted tools and other recorded Keychain choices stay unchanged; browser sessions are excluded.",
                             "允许共享读取 \(names) 的用量，并允许 Claude Code 访问钥匙串？macOS 可能请求批准。未选择工具和其他已记录的钥匙串选择保持不变，不包括浏览器会话。")
            }
            return .init("Allow shared usage reading for \(names)? These choices request consent, not activation. Omitted tools and recorded Keychain choices stay unchanged; browser sessions are excluded.",
                         "允许共享读取 \(names) 的用量？这些选择仅请求授权，不表示已启用读取；未选择工具和已记录的钥匙串选择保持不变，不包括浏览器会话。")
        case .connect(let tool, .browserSession):
            return .init("Enable advanced browser-session reading for \(tool.title)? This is a separate consent request. Detection is not permission. The runtime must explain and authorize any credential access before execution.",
                         "允许 \(tool.title) 的高级浏览器会话读取？这是单独的授权请求，检测结果不代表许可。运行时必须在执行前解释并取得任何凭据访问授权。")
        case .connect(let tool, .standard):
            return .init("Request shared reader consent for \(tool.title)? This changes CLI-owned consent. Detection and local Settings choices do not grant access.",
                         "请求 \(tool.title) 的共享读取授权？此操作会更改 CLI 管理的授权，检测结果和本地设置选择不授予访问权。")
        case .disconnect(let tool):
            return .init("Revoke access and Forget cached readings for \(tool.title)? This deletes its scoped cached readings. Other tools are kept.",
                         "撤销 \(tool.title) 的权限并忘记缓存读数？这会删除该工具范围内的缓存读数，保留其他工具。")
        case .installPlugin(let tool):
            return .init("Request ModelPlan plugin installation for \(tool.title)? The runtime may change host configuration and use the network. Confirming here is a request, not proof of installation.",
                         "请求为 \(tool.title) 安装 ModelPlan 插件？运行时可能更改宿主配置并使用网络。此处确认仅表示请求，不证明安装完成。")
        }
    }
    public static func status(_ phase: SettingsConnectionPhase) -> SettingsText {
        switch phase {
        case .unavailable: return .init("Usage consent is not connected in this build. Check CLI support in About.", "此构建尚未接通用量授权，请在关于中检查 CLI 支持。")
        case .idle: return .init("Detection, authorization, quota and subscription ownership are separate facts.", "检测、授权、额度与订阅归属是独立事实。")
        case .loading: return .init("Checking tools…", "正在检查工具…")
        case .awaitingConfirmation(let confirmation): return self.confirmation(confirmation.action)
        case .running: return .init("Request in progress…", "请求处理中…")
        case .cancelled: return .init("Request cancelled. An already accepted external action may still complete.", "请求已取消；已被外部接受的操作仍可能完成。")
        case .cleanupPending: return .init("Current permissions were read back. Cached-reading cleanup is still incomplete; review the manual cleanup instructions.", "已核验当前权限；缓存读数清理尚未完成，请查看手动清理说明。")
        case .consentRecordedReadingBlocked: return .init("Consent was recorded, but canonical reading mode still blocks activation.", "授权选择已记录，但规范读取模式仍阻止启用。")
        case .failed(let code):
            switch code {
            case .mutationReadbackUnavailable: return .init("The request was accepted, but current permissions could not be verified. No current permission or completed cleanup is assumed. Open About before retrying.", "请求已被接受，但无法核验当前权限；不认定当前授权或清理已完成。请在关于中查看说明后再重试。")
            case .cleanupReadbackUnavailable: return .init("The CLI reported unfinished cleanup, but current access could not be verified. Check detected tools and review the manual cleanup instructions.", "CLI报告清理未完成，但无法核验当前权限。请重新检查工具，并查看手动清理说明。")
            case .unavailable: return .init("This action is unavailable. Check CLI support and current permissions.", "此操作不可用，请检查 CLI 支持和当前权限。")
            case .stale: return .init("Tools or consent changed. Review the current text and choices before trying again.", "工具或授权已变化，请检查当前说明和选择后重试。")
            case .invalidResponse: return .init("The returned state could not be verified. No successful permission or installation is assumed.", "无法核验返回状态，不认定授权或安装成功。")
            case .cancelled: return .init("Request cancelled. Review current permissions before retrying.", "请求已取消，重试前请检查当前权限。")
            case .requestFailed: return .init("The component did not return a verified result. Open About to check the component and instructions before retrying.", "组件未返回可核验结果。请在关于中检查组件与说明，再决定是否重试。")
            }
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
